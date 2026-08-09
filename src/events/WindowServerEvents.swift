import Cocoa

/// The WindowServer event tap: AltTab's source of truth for window lifecycle, focus, geometry and Space
/// membership. Window state comes from SkyLight's notify-proc stream — immune to a busy or AX-lying app
/// (e.g. Electron throwing away its AX tree) — instead of Accessibility notifications. See
/// `SkyLight.framework.swift` for the underlying calls and `windowserver/` for the pure decision layer
/// (routing, decode, acquisition). AX is kept only for on-demand reads (subrole/title/tabs) and the actions.
///
/// Focus/MRU/selection authority lives in `WindowEventReducer` via `TrackedWindowStateBridge.dispatch`
/// (issue #57 / upstream `c14960bb`). The tap extracts payload, keeps opt-in bookkeeping, and feeds inputs;
/// it does not mutate `lastFocusOrder` itself.
class WindowServerEvents {
    /// WS-derived live window set; kept opted-in for per-window delivery (mandatory since Sequoia).
    private static var wsWindows = Set<CGWindowID>()
    private static var started = false
    /// Space switches emit storms of transient animation/snapshot windows; ignore create/destroy briefly
    /// around a Space transition so they aren't mistaken for real windows (RE "transition noise").
    private static var spaceTransitionUntil: TimeInterval = 0
    private static var inSpaceTransition: Bool { ProcessInfo.processInfo.systemUptime < spaceTransitionUntil }
    /// debounces the 1329/1401 Space-change burst into one settled handler (replaces SpacesEvents)
    private static var spaceChangeWorkItem: DispatchWorkItem?
    /// The window AltTab itself just focused (switcher selection / CLI --focus), consumed by the next
    /// didActivate of that app: the target is KNOWN, so the activation bumps it directly instead of divining
    /// it from a racy 808 / AX read (see `ActivationFocusResolver.onActivation`). Time-bounded and one-shot.
    private static var altTabInitiatedFocus: ActivationFocusResolver.AltTabFocusIntent?

    /// Whether this focus is worth recording is `ActivationFocusResolver.altTabIntentToRecord`'s decision (it
    /// carries the rationale); the tap only supplies the ambient facts and holds the slot. A focus that isn't
    /// worth recording leaves any pending intent alone — that one's activation may still be on its way.
    static func noteAltTabInitiatedFocus(_ wid: CGWindowID, _ pid: pid_t) {
        if let intent = ActivationFocusResolver.altTabIntentToRecord(
            wid: wid, pid: pid, frontmostPid: Applications.frontmostPid,
            at: ProcessInfo.processInfo.systemUptime) {
            altTabInitiatedFocus = intent
        }
    }

