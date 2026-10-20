# THOR-B014 · A font `thor fonts metrics` cannot read

**Where:** `thor fonts metrics <source>`.

## What happened

The file is not a TrueType, OpenType or WOFF font, it is truncated, or it is a WOFF2 and there is no fontTools with Brotli to convert it.

## Why

`thor fonts metrics` reads the font's tables (`head`, `hhea`, `cmap`, `hmtx`) in pure Dart. A WOFF2 stores those tables compressed with Brotli, and Dart does not ship a Brotli decompressor (there is no pure-Dart one that works with Dart 3). That is why a WOFF2 first goes through fontTools, the same tool `thor fonts subset` uses, which rewrites it as `.otf`. A WOFF (the older one) uses zlib and is read directly.

## How to fix it

```bash
# WRONG: measuring a WOFF2 without fontTools installed
thor fonts metrics web/fonts/figtree.woff2
```

```bash
# RIGHT: install fontTools with Brotli…
pip install fonttools brotli
thor fonts metrics web/fonts/figtree.woff2
# …or measure the font it came from (.ttf, .otf or .woff)
thor fonts metrics fonts/Figtree-Regular.ttf
```

The metrics (units per em, ascent, descent, widths) are the same in every format of a font: measuring the original once is enough.

[All codes](README.md)
