# Upstream review log

This log records how far upstream has been reviewed. “Reviewed” does not mean every upstream change was integrated.

## Current baseline

| Field | Value |
| --- | --- |
| Upstream | `https://github.com/lwouis/alt-tab-macos.git` |
| Fork point | `v11.4.3` |
| Fork commit | `10af70aaaaac0a2dbb7d0aaa61cda21b065c203f` |
| Last reviewed commit | `10af70aaaaac0a2dbb7d0aaa61cda21b065c203f` |
| Last review date | 2026-08-04 |

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
