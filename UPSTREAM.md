# Upstream review log

This log records how far upstream has been reviewed. “Reviewed” does not mean every upstream change was integrated.

## Current baseline

| Field | Value |
| --- | --- |
| Upstream | `https://github.com/lwouis/alt-tab-macos.git` |
| Fork point | `v11.4.3` |
| Fork commit | `10af70aaaaac0a2dbb7d0aaa61cda21b065c203f` |
| Last reviewed commit | `081f3ee4014e03557c2ab39e9e168dac308fa49b` |
| Last review date | 2026-08-07 |
| AlTab source milestone at this baseline | `altab-v1.0.0` (product `1.0.0`) |

“Reviewed” and “source milestone” do **not** mean AlTab has automatic security updates or feature parity with upstream.

## Review procedure

1. Run `git fetch upstream --tags`.
2. Inspect commits after the recorded revision, including the full diff and related tests.
3. Classify each change as integrate, adapt, defer, or skip.
4. Prefer small reviewed batches over broad merges.
5. Build and test the affected behavior.
6. Record the new last-reviewed commit and noteworthy decisions below.

## Decisions

| Date | Upstream range | Decision | Notes |
| --- | --- | --- | --- |
| 2026-08-04 | Through `10af70aa` | Baseline | Repository initialized from upstream `v11.4.3`; intentional divergence begins here. |
| 2026-08-06 | `10af70aa..081f3ee4` | Skip for issue #19 | Reviewed upstream through `v11.4.4`. The range does not address the inherited restricted-font subset; upstream still carries the same blob and private-use glyph renderer. Implement the compliant symbol catalog locally rather than merging or porting that pipeline. |
| 2026-08-07 | `081f3ee4` (no new commits) | Reconfirm for issue #10 | `git fetch upstream` for the source-first audit: `upstream/master` still at `081f3ee4` (`v11.4.4`). No new upstream range to classify. |
| 2026-08-08 | `726c5fd1` | Adapted for issue #46 | Cherry-picked `fix: rare crash when opening the customize style sheet` with `-x`. Retries `NSImage(contentsOfFile:)` once, logs missing/failed loads, and never force-unwraps so Customize Style degrades to a blank tile. Comment wording is updater-neutral (no Sparkle); AlTab has no updater dependency. |
| 2026-08-08 | `a2d05275` | Adapt for issue #47 | Compact manual port of `a2d05275` (upstream #5484): call `scrollToVisible` only for keyboard/programmatic selection so mouse hover no longer yanks the switcher viewport. Attribution preserved; no full range review of commits after `081f3ee4`. |
| 2026-08-08 | `893673cf` (adapted) | Adapt for issue #44 | Port weak-linked ScreenCaptureKit and macOS 26 capture routing from upstream `893673cf` (`fix: mitigate issues with official screenshot api`). Kept AlTab `base.xcconfig` identity (no upstream `DOMAIN`/`API_DOMAIN`). Snapshot size/scale/fullscreen/Preview on main; route non-fullscreen thumbnails through `captureScreenshot` and keep `captureSampleBuffer` for fullscreen + Preview. Pure route selection extracted to `WindowCaptureApiRouting` for unit tests. |
| 2026-08-08 | `1a85669b` | Integrate for issue #50 | Clean cherry-pick of the dock/menu-bar gesture lag fix (upstream #5911). Splits the permanently active HID gesture tap into a listen-only `detectTap` and an on-demand `absorbTap` armed only while the switcher is active or enough fingers are down to trigger. |
| 2026-08-08 | `ec30bb13` | Integrate for issue #49 | Clean cherry-pick of `ec30bb13` (upstream #5900): synthetic key-focus posts only mouse-down at `(300000, 300000)` so macOS 27 no longer treats the event as a resize grab. Last reviewed baseline remains `081f3ee4`; other commits in that range stay unintegrated until reviewed on their own. |
| 2026-08-08 | `e2db26d4` (within `10af70aa..081f3ee4`) | Adapt for issue #43 | Manual semantic port of `e2db26d4` (“exceptions may fail to ignore shortcuts”, upstream #5842 / v11.4.4). App-activation floor after `Applications.frontmostPid` matches upstream. Launch floor runs **after** `PreferencesEvents.initialize()` so the shortcut registry exists (upstream places it before registration in this fork’s order). Also enforce the disabled invariant in `KeyboardEvents.registerHotKeyIfNeeded`. Wording uses AlTab launch/restart, not Sparkle auto-update relaunch. Not a blind cherry-pick. |
| 2026-08-08 | Subset of `c14960bb` | Partial integrate for issue #54 | Ported only the root-window brute-force match kernel (`BruteForceWindowMatch` triad), the `windowByBruteForce` role gate (`AXWindow` only), and failed AX size/position conversion → nil. Deferred resumable inactive-tab scan cursors and requester-frame ownership wiring to the reducer integration (#55–#58). No wholesale merge of the tracked-window reducer. Provenance: `c14960bb` on the path to `v11.4.4` / `081f3ee4`. |
