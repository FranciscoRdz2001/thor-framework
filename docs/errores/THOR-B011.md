# THOR-B011 · Una imagen de `web/images/` que el build no puede leer

**Dónde:** `thor build` / `thor export` / `thor dev` · el paso de imágenes.

## Qué pasó

Un archivo de `web/images/` con extensión de imagen (`.png`, `.jpg`, `.webp`, `.gif`) no tiene la cabecera de ese formato: está cortado, o es otro formato con esa extensión.

## Por qué

El build lee el ancho y el alto de la cabecera para escribir `width`/`height` (sin saltos al cargar) y las variantes. Sin tamaño no puede hacer ninguna de las dos cosas. En `thor dev` es un aviso; en el build detiene todo.

## Cómo se arregla

```text
WRONG: web/images/foto.jpg es en realidad un HEIC renombrado
```

```bash
# RIGHT: convertirlo a un formato que el navegador lea
magick foto.heic web/images/foto.jpg
```

[Todos los códigos](README.md)
