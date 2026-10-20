# THOR-B010 · Falta `cwebp` para las variantes de las imágenes

**Dónde:** `thor build` / `thor export` · el paso de imágenes (`web/images/`).

## Qué pasó

La app declara `thor: images:` en su `pubspec.yaml` y no hay `cwebp` en el `PATH`, así que el build no puede escribir las variantes WebP.

## Por qué

Declarar `thor.images` es pedir las variantes: sin ellas la página saldría distinta de lo que la app espera (sin `srcset`), sin avisar. Sin la sección declarada, la falta de `cwebp` es solo un aviso y el build escribe los tamaños.

## Cómo se arregla

```bash
# WRONG: construir en una máquina sin el codificador
thor build
```

```bash
# RIGHT: instalar libwebp (macOS / Debian-Ubuntu) y volver a construir
brew install webp
sudo apt-get install -y webp
thor build
```

[Todos los códigos](README.md)
