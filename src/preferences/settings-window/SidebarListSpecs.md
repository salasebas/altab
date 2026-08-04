# SidebarList — Specs

## Summary

`SidebarListRow` is the recycled row widget for the shortcut sidebar (ControlsTab). It shows a title,
an optional summary, an optional icon, and a chevron.

## Behavior & edge cases

- `setContent(title, summary)` updates the visible strings and exposes both in the tooltip.
- `setSummary(summary)` keeps the existing title and refreshes the tooltip.
- An empty summary produces a title-only tooltip without an extra newline.

## Test scenarios

Mirrors `SidebarListTests.swift` 1:1.

- **testSetContentBuildsTooltipFromTitleAndSummary** — title and summary appear on separate tooltip lines.
- **testSetSummaryRefreshesTooltipWithoutReplacingTitle** — recycled rows update and clear summaries while retaining their title.
