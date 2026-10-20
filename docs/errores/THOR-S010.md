# THOR-S010 · Un `ThorState` sin registrar

**Dónde:** `thor_ui` · `ThorState` (la primera vez que se usa un estado).

## Qué pasó

La app o sus pruebas corrieron sin `thor`: un `dart run bin/server.dart` o un `dart test` directos. Un estado (`class CartState extends ThorState`) no tiene registrados sus métodos ni sus valores, y la página no puede nombrarlos.

## Por qué

Dart no puede listar los miembros de una clase mientras corre. `thor` los prepara antes de cada ejecución (`thor dev`, `thor build`, `thor preview`, `thor test`); sin él, el primer estado que la página o el test toca lanza este error.

## Cómo se arregla

```bash
# WRONG
dart run bin/server.dart
dart test
```

```bash
# RIGHT
thor dev            # or thor build / thor preview
thor test           # same arguments as dart test
thor test test/cart_state_test.dart -n 'adds a line'
```

Corre los comandos desde la raíz de la app.

[Todos los códigos](README.md)
