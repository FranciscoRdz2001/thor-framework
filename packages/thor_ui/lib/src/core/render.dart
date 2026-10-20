/// Rendering a widget tree to an HTML page, on the server: what the rest
/// of `thor_ui` asks of the render core, in one place (see `core.dart`).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:thor_server/thor_server.dart' show StaticFiles, ThorDev;

import '../foundation/css_rules.dart';
import '../foundation/foundation.dart' show kDebugMode;
import '../foundation/layout_hint.dart' show clearLayoutHints;
import '../widgets/cached.dart' show Cached;
import 'framework.dart' show Widget;
import 'page.dart';

export 'document.dart' show Document;

List<StyleRule> _styles = const [];
Future<T> Function<T>(Future<T> Function() body) _scope = _noScope;
bool _compact = !kDebugMode;

Future<T> _noScope<T>(Future<T> Function() body) => body();

/// Sets up rendering: [styles] go in every page's `<head>` (minified in
/// release), and every render runs inside [scope].
void initializeRender({
  List<StyleRule>? styles,
  required Future<T> Function<T>(Future<T> Function() body) scope,
}) {
  _styles = styles == null ? const [] : uniqueStyleRules(styles);
  _scope = scope;
  // Under `thor dev`, HTML rendered by the code before a hot reload goes.
  if (ThorDev.enabled) ThorDev.onReassemble(Cached.clear);
}

/// Whether pages are written without formatting whitespace (release) or
/// indented (debug). Tests set it to compare against release output.
set compactHtml(bool compact) => _compact = compact;

/// The HTML of [root], with status 200. A [standalone] fragment has no
/// document around it. A widget that fails to build throws (see
/// `writeComponent`).
Future<({int statusCode, List<int> body})> renderPage(
  Widget root, {
  bool standalone = false,
}) => _scope(() async {
  clearLayoutHints();
  try {
    if (_compact) {
      // Release: UTF-8 written straight from the tree.
      return (
        statusCode: 200,
        body: writeComponentUtf8(root, standalone: standalone, styles: _styles),
      );
    }
    final html = writeComponent(
      root,
      standalone: standalone,
      styles: _styles,
      compact: false,
    );
    return (statusCode: 200, body: utf8.encode(html));
  } finally {
    // The page's widgets aren't kept alive by the hints until the next one.
    clearLayoutHints();
  }
});

/// Serves [app] on `PORT` (8080 by default) with the files of the app's
/// `web/` folder: a static app in development (`thor dev`). Paths with an
/// extension that isn't a file are 404; every other path is the page.
Future<void> servePage(Widget app) async {
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final web = Directory('web');
  final files = web.existsSync() ? StaticFiles(web.path) : null;
  final server = await HttpServer.bind(
    InternetAddress.anyIPv4,
    port,
    shared: true,
  );
  stdout.writeln('thor: http://localhost:$port');
  if (ThorDev.enabled) {
    // `thor dev` hot reload: the page's widgets run the new code on the
    // next request; what caches old HTML goes.
    developer.registerExtension('ext.thor.reassemble', (_, _) async {
      ThorDev.reassembled();
      return developer.ServiceExtensionResponse.result(
        ThorDev.reassembledResult,
      );
    });
    ThorDev.exitWithParent();
  }
  await for (final request in server) {
    unawaited(_answer(request, app, files));
  }
}

Future<void> _answer(
  HttpRequest request,
  Widget app,
  StaticFiles? files,
) async {
  final response = request.response;
  try {
    final path = request.uri.path;
    final file = await files?.lookup(
      path,
      request.headers.value('accept-encoding'),
      request.headers.value('if-none-match'),
    );
    if (file != null) {
      response.statusCode = file.status;
      file.headers.forEach(response.headers.set);
      response.add(file.body);
    } else if (request.uri.pathSegments.lastOrNull?.contains('.') ?? false) {
      response.statusCode = HttpStatus.notFound;
    } else {
      final page = await renderPage(app);
      response
        ..statusCode = page.statusCode
        ..headers.contentType = ContentType.html
        ..add(page.body);
    }
  } on Object catch (e, s) {
    // The error goes to the log, never to the page.
    stderr.writeln('thor: ${request.uri} did not render: $e\n$s');
    response.statusCode = HttpStatus.internalServerError;
    if (ThorDev.enabled) {
      // For `thor dev`'s overlay (never in a release: see ThorDev).
      response
        ..headers.contentType = ContentType.html
        ..write(
          ThorDev.withBlocks('<!DOCTYPE html><html><body></body></html>', [
            ThorDev.errorBlock(
              phase: 'build',
              where: '${request.method} ${request.uri.path}',
              error: e,
              stack: s,
            ),
          ]),
        );
    }
  }
  await response.close();
}
