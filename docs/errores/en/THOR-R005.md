# THOR-R005 · Nested `@keyframes`

**Where:** `thor_ui` · the app's style sheets.

## What happened

A `keyframes(...)` rule ended up inside another one (a selector, an `@media`).

## Why

CSS only accepts `@keyframes` at the top level of the sheet.

## How to fix it

```dart
// WRONG
WindowSizeClass.medium.media([css.keyframes('spin', {...})])
```

```dart
// RIGHT
css.keyframes('spin', {...}),              // at the top level
WindowSizeClass.medium.media([css('.x').props(...)])
```

[All codes](README.md)
