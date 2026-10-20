# THOR-S016 · An `AnimatedSwitcher` with no states to switch

**Where:** `thor_lints` · rule `animated_switcher_without_watch` (in the editor and in `dart analyze`) and the code generation of `thor dev` / `thor build`.

## What happened

The `child` of an `AnimatedSwitcher` isn't a `Watch` with states: it's another widget (`Text`, `Column`…), a `Watch` without `builder:` or with `each:`, or a `Watch` of a `String`, a list or an `int` without `count:`. It animates nothing and nothing says so.

## Why

The `AnimatedSwitcher` marks the element of the `Watch` it wraps and animates the change between that `Watch`'s states (a `bool`, an enum or an `int` with `count:`), inside a browser view transition. On anything else there are no two states to swap. As the root of a `Watch`'s `builder:` it works with any child (`Watch(paso.actual, builder: (p) => AnimatedSwitcher(child: Text(titulos[p])))`): the `Watch` changes its whole element and the `AnimatedSwitcher` marks it; the rule lets it through. Deeper inside the `builder:` tree (inside a `Column`, for example) it marks an element nobody changes and the rule does warn. Wrappers that merge into their child (`Padding`, `Expanded`…) are looked through; a custom widget or a function that returns the `Watch` can't be seen and isn't flagged.

## How to fix it

```dart
// WRONG
AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  child: Text(view.title()),
)
```

```dart
// RIGHT: a Watch with a builder over a bool, an enum or an int with count:
AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  child: Watch(view.isGrid, builder: (grid) => grid ? const GridBody() : const ListBody()),
)
```

Without a state change there's nothing to animate: remove the `AnimatedSwitcher`. More in [Animations](../../guia/en/animations.md#switching-state-with-animatedswitcher).

[All codes](README.md)
