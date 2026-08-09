class CliEvents {
    static let portName = "\(App.bundleIdentifier).cli"

    static func observe() {
        var context = CFMessagePortContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        if let messagePort = CFMessagePortCreateLocal(nil, portName as CFString, handleEvent, &context, nil),
           let source = CFMessagePortCreateRunLoopSource(nil, messagePort, 0) {
            CFRunLoopAddSource(BackgroundWork.cliEventsThread.runLoop, source, .commonModes)
        } else {
            Logger.error { "Can't listen on message port. Is another \(App.name) already running?" }
            // TODO: should we quit or restart here?
            // It's complex since the app can be restarted sometimes,
            // and the new instance may coexist with the old for some duration
            // There is also the case of multiple instances at login
        }
    }

    /// Returning nil is not an error the caller can see: a NULL from a message-port callback arrives as a
    /// zero-byte reply, so the CLI prints an empty line and exits 0, exactly like a healthy call. Every
    /// way out therefore says in the log what it could not do.
    private static let handleEvent: CFMessagePortCallBack = { (_: CFMessagePort?, _: Int32, _ data: CFData?, _: UnsafeMutableRawPointer?) in
        Logger.debug { "" }
        guard let data, let message = String(data: data as Data, encoding: .utf8) else {
            Logger.error { "Failed to decode message" }
            return nil
        }
        Logger.info { message }
        let output = CliServer.executeCommandAndSendReponse(message)
        do {
            let reply = try CliServer.jsonEncoder.encode(output)
            Logger.debug { "replying \(reply.count) bytes to \(message): \(String(data: reply.prefix(60), encoding: .utf8) ?? "?")" }
            return Unmanaged.passRetained(reply as CFData)
        } catch {
            Logger.error { "Failed to encode the response to \(message): \(error)" }
            return nil
        }
    }
}

class CliServer {
    static let jsonEncoder = CliReplyResolver.makeJsonEncoder()
    static let error = CliReplyResolver.errorToken
    static let noOutput = CliReplyResolver.noOutputToken

    // main.sync is safe here: the main thread never synchronously waits on the CLI thread
    static func executeCommandAndSendReponse(_ rawValue: String) -> Codable {
        var output: Codable = ""
        DispatchQueue.main.sync {
            output = executeCommandAndSendReponse_(rawValue)
        }
        return output
    }

    private static func executeCommandAndSendReponse_(_ rawValue: String) -> Codable {
        if rawValue == "--list" {
            return JsonWindowList(windows: Windows.list
                .filter { !$0.isWindowlessApp }
                .map { JsonWindow(id: $0.cgWindowId, title: $0.title) }
            )
        }
        if rawValue == "--detailed-list" {
            return JsonWindowFullList(windows: Windows.list
                .filter { !$0.isWindowlessApp }
                .map {
                    JsonWindowFull(
                        id: $0.cgWindowId,
                        title: $0.title,
                        appName: $0.application.localizedName,
                        appBundleId: $0.application.bundleIdentifier,
                        spaceIndexes: $0.spaceIndexes,
                        lastFocusOrder: $0.lastFocusOrder,
                        creationOrder: $0.creationOrder,
                        isTabbed: $0.isTabbed,
                        isHidden: $0.isHidden,
                        isFullscreen: $0.isFullscreen,
                        isMinimized: $0.isMinimized,
                        isOnAllSpaces: $0.isOnAllSpaces,
                        position: $0.position,
                        size: $0.size
                    )
                }
            )
        }
        if rawValue == "--qa-state" {
            return qaState()
        }
        if rawValue.hasPrefix("--qa-mark=") {
            let mark = String(rawValue.dropFirst("--qa-mark=".count))
            Logger.info { "QAMARK \(mark)" }
            return noOutput
        }
        if rawValue.hasPrefix("--focus="),
           let id = CGWindowID(rawValue.dropFirst("--focus=".count)), let window = (Windows.list.first { $0.cgWindowId == id }) {
            window.focus()
            return noOutput
        }
        if rawValue.hasPrefix("--focusUsingLastFocusOrder="),
           let lastFocusOrder = Int(rawValue.dropFirst("--focusUsingLastFocusOrder=".count)), let window = (Windows.list.first { $0.lastFocusOrder == lastFocusOrder }) {
            window.focus()
            return noOutput
        }
        if rawValue.hasPrefix("--show="),
           let shortcutIndex = Int(rawValue.dropFirst("--show=".count)), (0..<Preferences.shortcutCount).contains(shortcutIndex) {
            App.showUi(shortcutIndex)
            return noOutput
        }
        // Counterpart to `--show=` for local QA harnesses. `--show=` opens the switcher without making
        // AlTab the active app, so Esc is not a reliable dismissal path for automation. `--hide` dismisses
        // without mutating window order or focus.
        if rawValue == "--hide" {
            App.hideUi()
            return noOutput
        }
        return error
    }

