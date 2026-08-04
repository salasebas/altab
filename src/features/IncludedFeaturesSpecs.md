# Included features — Specs

Altab includes the complete local feature set. Availability never depends on a license, trial,
account, purchase, elapsed time, or network response. Preferences remain opt-in where they were
already user choices; removing access checks does not force a preference on.

## Feature matrix

| Feature | Stored/runtime path | Required behavior |
| --- | --- | --- |
| Search in the switcher | `SearchModeResolver.enableEditing` and `TilesView` | Search entry and editing always proceed. |
| Search on release | global and per-shortcut `shortcutStyle` | `.searchOnRelease` is returned unchanged and starts the session in search. |
| Auto size | global and per-shortcut `appearanceSize` | `.auto` is returned unchanged and reaches automatic layout. |
| App Icons and Titles | global and per-shortcut `appearanceStyle` | `.appIcons` and `.titles` are returned unchanged and reach appearance/layout code. |
| Additional shortcuts | shortcut indexes 1 through 8 | Every configured hold/next pair is registered and executed like shortcut 0. |
| Per-shortcut options | keyboard indexes 0 through 8 and gesture index 9 | Production `Preferences` storage reads filtering, ordering, grouping, tab handling, shortcut style, and all five effective overrides unchanged. |

## Regression expectations

- Tests inject an isolated `UserDefaults` suite into production `Preferences`, store all 16 per-shortcut settings, and read them back through production accessors for keyboard indexes `0...8` and gesture index `9`.
- Both App Icons and Titles are tested because they share one preference but have separate render paths.
- Every keyboard and gesture configuration index tests effective App Icons/Titles, Auto size, Search on Release, appearance theme, and preview overrides, plus the unset-override path back to stored global choices.
- A precomputed production `ShortcutActions` lookup recognizes every `holdShortcut` and `nextWindowShortcut` key without generating identifiers at execution time.
- The shortcut-count UI permits adding slots up to nine and never routes to an access prompt.
- Search-mode decisions contain no entitlement/access-denied branch.
- Existing preferences in the Altab defaults domain are preserved; no downgrade or reset runs.
