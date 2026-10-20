# THOR-R033 · A `FutureBuilder` keeps the skeleton when its future completes with `null`

**Where:** `thor_ui` · `FutureBuilder<T?>`; the `thor dev` terminal and the
editor's `future_builder_nullable_has_data` lint.

## What happened

A `FutureBuilder`'s future completed with `null` (for example "that product
doesn't exist") and the `builder` painted the same thing it paints while waiting: the person
is left looking at the skeleton forever.

## Why

As in Flutter, `snapshot.hasData` is `false` when the data is `null`. A
`builder` that only looks at `hasData` can't tell "not here yet" from "it arrived and
there's nothing".

## How to fix it

When `T` can be `null`, check `connectionState` first.

```dart
// WRONG: with Future<Product?> the skeleton never goes away if there is no product
FutureBuilder<Product?>(
  future: data.product,
  builder: (context, snapshot) =>
      snapshot.hasData ? ProductCard(snapshot.data!) : const Skeleton(height: 240),
)
```

```dart
// RIGHT: waiting, skeleton; done, with data or without it
FutureBuilder<Product?>(
  future: data.product,
  builder: (context, snapshot) =>
      snapshot.connectionState != ConnectionState.done
      ? const Skeleton(height: 240)
      : snapshot.hasData
      ? ProductCard(snapshot.data!)
      : const Text('Product not found'),
)
```

If the `null` is a real error (a `404`), await the data in `load` and throw
`NotFound()`: the response goes out with its `404`.

If the `builder` passes the `snapshot` to another function, the lint doesn't judge it; the
`thor dev` warning does, because it compares what gets painted.

[All codes](README.md)
