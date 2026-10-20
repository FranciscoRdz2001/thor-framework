# THOR-R031 · Un `FutureBuilder` recibió un futuro nuevo en cada pasada

**Dónde:** `thor_ui` · el render de una página que se pinta completa (`cache:`, `thor export`, `HEAD`, el cliente de `thor_test`).

## Qué pasó

La página se pinta varias veces hasta que todos sus `FutureBuilder` tienen su resultado, y después de 8 pasadas todavía había un futuro sin resultado: cada pasada creó otro.

## Por qué

Un `FutureBuilder` espera un futuro que ya estaba creado cuando la página se pintó, como en Flutter: uno creado dentro de `build` es otro objeto en cada pintada y nunca es el que se esperó.

## Cómo se arregla

```dart
// WRONG: una llamada nueva en cada build
FutureBuilder<List<Product>>(
  future: catalog.featured(),
  builder: (context, snapshot) => ...,
)
```

```dart
// RIGHT: se inicia en `load` y viaja en los datos de la página
@override
Future<Home> load(PageRequest request) async =>
    Home(featured: defer(catalog.featured()));

// en build: future: state.data.featured
```

[Todos los códigos](README.md)
