# THOR-R013 · A `tw()` utility or variant that Thor doesn't know

**Where:** `thor_ui/web.dart` · `tw()`.

## What happened

`tw('…')` received a utility (`pd-4`, `space-x-4`) or a variant
(`focus:`, `2xl:`, `md:hover:`) outside Thor's subset, or a named color
(`text-muted`, `bg-red-500`) that the theme doesn't have in
`ThemeData(colorTokens:)` (the latter is checked at paint time, in debug). The
message names the closest match or what to use instead.

## Why

Thor resolves each utility on the server into declarations on the element's
class; there's no Tailwind CSS in the browser to pick it up later. Whatever
isn't in the grammar isn't written: a made-up utility would fail
silently and a free value (`p-[1px;color:red]`) could sneak in CSS. The
variants are Thor's states (`hover:`, `active:`, `focus-visible:`,
`focus-within:`, `group-hover:`, `dark:`), its four breakpoints and the
container width (`@md:`, `@min-[400px]:`), one per utility.

## How to fix it

```dart
// WRONG
tw('space-x-4 focus:ring md:hover:bg-primary')
```

```dart
// RIGHT: gap on the parent, keyboard focus, one variant per utility
tw('flex gap-x-4 focus-visible:border-primary hover:bg-primary')
// Two conditions together: Style(...).when() or a widget.

// A custom color: into the theme, and by its name.
ThemeData(colorTokens: {'muted': Color(0xFF6B7280)})
tw('text-muted')
```

[All codes](README.md)
