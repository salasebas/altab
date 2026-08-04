import Cocoa
import ShortcutRecorder

// Stubs for test-target sources that render symbol-backed controls. The real Symbols enum and
// NSImage.fromSymbol live in TileFontIconView.swift and HelperExtensions.swift respectively, neither
// of which is in the test target's source membership. Tests never render an icon, so a minimal stub
// satisfying the signatures is enough.
enum Symbols: String {
    case stub = ""
    case cursorarrowRays
    case laptopcomputer
    case magnifyingglass
    case moonFill
    case moonphaseLastQuarterInverse
    case moonphaseWaningCrescentInverse
    case moonphaseWaningGibbousInverse
    case pauseRectangle
    case sparkles
    case sunMax
}

extension NSImage {
    static func fromSymbol(_ symbol: Symbols, pointSize: CGFloat, rotated180: Bool = false) -> NSImage {
        let image = NSImage()
        image.isTemplate = true
        return image
    }
}

// Test-target reimplementation of `SettingsSearchIndex`'s inline-registration API. The production
// type lives in the app target but its `sheetSearchableStrings(forButtonAction:)` references the
// sheet classes + AppearanceTab/ControlsTab selectors, which would drag the whole settings window
// into the test target. The indexing surface that the row/label widgets actually call
// (`registerString` / `registerStrings` / `registerTarget`) and that the editor tests drive
// (`indexed { ... }`) is small and self-contained, so we mirror just that here. Keep in sync with
// the production version's behavior for these five members.
enum SettingsSearchIndex {
    static var current: Builder?

    final class Builder {
        var strings: [String] = []
        var targets: [SettingsSearchHighlightTarget] = []
    }

    static func indexed<T>(_ build: () -> T) -> (result: T, builder: Builder) {
        let previous = current
        let builder = Builder()
        current = builder
        defer { current = previous }
        let result = build()
        return (result, builder)
    }

    static func registerString(_ s: String?) {
        guard let current, let s else { return }
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { current.strings.append(trimmed) }
    }

    static func registerStrings(_ strings: [String]) {
        guard let current else { return }
        for s in strings {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { current.strings.append(t) }
        }
    }

    static func registerTarget(_ target: SettingsSearchHighlightTarget?) {
        guard let target, let current else { return }
        current.targets.append(target)
    }
}

class Appearance {
    static var searchMatchHighlightColor: NSColor = .yellow
    static var searchMatchForegroundColor: NSColor = .black
}

// Minimal stubs so `TableGroupView.swift` / `SidebarList.swift` compile in the test target without
// dragging in `AppearanceTab` (which `IllustratedImageThemeView` lives in) or the full
// `SettingsWindow`. Tests never instantiate these — they only need the symbols to resolve.
enum SettingsWindow {
    static let contentWidth = CGFloat(700)
}

class IllustratedImageThemeView: NSView {}

// `EventClosure` is declared in `LabelAndControl.swift` (app target only). `TableGroupView`
// uses it in its row-builder signatures, so mirror the typealias here.
typealias EventClosure = (NSEvent, NSView) -> Void

// Helpers from `HelperExtensions.swift` (app target only) that `TableGroupView` /
// `SettingsSearchHighlight` reference. The test never exercises their visual behavior — it only
// needs the symbols to resolve — so these are functional-but-minimal stand-ins.
func noAnimation<T: CALayer>(_ make: () -> T) -> T {
    return make()
}

// 10.13-safe stand-ins (the test target's deployment floor matches the app's 10.13). The real
// extensions in HelperExtensions.swift `#available`-gate the 10.14+ system colors; the tests
// never inspect these values, so plain 10.13-era colors suffice.
extension NSColor {
    class var systemAccentColor: NSColor { .alternateSelectedControlColor }
    class var tableBorderColor: NSColor { .gridColor }
    class var tableBackgroundColor: NSColor { .windowBackgroundColor }
    class var tableSeparatorColor: NSColor { .gridColor }
    class var tableHoverColor: NSColor { .selectedControlColor }
}

extension NSView {
    func addOrUpdateConstraint(_ anchor: NSLayoutDimension, _ constant: CGFloat) {
        if let constraint = (constraints.first { $0.firstAnchor == anchor && $0.secondAnchor == nil }) {
            constraint.constant = constant
        } else {
            anchor.constraint(equalToConstant: constant).isActive = true
        }
    }
}

enum SearchKeyResult {
    case handled
    case passToField
    case passToShortcuts
}

class TilesViewMock {
    var isSearchEditing = false
    func handleSearchEditingKeyDown(_ event: NSEvent) -> SearchKeyResult { return .passToField }
}

