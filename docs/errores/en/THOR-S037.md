# THOR-S037 · A `QueryBuilder` state that couldn't be drawn without data

**Where:** `thor dev` · browser console; the warning appears when the query reaches a state the server didn't draw.

## What happened

A `QueryBuilder` whose `builder` reads `snapshot.data!` (or `requireData`) in the "has data" branch, and the server painted without data (the query is `ssr: false`, or the first paint failed). The data arrived but the skeleton doesn't change.

```dart
QueryBuilder<List<Review>>(
  query: reviews,
  builder: (context, snapshot) => snapshot.hasData
      ? Text('${snapshot.data!.length} reviews')   // the server does not have the data
      : const Skeleton(height: 24),
)
```

## Why

The `builder` runs on the server, once per state, and the browser only switches between them. To have the "has data" state ready the server calls the `builder` with an `AsyncSnapshot.placeholder` (`hasData` is `true`; reading `data` throws): there `snapshot.data!`, `data ?? []` or `requireData` throw and the state isn't sent (better without it than with a made-up value, like an empty list). The browser doesn't run the `builder` again: the value has to be bound, not read.

In production (without `thor dev`) the page is the same, but an error that is **not** a read of the data (a failing cast, an out-of-range index: a real bug, which the live state would also have) reaches the server's `onError`, once per `builder`. A `data!`, a call on null or `requireData` are expected reads and aren't reported.

## How to fix it

```dart
// RIGHT: what changes with the data goes through the state
QueryBuilder<List<Review>>(
  query: reviews,
  builder: (context, snapshot) => snapshot.hasData
      ? Watch(shop.reviewCount)            // String reviewCount() => '${reviews.data.value?.length ?? 0} reviews';
      : const Skeleton(height: 24),
)

// or: placeholder data, if you really need it in the builder
QueryBuilder<List<Review>>(query: reviews, initialData: const [], builder: …)
```

[All codes](README.md)
