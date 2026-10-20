# THOR-B014 · Una fuente que `thor fonts metrics` no puede leer

**Dónde:** `thor fonts metrics <fuente>`.

## Qué pasó

El archivo no es una fuente TrueType, OpenType ni WOFF, está cortado, o es un WOFF2 y no hay fontTools con Brotli para convertirlo.

## Por qué

`thor fonts metrics` lee las tablas de la fuente (`head`, `hhea`, `cmap`, `hmtx`) en Dart puro. Un WOFF2 guarda esas tablas comprimidas con Brotli, y Dart no trae un descompresor de Brotli (no hay uno en Dart puro que funcione con Dart 3). Por eso un WOFF2 pasa antes por fontTools, la misma herramienta de `thor fonts subset`, que lo reescribe como `.otf`. Un WOFF (el de antes) usa zlib y se lee directo.

## Cómo se arregla

```bash
# WRONG: medir un WOFF2 sin fontTools instalado
thor fonts metrics web/fonts/figtree.woff2
```

```bash
# RIGHT: instalar fontTools con Brotli…
pip install fonttools brotli
thor fonts metrics web/fonts/figtree.woff2
# …o medir la fuente de la que salió (.ttf, .otf o .woff)
thor fonts metrics fonts/Figtree-Regular.ttf
```

Las medidas (unidades por em, ascenso, descenso, anchos) son las mismas en todos los formatos de una fuente: basta con medir el original una vez.

[Todos los códigos](README.md)
