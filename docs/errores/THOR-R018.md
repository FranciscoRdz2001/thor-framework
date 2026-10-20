# THOR-R018 · Un argumento de `Style` que no es CSS

**Dónde:** `thor_lints` · regla `style_css_names` (en `dart analyze` y el IDE).

## Qué pasó

`Style` (capa web, `package:thor_ui/web.dart`) recibió un nombre que no es una propiedad CSS (`spacing`, `paddin`, `mainAxisAlignment`) o un valor de Flutter donde va uno de CSS (`padding: EdgeInsets.all(16)`, `gap: 8`).

## Por qué

`Style` habla CSS: cada parámetro es una propiedad CSS en camelCase (como `CSSProperties`) y recibe un solo valor CSS tipado. El compilador solo dice "no named parameter" o "can't be assigned"; la regla nombra la propiedad o el valor que hay que escribir.

## Cómo se arregla

```dart
// WRONG
Style(spacing: 8.px, padding: EdgeInsets.all(16), mainAxisAlignment: MainAxisAlignment.center)
```

```dart
// RIGHT
Style(gap: 8.px, padding: 16.px, justifyContent: JustifyContent.center)
// por lado: paddingInline, paddingBlock, paddingTop…
```

[Todos los códigos](README.md)