class TilesPanelMock {
    var tilesView = TilesViewMock()
    var isKeyWindow = false
}

class App {
    class AppMock {
        var tilesPanel = TilesPanelMock()
    }
    static let app = AppMock()
    static let bundleIdentifier = "dev.salasebas.Altab"
    static var cycleDirections = [Direction]()
    static var focusedShortcutIndices = [Int]()
    static var shownShortcutIndices = [Int]()

    static func focusTarget() {
        guard let session = SwitcherSession.current else { return }
        focusedShortcutIndices.append(session.shortcutIndex)
        ControlsTab.shortcutsActionsTriggered.append(Preferences.indexToName("holdShortcut", session.shortcutIndex))
        SwitcherSession.current = nil
    }

    static func previousWindowShortcutWithRepeatingKey() {
        ControlsTab.shortcutsActionsTriggered.append("previousWindowShortcut")
    }

    static func cycleSelection(_ direction: Direction, allowWrap: Bool = true) {
        cycleDirections.append(direction)
    }

    static func hideUi(_ keepPreview: Bool = false) {
        ControlsTab.shortcutsActionsTriggered.append("cancelShortcut")
        SwitcherSession.current = nil
    }

    static func showUiOrCycleSelection(_ shortcutIndex: Int, _ forceDoNothingOnRelease: Bool) {
        let session = SwitcherSession.current ?? SwitcherSession()
        session.shortcutIndex = shortcutIndex
        SwitcherSession.current = session
        shownShortcutIndices.append(shortcutIndex)
        ControlsTab.shortcutsActionsTriggered.append(Preferences.indexToName("nextWindowShortcut", shortcutIndex))
    }

    static func resetShortcutActionCalls() {
        cycleDirections = []
        focusedShortcutIndices = []
        shownShortcutIndices = []
    }
}

enum Direction {
    case right
    case left
    case leading
    case trailing
    case up
    case down
}

class PreferencesEvents {
    static func preferenceChanged(_ key: String) {}
}

class TilesPanel {
    static let shared = TilesPanel()
    var isKeyWindow: Bool {
        get { App.app.tilesPanel.isKeyWindow }
        set { App.app.tilesPanel.isKeyWindow = newValue }
    }
}

class TilesView {
    static var searchMode = SearchMode.off

    static var isSearchEditing: Bool {
        get { App.app.tilesPanel.tilesView.isSearchEditing }
        set { App.app.tilesPanel.tilesView.isSearchEditing = newValue }
    }

    static func handleSearchEditingKeyDown(_ event: NSEvent) -> SearchKeyResult {
        return App.app.tilesPanel.tilesView.handleSearchEditingKeyDown(event)
    }

    static func disableSearchMode() {
        searchMode = .off
    }

    static func toggleSearchModeFromShortcut() {
        searchMode = searchMode == .off ? .editing : .off
    }
}

final class WindowApplication {
    func quit() {
        ControlsTab.shortcutsActionsTriggered.append("quitAppShortcut")
    }

    func hideOrShow() {
        ControlsTab.shortcutsActionsTriggered.append("hideShowAppShortcut")
    }
}

final class Window {
    let application = WindowApplication()

    func close() {
        ControlsTab.shortcutsActionsTriggered.append("closeWindowShortcut")
    }

    func minDemin() {
        ControlsTab.shortcutsActionsTriggered.append("minDeminWindowShortcut")
    }

    func toggleFullscreen() {
        ControlsTab.shortcutsActionsTriggered.append("toggleFullscreenWindowShortcut")
    }
}

enum Windows {
    static var window: Window? = Window()

    static func selectedWindow() -> Window? {
        window
    }
}

