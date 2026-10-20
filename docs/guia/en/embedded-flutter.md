# Embedded Flutter

`FlutterView` places a Flutter web app in a region of a Thor page, such as a chart, an editor or a game, while the rest of the page stays indexable HTML.

:::flutter Flutter: `HtmlElementView` inside an app · Thor: `FlutterView` inside a page

```dart
FlutterView(
  src: '/flutter/', // the folder of the Flutter build
  initialData: {'view': 'chart', 'values': [12, 19, 7]},
  aspectRatio: 16 / 9, // or height: 320
  semanticLabel: 'Sales per month',
  placeholder: const Center(child: Text('Sales: Jan 12 · Feb 19 · Mar 7')),
  onMessage: sales.tapped, // a method of a view model
)
```

## Loading the view

The server renders a box at its final size with the `placeholder` inside. Without JavaScript, the `placeholder` is the content: put the HTML version of what Flutter draws there, like the chart's numbers.

With the first view, a loader under 1 KB downloads the Flutter build. A single Flutter app serves every view on the page, and each `FlutterView` is a new view with its own `initialData`. The `placeholder` is removed when the view paints its first frame, without changing the box's size; if the build doesn't load, it stays.

| `loading` | The view is mounted |
| --- | --- |
| `visible` (default) | when it's within 200 px of the screen |
| `idle` | when the browser becomes idle after the page loads |
| `interaction` | on the first tap, focus or key press inside it; that tap doesn't reach Flutter |
| `eager` | when the page loads, only if the view is the reason for the page |

## Size

A Flutter view isn't sized by its content: set `height` or `aspectRatio`. The width is `width` or all the available space, never more than the parent. Without a height, or with a size that is `0`, negative or infinite, the page fails to render.

## The Flutter project

The Flutter project uses `runThorEmbed` instead of `runApp` and builds one widget per view. `runThorEmbed` lives in `thor_embed.dart`, a file that only depends on `package:web`: copy it into the project's `lib/` folder from [The bootstrap file](#the-bootstrap-file).

```dart no-check
void main() {
  runThorEmbed((context, embed) => MaterialApp(
    home: switch (embed.map['view']) {
      'chart' => BarChart(embed: embed),
      _ => const SizedBox(),
    },
  ));
  SemanticsBinding.instance.ensureSemantics(); // accessibility from the start
}
```

`runThorEmbed` creates a `View` for each view on the page, exposes its `initialData` in `embed.data` (or `embed.map`) and notifies the page after the first frame.

### Messages to the page

`embed.send({'bar': 'apr'})` reaches `FlutterView(onMessage:)` as a `String` with the JSON. With a method of a ViewModel (`ThorState`), the message can change the rest of the page:

```dart
class SalesViewModel extends ThorState {
  final last = state('');

  void tapped(String json) => last.value = json;
}
```

> **Important:** Treat the message as data from another program: unexpected JSON must not break the page. Messages that arrive before the ViewModel starts are lost, and only `initialData` travels from the page to Flutter.

### The bootstrap file

