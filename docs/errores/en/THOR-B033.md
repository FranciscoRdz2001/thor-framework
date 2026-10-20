# THOR-B033 · A standalone `ValueNotifier` as a state field

**Where:** `thor build` / `thor dev` · warning.

## What happened

A `ThorState` has a `ValueNotifier` or `ChangeNotifier` field that is not a `state(...)`. The field does not react in the browser.

## Why

The browser only listens to `state(...)` fields: nobody listens to a notifier of your own, so a `Watch` or a `ValueListenableBuilder` over it never updates.

## How to fix it

Make the field a `state(...)`: a `StateSignal` is a `ValueNotifier` (`addListener` and `ValueListenableBuilder` work on it) and it reacts in the browser.

```dart
// WRONG
final count = ValueNotifier<int>(0);
```

```dart
// RIGHT
final count = state(0);
```

More in [State](../../guia/en/state.md#valuenotifier-and-valuelistenablebuilder).

[All codes](README.md)