    static func observe() {
        guard !started else { return }
        started = true
        // Register our notify procs + opt into per-window notifications on the (AppKit-shared) main connection.
        // We deliberately DO NOT call `SLSConnectionDispatchNotificationsToMainQueueIfNotMainThread`: on the
        // shared connection it overrode AppKit's own coordinated-notification routing, so AppKit's
        // `activeSpaceChanged:` / appearance handlers started firing inline on the `_NSEventThread` (whichever
        // thread snarfs the datagram), crashing on their main-thread-only AppKit work. Our `notifyProc` hops to
        // main itself, so we don't need that call — letting AppKit keep its main-thread delivery.
        for n in WsEventRouting.Notification.allCases {
            SLSRegisterConnectionNotifyProc(CGS_CONNECTION, notifyProc, n.rawValue, nil)
        }
        wsWindows = Set(onScreenWindowIds())
        requestNotifications()
        Logger.info { "WindowServerEvents: tap installed on cid \(CGS_CONNECTION), opted in to \(wsWindows.count) windows" }
        // app activation + hidden state have no WindowServer equivalent (they're AppKit concepts) — NSWorkspace
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { note in
            if let app = runningApp(note) {
                let pid = app.processIdentifier
                Applications.frontmostPid = pid
                // Re-evaluate the "ignore shortcuts" exception the moment an app becomes frontmost, whatever
                // happens to the window MRU below (#5842 / AlTab #43). The window-focus paths also call this,
                // but they only fire once a window is resolved and bumped — an activation that emits no 808
                // and whose AX focused-window read fails or races (iTerm2 is AX-heavy) would never disable the
                // shortcut, and an app already frontmost when AlTab (re)launches never got a bump at all. This
                // app-activation floor restores the pre-WS-migration guarantee
                // (`checkIfShortcutsShouldBeDisabled(nil, app)` that closed upstream #5228). `focusedWindow`
                // may be stale/nil; it only feeds the `.whenFullscreen` rule, and the app itself is what the
                // `.always` rule keys off. Adapted from upstream e2db26d4.
                if let frontmostApp = Applications.findOrCreate(pid, false) {
                    App.checkIfShortcutsShouldBeDisabled(frontmostApp.focusedWindow, frontmostApp)
                }
                // The activation decisions — which windows the 808 storm may raise, whether an
                // AltTab-initiated target bumps directly, when the AX backstop runs — live in
                // `WindowEventReducer.appActivated` (+ `ActivationFocusResolver`); the timing/consume of the
                // one-shot AltTab-initiated intent stays here (it's this tap's own bookkeeping).
                let now = ProcessInfo.processInfo.systemUptime
                var knownTarget: CGWindowID? = nil
                if ActivationFocusResolver.altTabIntentApplies(altTabInitiatedFocus, activatedPid: pid, now: now) {
                    knownTarget = altTabInitiatedFocus?.wid
                    altTabInitiatedFocus = nil
                }
                TrackedWindowStateBridge.dispatch(.appActivated(pid: pid, now: now, altTabTargetWid: knownTarget))
            }
        }
        center.addObserver(forName: NSWorkspace.didHideApplicationNotification, object: nil, queue: .main) { note in
            if let app = runningApp(note) { applicationVisibilityChanged(app.processIdentifier, hidden: true) }
        }
        center.addObserver(forName: NSWorkspace.didUnhideApplicationNotification, object: nil, queue: .main) { note in
            if let app = runningApp(note) { applicationVisibilityChanged(app.processIdentifier, hidden: false) }
        }
        // Initial inventory + z-order seed run from `App.continueAppLaunchAfterPermissionsAreGranted` after
        // `Spaces.refresh` (the sweep bails on an empty Space list) — not from the tap install, which is
        // before the permission gate.
    }

    /// Non-capturing C callback. The WindowServer calls it on whichever thread snarfs the datagram (often the
    /// `_NSEventThread`, since we don't route this connection's notifications to the main queue — that broke
    /// AppKit's own coordinated handlers). The payload pointer is only valid for this call, so extract the
    /// integers synchronously, then hop to main ourselves before touching the model.
    private static let notifyProc: CGSConnectionNotifyProc = { event, data, len, _, _ in
        // Stamp the ARRIVAL, not the processing: the hop to main can queue behind our own work (a show, a
        // capture), which stretches the apparent gap between two events the WindowServer emitted in the same
        // instant. Every timing decision downstream — above all how long an activation's raise burst is
        // considered in flight — is only as good as this stamp.
        let at = ProcessInfo.processInfo.systemUptime
        var w0: UInt32 = 0, w8: UInt32 = 0
        var s0: UInt64 = 0
        if let d = data, len >= 4 { memcpy(&w0, d, 4) }
        if let d = data, len >= 8 { memcpy(&s0, d, 8) }
        if let d = data, len >= 12 { memcpy(&w8, d.advanced(by: 8), 4) }
        if Thread.isMainThread {
            handle(event, w0, s0, w8, at)
        } else {
            DispatchQueue.main.async { handle(event, w0, s0, w8, at) }
        }
    }

