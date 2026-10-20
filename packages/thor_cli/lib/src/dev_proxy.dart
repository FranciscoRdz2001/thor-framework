import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:thor_server/thor_server.dart'
    show DevHosts, frameAncestorsPolicy;

import 'dev/inspect.dart';
import 'dev/overlay.dart';
import 'live_reload.dart';
import 'run.dart' show ThorException;

export 'live_reload.dart';

/// What `thor dev` puts in front of the app: one stable port while the app
/// restarts, and the browser reloading itself when it does.
///
/// Every request goes to the app's server ([upstream]). While the app
/// restarts, requests wait for it instead of failing; if it doesn't start
/// (a compile error), they get a page with the error that reloads itself
/// once the code is fixed. HTML pages get a small script that listens on
/// [eventsPath] and reloads the page when the app changes, keeping its
/// scroll, form fields, focus and `ThorState` values ([liveReloadScript]).
///
/// Errors show over the page ([overlayScript]), with the file and line and
/// the code there: an exception of a page (the error blocks the app's
/// server writes under `thor dev`, see `ThorDev`), a compile error of the
/// server or of the engine, a failure of code generation ([problem]).
class DevProxy {
  /// A proxy for the app listening on [upstream] (a port on this machine);
  /// [sources] locates the files of stack traces.
  DevProxy({
    required this.upstream,
    this.wait = const Duration(seconds: 30),
    SourceMap? sources,
    this.hosts = const DevHosts(),
    bool? overlayUi,
    List<String>? frameAncestors,
    this.injectScripts = const [],
  }) : sources =
           sources ??
           SourceMap(appDir: Directory.current.path, packages: const {}),
       overlayUi = overlayUi ?? Platform.environment['THOR_OVERLAY'] != 'off',
       _framePolicy = _framing(
         frameAncestors ??
             parseFrameAncestors(Platform.environment['THOR_FRAME_ANCESTORS']),
       );

  /// `frame-ancestors 'self' …` for the origins that may frame the app, or
  /// null (dart:io's `X-Frame-Options: SAMEORIGIN` stays: nobody else does).
  final String? _framePolicy;

  /// The origins that may frame the app (an editor that shows it in an
  /// iframe from another origin): `frameAncestors:`, or `THOR_FRAME_ANCESTORS`
  /// (comma-separated). None by default; a wildcard or a path is refused.
  /// Every response then carries `Content-Security-Policy: frame-ancestors
  /// 'self' ORIGINS` and no `X-Frame-Options`, the app's own
  /// `X-Frame-Options` is dropped and its `frame-ancestors` directive is
  /// replaced, so the app's `DENY` cannot blank the iframe.
  bool get allowsFraming => _framePolicy != null;

  static String? _framing(List<String> origins) {
    if (origins.isEmpty) return null;
    try {
      return frameAncestorsPolicy(origins);
    } on ArgumentError catch (e) {
      throw ThorException(
        'frame ancestors (THOR_FRAME_ANCESTORS): ${e.message} '
        '(got "${e.invalidValue}")',
      );
    }
  }

  /// JavaScript files put in every page the app serves, as one inline
  /// `<script>` each, after the live reload (`thor dev --inject <file>`): an
  /// editor's bridge into the page, a probe. They are read on every request,
  /// so a change shows on the next reload; one that can't be read is
  /// skipped. Dev only: a release build never goes through the proxy.
  final List<File> injectScripts;

  /// Where the files of stack traces are.
  final SourceMap sources;

  /// The `Host` values it answers to; any other gets a 403 (DNS
  /// rebinding: [DevHosts]).
  final DevHosts hosts;

  /// Failures that don't stop the app (the engine didn't compile): shown
  /// over every page until [clearProblem].
  final _problems = <String, List<Map<String, Object?>>>{};

  /// The editor the inspector opens (`THOR_EDITOR`: vscode, cursor, zed,
  /// idea or none).
  final InspectEditor editor = InspectEditor.parse(
    Platform.environment['THOR_EDITOR'],
  );

