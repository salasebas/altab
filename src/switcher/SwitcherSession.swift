import Cocoa

/// Holds all state scoped to a single switcher invocation: from when the user
/// first triggers the shortcut to when the panel is dismissed.
///
/// `current` is non-nil iff the switcher panel is conceptually shown to the
/// user. Lifetime is owned by `App.showUiOrCycleSelection` (creates) and
/// `App.hideUi` (destroys).
final class SwitcherSession {
    static var current: SwitcherSession?
    static var isActive: Bool { current != nil }
    /// The shortcut index of the currently-active session, or 0 when no session is active.
    /// Used by every per-shortcut effective preference read in `Appearance`, `TileView`, etc.
    static var activeShortcutIndex: Int { current?.shortcutIndex ?? 0 }

    var shortcutIndex: Int = 0
    var isFirstSummon: Bool = true
    var forceDoNothingOnRelease: Bool = false

    /// `systemUptime` at which the panel's pixels actually reached the screen this summon — set when our own
    /// panel's WindowServer `orderedIn` arrives (WindowServerEvents), which can lag the show's main-thread work
    /// by ~500ms when the WindowServer is busy settling a Space transition. The artificial key-repeat
    /// (`KeyRepeatTimer`) measures its initial-delay grace from here, not from arm time, so a slow show can't
    /// consume the grace and auto-advance the selection before the user has even seen the switcher.
    ///
    /// **Not set today**, and `panelShownAt` exists because of it: order-in is only delivered for wids in the
    /// per-window opt-in set (`WindowServerEvents.wsWindows`), which the panel is not in, and putting it there
    /// would feed our own panel's events into the reducer. Kept as the accurate correction should that change.
    var panelBecameVisibleAt: TimeInterval?
    /// `systemUptime` at which `TilesPanel.show()` ordered the panel front this summon. The anchor for the
    /// key-repeat grace that cannot go missing, where `panelBecameVisibleAt` can and does — without it every
    /// tick fell through to the 1s `missedVisibleSignalBudget` and hold-to-cycle started 1377ms in instead of
    /// the system's 417ms.
    var panelShownAt: TimeInterval?

    var selectedIndex: Int = 0
    var hoveredIndex: Int?
    var selectedTarget: String?
    var searchQuery: String = ""
}
