# THOR-R017 · Un widget `const` que lee algo más que sus campos

**Dónde:** `thor_ui` · widgets `const` reutilizados entre páginas (la verificación de `thor dev` y de los tests).

## Qué pasó

Con la verificación activa, un widget `const` que se reutilizó de una página anterior se volvió a construir para comparar, y dio otro HTML aunque los widgets heredados de arriba eran los mismos.

## Por qué

thor guarda el HTML de un widget `const` (la misma instancia en todas las páginas) y lo vuelve a poner tal cual. Eso solo es correcto si su `build` depende de sus campos y de los widgets heredados (`Theme.of`, `Localizations.of`…). Uno que lee una variable global, un singleton o la hora saldría con el HTML de la primera página que lo guardó. Dart no puede comprobarlo al compilar; la verificación lo encuentra en los tests o en `thor dev`.

## Cómo se arregla

```dart
// WRONG: const, pero su build lee un global
class CartBadge extends StatelessWidget {
  const CartBadge({super.key});
  @override
  Widget build(BuildContext context) => Text('${cart.items.length}');
}
// … const CartBadge()
```

```dart
// RIGHT: el valor entra como campo (y la instancia deja de ser const)
class CartBadge extends StatelessWidget {
  const CartBadge({super.key, required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Text('$count');
}
// … CartBadge(count: cart.items.length)
```

Si el valor debe cambiar en el navegador, es un `ThorState` (un subárbol con un `ThorState` nunca se guarda).

[Todos los códigos](README.md)