    /// Read-only snapshot of model + drawn tiles. Mutates nothing: `shown` is computed into a local, not
    /// written to `Window.shouldShowTheUser`, and the list is not sorted. Window titles and bundle ids are
    /// same-user local debug data (no network transmission).
    ///
    /// Adapted for the pre-reducer model: no `TabGroups` registry, latch, held-wids, or mirrored/borrowed
    /// synthetic flags. Groups are derived from `tabbedSiblingWids`; phantom is the live `isPhantom` flag.
    private static func qaState() -> Codable {
        let filters = WindowFilters.snapshot()
        let frontmostPid = Applications.frontmostPid
        let visibleSpaceIds = Spaces.visibleSpaces
        let windows = Windows.list.enumerated().map { (i, w) -> QaWindow in
            let wid = w.cgWindowId
            let shown = WindowFilterResolver.shouldShow(
                w.state, w.application.state,
                onlyFrontmostApp: filters.appsToShow == .active,
                excludeFrontmostApp: filters.appsToShow == .nonActive,
                hideHidden: filters.showHiddenWindows == .hide,
                hideWindowless: filters.showWindowlessApps == .hide,
                hideFullscreen: filters.showFullscreenWindows == .hide,
                hideMinimized: filters.showMinimizedWindows == .hide,
                onlyVisibleSpaces: filters.spacesToShow == .visible,
                onlyNonVisibleSpaces: filters.spacesToShow == .nonVisible,
                onlyPreferredScreen: filters.screensToShow == .showingAltTab,
                separateTabs: filters.groupTabs == .separateWindows,
                frontmostPid: frontmostPid,
                visibleSpaceIds: visibleSpaceIds,
                exceptions: filters.exceptions,
                isOnPreferredScreen: w.isOnScreen(NSScreen.preferred))
            return QaWindow(
                index: i,
                wid: wid,
                title: w.title,
                app: w.application.runningApplication.localizedName,
                bundleId: w.application.bundleIdentifier,
                pid: w.application.pid,
                shown: shown,
                tabbed: w.isTabbed,
                siblings: w.tabbedSiblingWids,
                isGroupRepresentative: w.tabbedSiblingWids != nil && !w.isTabbed,
                phantom: w.isPhantom,
                fullscreen: w.isFullscreen,
                minimized: w.isMinimized,
                appHidden: w.isHidden,
                windowless: w.isWindowlessApp,
                focused: w.application.pid == frontmostPid && w.application.focusedWindow === w,
                isMainWindow: w.state.isMainWindow,
                spaceIds: w.spaceIds,
                spaceIndexes: w.spaceIndexes,
                lastFocusOrder: w.lastFocusOrder,
                creationOrder: w.creationOrder,
                position: w.position,
                size: w.size,
                axHash: w.axUiElement.map { Int(CFHash($0) % 100_000) })
        }
        return QaState(
            at: Date().timeIntervalSince1970,
            frontmostPid: frontmostPid,
            frontmostApp: NSWorkspace.shared.frontmostApplication?.localizedName,
            currentSpaceId: Spaces.currentSpaceId,
            currentSpaceIndex: Spaces.currentSpaceIndex,
            visibleSpaceIds: visibleSpaceIds,
            allSpaces: Spaces.idsAndIndexes.map { QaSpace(id: $0.0, index: $0.1) },
            switcherVisible: SwitcherSession.isActive,
            selectedIndex: SwitcherSession.current?.selectedIndex,
            recentlyCreatedWids: Array(Windows.recentlyCreatedWindows),
            apps: Applications.list.map {
                QaApp(pid: $0.pid, name: $0.runningApplication.localizedName, bundleId: $0.bundleIdentifier, hidden: $0.isHidden)
            },
            groups: derivedTabGroups(),
            windows: windows,
            tiles: renderedTiles())
    }

    /// Cluster windows that share the same `tabbedSiblingWids` set. Representative is the non-tabbed member
    /// when present (active tab). No live `TabGroups` registry exists until the reducer port lands.
    private static func derivedTabGroups() -> [QaGroup] {
        var byKey = [String: (members: [CGWindowID], representative: CGWindowID?)]()
        for w in Windows.list {
            guard let siblings = w.tabbedSiblingWids, siblings.count >= 2 else { continue }
            let key = siblings.sorted().map(String.init).joined(separator: ",")
            var entry = byKey[key] ?? (members: siblings.sorted(), representative: nil)
            if !w.isTabbed, let wid = w.cgWindowId {
                entry.representative = wid
            }
            byKey[key] = entry
        }
        return byKey.values.enumerated().map { i, g in
            QaGroup(groupId: i, members: g.members, representative: g.representative)
        }.sorted { $0.groupId < $1.groupId }
    }

