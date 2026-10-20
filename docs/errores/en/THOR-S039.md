# THOR-S039 · The browser called a query or command the registry doesn't declare

**Where:** `thor dev` · server terminal, with the id (`MapState.near`).

## What happened

The browser made a `POST` to a query (`queryWith`) or command (`commandWith`) and the server answered `404` because the generated registry doesn't list that field.

## Why

The server only answers the ids the build declared. A `ThorState`'s public fields are included automatically, with a simple argument, a record or a class. If one is missing, the registry is out of date or the field isn't public (`_near`).

## How to fix it

```dart
// WRONG: private, it does not enter the registry
final _near = queryWith(repo.near, arg: (lat: 0.0, lng: 0.0));

// RIGHT
final near = queryWith(repo.near, arg: (lat: 0.0, lng: 0.0));
```

Rebuild (`thor dev` does it on save) and check the state and field names in the id.

[All codes](README.md)
