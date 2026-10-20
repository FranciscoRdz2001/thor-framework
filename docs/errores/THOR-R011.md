# THOR-R011 · Un ancho de columna de `Table` que CSS no puede expresar

**Dónde:** `thor_ui` · `MaxColumnWidth` / `MinColumnWidth`.

## Qué pasó

Un `MaxColumnWidth` o `MinColumnWidth` combina dos anchos que una pista de
grilla CSS no puede comparar (el menor entre una parte flexible y un
largo, o entre el contenido y un largo).

## Por qué

thor convierte cada `TableColumnWidth` en una pista de `grid-template-columns`
y deja que el navegador mida las columnas. `max()`/`min()` solo comparan
largos (`px`, `%`); una parte flexible (`fr`) solo puede ser el máximo de
un `minmax()`.

## Cómo se arregla

```dart
// WRONG: el menor entre 200 px y una parte del espacio libre
MinColumnWidth(FixedColumnWidth(200), FlexColumnWidth())
```

```dart
// RIGHT: dos largos, o una parte flexible con un mínimo
MinColumnWidth(FixedColumnWidth(200), FractionColumnWidth(0.3))
MaxColumnWidth(FixedColumnWidth(120), FlexColumnWidth())
```

[Todos los códigos](README.md)