  /// Whether the overlay is drawn (`THOR_OVERLAY=off` turns it off). Off,
  /// every page gets the script anyway, with nothing drawn: a host (an
  /// editor embedding the app) reads `window.__thorDevErrors` and the
  /// `thor:dev-errors` event, also for the browser's uncaught errors of a
  /// page the server rendered clean.
  final bool overlayUi;

  /// Shows [title] and [detail] (a compiler's output) over every page
  /// until [clearProblem] with the same [key]; pages reload.
  ///
  /// [detail] lines like `file:line:col: Error: …` (or `Warning:`) become
  /// entries with their file, the code there, the code's page and the fix;
  /// warnings show as a badge, errors cover the page. The same problem
  /// again reloads nothing.
  ///
  /// With [strict] every line of [detail] is a finding (a line that is not
  /// a diagnostic is an error, not noise): for `.dart_tool/thor/`'s files.
  void problem(String key, String title, String detail, {bool strict = false}) {
    final entries = compileEntries(
      key,
      title,
      detail,
      sources,
      keepUnparsed: strict,
    );
    final same = jsonEncode(_problems[key] ?? const []) == jsonEncode(entries);
    _problems[key] = entries;
    if (!same) _broadcast('reload');
  }

  /// The failure [key] is fixed; with [reload], pages that showed it
  /// reload (when nothing else will reload them).
  void clearProblem(String key, {bool reload = false}) {
    if (_problems.remove(key) == null) return;
    if (reload) {
      _broadcast('reload');
    } else {
      _broadcastResult();
    }
  }

  /// The app server's port.
  int upstream;

  /// How long a request waits for a restarting app.
  final Duration wait;

  /// Where pages listen for reloads (server-sent events).
  static const eventsPath = liveReloadEventsPath;

  /// `GET` it for [status] as JSON (a tool that drives `thor dev`).
  static const statusPath = '/__thor/status';

  /// A new value per `thor dev` run: a page that reconnects to a newer run
  /// reloads (the app may have changed meanwhile).
  final String run = DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  var _reloads = 0;

  /// The version of what pages show: this run and how many reloads it
  /// asked for. A page is served with the one of the moment it was asked
  /// for; connecting later with another means it missed a change.
  String get stamp => '$run.$_reloads';

  final _servers = <HttpServer>[];
  final _client = HttpClient()..autoUncompress = false;
  final _listeners = <HttpResponse>{};
  final _results = StreamController<Map<String, Object?>>.broadcast();

  /// Every `result` event ([status]), as it is sent on [eventsPath]: how a
  /// tool that embeds the proxy (or `thor dev --json`) learns what a change
  /// did.
  Stream<Map<String, Object?>> get results => _results.stream;
  var _ready = Completer<void>();
  String? _failure;
  var _failureTitle = '';

  /// Listens on [port]: the loopback (IPv4, and IPv6 when the machine has
  /// it), so only this machine reaches it. With [host] (`thor dev --host`)
  /// on that address instead (`0.0.0.0` or `::`: every interface).
  Future<void> start(int port, {InternetAddress? host}) async {
    final first = await HttpServer.bind(
      host ?? InternetAddress.loopbackIPv4,
      port,
    );
    _servers.add(first);
    if (host == null) {
      // `localhost` may resolve to `::1`: same port, best effort.
      try {
        _servers.add(
          await HttpServer.bind(InternetAddress.loopbackIPv6, first.port),
        );
      } on SocketException {
        // No IPv6 loopback (or its port is taken): IPv4 does.
      }
    }
    final policy = _framePolicy;
    for (final server in _servers) {
      if (policy != null) {
        // Every response of the proxy, its own pages too.
        server.defaultResponseHeaders
          ..removeAll('x-frame-options')
          ..set('content-security-policy', policy);
      }
      server.listen((request) => unawaited(_handle(request)));
    }
  }

