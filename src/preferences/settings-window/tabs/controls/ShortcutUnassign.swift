import Foundation

/// Pure kernel for the conflict dialog's "Unassign existing shortcut and continue".
///
/// Upstream issue #5897 / AlTab #48: accepting a Vim or arrow-key conflict used to clear only the
/// in-memory registry (and a live recorder if one happened to be on screen). Shortcuts that live in
/// lazily built sheets — e.g. default `hideShowAppShortcut = H` — kept their preference, so the next
/// launch re-registered the conflict and disabled the newly enabled navigation setting.
///
/// Production routes both resolvers through `ControlsTab.unassignShortcut`, which uses this kernel to
/// pick the preference key and write `nil` through `Preferences` so the normal change pipeline
/// reconciles registry and UI. Cancel must never call `clearPreference`.
enum ShortcutUnassign {
    /// Preference key that must be cleared when resolving a conflict for registry id `id`.
    ///
    /// For a numbered shortcut's Trigger, the hold cannot stand alone, so unassign always clears the
    /// "and press" (`nextWindowShortcut`) part — whether the conflict was reported against the hold
    /// or the press.
    static func preferenceKey(forConflictId id: String) -> String {
        if id.hasPrefix("holdShortcut") || id.hasPrefix("nextWindowShortcut") {
            return Preferences.indexToName("nextWindowShortcut", Preferences.nameToIndex(id))
        }
        return id
    }

    /// Persist the unassignment. Call only when the user accepts the conflict dialog.
    /// Returns the preference key that was cleared so a displayed recorder (if any) can sync.
    @discardableResult
    static func clearPreference(forConflictId id: String, notify: Bool = true) -> String {
        let key = preferenceKey(forConflictId: id)
        Preferences.setShortcut(key, nil, notify)
        return key
    }
}
