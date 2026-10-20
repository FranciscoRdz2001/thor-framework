# THOR-R021 · A theme color declared twice

**Where:** `thor_ui` · `ThemeData(colorTokens:, tokens:)`.

## What happened

The same name appears twice among the theme's custom colors: in the
`colorTokens` map and in the typed `tokens` list, or twice in `tokens`.

## Why

Each name is a variable (`--t-<name>`) with a single value per theme.
If Thor let one win, the other would disappear without warning and the page's
color would depend on the order in which they were written.

## How to fix it

```dart
// WRONG
ThemeData(
  colorTokens: {'band': Color(0xFFF7F6F2)},
  tokens: [AppColors.band],          // ColorToken('band', …)
)
```

```dart
// RIGHT: each color in one place; the typed ones carry light and dark
ThemeData(tokens: AppColors.values)
```

[All codes](README.md)