  /// The port it listens on.
  int get port => _servers.first.port;

  /// The app is restarting: new requests wait for [ready] or [failed].
  void restarting() {
    if (_ready.isCompleted) _ready = Completer<void>();
  }

  /// The app listens again: waiting requests go through and open pages
  /// reload.
  void ready() {
    _failure = null;
    if (!_ready.isCompleted) _ready.complete();
    _broadcast('reload');
  }

  /// The app didn't start (or its new code doesn't compile: [title]):
  /// requests get [error] until the next [ready].
  void failed(String error, {String title = 'The app did not start'}) {
    _failure = error;
    _failureTitle = title;
    if (!_ready.isCompleted) _ready.complete();
    _broadcast('reload');
  }

  /// Why the app is not running (it exited or its code does not compile),
  /// or null while it is up.
  String? get failure => _failure;

  /// Whether a failure shown over the pages is an error (the engine did
  /// not compile, code generation failed): warnings are not.
  bool get hasErrors => firstError != null;

  /// The first error shown over the pages (`title: message`, its first
  /// line), or null when there is none ([hasErrors]).
  String? get firstError {
    for (final entries in _problems.values) {
      for (final e in entries) {
        if (e['severity'] == 'warning') continue;
        final message = '${e['message'] ?? ''}'.split('\n').first.trim();
        return message.isEmpty ? '${e['title']}' : '${e['title']}: $message';
      }
    }
    return null;
  }

  /// What `thor dev` accepted, for a tool: `stamp` (same as the `reload`
  /// events), `state` (`ready`, `restarting` or `failed`), `ok` (ready and
  /// no error open), `failure` (why the app is not running, or null) and
  /// `problems` (every open finding: `key`, `severity`, `title`,
  /// `message`, and the file and line when there are). Also sent as the
  /// `result` event right after each `reload` on [eventsPath], and by `GET`
  /// [statusPath].
  Map<String, Object?> get status {
    final state = !_ready.isCompleted
        ? 'restarting'
        : _failure != null
        ? 'failed'
        : 'ready';
    return {
      'stamp': stamp,
      'run': run,
      'reloads': _reloads,
      'state': state,
      'ok': state == 'ready' && !hasErrors,
      'failure': _failure,
      'problems': [
        for (final MapEntry(:key, :value) in _problems.entries)
          for (final e in value) {'key': key, ...e},
      ],
    };
  }

  /// Stops listening and closes the open pages' connections.
  Future<void> close() async {
    for (final listener in [..._listeners]) {
      await listener.close().catchError((_) {});
    }
    _listeners.clear();
    await _results.close();
    _client.close(force: true);
    for (final server in _servers) {
      await server.close(force: true);
    }
  }

  void _broadcast(String event) {
    if (event == 'reload') _reloads++;
    for (final listener in [..._listeners]) {
      try {
        // Unbuffered (see _events): each write goes out as it is made.
        listener.write('event: $event\ndata: $stamp\n\n');
      } on Object {
        _drop(listener);
      }
    }
    if (event == 'reload') _broadcastResult();
  }

  /// The `result` event: [status] as one line of JSON.
  void _broadcastResult() {
    final snapshot = status;
    if (_results.hasListener) _results.add(snapshot);
    final data = jsonEncode(snapshot);
    for (final listener in [..._listeners]) {
      try {
        listener.write('event: result\ndata: $data\n\n');
      } on Object {
        _drop(listener);
      }
    }
  }

  void _drop(HttpResponse listener) {
    _listeners.remove(listener);
    unawaited(listener.close().catchError((_) {}));
  }

