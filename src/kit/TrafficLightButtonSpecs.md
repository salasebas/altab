# Traffic-light hover controls — Specs

## Rendering

Thumbnails show quit, close, minimize, and fullscreen traffic-light controls on mouse hover. The
controls always keep their colored or Graphite disk, border, dimming, hit target, action, and
tooltip. `showSymbolsInHoverControls` only controls whether the inner quit, close, minimize,
fullscreen, or exit-fullscreen glyph is drawn.

The preference defaults to `true`. When it is `false`, symbol drawing is skipped after the disk is
drawn and before the existing dimming pass. Hiding colored circles remains the stronger visibility
setting, so symbol drawing is irrelevant while `hideColoredCircles` is enabled.

## Settings

The global switch lives in Appearance → Customize more and retains its persisted value when it is
disabled. It is enabled only for the Thumbnails appearance while colored circles are visible. Its
localized label participates in Settings search before and after the sheet is built.
