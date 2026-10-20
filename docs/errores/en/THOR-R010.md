# THOR-R010 · `RequestScope.of` outside a page

**Where:** `thor_ui/router.dart` · `RequestScope.of`.

## What happened

A widget asked for the request (`RequestScope.of(context)`) and no route is being rendered.

## Why

Only the pages served by `RouteHandler` with `WidgetRenderer` publish the request. A widget reused in a static app, a test or a shared `Cached` doesn't have it.

## How to fix it

```dart
// WRONG
final user = RequestScope.of(context).locals['user'];
```

```dart
// RIGHT
// Read it in the route's load and pass it as a parameter:
Future<User?> load(PageRequest request) async => request.locals['user'] as User?;
Widget build(BuildContext context, PageState<User?> state) => Header(user: state.data);
```

[All codes](README.md)
