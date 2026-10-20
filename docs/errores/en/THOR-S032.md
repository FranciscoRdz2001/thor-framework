# THOR-S032 · A row with a lambda but without its class probe

**Where:** `thor_ui` · `row.text((o) => o.property)` when painting.

## What happened

`row.text` received a lambda and Thor doesn't have the row's class registered. It happens when running the app without `thor` (a bare `dart run bin/server.dart`, a test with `dart test`).

## Why

Thor works out which property the lambda reads while preparing the app, and that runs with `thor dev`, `thor build`, `thor test` and `thor render`.

## How to fix it

Run the app or its tests with `thor`. Or pass a state method, which needs no probe:

```dart
row.text(orders.customerOf)      // String customerOf(Order o) => o.customer
```

More in [State](../../guia/en/state.md#lists).

[All codes](README.md)
