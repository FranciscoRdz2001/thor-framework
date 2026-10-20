# THOR-B010 · `cwebp` is missing for the image variants

**Where:** `thor build` / `thor export` · the image step (`web/images/`).

## What happened

The app declares `thor: images:` in its `pubspec.yaml` and there is no `cwebp` on the `PATH`, so the build cannot write the WebP variants.

## Why

Declaring `thor.images` means asking for the variants: without them the page would come out different from what the app expects (without `srcset`), silently. Without the section declared, a missing `cwebp` is only a warning and the build writes the sizes.

## How to fix it

```bash
# WRONG: building on a machine without the encoder
thor build
```

```bash
# RIGHT: install libwebp (macOS / Debian-Ubuntu) and build again
brew install webp
sudo apt-get install -y webp
thor build
```

[All codes](README.md)
