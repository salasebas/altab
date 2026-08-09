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
| 2026-08-08 | `ec30bb13` | Integrate for issue #49 | Clean cherry-pick of `ec30bb13` (upstream #5900): synthetic key-focus posts only mouse-down at `(300000, 300000)` so macOS 27 no longer treats the event as a resize grab. Last reviewed baseline remains `081f3ee4`; other commits in that range stay unintegrated until reviewed on their own. |
