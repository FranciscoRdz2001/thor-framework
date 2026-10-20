# THOR-P004 · `next()` twice in a middleware

**Where:** `thor_server` · a group's middleware (`Group(middleware:)`).

## What happened

A middleware (`(request, next)`, in `Group(middleware: [...])`) called `next()` more than once in the same request.

## Why

`next()` runs everything below (cache, guards, action, loads and render). Calling it twice would render the page twice, run the action twice and mix two responses; the server cuts it off with a 500.

## How to fix it

```dart
// WRONG
Future<ThorResponse> handle(PageRequest r, Next next) async {
  await next(); // to measure
  return next();
}
```

```dart
// RIGHT
Future<ThorResponse> handle(PageRequest r, Next next) async {
  final response = await next(); // once; keep the response
  return response.withHeaders({'server-timing': 'app'});
}
```

[All codes](README.md)
