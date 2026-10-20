# THOR-S005 · El navegador no encuentra un miembro de un `ThorState`

**Dónde:** `thor_ui` · al arrancar la página en el navegador.

## Qué pasó

El HTML nombra un campo o método (`counter.inc`) que la página no conoce.

## Por qué

Casi siempre el JavaScript de la página quedó viejo o no incluye ese estado: se agregó un estado o un método y la app no se recompiló, o la instancia del estado no es de nivel superior.

## Cómo se arregla

```dart
// WRONG
// lib/cart_state.dart: estado nuevo, pero la instancia no es top-level
class CartState extends ThorState { ... }
Widget build(...) => Watch(CartState().total) // instancia local
```

```dart
// RIGHT
// A top-level instance: thor includes it in the page.
final cart = CartState();
Watch(cart.total)

```

Con `thor dev` la página se recompila sola cuando cambia un archivo; si ves este error ahí, revisa la terminal: puede que la compilación haya fallado.

[Todos los códigos](README.md)