```dart no-check
// lib/thor_embed.dart
/// The Flutter side of thor's `FlutterView`: one Flutter app that draws a
/// widget in every host element a thor page adds as a view.
///
/// Copy this file into your Flutter project (it only needs `package:web`).
/// The page's loader adds one view per `FlutterView` with the JSON of its
/// `initialData`; this file reads it back, tells the page when the view
/// painted its first frame (the placeholder goes away then) and sends
/// messages to the page (`FlutterView(onMessage:)`).
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui' show FlutterView;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Event the host element receives after the view's first frame.
const readyEvent = 'thor-flutter-ready';

/// Event (bubbling, `detail` = a JSON string) with a message for the page.
const messageEvent = 'thor-flutter-message';

/// What a view knows about its place in the page.
class ThorEmbed {
  ThorEmbed._(this.viewId, this.data, this._host);

  /// The Flutter view's id.
  final int viewId;

  /// The `initialData` of the page's `FlutterView` (decoded JSON), or null.
  final Object? data;

  final web.Element? _host;

  /// [data] as a map (empty when it is not one).
  Map<String, Object?> get map =>
      data is Map ? (data! as Map).cast<String, Object?>() : const {};

  /// Sends [message] (JSON-encodable) to the page: `FlutterView(onMessage:)`
  /// receives it as a JSON string once the page's engine is running.
  void send(Object? message) {
    _host?.dispatchEvent(
      web.CustomEvent(
        messageEvent,
        web.CustomEventInit(detail: jsonEncode(message).toJS, bubbles: true),
      ),
    );
  }

  /// The [ThorEmbed] of the view [context] is in.
  static ThorEmbed of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_EmbedScope>()!.embed;
}

/// Runs [builder] in every view the page adds (use it instead of `runApp`).
void runThorEmbed(
  Widget Function(BuildContext context, ThorEmbed embed) builder,
) {
  runWidget(_MultiView(builder: builder));
}

class _MultiView extends StatefulWidget {
  const _MultiView({required this.builder});

  final Widget Function(BuildContext context, ThorEmbed embed) builder;

  @override
  State<_MultiView> createState() => _MultiViewState();
}

class _MultiViewState extends State<_MultiView> with WidgetsBindingObserver {
  Map<Object, Widget> _views = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _update();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Views are added and removed from JS; Flutter reports it as a change of
  // metrics.
  @override
  void didChangeMetrics() => setState(_update);

  void _update() {
    _views = {
      for (final FlutterView view
          in WidgetsBinding.instance.platformDispatcher.views)
        view.viewId: _views[view.viewId] ?? _create(view),
    };
  }

  Widget _create(FlutterView view) {
    final id = view.viewId;
    final host = ui_web.views.getHostElement(id) as web.Element?;
    final embed = ThorEmbed._(
      id,
      ui_web.views.getInitialData(id).dartify(),
      host,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The frame is on screen after the next animation frame.
      web.window.requestAnimationFrame(
        ((JSNumber _) => host?.dispatchEvent(web.Event(readyEvent))).toJS,
      );
    });
    return View(
      view: view,
      child: _EmbedScope(
        embed: embed,
        child: Builder(builder: (context) => widget.builder(context, embed)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      ViewCollection(views: _views.values.toList(growable: false));
}

class _EmbedScope extends InheritedWidget {
  const _EmbedScope({required this.embed, required super.child});

  final ThorEmbed embed;

  @override
  bool updateShouldNotify(_EmbedScope old) => false;
}
```

## Building

Declare the Flutter project in the app's `pubspec.yaml`:

```yaml
thor:
  flutter:
    project: flutter_widgets # the folder of the Flutter project
    public: flutter          # published at /flutter/ (the default)
    cdn: false               # true: CanvasKit from gstatic.com
```

`thor build` runs `flutter build web --release` in that project and puts the result in `web/flutter/`, which is published along with the other public files. It looks for Flutter in `FLUTTER_ROOT` or on the `PATH`; `thor build --no-flutter` reuses the existing build.

- `thor dev` serves `web/`: after a `thor build`, views work in development; without a build, you see the `placeholder`s.
- If the project has no `web/flutter_bootstrap.js`, `thor build` writes Thor's; with `flutter run`, that bootstrap draws a single view so you can develop the widget on its own.
- The Flutter project isn't part of the app's Dart workspace, because it needs the Flutter SDK.

Flutter web downloads the compiled app and CanvasKit, several megabytes per user the first time. That's why `visible` is the default and the rest of the page doesn't wait.

## Security

- `initialData` is escaped when rendering and reaches Flutter unchanged. A value that can't be encoded as JSON, such as a `DateTime`, fails at render time.
- With Content Security Policy, allow the loader by its `sha256-…` hash and add `'wasm-unsafe-eval'` to `script-src`; with `cdn: true` or Flutter's default fonts, also `https://www.gstatic.com` and `https://fonts.gstatic.com` ([Session and security](session-and-security.md#content-security-policy)).
- A page runs a single Flutter app: two `FlutterView`s with different `src` fail to render.

## Accessibility

`semanticLabel` turns the box into a region with that name, marked as busy while loading. Inside, Flutter's semantics tree exposes real buttons and text; `SemanticsBinding.instance.ensureSemantics()` enables it from the start. The `placeholder` is what a screen reader reads without JavaScript: it must say the same as the view.

## Limits

- `FlutterView` needs `ThorApp`: without it, the box renders but the view doesn't load.
- Views are never removed: each navigation loads a new page.
- Flutter's files don't carry a hash in their names: configure their caching on the host or publish each version in its own folder (`src: '/flutter-v2/'`).

## Next steps

:::cards
- [State](state.md) — the ViewModel that receives Flutter's messages
- [Build and deploy](build-and-deploy.md) — caching and headers on the host
- [What runs where](how-it-works.md) — what Thor sends to the browser
:::
