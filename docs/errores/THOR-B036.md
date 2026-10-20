# THOR-B036 · Dos estados con el mismo nombre de clase

**Dónde:** `thor dev` / `thor build` / `thor test`.

## Qué pasó

Dos clases que extienden `ThorState`, en archivos distintos, se llaman igual (`IconVariantsState` en `a.dart` y en `b.dart`).

## Por qué

En Flutter dos clases con el mismo nombre en archivos distintos son legales: cada import decide cuál ves. Un estado de Thor es distinto, porque viaja al navegador. La página, el protocolo y el navegador nombran un estado solo por el nombre de su clase (`IconVariantsState.variant`), y no hay imports en el HTML ni en el código del navegador. Con dos del mismo nombre, el navegador se queda con una y la otra página llama a métodos y enums que no son suyos.

## Cómo se arregla

Cambia el nombre de una de las dos, con el nombre de la página o la función de prefijo (`CartPagePanelState`, `SettingsPanelState`). El mensaje del error sugiere uno a partir del archivo.

```dart
// WRONG
class IconVariantsState extends ThorState { … } // icons.dart
class IconVariantsState extends ThorState { … } // buttons.dart
```

```dart
// RIGHT
class IconVariantsState extends ThorState { … }       // icons.dart
class ButtonsVariantsState extends ThorState { … }    // buttons.dart
```

[Todos los códigos](README.md)