    private static func handle(_ event: UInt32, _ w0: UInt32, _ space: UInt64, _ widInSpace: UInt32,
                              _ at: TimeInterval) {
        guard let n = WsEventRouting.notification(event) else { return }
        switch n {
        case .activeSpaceChanged, .spaceCurrentChanged:
            spaceTransitionUntil = ProcessInfo.processInfo.systemUptime + 0.5
        case .windowCreated:
            if !inSpaceTransition {
                subscribe(w0)
            }
            // Brand-new / lastCreated bookkeeping lives in the reducer (`.windowCreated`).
        case .windowDestroyed:
            unsubscribe(w0)
        case .windowOrderedIn:
            // Our own panel's orderedIn is the true "pixels on screen" moment — it can trail the show's
            // main-thread work by ~500ms while the WindowServer settles a Space transition. Anchor the
            // key-repeat grace to it (see `SwitcherSession.panelBecameVisibleAt`).
            if let session = SwitcherSession.current, session.panelBecameVisibleAt == nil,
               let panel = TilesPanel.shared, panel.windowNumber > 0, w0 == CGWindowID(panel.windowNumber) {
                session.panelBecameVisibleAt = ProcessInfo.processInfo.systemUptime
            }
        default:
            break
        }
        // The raw notification is NOT logged here. Every one of them routes to the reducer, which logs the
        // input plus everything it decided as a single line (`TrackedWindowStateBridge.dispatch`).
        route(n, w0, space, widInSpace, at)
    }

    /// Turn a WindowServer notification into a `ReducerInput` and dispatch it through the reducer — which owns
    /// every decision this switch used to make inline (`WindowEventReducer.reduce`). Window events key off
    /// `w0` (the wid); Space-membership events (1325/1326) key off `widInSpace`/`space` from the payload.
    /// Runs on main.
    private static func route(_ n: WsEventRouting.Notification, _ w0: CGWindowID, _ space: CGSSpaceID,
                              _ widInSpace: CGWindowID, _ now: TimeInterval) {
        switch WsEventRouting.action(for: n) {
        case .bumpFocusOrder:
            TrackedWindowStateBridge.dispatch(.windowFocused(wid: w0, now: now))
        case .remove:
            TrackedWindowStateBridge.dispatch(.windowDestroyed(wid: w0))
        case .updateGeometry, .refreshVisibility:
            if n == .windowOrderedOut {
                TrackedWindowStateBridge.dispatch(.windowOrderedOut(wid: w0, inSpaceTransition: inSpaceTransition))
            } else if n == .windowOrderedIn {
                TrackedWindowStateBridge.dispatch(.windowOrderedIn(wid: w0, now: now, inSpaceTransition: inSpaceTransition))
            } else {
                TrackedWindowStateBridge.dispatch(.windowMovedOrResized(wid: w0, inSpaceTransition: inSpaceTransition))
            }
        case .updateSpaceMembership:
            TrackedWindowStateBridge.dispatch(.spaceMembershipChanged(wid: widInSpace, spaceId: space,
                added: n == .windowAddedToSpace, now: now, inSpaceTransition: inSpaceTransition))
        case .acquireAndDiscriminate:
            TrackedWindowStateBridge.dispatch(.windowCreated(wid: w0, now: now, inSpaceTransition: inSpaceTransition))
        case .spaceTransition:
            // 1329/1401 fire during the transition. Debounce, then refresh topology + reconcile once it settles.
            Logger.debug { "WS \(n) space=\(space)" }
            scheduleSpaceChangeHandling()
        }
    }