class ControlsTab {
    // Fidelity gaps vs production — tests relying on this registry inherit them, so override
    // entries explicitly when they matter (two conflict-detector bugs hid behind them already):
    // 1. every hold is the same ⌥, so a conflict that should be found via a shortcut's OWN hold
    //    is accidentally also found via the other holds (production defaults share this shape;
    //    use a unique hold like ⌃ to isolate same-index detection);
    // 2. nextWindowShortcut/nextWindowShortcut2 are stored RAW (⇥, `) while production stores
    //    them COMBINED with their hold (⌥⇥, ⌥`).
    static let defaultShortcuts = [
        "holdShortcut": ATShortcut(Shortcut(keyEquivalent: "⌥")!, "holdShortcut", .global, .up, 0),
        "holdShortcut2": ATShortcut(Shortcut(keyEquivalent: "⌥")!, "holdShortcut2", .global, .up, 1),
        "holdShortcut3": ATShortcut(Shortcut(keyEquivalent: "⌥")!, "holdShortcut3", .global, .up, 2),
        "nextWindowShortcut": ATShortcut(Shortcut(keyEquivalent: "⇥")!, "nextWindowShortcut", .global, .down),
        "nextWindowShortcut2": ATShortcut(Shortcut(keyEquivalent: "`")!, "nextWindowShortcut2", .global, .down),
        "→": ATShortcut(Shortcut(keyEquivalent: "→")!, "→", .local, .down),
        "←": ATShortcut(Shortcut(keyEquivalent: "←")!, "←", .local, .down),
        "↑": ATShortcut(Shortcut(keyEquivalent: "↑")!, "↑", .local, .down),
        "↓": ATShortcut(Shortcut(keyEquivalent: "↓")!, "↓", .local, .down),
//        "vimCycleRight": ATShortcut(Shortcut(keyEquivalent: "l")!, "vimCycleRight", .local, .down),
//        "vimCycleLeft": ATShortcut(Shortcut(keyEquivalent: "h")!, "vimCycleLeft", .local, .down),
//        "vimCycleUp": ATShortcut(Shortcut(keyEquivalent: "k")!, "vimCycleUp", .local, .down),
//        "vimCycleDown": ATShortcut(Shortcut(keyEquivalent: "j")!, "vimCycleDown", .local, .down),
        "focusWindowShortcut": ATShortcut(Shortcut(keyEquivalent: " ")!, "focusWindowShortcut", .local, .down),
        "previousWindowShortcut": ATShortcut(Shortcut(keyEquivalent: "⇧")!, "previousWindowShortcut", .local, .down),
        "cancelShortcut": ATShortcut(Shortcut(keyEquivalent: "⎋")!, "cancelShortcut", .local, .down),
        "searchShortcut": ATShortcut(Shortcut(keyEquivalent: "s")!, "searchShortcut", .local, .down),
        "closeWindowShortcut": ATShortcut(Shortcut(keyEquivalent: "w")!, "closeWindowShortcut", .local, .down),
        "minDeminWindowShortcut": ATShortcut(Shortcut(keyEquivalent: "m")!, "minDeminWindowShortcut", .local, .down),
        "toggleFullscreenWindowShortcut": ATShortcut(Shortcut(keyEquivalent: "f")!, "toggleFullscreenWindowShortcut", .local, .down),
        "quitAppShortcut": ATShortcut(Shortcut(keyEquivalent: "q")!, "quitAppShortcut", .local, .down),
        "hideShowAppShortcut": ATShortcut(Shortcut(keyEquivalent: "h")!, "hideShowAppShortcut", .local, .down),
    ]
    static var shortcuts = defaultShortcuts

    static func executeAction(_ action: String) {
        shortcutsActionsTriggered.append(action)
        if action.starts(with: "holdShortcut") {
            SwitcherSession.current = nil
        }
        if action.starts(with: "nextWindowShortcut") {
            let session = SwitcherSession.current ?? {
                let new = SwitcherSession()
                SwitcherSession.current = new
                return new
            }()
            session.shortcutIndex = Preferences.nameToIndex(action)
        }
    }

    static var shortcutsActionsTriggered: [String] = []
}

class KeyRepeatTimer {
    static func stopTimerForRepeatingKey(_ shortcutName: String) {
    }
}

class Logger {
    static func debug(_ message: @escaping () -> Any?, file: String = #file, function: String = #function, line: Int = #line, context: Any? = nil) {}
    static func info(_ message: @escaping () -> Any?, file: String = #file, function: String = #function, line: Int = #line, context: Any? = nil) {}
    static func warning(_ message: @escaping () -> Any?, file: String = #file, function: String = #function, line: Int = #line, context: Any? = nil) {}
    static func error(_ message: @escaping () -> Any?, file: String = #file, function: String = #function, line: Int = #line, context: Any? = nil) {}
}

class ModifierFlags {
    static var current: NSEvent.ModifierFlags = []
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension CaseIterable where Self: Equatable {
    var index: Int {
        Self.allCases.distance(from: Self.allCases.startIndex, to: Self.allCases.firstIndex(of: self)!)
    }

    var indexAsString: String {
        String(index)
    }
}

final class ConcurrentMap<K: Hashable, V>: @unchecked Sendable {
    private var map = [K: V]()
    private let lock = NSLock()

    @discardableResult
    func withLock<T>(_ block: (inout [K: V]) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return block(&map)
    }
}
