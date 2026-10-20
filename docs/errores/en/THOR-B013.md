# THOR-B013 · An AVIF encoder is missing for the images

**Where:** `thor build` / `thor export` · the image step (`web/images/`).

## What happened

The app asks for AVIF in its `pubspec.yaml` (`thor: images: formats: [webp, avif]`) and there is no ImageMagick on the `PATH` that writes AVIF.

## Why

Asking for AVIF means asking for its variants: without them the page would come out without the `<source type="image/avif">` the app expects, silently. The build uses ImageMagick (and not `avifenc`) because it also resizes. `magick -list format` must show `AVIF` with `w`.

## How to fix it

```yaml
# WRONG: asking for AVIF on a machine without the encoder
thor:
  images:
    formats: [webp, avif]
```

```bash
# RIGHT: install ImageMagick with AVIF (macOS / Debian-Ubuntu) and build again
brew install imagemagick
sudo apt-get install -y imagemagick libheif1
magick -list format | grep AVIF   # should say rw
thor build
```

Or remove `avif` from `formats`: the WebP variants are enough.

[All codes](README.md)
