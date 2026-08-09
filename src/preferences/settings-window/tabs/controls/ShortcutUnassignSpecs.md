# ShortcutUnassign — Specs

## Summary

`ShortcutUnassign` is the pure kernel behind conflict-dialog "Unassign existing shortcut and continue"
for Vim keys and arrow keys (upstream #5897 / AlTab #48). Accepting must clear the **stored
preference**, not only the runtime registry, so a shortcut whose recorder lives in a lazily built
sheet (e.g. default `hideShowAppShortcut = H`) stays unassigned after relaunch and does not disable
the newly enabled navigation setting.

Production `ControlsTab.unassignShortcut` calls this kernel, then nils any displayed recorder for the
same preference key. Cancel never calls `clearPreference`, so neither preference nor registration
changes.

## Behavior & edge cases

- Static / "when active" ids (`hideShowAppShortcut`, …) clear that same preference key.
- Numbered Trigger ids (`holdShortcut`, `nextWindowShortcut`, `holdShortcut2`, …) always clear the
  matching `nextWindowShortcut` ("and press") key — never the hold alone.
- Clearing writes `nil` through `Preferences.setShortcut` so the value survives cache invalidation
  and process relaunch (registered defaults no longer win).
- Hidden recorder (sheet never opened / no entry in `shortcutControls`): preference still clears.
- Visible recorder: the returned preference key is the control id to nil on the live recorder.
- Cancel: do not call `clearPreference` — preference and runtime registration stay as they were.

## Test scenarios

Mirrors `ShortcutUnassignTests.swift` 1:1.

### preferenceKey
- **testPreferenceKey_staticShortcutKeepsSameId** — `hideShowAppShortcut` maps to itself.
- **testPreferenceKey_holdAndNextClearPressPart** — hold and nextWindow ids map to the press key for that shortcut index (including numbered shortcuts).

### clearPreference (accept path)
- **testClearPreference_hiddenRecorderClearsStoredHideShow** — default H cleared with no live recorder; still nil after `invalidateAllCache` (relaunch simulation).
- **testClearPreference_vimKeysRemainEnabledAfterRelaunchSimulation** — after clearing H, `vimKeysEnabled=true` survives cache invalidation alongside the unassigned shortcut.
- **testClearPreference_arrowConflictClearsUserBoundPressWithoutRecorder** — user-bound arrow press on a numbered shortcut is persistently cleared with no live recorder.
- **testClearPreference_returnsKeyForVisibleRecorderSync** — returned key matches the preference key so a displayed recorder can be synchronized.

### cancel path
- **testCancelDoesNotClearPreference** — skipping `clearPreference` leaves the stored shortcut and related flags untouched.
