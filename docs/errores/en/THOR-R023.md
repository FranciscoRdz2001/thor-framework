# THOR-R023 · A theme color's channels aren't known on the server

**Where:** `thor_style` · `Color.value`, `alpha`, `red`, `green`, `blue`, `opacity` and `Color.alphaBlend` on a theme variable, a `Color.css` or a color with `.when()` variants (check `hasChannels` first).

## What happened

A color that comes from the theme (`ThemeColor.primary`, `Theme.of(context).colorScheme.primary`, a `ColorToken`) is read by its channels: `.value`, `.red`, `.opacity`… or goes into `Color.alphaBlend`.

## Why

That color is a CSS variable (`var(--t-primary)`): in light mode it has one value and in dark mode another, and the browser decides which. The server paints the page only once, so any number it extracted would belong to the wrong mode, and the bug wouldn't show until someone opens dark mode. Failing is better than silently painting wrong.

## How to fix it

```dart
// WRONG
final light = Theme.of(context).colorScheme.primary.value > 0x80000000;
final soft = Color.alphaBlend(scheme.primary.withValues(alpha: .1), scheme.surface);
```

```dart
// RIGHT: a transparency is blended in the browser and follows the theme
color: scheme.primary.withValues(alpha: 0.1)

// two colors depending on the mode: .when()
color: Colors.white.when(dark: Colors.black)

// the channels of a fixed color can be read
const Color(0xFF6750A4).red

// the color the server knows (the light one; the dark one with themeMode: dark),
// for a calculation that holds in a single mode: it does not follow the theme
scheme.primary.fallback!.red
```

[All codes](README.md)
