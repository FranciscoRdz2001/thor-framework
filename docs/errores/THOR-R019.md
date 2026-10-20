# THOR-R019 · Dos `Hero` con el mismo `tag` en una página

**Dónde:** `thor_ui` · `Hero` (en debug; en release el segundo se omite).

## Qué pasó

Dos `Hero` de la misma página tienen el mismo `tag`, así que sus elementos tendrían el mismo `view-transition-name`.

## Por qué

En una transición de vista cada nombre corresponde a un solo elemento de la página. Si dos lo comparten, el navegador cancela toda la transición y la navegación queda sin animación. En release thor deja el nombre en el primero y quita el del segundo, para que la transición siga funcionando.

## Cómo se arregla

Haz el `tag` único dentro de la página, por ejemplo con el id del elemento que representa.

```dart
// WRONG: todas las tarjetas de la lista con el mismo tag
Hero(tag: 'titulo', child: Text(articulo.titulo))
```

```dart
// RIGHT: uno por artículo, igual en la lista y en la página del artículo
Hero(tag: 'articulo-${articulo.slug}', child: Text(articulo.titulo))
```

[Todos los códigos](README.md)
