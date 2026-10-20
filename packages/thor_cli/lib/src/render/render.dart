/// `thor render`: one route (or one widget) of an app → its HTML, its CSS,
/// its accessibility tree, the server's errors, the inspector's warnings
/// and screenshots, in seconds.
///
/// Structure: nothing new on the server. It runs the app like `thor dev`
/// (JIT, `THOR_DEV=1`: error blocks and `data-thor-src` in the HTML), asks
/// for the page over HTTP, and stops it; the browser part only reads what
/// the page already carries.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../assets.dart';
import '../dotenv.dart';
import '../run.dart';
import '../workspace.dart';
import 'browser.dart';
import 'report.dart';

/// What to render and how.
class RenderRequest {
  /// A request for [target]: a route (`/news/2?x=1`) or, with [widget], a
  /// widget (`lib/widgets/card.dart#Card`).
  const RenderRequest(
    this.target, {
    this.widget = false,
    this.cookies = const {},
    this.widths = const [390, 800, 1440],
    this.browser = true,
    this.codegen = true,
    this.outDir,
  });

  /// The route, or `file.dart#Name` with [widget].
  final String target;

  /// Whether [target] is a widget, not a route.
  final bool widget;

  /// Cookies sent with the request (a session).
  final Map<String, String> cookies;

  /// Screenshot widths.
  final List<int> widths;

  /// Whether to use the browser (screenshots, ARIA, warnings, console).
  final bool browser;

  /// Whether to run code generation first.
  final bool codegen;

  /// Where screenshots go (default `.dart_tool/thor/render/<slug>`).
  final String? outDir;
}

/// Renders [request] in [app].
Future<RenderReport> render(Project app, RenderRequest request) async {
  final clock = Stopwatch()..start();
  await pubGetIfStale(app.pubRoot, app.dir);
  // A package's files (a design system's fonts) are served from web/: the
  // screenshots would show them missing otherwise.
  PublicAssets(app).sync();
  if (request.codegen) await generate(app.dir);
  final out =
      request.outDir ??
      app.path(p.join('.dart_tool', 'thor', 'render', _slug(request.target)));
  if (request.widget) return _renderWidget(app, request, out, clock);

  final port = await _anyFreePort();
  final server = await _startServer(app, port);
  try {
    final base = Uri.parse('http://127.0.0.1:$port');
    final page = await _get(base.resolve(request.target), request.cookies);
    final linked = <String, String>{};
    for (final href in localStylesheets(page.body)) {
      final css = await _get(base.resolve(href), request.cookies);
      if (css.status == 200) linked[href] = css.body;
    }
    BrowserResult? browser;
    String? why;
    if (request.browser && page.status == 200) {
      try {
        browser = await runBrowser(
          url: '${base.resolve(request.target)}',
          appDir: app.dir,
          outDir: out,
          widths: request.widths,
          cookies: request.cookies,
        );
      } on BrowserMissing catch (e) {
        why = e.reason;
      }
    } else if (request.browser) {
      why = 'status ${page.status}: nothing to show';
    }
    return RenderReport(
      target: request.target,
      status: page.status,
      location: page.location,
      html: page.body,
      linkedCss: linked,
      browser: browser,
      browserError: why,
      elapsed: clock.elapsed,
    );
  } finally {
    await _stop(server);
  }
}

/// A widget: a generated entry renders `ThorApp(child: Name())` (a class
/// with a no-argument constructor or a function returning a widget) and
/// prints the page; the browser part gets it from a throwaway server.
Future<RenderReport> _renderWidget(
  Project app,
  RenderRequest request,
  String out,
  Stopwatch clock,
) async {
  final hash = request.target.lastIndexOf('#');
  if (hash <= 0 || hash == request.target.length - 1) {
    throw ThorException(
      'A widget is `file.dart#Name`: a class with a no-argument '
      'constructor or a function that returns a Widget '
      '(got "${request.target}").',
    );
  }
  final file = p.absolute(app.dir, request.target.substring(0, hash));
  final name = request.target.substring(hash + 1);
  if (!File(file).existsSync()) throw ThorException('No file $file.');
  final entry = File(app.path('.dart_tool/thor/render/widget_entry.dart'))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(
      widgetEntry(
        Uri.file(file),
        name,
        states: File(app.path('.dart_tool/thor/states.dart')).existsSync(),
      ),
    );
  final result = await Process.run(
    'dart',
    ['run', entry.path],
    workingDirectory: app.dir,
    environment: appEnvironment(app.dir, const {'THOR_DEV': '1'}),
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (result.exitCode != 0) {
    throw ThorException('The widget did not render:\n${result.stderr}');
  }
  final html = result.stdout as String;
  BrowserResult? browser;
  String? why;
  if (request.browser) {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) {
      final static = _static(app, r.uri.path);
      if (static != null) {
        r.response.headers.contentType = _type(static.path);
        r.response.add(static.readAsBytesSync());
      } else {
        r.response.headers.contentType = ContentType.html;
        r.response.write(html);
      }
      unawaited(r.response.close());
    });
    try {
      browser = await runBrowser(
        url: 'http://127.0.0.1:${server.port}/',
        appDir: app.dir,
        outDir: out,
        widths: request.widths,
      );
    } on BrowserMissing catch (e) {
      why = e.reason;
    } finally {
      await server.close(force: true);
    }
  }
  return RenderReport(
    target: request.target,
    status: 200,
    html: html,
    browser: browser,
    browserError: why,
    elapsed: clock.elapsed,
  );
}