  Future<void> _handle(HttpRequest request) async {
    final refusal = hosts.check(request);
    if (refusal != null) return _refuse(request.response, refusal);
    if (request.uri.path == eventsPath) return _events(request);
    if (request.uri.path == statusPath) return _status(request.response);
    try {
      await _ready.future.timeout(wait);
    } on TimeoutException {
      return _page(
        request.response,
        HttpStatus.serviceUnavailable,
        'The app is still starting',
        'It took more than ${wait.inSeconds} s. This page reloads when it '
            'answers.',
      );
    }
    final failure = _failure;
    if (failure != null) {
      return _page(
        request.response,
        HttpStatus.internalServerError,
        _failureTitle,
        failure,
      );
    }
    try {
      await _forward(request);
    } on Object catch (e) {
      // The app went away mid-request (a restart): the proxy stays up.
      await _page(
        request.response,
        HttpStatus.badGateway,
        'The app did not answer',
        '$e',
      ).catchError((_) {});
    }
  }

  /// A 403 with the reason, without the live reload script or the overlay
  /// (nothing of the app: it may be a page of another site asking).
  Future<void> _refuse(HttpResponse response, String message) async {
    response
      ..statusCode = HttpStatus.forbidden
      ..headers.contentType = ContentType.text
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
      ..write(message);
    await response.close();
  }

  Future<void> _status(HttpResponse response) async {
    response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
      ..write(jsonEncode(status));
    await response.close();
  }

  void _events(HttpRequest request) {
    final response = request.response
      ..bufferOutput = false
      ..headers.contentType = ContentType('text', 'event-stream')
      ..headers.set('cache-control', 'no-cache');
    // Tell the page which run it talks to; a newer one means reload.
    response.write('event: hello\ndata: $stamp\n\n');
    _listeners.add(response);
    unawaited(response.done.whenComplete(() => _listeners.remove(response)));
  }

  Future<void> _forward(HttpRequest request) async {
    // Before asking the app: a change after this makes the page reload.
    final stamp = this.stamp;
    final out = await _client.openUrl(
      request.method,
      request.requestedUri.replace(
        scheme: 'http',
        host: '127.0.0.1',
        port: upstream,
      ),
    );
    out.followRedirects = false;
    // A page the browser has cached (a reload sends `If-None-Match`) is
    // asked for whole: what the proxy adds to it (the overlay, the version)
    // changes without the app's page changing, and a 304 would keep the old.
    final navigation =
        request.headers
            .value(HttpHeaders.acceptHeader)
            ?.contains('text/html') ??
        false;
    request.headers.forEach((name, values) {
      // Plain bodies: the proxy has to read the HTML it changes.
      if (name == HttpHeaders.acceptEncodingHeader) return;
      if (navigation &&
          (name == HttpHeaders.ifNoneMatchHeader ||
              name == HttpHeaders.ifModifiedSinceHeader)) {
        return;
      }
      for (final value in values) {
        out.headers.add(name, value, preserveHeaderCase: true);
      }
    });
    // HttpClient asks for gzip by default; the proxy reads the HTML.
    out.headers.removeAll(HttpHeaders.acceptEncodingHeader);
    await out.addStream(request);
    final answer = await out.close();
    final response = request.response..statusCode = answer.statusCode;
    // An encoded body (the app compressed it on its own) can't be read as
    // text: it goes through as it is, without the scripts.
    final html =
        answer.headers.contentType?.mimeType == 'text/html' &&
        answer.headers.value(HttpHeaders.contentEncodingHeader) == null;
    answer.headers.forEach((name, values) {
      // The body is re-sent (and HTML changes length): framing is ours. An
      // HTML page is never cached in development: it is the app's page plus
      // what this proxy knows now.
      if (name == HttpHeaders.transferEncodingHeader ||
          (html &&
              (name == HttpHeaders.contentLengthHeader ||
                  name == HttpHeaders.etagHeader ||
                  name == HttpHeaders.lastModifiedHeader ||
                  name == HttpHeaders.cacheControlHeader))) {
        return;
      }
      final policy = _framePolicy;
      if (policy != null) {
        // The app's own framing rules would contradict the ones asked for.
        if (name == 'x-frame-options') return;
        if (name == 'content-security-policy') {
          for (final value in values) {
            response.headers.add(
              name,
              _withFrameAncestors(value, policy),
              preserveHeaderCase: true,
            );
          }
          return;
        }
      }
      for (final value in values) {
        response.headers.add(name, value, preserveHeaderCase: true);
      }
    });
    if (html) response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    if (!html || request.method == 'HEAD') {
      // Unbuffered: an event stream or a download must not wait for 8 KB.
      response.bufferOutput = false;
      await response.addStream(answer);
      return response.close();
    }
    // Read as the app wrote it, sent as UTF-8 (the proxy writes text). A
    // streamed page goes out as it arrives: only the tail that may
    // hold the last `</body>` waits, and the scripts go in there.
    final charset = answer.headers.contentType?.charset;
    response.headers.contentType = ContentType(
      'text',
      'html',
      charset: 'utf-8',
    );
    // Each write goes out as it is made (no 8 KB buffer in front of it).
    response.bufferOutput = false;
    final page = _PageStream(sources);
    await for (final text in (Encoding.getByName(charset) ?? utf8).decoder.bind(
      answer,
    )) {
      final out = page.add(text);
      if (out.isNotEmpty) response.write(out);
    }
    response.write(_finish(page, stamp));
    await response.close();
  }

