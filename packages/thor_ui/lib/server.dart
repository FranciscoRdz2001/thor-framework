/// Server side of a thor app: render pages to HTML, at build time (static
/// site) or per request.
///
/// ```dart
/// void main() {
///   initializeThor(styles: appStyles);
///   runApp(Document(title: 'My app', body: const App()));
/// }
/// ```
library;

import 'dart:async';
import 'dart:io';

import 'package:thor_engine/thor_engine.dart' show SignalScope;
import 'package:thor_server/thor_server.dart'
    show RouteHandler, ThorDev, ThorServer, currentImageManifest;

import 'router.dart' show WidgetRenderer;
import 'src/core/core.dart' show BuildContext, StatelessWidget, Widget;
import 'src/core/render.dart';
import 'src/foundation/const_memo.dart';
import 'src/foundation/css_rules.dart';
import 'src/foundation/image_manifest_scope.dart';
import 'src/foundation/inspect.dart' show ThorInspect;
import 'src/foundation/localizations.dart' show Locale, PreferredLocales;
import 'src/foundation/style_registry.dart' show ThorApp;

export 'src/core/document.dart' show Document;
export 'src/foundation/localizations.dart' show Locale;

/// Initializes thor on the server. Call it once, before `runApp`.
///
/// [styles] are the app's own stylesheet rules (what no widget covers), in
/// every page, in this order.
///
/// Every page render runs in its own
/// `SignalScope`: signals written while rendering one page are invisible
/// to the others, so top-level signals are safe in server mode too.
void initializeThor({List<StyleRule>? styles}) {
  initializeRender(
    styles: styles,
    // A lambda: the generic tear-off (`R Function<R>`) has no Future bound.
    // ignore: unnecessary_lambdas
    // A render inside a request's scope (`WidgetRenderer.inRequestScope`)
    // reads what the request's loads wrote: it keeps that scope.
    scope: <T>(body) => SignalScope.isActive ? body() : SignalScope.run(body),
  );
  // `THOR_CONST_MEMO` (`on`, `verify`) turns on the memo of const
  // subtrees; a `thor dev` reload drops what it kept.
  final memo = switch (Platform.environment['THOR_CONST_MEMO']) {
    'on' => ConstMemoMode.on,
    'verify' => ConstMemoMode.verify,
    _ => null,
  };
  if (memo != null) ConstMemo.mode = memo;
  if (ThorDev.enabled && !_constMemoHooked) {
    _constMemoHooked = true;
    ThorDev.onReassemble(ConstMemo.clear);
    ThorDev.onReassemble(ThorInspect.clearSources);
  }
}

bool _constMemoHooked = false;

/// Serves [app] (a `Document`): the entry of a static app.
///
/// With `THOR_RENDER_TO=<file>` in the environment it renders the page once
/// to that file instead, with no server: how `thor build` pre-renders a
/// static app. A page that doesn't render (an exception, a status other
/// than 200) fails the process.
///
/// `THOR_LOCALE=es` renders it in that locale: the visitor's preferred
/// locale for a localized `ThorApp` (how `thor build` pre-renders each
/// locale of `lib/l10n/`).
///
/// `THOR_IMAGES=<file>` is the build's image manifest: an
/// `Image.asset` it lists gets its sizes and its `srcset`.
///
/// A [ThorApp.router] is served instead: its routes, its locales, each
/// page drawn in it, `PORT` (default 4300) and `build/public` (after `thor
/// build`) else `web/`. An app that needs more (the environment checked
/// first, sessions, shared stylesheets) builds its `ThorServer` with
/// `RouteHandler(routes: app.routes, locales: app.localeRouting, renderer:
/// WidgetRenderer.router(app, …))`.
void runApp(Widget app) {
  if (app case final ThorApp routed when routed.routerConfig != null) {
    unawaited(
      ThorServer.serve(
        () => ThorServer(
          handler: RouteHandler(
            routes: routed.routes,
            locales: routed.localeRouting,
            renderer: WidgetRenderer.router(routed),
          ),
          publicDir: ThorServer.appPublicDir(),
        ),
        port: int.tryParse(Platform.environment['PORT'] ?? '') ?? 4300,
      ),
    );
    return;
  }
  if (ThorDev.enabled) {
    // A new image in web/images/ reaches the next render.
    app = _LiveImages(child: app);
  } else {
    final images = currentImageManifest();
    if (!images.isEmpty) {
      app = ImageManifestScope(manifest: images, child: app);
    }
  }
  final tag = Platform.environment['THOR_LOCALE'];
  if (tag != null && tag.isNotEmpty) {
    final locale = Locale.tryParse(tag);
    if (locale == null) {
      stderr.writeln('thor: THOR_LOCALE=$tag is not a language tag');
      exit(64);
    }
    app = PreferredLocales(locales: [locale], child: app);
  }
  final target = Platform.environment['THOR_RENDER_TO'];
  if (target == null) {
    servePage(app);
    return;
  }
  unawaited(_renderTo(app, File(target)));
}

Future<void> _renderTo(Widget app, File target) async {
  try {
    final result = await renderPage(app);
    if (result.statusCode != 200) {
      stderr.writeln('thor: the page answered ${result.statusCode}');
      exit(1);
    }
    target.parent.createSync(recursive: true);
    target.writeAsBytesSync(result.body);
    exit(0);
  } on Object catch (e, s) {
    stderr
      ..writeln('thor: the page did not render: $e')
      ..writeln(s);
    exit(1);
  }
}

/// The image manifest of each render under `thor dev`: the one read after
/// the last hot reload.
class _LiveImages extends StatelessWidget {
  const _LiveImages({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ImageManifestScope(manifest: currentImageManifest(), child: child);
}
