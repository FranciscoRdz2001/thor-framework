# THOR-P037 · `PageRequest.loaded<D>()` with no loaded data

**Where:** `thor_server` · `PageRequest.loaded`.

## What happened

The code called `PageRequest.loaded<D>()` when the request had no `load` data (or no level loaded a `D`).

## Why

`loaded<D>()` returns what the page's `load` and its layouts' loads returned, for code that only reaches the request with `PageRequest.current` (a query's function, an `events()` `initial`). That data exists while the page draws and runs its queries. A command or a browser `refresh` is another request that does not load the page again: there is nothing to read. It looks for the value: if no `load` returned a `D`, the message lists the types they did return.

## How to fix it

```dart
// WRONG — a command runs in its own request: the page was not loaded
Future<void> save() async => repo.save(PageRequest.current.loaded<Doc>());
```

```dart
// RIGHT — the page's own drawing reads it; a command takes it as its argument
final feed = events<String>('/doc/stream', initial: () => PageRequest.current.loaded<Doc>().title);

final save = commandWith(repo.save); // Future<void> save(DocEdit edit)
```

[All codes](README.md)