  /// What is left of a page: its held tail with the scripts in.
  String _finish(_PageStream page, String stamp) {
    final entries = [...page.entries];
    for (final problem in _problems.values) {
      entries.addAll(problem);
    }
    var tail = page.rest();
    if (entries.isNotEmpty || !overlayUi) {
      tail = withOverlay(tail, overlayScript(entries, editor, overlayUi));
    }
    return withLiveReload(tail, editor, stamp, _injected());
  }

  /// The [injectScripts] as inline scripts.
  String _injected() {
    final out = StringBuffer();
    for (final file in injectScripts) {
      try {
        // A `</script` in the file would end its tag early.
        final code = file.readAsStringSync().replaceAllMapped(
          RegExp('</(script)', caseSensitive: false),
          (m) => '<\\/${m[1]}',
        );
        out.write('<script>$code</script>');
      } on FileSystemException {
        // Gone or unreadable: the page loads without it.
      }
    }
    return '$out';
  }

  /// [html] without the app's error blocks, and with the overlay if there
  /// is anything to show.
  String _withOverlay(
    String html, [
    List<Map<String, Object?>> more = const [],
  ]) {
    final entries = <Map<String, Object?>>[...more];
    final clean = html.replaceAllMapped(errorBlocks, (m) {
      try {
        final block = jsonDecode(m[1]!);
        if (block is Map<String, Object?>) {
          entries.add(pageErrorEntry(block, sources));
        }
      } on FormatException {
        // Not ours after all: dropped anyway.
      }
      return '';
    });
    for (final problem in _problems.values) {
      entries.addAll(problem);
    }
    if (entries.isEmpty && overlayUi) return clean;
    return withOverlay(clean, overlayScript(entries, editor, overlayUi));
  }

  Future<void> _page(
    HttpResponse response,
    int status,
    String title,
    String detail,
  ) async {
    final stamp = this.stamp;
    response
      ..statusCode = status
      ..headers.contentType = ContentType.html
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
      ..write(
        withLiveReload(
          _withOverlay(
            '<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">'
            '<title>${_escape(title)}</title></head>'
            '<body style="font: 14px/1.5 ui-monospace, monospace; '
            'margin: 2rem; color: #1f2328">'
            '<h1 style="font-size: 18px">${_escape(title)}</h1>'
            '<pre style="white-space: pre-wrap; background: #f6f8fa; '
            'padding: 1rem; border-radius: 6px">${_escape(detail)}</pre>'
            '</body></html>',
            status == HttpStatus.internalServerError
                ? compileEntries('compile', title, detail, sources)
                : const [],
          ),
          editor,
          stamp,
        ),
      );
    await response.close();
  }
}

const _escaper = HtmlEscape(HtmlEscapeMode.element);
String _escape(String text) => _escaper.convert(text);