    /// What the tiles on screen are currently showing, as opposed to what the model says they should show.
    /// The two only match if every model flip that happens while the panel is open also repaints — a model
    /// change without repaint is a bug no model-side oracle can see. Read off laid-out `TileView`s.
    private static func renderedTiles() -> [QaTile] {
        guard SwitcherSession.isActive else { return [] }
        return TilesView.recycledViews.enumerated().compactMap { (i, view) -> QaTile? in
            guard view.frame != .zero, let window = view.window_ else { return nil }
            let icons = view.statusIcons.icons
            return QaTile(index: i, wid: window.cgWindowId, title: window.title,
                app: window.application.runningApplication.localizedName,
                minimizedIcon: icons[StatusIconsView.minimizedIdx].visible,
                fullscreenIcon: icons[StatusIconsView.fullscreenIdx].visible,
                appHiddenIcon: icons[StatusIconsView.hiddenIdx].visible,
                spaceIcon: icons[StatusIconsView.spaceIdx].visible)
        }
    }

    private struct QaState: Codable {
        var at: TimeInterval
        var frontmostPid: pid_t?
        var frontmostApp: String?
        var currentSpaceId: UInt64
        var currentSpaceIndex: Int
        var visibleSpaceIds: [UInt64]
        var allSpaces: [QaSpace]
        var switcherVisible: Bool
        var selectedIndex: Int?
        var recentlyCreatedWids: [CGWindowID]
        var apps: [QaApp]
        var groups: [QaGroup]
        var windows: [QaWindow]
        /// empty while the switcher is closed — there is nothing drawn to report
        var tiles: [QaTile]
    }

    private struct QaTile: Codable {
        var index: Int
        var wid: CGWindowID?
        var title: String
        var app: String?
        var minimizedIcon: Bool
        var fullscreenIcon: Bool
        var appHiddenIcon: Bool
        var spaceIcon: Bool
    }

    private struct QaSpace: Codable {
        var id: UInt64
        var index: Int
    }

    private struct QaApp: Codable {
        var pid: pid_t
        var name: String?
        var bundleId: String?
        var hidden: Bool
    }

    private struct QaGroup: Codable {
        var groupId: Int
        var members: [CGWindowID]
        var representative: CGWindowID?
    }

    private struct QaWindow: Codable {
        var index: Int
        var wid: CGWindowID?
        var title: String
        var app: String?
        var bundleId: String?
        var pid: pid_t
        var shown: Bool
        var tabbed: Bool
        var siblings: [CGWindowID]?
        var isGroupRepresentative: Bool
        var phantom: Bool
        var fullscreen: Bool
        var minimized: Bool
        var appHidden: Bool
        var windowless: Bool
        var focused: Bool
        var isMainWindow: Bool
        var spaceIds: [UInt64]
        var spaceIndexes: [Int]
        var lastFocusOrder: Int
        var creationOrder: Int
        var position: CGPoint?
        var size: CGSize?
        var axHash: Int?
    }

    private struct JsonWindowList: Codable {
        var windows: [JsonWindow]
    }

    private struct JsonWindow: Codable {
        var id: CGWindowID?
        var title: String
    }

    private struct JsonWindowFullList: Codable {
        var windows: [JsonWindowFull]
    }

    private struct JsonWindowFull: Codable {
        var id: CGWindowID?
        var title: String
        var appName: String?
        var appBundleId: String?
        var spaceIndexes: [SpaceIndex]
        var lastFocusOrder: Int
        var creationOrder: Int
        var isTabbed: Bool
        var isHidden: Bool
        var isFullscreen: Bool
        var isMinimized: Bool
        var isOnAllSpaces: Bool
        var position: CGPoint?
        var size: CGSize?
    }
}

class CliClient {
    static func detectCommand() -> String? {
        CliReplyResolver.detectCommand(from: CommandLine.arguments)
    }

    /// Every failure exits non-zero and says which one it was, on stderr so it cannot be mistaken for the
    /// answer. Silence on stdout with exit 0 means one thing only: the command ran and has no output.
    static func sendCommandAndProcessResponse(_ command: String) {
        do {
            let serverPortClient = try CFMessagePortCreateRemote(nil, CliEvents.portName as CFString).unwrapOrThrow()
            let data = try command.data(using: .utf8).unwrapOrThrow()
            var returnData: Unmanaged<CFData>?
            let status = CFMessagePortSendRequest(serverPortClient, 0, data as CFData, 2, 2, CFRunLoopMode.defaultMode.rawValue, &returnData)
            let responseData = returnData?.takeRetainedValue() as Data?
            switch CliReplyResolver.classify(command: command, responseData: responseData, portStatus: status, appName: App.name) {
            case .output(let response):
                print(response)
                exit(0)
            case .silentSuccess:
                exit(0)
            case .failure(let message):
                fail(message)
            }
        } catch {
            fail("\(App.name).app needs to be running for CLI commands to work")
        }
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        exit(1)
    }
}
