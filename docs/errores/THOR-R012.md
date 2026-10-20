# THOR-R012 · Los especímenes de la hoja compartida no se dibujan

**Dónde:** `thor_ui` · `WidgetRenderer(shareStyles: true, specimens:)`.

## Qué pasó

Al armar la hoja compartida (`/_thor/base.<hash>.css`), el servidor dibuja
una vez los `specimens` dentro de `app` con una petición vacía, y uno de
ellos lanzó una excepción. Las páginas siguen funcionando, pero con todos
sus estilos en línea (sin hoja compartida).

## Por qué

La hoja tiene que salir **del código**, no del tráfico: cada isolate del
servidor la arma por su cuenta y todos deben llegar al mismo archivo. Por
eso los especímenes se dibujan sin datos de ninguna petición: sin sesión,
sin `request.context`, sin parámetros de ruta. Un widget que lee algo de
eso (o un `app` que lo lee) no puede ser espécimen.

## Cómo se arregla

```dart
// WRONG: el espécimen necesita la sesión de una petición
specimens: [UserMenu()], // RequestScope.of(context).context.get(session)
```

```dart
// RIGHT: el componente con valores fijos, como lo usan las páginas
specimens: [
  Column(children: [
    ShadButton(onPressed: () {}, child: Text('Guardar')),
    ShadButton.outline(onPressed: () {}, child: Text('Cancelar')),
  ]),
],
```

Un espécimen tiene que ir en el mismo contexto que en las páginas (dentro
de un `Column`, un hijo de flex lleva sus valores de flex en la clase): si
no, la clase sale distinta y la página la sigue mandando en línea.

[Todos los códigos](README.md)
