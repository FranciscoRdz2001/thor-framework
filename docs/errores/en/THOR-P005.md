# THOR-P005 · A value is missing from `request.context`

**Where:** `thor_server` · `RequestContext.get`.

## What happened

A `load`, an action, a guard or a widget asked for `request.context.get(key)` and no middleware of the groups that contain the route set that key.

## Why

The route is not in the `children` of the `Group` whose middleware sets the value (for example, it sits next to the group of signed-in pages instead of inside it), or the middleware only sets it in some cases (a session that may be missing).

## How to fix it

```dart
// WRONG
// ReportsPage.load reads request.context.get(currentUser)
final ThorRouter router = ThorRouter([
  Group(middleware: [session], children: [panelRoute]),
  reportsRoute,
]);
```

```dart
// RIGHT
final ThorRouter router = ThorRouter([
  Group(middleware: [session], children: [panelRoute, reportsRoute]),
]);

// or, if the value may be missing, read it as optional:
final user = request.context.maybeGet(currentUser);
if (user == null) throw Redirect.found(loginRoute.link());
```

[All codes](README.md)
