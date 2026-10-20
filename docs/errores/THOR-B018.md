# THOR-B018 · Una clase de estado que el registro no puede nombrar

**Dónde:** `thor dev` / `thor build` / `thor test`.

## Qué pasó

Una clase que extiende `ThorState` es privada (`_CartState`), abstracta o tiene parámetros de tipo (`Box<T>`), o un método suyo devuelve un enum privado.

## Por qué

thor registra cada estado desde fuera de tu archivo y nombra la clase, sus métodos y los valores de sus enums desde ahí: un nombre privado no se ve desde otra biblioteca, y una clase abstracta o genérica no es un estado concreto de una página.

## Cómo se arregla

```dart
// WRONG
class _CartState extends ThorState { … }
enum _Tab { home, cart }
class ShopState extends ThorState {
  _Tab tab() => _Tab.home;
}
```

```dart
// RIGHT
class CartState extends ThorState { … }
enum Tab { home, cart }
class ShopState extends ThorState {
  Tab tab() => Tab.home;
}
```

[Todos los códigos](README.md)
