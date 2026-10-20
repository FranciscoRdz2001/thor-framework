# THOR-P019 · `PageRequest.current` outside a query or a command

**Where:** `thor_server` · `PageRequest.current`.

## What happened

The code read `PageRequest.current` outside a query or command function (`query(fn)` or `command(fn)` in a `ThorState`).

## Why

A query or command function does not receive the request (so any repository method works), and it reaches it —the session the middleware left, the cookies— with `PageRequest.current`. Thor sets it only while the function runs: when painting the page, when answering a `refresh` and when running a command the browser asked for. A `load`, an action or a middleware already receive the request as a parameter.

## How to fix it

```dart
// WRONG — in a load
Future<Profile> load(PageRequest request) => repo.forUser(PageRequest.current);
```

```dart
// RIGHT — a load uses its parameter; a query function reads current
Future<Profile> load(PageRequest request) => repo.forUser(request);

Future<Profile> info() async {                     // query(repo.info)
  final user = PageRequest.current.context.get(currentUser);
  return db.profile(user);
}
```

[All codes](README.md)