/// The entry that renders widget [name] of [library] as a page; with
/// [states], it registers the app's states first (`../states.dart`, next
/// to it in `.dart_tool/thor/`).
String widgetEntry(Uri library, String name, {bool states = false}) =>
    '''
// Generated by `thor render --widget`.
import 'dart:io';

import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

import '$library' as target;
${states ? "import '../states.dart';\n" : ''}
Future<void> main() async {
  ${states ? 'registerThorStates();\n  ' : ''}initializeThorTests(compactHtml: false);
  stdout.write(await renderDocument(ThorApp(child: target.$name())));
}
''';

Future<Process> _startServer(Project app, int port) async {
  final server = await Process.start(
    'dart',
    ['run', app.entry],
    workingDirectory: app.dir,
    environment: appEnvironment(app.dir, {
      'PORT': '$port',
      'ISOLATES': '1',
      'THOR_DEV': '1',
    }),
  );
  final listening = Completer<void>();
  final errors = <String>[];
  server.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((
    line,
  ) {
    if (line.startsWith('thor: http') || line.startsWith('Serving at http')) {
      if (!listening.isCompleted) listening.complete();
    }
  });
  server.stderr.transform(utf8.decoder).listen(errors.add);
  unawaited(
    server.exitCode.then((code) {
      if (!listening.isCompleted) {
        listening.completeError(
          ThorException(
            'The app exited with code $code before listening:\n'
            '${errors.join()}',
          ),
        );
      }
    }),
  );
  await listening.future.timeout(
    const Duration(minutes: 2),
    onTimeout: () {
      server.kill(ProcessSignal.sigkill);
      throw ThorException('The app did not start in 2 minutes.');
    },
  );
  return server;
}

/// A port the system says is free (two renders at once get different
/// ones, unlike a scan from a fixed start).
Future<int> _anyFreePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

/// Stops the app: `THOR_DEV` servers leave when their stdin closes; a
/// kill in case it doesn't.
Future<void> _stop(Process server) async {
  unawaited(server.stdin.close().catchError((Object _) {}));
  final code = await server.exitCode
      .then<int?>((c) => c)
      .timeout(const Duration(seconds: 3), onTimeout: () => null);
  if (code == null) {
    server.kill(ProcessSignal.sigkill);
    await server.exitCode;
  }
}

Future<({int status, String body, String? location})> _get(
  Uri url,
  Map<String, String> cookies,
) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(url);
    request.followRedirects = false;
    if (cookies.isNotEmpty) {
      request.headers.set(
        HttpHeaders.cookieHeader,
        [for (final e in cookies.entries) '${e.key}=${e.value}'].join('; '),
      );
    }
    final response = await request.close();
    return (
      status: response.statusCode,
      body: await utf8.decodeStream(response),
      location: response.headers.value(HttpHeaders.locationHeader),
    );
  } finally {
    client.close(force: true);
  }
}

/// The app's own stylesheets [html] links (not other hosts').
Iterable<String> localStylesheets(String html) sync* {
  for (final m in RegExp(r'<link\b[^>]*>').allMatches(html)) {
    final tag = m[0]!;
    if (!tag.contains('stylesheet')) continue;
    final href = RegExp(r'href="([^"]+)"').firstMatch(tag)?[1];
    // Only the app's own sheets: nothing from other hosts.
    if (href != null && !href.startsWith('http') && !href.startsWith('//')) {
      yield href;
    }
  }
}

File? _static(Project app, String path) {
  if (path == '/' || path.contains('..')) return null;
  final file = File(p.join(app.dir, 'web', path.substring(1)));
  return file.existsSync() ? file : null;
}

ContentType _type(String path) => switch (p.extension(path)) {
  '.css' => ContentType('text', 'css', charset: 'utf-8'),
  '.js' => ContentType('text', 'javascript', charset: 'utf-8'),
  '.svg' => ContentType('image', 'svg+xml'),
  '.png' => ContentType('image', 'png'),
  '.woff2' => ContentType('font', 'woff2'),
  _ => ContentType.binary,
};

String _slug(String target) {
  final slug = target
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
      .replaceAll(RegExp('^-+|-+\$'), '');
  return slug.isEmpty ? 'root' : slug;
}
