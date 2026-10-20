# THOR-P016 · A middleware in the list failed

**Where:** `thor_server` · the middleware chain of a `Group` or a `ThorRoute` (`chainMiddleware`).

## What happened

A middleware threw an error that is not a `Redirect` or `HttpError`, or called `next()` twice. The message says which one: its name (the function's, or the one you gave it with `namedMiddleware`), its position in the list and which list it belongs to. The stack trace is the original error's.

## Why

A middleware list is a single chain; without the name, a 500 would not say which of them failed. An error that comes from further down (another middleware, the page) keeps its own name.

## How to fix it

Fix that middleware. To cut the request short on purpose, use `throw Redirect(...)`, `throw HttpError(...)` or return a response without calling `next()`:

```dart
// WRONG
Future<ThorResponse> requireUser(PageRequest request, Next next) {
  final user = request.context.get(session);   // StateError without a session
  return next();
}
```

```dart
// RIGHT
Future<ThorResponse> requireUser(PageRequest request, Next next) {
  if (request.context.maybeGet(session) == null) {
    throw Redirect.found(loginRoute.link());
  }
  return next();
}
```

A middleware that returns a function (`requireRole('admin')`) is named with `namedMiddleware('requireRole(admin)', …)`.

[All codes](README.md)