/// [html] with [overlay] (the overlay's script) before its last `</body>`
/// (at the end if it has none).
String withOverlay(String html, String overlay) {
  final end = html.toLowerCase().lastIndexOf('</body>');
  return end < 0
      ? '$html$overlay'
      : '${html.substring(0, end)}$overlay${html.substring(end)}';
}

/// [html] with [liveReloadScript] (for [stamp], if given) and the inspector ([inspectScript] for
/// [editor]) before its last `</body>` (at the end if it has none).
String withLiveReload(
  String html, [
  InspectEditor editor = InspectEditor.vscode,
  String? stamp,
  String injected = '',
]) {
  final reload = stamp == null ? liveReloadScript : liveReloadScriptFor(stamp);
  final scripts = '$reload${inspectScript(editor)}$injected';
  final end = html.toLowerCase().lastIndexOf('</body>');
  return end < 0
      ? '$html$scripts'
      : '${html.substring(0, end)}$scripts${html.substring(end)}';
}

/// The page as it streams from the app: what is safe to send now, and the
/// tail that is not yet.
///
/// Held back are the text from the last `</body>` seen (the scripts go
/// before the last one, as in a whole page), the start of a `</body>`
/// cut between two chunks, and an error block of `thor dev` (it becomes
/// the overlay, it is not sent) until it is whole. A streamed document has
/// no `</body>` until its end, so nothing waits meanwhile.
class _PageStream {
  _PageStream(this.sources);

  final SourceMap sources;

  /// The error blocks found so far, as overlay entries.
  final entries = <Map<String, Object?>>[];

  var _held = '';

  static const _close = '</body>';
  static const _blockStart =
      '<script type="application/json" id="thor-dev-error">';

  /// Takes [text]; returns what can go to the browser now.
  String add(String text) {
    var all = _held + text;
    _held = '';
    all = all.replaceAllMapped(errorBlocks, (m) {
      try {
        final block = jsonDecode(m[1]!);
        if (block is Map<String, Object?>) {
          entries.add(pageErrorEntry(block, sources));
        }
      } on FormatException {
        // Not ours after all: dropped anyway.
      }
      return '';
    });
    // An error block still open: wait for its end.
    final open = all.lastIndexOf(_blockStart);
    if (open >= 0) {
      _held = all.substring(open);
      return all.substring(0, open);
    }
    final lower = all.toLowerCase();
    final body = lower.lastIndexOf(_close);
    if (body >= 0) {
      _held = all.substring(body);
      return all.substring(0, body);
    }
    final cut =
        _partialStart(lower, _blockStart) ?? _partialStart(lower, _close);
    if (cut == null) return all;
    _held = all.substring(cut);
    return all.substring(0, cut);
  }

  /// The tail still held, at the end of the page.
  String rest() {
    final tail = _held;
    _held = '';
    return tail;
  }

  /// Where a proper prefix of [marker] starts at the end of [lower], if any.
  static int? _partialStart(String lower, String marker) {
    for (var n = marker.length - 1; n > 0; n--) {
      if (lower.length >= n && lower.endsWith(marker.substring(0, n))) {
        return lower.length - n;
      }
    }
    return null;
  }
}

/// The origins of `THOR_FRAME_ANCESTORS` (comma-separated), none when it is
/// unset or blank.
List<String> parseFrameAncestors(String? value) => [
  for (final origin in (value ?? '').split(','))
    if (origin.trim().isNotEmpty) origin.trim(),
];

/// [csp] with its `frame-ancestors` directive, if any, replaced by [policy]
/// (the app's `frame-ancestors 'none'` would blank the iframe anyway).
String _withFrameAncestors(String csp, String policy) => [
  for (final directive in csp.split(';'))
    RegExp(
          r'^\s*frame-ancestors(\s|$)',
          caseSensitive: false,
        ).hasMatch(directive)
        ? policy
        : directive.trim(),
].where((d) => d.isNotEmpty).join('; ');
