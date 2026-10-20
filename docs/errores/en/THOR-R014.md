# THOR-R014 · Two `tw()` utilities set the same property

**Where:** `thor_ui/web.dart` · `tw()`.

## What happened

Two utilities of the same variant write the same CSS property
(`p-4 p-8`, `flex hidden`, `w-full size-10`).

## Why

In Tailwind the one that appears later **in its sheet** wins, not in the
`class` attribute, so the result depends on an order you can't see.
Thor prefers failing to picking one. The exceptions are defaults
that another utility exists to change: the line height of
`text-sm` is changed by `leading-6`, and the duration of `transition` is changed by
`duration-300`, in any order.

## How to fix it

```dart
// WRONG
tw('p-4 p-8')
tw('flex hidden')
```

```dart
// RIGHT: one per variant
tw('p-4 md:p-8')
tw('hidden md:flex')
```

[All codes](README.md)