    /// Arm the hold-release re-check (the reducer's `scheduleHoldReleaseCheck` effect): the shell owns the
    /// timer (`recheckInterval`), the reducer owns the release decision (`.holdReleaseCheck`).
    static func armHoldReleaseCheck(_ wid: CGWindowID, attempt: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + recheckInterval) {
            TrackedWindowStateBridge.dispatch(.holdReleaseCheck(wid: wid, attempt: attempt))
        }
    }

    /// Arm the drag-out re-check (the reducer's `scheduleDragOutCheck` effect).
    static func armDragOutCheck(_ wid: CGWindowID, previousRepWid: CGWindowID, attempt: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + recheckInterval) {
            TrackedWindowStateBridge.dispatch(.dragOutCheck(wid: wid, previousRepWid: previousRepWid, attempt: attempt))
        }
    }

    /// AppKit app-activation is the backstop for a window-focus (808) that never arrives. Read the
    /// now-front app's focused window from AX; the gate and the bump belong to `.axFocusedWindowRead`.
    /// Also invoked by `TrackedWindowStateBridge` via `.bumpFocusViaAxBackstop`.
    static func bumpFocusOnActivation(_ pid: pid_t) {
        guard let app = Applications.findOrCreate(pid, false), let appAx = app.axUiElement else { return }
        AXCallScheduler.shared.schedule(key: "pid-\(pid)-activation-focus", pid: pid) {
            // Our own windows (e.g. Preferences) are tracked like any app's, so self activation gets the same MRU
            // bump; both AX reads here go through the pid-aware guards so the own-process ones run on main.
            guard let focused = try? appAx.attributes([kAXFocusedWindowAttribute], pid: pid).focusedWindow,
                  let wid = try? focused.cgWindowId(pid: pid) else { return }
            DispatchQueue.main.async {
                TrackedWindowStateBridge.dispatch(.axFocusedWindowRead(wid: wid, viaActivationBackstop: true))
            }
        }
    }

    /// 1329/1401 can fire several times during one Space transition; debounce so the topology refresh + UI
    /// reconcile run once, after it settles. The settled reaction is the reducer's `.spaceChangeSettled` branch.
    private static func scheduleSpaceChangeHandling() {
        spaceChangeWorkItem?.cancel()
        let work = DispatchWorkItem { TrackedWindowStateBridge.dispatch(.spaceChangeSettled) }
        spaceChangeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    /// Hold-release re-check interval shared with the pure reducer (`WindowEventReducer.holdReleaseMaxAttempts`).
    static let recheckInterval: TimeInterval = 0.4

    private static func runningApp(_ note: Notification) -> NSRunningApplication? {
        note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
    }

    /// Replaces AX's kAXApplicationHidden/Shown: "hidden" is an AppKit state the WindowServer doesn't own.
    private static func applicationVisibilityChanged(_ pid: pid_t, hidden: Bool) {
        guard let app = Applications.list.first(where: { $0.pid == pid }) else { return }
        app.isHidden = hidden
        App.refreshOpenUiAfterExternalEvent(Windows.list.filter { $0.application.pid == pid })
    }

    private static func onScreenWindowIds() -> [CGWindowID] {
        var buf = [CGWindowID](repeating: 0, count: 4096)
        var out: Int32 = 0
        guard SLSGetOnScreenWindowList(CGS_CONNECTION, 0, 4096, &buf, &out) == .success, out > 0 else { return [] }
        return Array(buf.prefix(Int(out)))
    }

    private static func requestNotifications() {
        var list = Array(wsWindows)
        guard !list.isEmpty else { return }
        SLSRequestNotificationsForWindows(CGS_CONNECTION, &list, Int32(list.count))
    }

    /// Opt the WindowServer into per-window notifications for a wid we now track — from ANY source, including
    /// the brute-force discovery of other-Space windows. Those never appear in SLSGetOnScreenWindowList, so
    /// before this they were tracked-but-unsubscribed: we got no destroy/geometry/order events for them (AX's
    /// per-app observers used to cover them, any Space). Coalesced so a discovery burst re-requests once.
    static func subscribe(_ wid: CGWindowID) {
        guard wsWindows.insert(wid).inserted else { return }
        scheduleRequestNotifications()
    }

    /// Drop a wid from the opt-in set when we stop tracking it (destroyed / removed).
    static func unsubscribe(_ wid: CGWindowID) {
        guard wsWindows.remove(wid) != nil else { return }
        scheduleRequestNotifications()
    }

    private static var requestNotificationsPending = false
    /// Coalesce re-requests to once per main-runloop tick — a discovery pass appends many windows at once.
    private static func scheduleRequestNotifications() {
        guard !requestNotificationsPending else { return }
        requestNotificationsPending = true
        DispatchQueue.main.async {
            requestNotificationsPending = false
            requestNotifications()
        }
    }
}
