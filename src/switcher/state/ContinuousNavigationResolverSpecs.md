# Continuous keyboard navigation

## Boundary policy

- Discrete keyboard navigation wraps at the first and last selectable window or row.
- Continuous keyboard navigation stops at boundaries by default.
- When `wrapContinuousKeyboardNavigation` is enabled, native key repeat and the synthetic repeat timer may wrap at boundaries.
- An interaction that passes `allowWrap: false` never wraps, even when the preference is enabled. Trackpad navigation uses this path.

## Integration

- `Windows.selectedWindowIndexAfterCycling` remains responsible for skipping filtered and hidden windows and calculating the circular destination.
- `TilesView.nextRow` remains responsible for calculating the circular row destination.
- A repeat is active when either `ATShortcut.lastEventIsARepeat` is true or `KeyRepeatTimer.timerIsSuspended` is false.
- Search-editing arrow routing propagates native repeat state before cycling the selection.
- Key and modifier release cancellation remains owned by `ATShortcut` and `KeyRepeatTimer`; reaching a boundary does not start, stop, or replace a timer.
