# THOR-R016 · A `FontFace` `unicodeRange` that isn't a range

**Where:** `thor_ui` · `FontFace.css` (when writing the theme's `@font-face`).

## What happened

`FontFace(unicodeRange:)` doesn't have the shape of CSS's `unicode-range` (`U+0000-00FF, U+2013`, `U+4??`).

## Why

The value goes into the sheet as is: a malformed one would make the browser discard the rule (the font is never used) or, with `;` and `}`, would open another rule.

## How to fix it

```dart
// WRONG
FontFace('Inter', url: '/fonts/inter-latin.woff2', unicodeRange: 'latin')
```

```dart
// RIGHT: the one `thor fonts subset` prints
FontFace('Inter', url: '/fonts/inter-latin.woff2',
    unicodeRange: 'U+0000-00FF,U+0131,U+2000-206F')
```

[All codes](README.md)
