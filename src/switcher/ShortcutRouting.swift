enum SwitcherShortcutAction: Equatable {
    case focusTarget
    case showOrCycle(index: Int)
}

extension ShortcutActions {
    private static let switcherActionsById: [String: SwitcherShortcutAction] = {
        var actions = [String: SwitcherShortcutAction](minimumCapacity: IncludedFeatures.keyboardShortcutCount * 2)
        for index in IncludedFeatures.keyboardShortcutIndices {
            actions[Preferences.indexToName("holdShortcut", index)] = .focusTarget
            actions[Preferences.indexToName("nextWindowShortcut", index)] = .showOrCycle(index: index)
        }
        return actions
    }()

    static func switcherAction(_ id: String) -> SwitcherShortcutAction? {
        switcherActionsById[id]
    }
}
