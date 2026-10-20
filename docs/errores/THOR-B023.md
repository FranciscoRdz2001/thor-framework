# THOR-B023 · Una página con acciones que el registro no puede nombrar

**Dónde:** `thor dev` / `thor build` / `thor test`.

## Qué pasó

Una clase de página privada (`_ContactPage`) o con parámetros de tipo tiene métodos de acción (`Future<ActionResult?> x(PageRequest …)`).

## Por qué

thor registra las acciones desde fuera de tu archivo y nombra la clase para sacar sus métodos (`(p as ContactPage).send`). Una clase privada no se puede nombrar desde otro archivo, y una genérica no tiene un solo tipo.

## Cómo se arregla

```dart
// WRONG
class _ContactPage extends ThorPage<void> { Future<ActionResult?> send(…) … }
```

```dart
// RIGHT
class ContactPage extends ThorPage<void> { Future<ActionResult?> send(…) … }
```

[Todos los códigos](README.md)
