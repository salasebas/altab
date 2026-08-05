# Included features — Specs

AlTab includes the complete local feature set. Availability never depends on a license, trial,
account, purchase, elapsed time, or network response. Preferences remain opt-in where they were
already user choices; removing access checks does not force a preference on.

## Feature matrix

| Feature | Stored/runtime path | Required behavior |
| --- | --- | --- |
| Search in the switcher | `SearchModeResolver.enableEditing` and `TilesView` | Search entry and editing always proceed. |
| Search on release | global and per-shortcut `shortcutStyle`; `Preferences.effectiveShortcutStyle` from `App` into `TilesView.startSearchSession` | `.searchOnRelease` is returned unchanged and starts the session in search. |
| Auto size | global and per-shortcut `appearanceSize`; `Preferences.effectiveAppearanceSize` from `TilesView.updateItemsAndLayout` | `.auto` is returned unchanged and selects automatic layout. |
| App Icons and Titles | global and per-shortcut `appearanceStyle`; `Preferences.effectiveAppearanceStyle` from `Appearance` and `TileView.applyCurrentStyle` | `.appIcons` and `.titles` are returned unchanged for layout and rendering. |
| Additional shortcuts | shortcut indexes 1 through 8; `Preferences.shortcutRegistrationPlan` from `ControlsTab`; `ShortcutActions.execute` | Every configured hold/next pair is registered and executed like shortcut 0. |
| Per-shortcut options | keyboard indexes 0 through 8 and gesture index 9 | Production `Preferences` storage reads filtering, ordering, grouping, tab handling, shortcut style, and all five effective overrides unchanged. |

## Regression expectations

- Tests inject an isolated `UserDefaults` suite into production `Preferences`, store all 16 per-shortcut settings, and read them back through production accessors for keyboard indexes `0...8` and gesture index `9`.
- One deferred defaults schema supplies both `ownedKeys` and registered default values. Its unit contract proves key collection does not evaluate values and that materialized keys cannot diverge; the production inventory test covers all indexed trigger and per-shortcut keys.
- Both App Icons and Titles are tested because they share one preference but have separate render paths.
- Every keyboard and gesture configuration index tests effective App Icons/Titles, Auto size, Search on Release, appearance theme, and preview overrides, plus the unset-override path back to stored global choices.
- Production Preferences tests read the stored global and override choices used by session start, automatic layout, and appearance rendering. The source guard pins those direct AppKit call sites where end-to-end unit construction is impractical.
- A precomputed production `ShortcutActions` lookup recognizes every `holdShortcut` and `nextWindowShortcut` key without generating identifiers at execution time, and compiled tests execute all 18 production routes.
- The production registration plan proves all configured hold/next pairs through shortcut index 8 remain active while all 18 supported keys are registered; the shortcut-count contract permits adding through slot 9 and never routes to an access prompt. The source guard pins both contracts to `ControlsTab`.
- Search-mode decisions contain no entitlement/access-denied branch.
- Existing preferences in the AlTab defaults domain are preserved; no downgrade or reset runs.
