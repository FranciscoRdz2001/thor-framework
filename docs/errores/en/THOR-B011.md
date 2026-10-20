# THOR-B011 · An image in `web/images/` the build cannot read

**Where:** `thor build` / `thor export` / `thor dev` · the image step.

## What happened

A file in `web/images/` with an image extension (`.png`, `.jpg`, `.webp`, `.gif`) does not have that format's header: it is truncated, or it is another format with that extension.

## Why

The build reads the width and height from the header to write `width`/`height` (no layout shifts on load) and the variants. Without a size it can do neither. In `thor dev` it is a warning; in the build it stops everything.

## How to fix it

```text
WRONG: web/images/photo.jpg is really a renamed HEIC
```

```bash
# RIGHT: convert it to a format the browser can read
magick photo.heic web/images/photo.jpg
```

[All codes](README.md)
