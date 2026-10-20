# THOR-P012 · An environment secret reached a page

**Where:** `thor_server` · `RouteHandler` (with `thor dev`) and `exportSite` (always).

## What happened

The body or headers of a response contain the value of a loaded `EnvSecret`. With `thor dev` the response is a `500` that does not show the value; when exporting a static site, the export stops.

## Why

Whatever reaches the HTML or the JS can be seen by anyone and stays in caches and in the browser history. A `Secret` is no longer printed (`toString` gives `***`) or converted to JSON, but `reveal()` does give the text: this check catches the case where that text ends up in a page.

## How to fix it

Use the secret only on the server, where it is needed (signing a cookie, a header to the backend), and never pass it to a widget, a `ThorState` or `PageMeta`. If the browser needs a value, make it a public variable (`public: true`), not a secret.

```dart
// WRONG
Text('key: ${env.of(AppEnv.apiKey).reveal()}')
```

```dart
// RIGHT: it stays on the server
client.get(url, headers: {'authorization': 'Bearer ${env.of(AppEnv.apiKey).reveal()}'});
```

[All codes](README.md)
