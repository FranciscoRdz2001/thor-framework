# THOR-P034 · A `query` or a `command` threw an exception that is not an `HttpError`

**Where:** `thor_server` · the call of a `query`/`command` (only with `thor dev`: first line of `detail` in the overlay and a `[thor]` line in the server console).

## What happened

The function of a `query` or a `command` threw `Exception('No connection')` (or a `StateError`, a database error…). The page shows "Something went wrong" (the app's `generic` message) and the exception's text does not reach the browser; `thor dev` also reports it as a page error.

## Why

An ordinary exception can carry paths, SQL or keys: Thor never sends it to a visitor. Only the message of an `HttpError` (or of a `Redirect`) is meant for whoever is looking at the screen. In Flutter a `FutureBuilder` shows `snapshot.error` as is; here that step is explicit.

## How to fix it

```dart
// WRONG: the page shows "Something went wrong", not this text
Future<List<Product>> fetch(bool fail) async {
  if (fail) throw Exception('No connection');
  ...
}
```

```dart
// RIGHT: an HttpError carries a status and a message for the visitor
Future<List<Product>> fetch(bool fail) async {
  if (fail) throw const HttpError(503, 'No connection');
  ...
}
```

On the page: `QueryError(products)` paints that message (and `snapshot.error` in a `QueryBuilder`). More in [State](../../guia/en/state.md#server-data).

[All codes](README.md)
