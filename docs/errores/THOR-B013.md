# THOR-B013 · Falta un codificador AVIF para las imágenes

**Dónde:** `thor build` / `thor export` · el paso de imágenes (`web/images/`).

## Qué pasó

La app pide AVIF en su `pubspec.yaml` (`thor: images: formats: [webp, avif]`) y no hay en el `PATH` un ImageMagick que escriba AVIF.

## Por qué

Pedir AVIF es pedir sus variantes: sin ellas la página saldría sin el `<source type="image/avif">` que la app espera, sin avisar. El build usa ImageMagick (y no `avifenc`) porque también redimensiona. `magick -list format` debe mostrar `AVIF` con `w`.

## Cómo se arregla

```yaml
# WRONG: pedir AVIF en una máquina sin el codificador
thor:
  images:
    formats: [webp, avif]
```

```bash
# RIGHT: instalar ImageMagick con AVIF (macOS / Debian-Ubuntu) y volver a construir
brew install imagemagick
sudo apt-get install -y imagemagick libheif1
magick -list format | grep AVIF   # debe decir rw
thor build
```

O quitar `avif` de `formats`: las variantes WebP bastan.

[Todos los códigos](README.md)
