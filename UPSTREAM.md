# Upstream review log

This log records how far upstream has been reviewed. “Reviewed” does not mean every upstream change was integrated.

## Current baseline

| Field | Value |
| --- | --- |
| Upstream | `https://github.com/lwouis/alt-tab-macos.git` |
| Fork point | `v11.4.3` |
| Fork commit | `10af70aaaaac0a2dbb7d0aaa61cda21b065c203f` |
| Last reviewed commit | `081f3ee4014e03557c2ab39e9e168dac308fa49b` (`v11.4.4`) |
| Last review date | 2026-08-09 |
| Selective product integration of that range | **Complete** (tracker #61; see matrix below) |
| AlTab source milestone at this baseline | `altab-v1.0.0` (product `1.0.0`); post-milestone ports land on `main` until the next `altab-v*` tag |

“Reviewed”, “selectively integrated”, and “source milestone” do **not** mean AlTab has automatic security updates or feature parity with upstream. `git cherry` may still report adapted ports as unintegrated by patch identity; that is expected.

## Review procedure

1. Run `git fetch upstream --tags`.
2. Inspect commits after the recorded revision, including the full diff and related tests.
3. Classify each change as integrate, adapt, defer, or skip.
4. Prefer small reviewed batches over broad merges.
5. Build and test the affected behavior.
6. Record the new last-reviewed commit and noteworthy decisions below.

## v11.4.4 selective integration closeout (#61)

On 2026-08-09, `git fetch upstream --tags` still places `upstream/master` and tag `v11.4.4` at `081f3ee4`. There are no commits after that revision.

Tracker [#61](https://github.com/salasebas/altab/issues/61) recorded the full product delta from the fork point (`10af70aa` / `v11.4.3`) through `081f3ee4` / `v11.4.4`. Every commit in that range is classified below. Applicable reliability, capture, gesture, shortcut, Space, and tracked-window work was integrated or adapted on dedicated branches/PRs. Intentionally deferred and hard-skipped commits keep AlTab fork boundaries (no Sparkle/telemetry, no upstream release metadata, preserved space-label default).

AlTab does **not** claim automatic upstream or security-update parity after this closeout.

### Commit classification (`10af70aa..081f3ee4`)

| Upstream commit | Summary | Decision | AlTab issue | Local PR |
| --- | --- | --- | --- | --- |
| `e2db26d4` | Exceptions may fail to ignore shortcuts | **Adapt** | #43 | [#68](https://github.com/salasebas/altab/pull/68) |
| `893673cf` | Mitigate official screenshot API issues | **Adapt** | #44 | [#67](https://github.com/salasebas/altab/pull/67) |
| `e20c3277` | Space indicators off by default | **Defer** | #61 | — (keep `hideSpaceNumberLabels` default `false`) |
| `499006c1` | Make Preview lazy | **Adapt** | #45 | [#72](https://github.com/salasebas/altab/pull/72) |
| `726c5fd1` | Rare crash opening Customize Style | **Adapt** | #46 | [#63](https://github.com/salasebas/altab/pull/63) |
| `3c095716` | Align auto-updates with appcast (license tier analytics) | **Skip** | #61 | — (conflicts with no-updater / no-telemetry) |
| `0af0336d` | Stale README stats (semantic-release assets) | **Skip** | #61 | — (upstream release automation only) |
| `a2d05275` | Mouse hover scrolls the switcher | **Adapt** | #47 | [#62](https://github.com/salasebas/altab/pull/62) |
| `1014601a` | Shortcut conflicts not remembered | **Integrate** | #48 | [#70](https://github.com/salasebas/altab/pull/70) |
| `ec30bb13` | Focusing a window might make it expand | **Integrate** | #49 | [#65](https://github.com/salasebas/altab/pull/65) |
| `1a85669b` | Dock/menu-bar lag with gestures | **Integrate** | #50 | [#64](https://github.com/salasebas/altab/pull/64) |
| `c14960bb` | Improve tabs and phantom windows | **Adapt** (split) | #51 → #54–#60 | [#66](https://github.com/salasebas/altab/pull/66), [#73](https://github.com/salasebas/altab/pull/73), [#77](https://github.com/salasebas/altab/pull/77), [#76](https://github.com/salasebas/altab/pull/76), [#75](https://github.com/salasebas/altab/pull/75), [#71](https://github.com/salasebas/altab/pull/71), [#69](https://github.com/salasebas/altab/pull/69) |
| `767b96fc` | Switcher might show previous Space briefly | **Adapt** | #52 | [#83](https://github.com/salasebas/altab/pull/83) |
| `081f3ee4` | chore(release): 11.4.4 | **Skip** | #61 | — (upstream appcast/assets/branding/release metadata only) |

### `c14960bb` work breakdown (parent #51)

| Sub-issue | Scope | Local PR |
| --- | --- | --- |
| #54 | AX root-window brute-force match + failed geometry → nil | [#66](https://github.com/salasebas/altab/pull/66) |
| #55 | Pure tracked-window reducer + offline replay harness | [#73](https://github.com/salasebas/altab/pull/73) |
| #56 | Production routing of tab/phantom/liveness through the bridge | [#77](https://github.com/salasebas/altab/pull/77) |
| #57 | Focus / MRU / selection / reopen on the reducer | [#76](https://github.com/salasebas/altab/pull/76) |
| #58 | Minimize/restore-safe thumbnails + SCK partial-frame refusal | [#75](https://github.com/salasebas/altab/pull/75) |
| #59 | CLI reply hardening + local QA diagnostics | [#71](https://github.com/salasebas/altab/pull/71) |
| #60 | Lost modifier release settle + key-repeat panel gate | [#69](https://github.com/salasebas/altab/pull/69) |

Explicit omissions from `c14960bb`: Sparkle/license/AppCenter paths, upstream identity/signing, `DebugProfile` deployment helpers, and any revive of deleted service files. AlTab continuous navigation, branding, and unrestricted features remain.

### Validation evidence for the closeout revision

- Implementation issues #43–#52 and #54–#60 are closed with merged PRs listed above.
- Fork-boundary guards used for integration batches: `scripts/check_service_isolation.sh`, `scripts/check_unrestricted_features.sh`, `scripts/check_source_compliance.sh`, and the unit suite via the usual Test scheme / `ai/build.sh` path on each feature PR.
- Deferred: product default `hideSpaceNumberLabels` stays visible (`false`) until an explicit AlTab UX decision.
- Skipped permanently for this range: appcast license-tier analytics (`3c095716`), semantic-release README stats (`0af0336d`), release commit metadata (`081f3ee4`).

## Decisions (chronological detail)

| Date | Upstream range | Decision | Notes |
| --- | --- | --- | --- |
| 2026-08-04 | Through `10af70aa` | Baseline | Repository initialized from upstream `v11.4.3`; intentional divergence begins here. |
| 2026-08-06 | `10af70aa..081f3ee4` | Skip for issue #19 | Reviewed upstream through `v11.4.4`. The range does not address the inherited restricted-font subset; upstream still carries the same blob and private-use glyph renderer. Implement the compliant symbol catalog locally rather than merging or porting that pipeline. |
| 2026-08-07 | `081f3ee4` (no new commits) | Reconfirm for issue #10 | `git fetch upstream` for the source-first audit: `upstream/master` still at `081f3ee4` (`v11.4.4`). No new upstream range to classify. |
| 2026-08-08 | `726c5fd1` | Adapted for issue #46 | Cherry-picked `fix: rare crash when opening the customize style sheet` with `-x`. Retries `NSImage(contentsOfFile:)` once, logs missing/failed loads, and never force-unwraps so Customize Style degrades to a blank tile. Comment wording is updater-neutral (no Sparkle); AlTab has no updater dependency. Local PR #63. |
| 2026-08-08 | `a2d05275` | Adapt for issue #47 | Compact manual port of `a2d05275` (upstream #5484): call `scrollToVisible` only for keyboard/programmatic selection so mouse hover no longer yanks the switcher viewport. Attribution preserved. Local PR #62. |
| 2026-08-08 | `893673cf` (adapted) | Adapt for issue #44 | Port weak-linked ScreenCaptureKit and macOS 26 capture routing from upstream `893673cf` (`fix: mitigate issues with official screenshot api`). Kept AlTab `base.xcconfig` identity (no upstream `DOMAIN`/`API_DOMAIN`). Snapshot size/scale/fullscreen/Preview on main; route non-fullscreen thumbnails through `captureScreenshot` and keep `captureSampleBuffer` for fullscreen + Preview. Pure route selection extracted to `WindowCaptureApiRouting` for unit tests. Local PR #67. |
| 2026-08-08 | `1a85669b` | Integrate for issue #50 | Clean cherry-pick of the dock/menu-bar gesture lag fix (upstream #5911). Splits the permanently active HID gesture tap into a listen-only `detectTap` and an on-demand `absorbTap` armed only while the switcher is active or enough fingers are down to trigger. Local PR #64. |
| 2026-08-08 | `ec30bb13` | Integrate for issue #49 | Clean cherry-pick of `ec30bb13` (upstream #5900): synthetic key-focus posts only mouse-down at `(300000, 300000)` so macOS 27 no longer treats the event as a resize grab. Local PR #65. |
| 2026-08-08 | `e2db26d4` (within `10af70aa..081f3ee4`) | Adapt for issue #43 | Manual semantic port of `e2db26d4` (“exceptions may fail to ignore shortcuts”, upstream #5842 / v11.4.4). App-activation floor after `Applications.frontmostPid` matches upstream. Launch floor runs **after** `PreferencesEvents.initialize()` so the shortcut registry exists (upstream places it before registration in this fork’s order). Also enforce the disabled invariant in `KeyboardEvents.registerHotKeyIfNeeded`. Wording uses AlTab launch/restart, not Sparkle auto-update relaunch. Local PR #68. |
| 2026-08-08 | Subset of `c14960bb` | Partial integrate for issue #54 | Ported only the root-window brute-force match kernel (`BruteForceWindowMatch` triad), the `windowByBruteForce` role gate (`AXWindow` only), and failed AX size/position conversion → nil. Deferred resumable inactive-tab scan cursors and requester-frame ownership wiring to the reducer integration (#55–#58). No wholesale merge of the tracked-window reducer. Local PR #66. |
| 2026-08-08 | Subset of `c14960bb` (ancestor of `081f3ee4`) | Adapt for issue #60 | Ported only the key-repeat / lost-hold-release keyboard subset: settle a lost modifier release before navigation (`settleLostHoldRelease` + `ATShortcut.settleLostRelease`), keep repeat-timer cleanup separate (`stopRepeatIfUp`), gate artificial repeats on panel visibility (`KeyRepeatTimer` + triad), and stamp `SwitcherSession.panelShownAt` from `TilesPanel.show()`. Preserved AlTab continuous-navigation wrapping. Local PR #69. |
| 2026-08-08 | `1014601a` (single commit) | Integrate for issue #48 | Cherry-picked `1014601a` (`fix: shortcut conflicts were not properly remembered`, closes upstream #5897). Routes Vim/arrow conflict accept through `unassignShortcut` so the preference is cleared even when the recorder sheet was never built. Fork follow-up: `ShortcutUnassign` kernel + regression triad. Local PR #70. |
| 2026-08-08 | CLI / QA subset of `c14960bb` | Adapt for issue #59 | Ported only the CLI transport hardening and local QA diagnostics from the large v11.4.4 tab/phantom commit. **Included:** non-conforming float JSON encoding; client failures for no/empty/non-text/rejected replies (stderr + non-zero); server reply logging; `--qa-state` / `--qa-mark` / `--hide` with AlTab `App.name` and bundle-id port. **Adapted:** `--qa-state` to AlTab naming and reducer-era tile state. No upstream identity, network, analytics, or deleted service paths. Local PR #71. |
| 2026-08-08 | `499006c1` (adapted) | Adapt for issue #45 | Manual port of `499006c1` (`fix: make preview lazy to relieve pressure on the os`, upstream #5861). Ordinary captures stay thumbnail-scale; full-res Preview frames are just-in-time for the selected window ±2 displayed neighbors, stored on `SwitcherSession` behind a ten-entry LRU (`PreviewFrameLru`), distinct throttle key, and released with the session / `PreviewPanel.hide()`. `WindowCaptureApiRouting.api` is fullscreen-only (Preview no longer forces `captureSampleBuffer`). Pure kernels + tests for LRU, neighborhood wrap/hidden filtering, and `anyShortcutShowsWindowCaptures`. Depends on prior #44 (`893673cf`) capture routing. Local PR #72. |
| 2026-08-08 | Core model/test subset of `c14960bb` | Adapt for issue #55 | Ported the pure tracked-window authority without production cutover: `TrackedWindowState` + `TabGroupsTable`, `WindowEventReducer`, `TrackedWindowStateBridge`, `TabGroups` registry, expanded `TabGroupResolver` / `TabWindow`, and the full replay harness. Local PR #73. |
| 2026-08-08 | Live adapter cutover subset of `c14960bb` | Adapt for issue #56 | Production routing of tab/phantom/liveness through `TrackedWindowStateBridge.dispatch` so the shell executes reducer effects without re-deciding them. Preserved AlTab continuous navigation and Preview neighborhood. Local PR #77. |
| 2026-08-08 | Focus/MRU/selection subset of `c14960bb` | Adapt for issue #57 | Production cutover of focus, MRU, selection, and reopen onto the reducer (stacked on #56). Local PR #76. |
| 2026-08-08 | Minimize/restore/capture subset of `c14960bb` | Adapt for issue #58 | Ported restore-safe thumbnail behavior on top of the #56/#57 reducer cutover: `WindowThumbnails.deferCaptureUntilRestoreEnds`, `isPartialFrame` / `acceptCapture`, shared `capturePixelSize`, and ScreenCaptureKit deliveries that refuse mid-animation miniature frames. Local PR #75. |
| 2026-08-08 | `767b96fc` (adapted) | Adapt for issue #52 | Cherry-picked `767b96fc` (`fix: switcher might show previous space briefly`, upstream #5864) onto the #55–#58 reducer cutover. Leading-edge `.spaceTransitionStarted` re-reads topology only; trailing `.spaceChangeSettled` keeps membership/WS/shortcut/UI work; show path re-reads topology while `WindowServerEvents.inSpaceTransition`. Local PR #83. |
| 2026-08-09 | Full `10af70aa..081f3ee4` (`v11.4.4`) | Closeout for issue #61 | Reconfirmed `upstream/master` still at `081f3ee4`. Every commit classified in the matrix above: integrated/adapted product fixes closed via #43–#52 and #54–#60; deferred `e20c3277`; hard-skipped `3c095716`, `0af0336d`, and release commit `081f3ee4`. No wholesale merge of `upstream/master`. No claim of automatic parity. |
