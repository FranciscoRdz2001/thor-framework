# thor_server

thor's server, in pure Dart over `dart:io`: routes (a table in code), data
loaded before the page renders (`load`), form actions (POST, then redirect),
cookies and sessions, static files with `ETag`/304, a page cache that serves
stale while it refreshes, health checks and a clean shutdown on `SIGTERM`.

Pages are rendered by a `PageRenderer`; `thor_ui` provides the one that turns
Flutter-style widgets into HTML. An app imports it through
`package:thor_ui/server.dart` and `package:thor_ui/router.dart`, and runs it
with `ThorServer.serve`.

```dart
Future<void> main() => ThorServer.serve(
  () => ThorServer(handler: RouteHandler(routes: app.routes, renderer: renderer)),
);
```

See [the guide](https://thor-docs.vercel.app) for routes, data and deploying.
