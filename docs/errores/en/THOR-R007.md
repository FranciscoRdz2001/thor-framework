# THOR-R007 · A translations delegate loads asynchronously

**Where:** `thor_ui` · `LocalizationsDelegate.load`.

## What happened

`load(locale)` returned a regular `Future`.

## Why

Thor renders a page in **a single synchronous pass**; it can't await a `Future` in the middle of the build. The strings have to be ready: `SynchronousFuture`.

## How to fix it

```dart
// WRONG
Future<Strings> load(Locale l) async => Strings(await fetch(l));
```

```dart
// RIGHT
Future<Strings> load(Locale l) => SynchronousFuture(Strings.forLocale(l));
// Async work goes in the route's load (data), not in the delegate.
```

[All codes](README.md)
