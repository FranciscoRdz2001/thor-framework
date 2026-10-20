# THOR-P010 · A cookie after the early response

**Where:** `thor_server` · `RouteHandler` (a route with `earlyHints`).

## What happened

A page with `earlyHints` took longer than `earlyHintsAfter` to load its data: the server had already sent the status and the headers (with the `Link` headers for its style sheets) and, afterwards, a `load` or the `build` set a cookie.

## Why

Cookies travel in the headers, and the headers have already gone out. The cookie does not reach the browser: the server reports it and discards it.

## How to fix it

Set the cookie before the response: in a middleware of the group (`Group(middleware:)`), in a guard or in an action. Or remove `earlyHints` from that group.

```dart
// WRONG: in PanelPage, under Group(earlyHints: true, …)
@override
Future<Panel> load(PageRequest request) async {
  request.response.setCookie('seen', '1');
  return api.panel();
}
```

```dart
// RIGHT: a middleware of the group, Group(middleware: [markSeen], …)
Future<ThorResponse> markSeen(PageRequest request, Next next) {
  request.response.setCookie('seen', '1');
  return next();
}
```

[All codes](README.md)
