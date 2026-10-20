# THOR-R017 · A `const` widget that reads more than its fields

**Where:** `thor_ui` · `const` widgets reused across pages (the check in `thor dev` and in tests).

## What happened

With the check enabled, a `const` widget reused from a previous page was rebuilt for comparison, and it produced different HTML even though the inherited widgets above it were the same.

## Why

Thor stores the HTML of a `const` widget (the same instance on every page) and puts it back as is. That's only correct if its `build` depends on its fields and on inherited widgets (`Theme.of`, `Localizations.of`…). One that reads a global variable, a singleton or the time would come out with the HTML of the first page that stored it. Dart can't check this at compile time; the check finds it in tests or in `thor dev`.

## How to fix it

```dart
// WRONG: const, but its build reads a global
class CartBadge extends StatelessWidget {
  const CartBadge({super.key});
  @override
  Widget build(BuildContext context) => Text('${cart.items.length}');
}
// … const CartBadge()
```

```dart
// RIGHT: the value comes in as a field (and the instance is no longer const)
class CartBadge extends StatelessWidget {
  const CartBadge({super.key, required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Text('$count');
}
// … CartBadge(count: cart.items.length)
```

If the value must change in the browser, it's a `ThorState` (a subtree with a `ThorState` is never stored).

[All codes](README.md)
