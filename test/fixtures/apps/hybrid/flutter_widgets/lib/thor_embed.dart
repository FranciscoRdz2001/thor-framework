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
