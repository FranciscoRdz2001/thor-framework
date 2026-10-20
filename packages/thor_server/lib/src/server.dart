import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'cache_bus.dart';
import 'dev.dart';
import 'handler.dart';
import 'host_check.dart';
import 'http_types.dart';
import 'middleware.dart' show SecurityHeaders;
import 'request.dart';
import 'static_files.dart';

/// thor's HTTP server: static files first, then the routes.
///
/// For a host: `GET /_thor/health` answers `200` while the server
/// takes requests and `503` once it is shutting down ([healthPath]), and
/// [serve] turns `SIGTERM`/`SIGINT` into a clean stop: no new connections,
/// the requests in flight finish (up to `shutdownTimeout`), then exit 0.
///
/// ```dart
/// Future<void> main() => ThorServer.serve(
///   () => ThorServer(handler: RouteHandler(routes: routes, renderer: widgetRenderer())),
///   port: 8080, // one isolate per core by default (`isolates:`)
/// );
/// ```
class ThorServer {
  /// Serves [handler], and the files of [publicDir] (the built site: engine,
  /// images, fonts) before it.
  ThorServer({
    required this.handler,
    this.publicDir,
    this.compress = true,
    this.maxBodyBytes = 1 << 20,
    this.bodyReadTimeout = const Duration(seconds: 30),
    this.idleTimeout = const Duration(seconds: 75),
    this.healthPath = '/_thor/health',
    List<String>? allowedHosts,
    Uri? publicOrigin,
    this.securityHeaders,
  }) : publicOrigin = _checkOrigin(publicOrigin),
       allowedHosts = _checkHosts(allowedHosts),
       _files = publicDir == null
           ? null
           : StaticFiles(publicDir, compress: compress) {
    // A bad `frameAncestors` origin stops the server here, not on a request.
    securityHeaders?.headers;
  }

  // A release build too: an empty list would answer 400 to every request.
  static List<String>? _checkHosts(List<String>? hosts) {
    if (hosts != null && hosts.isEmpty) {
      throw ArgumentError.value(
        hosts,
        'allowedHosts',
        'is empty: no request would pass; use null for any host',
      );
    }
    return hosts;
  }

  static Uri? _checkOrigin(Uri? origin) {
    if (origin == null) return null;
    final uri = origin;
    if (!(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError.value(
        origin,
        'publicOrigin',
        'must be an origin: Uri.parse(\'https://example.com\') '
            '(no path, query or user)',
      );
    }
    return Uri.parse(uri.origin);
  }

  /// The folder a server app serves ([publicDir]): `build/public` once
  /// `thor build` wrote it, else `web/`. Under `thor dev` always `web/`:
  /// that is where it writes the engine of the current code, and a
  /// `build/public` left by an earlier build holds a stale one.
  static String appPublicDir() =>
      !ThorDev.enabled && Directory('build/public').existsSync()
      ? 'build/public'
      : 'web';

  /// The routes.
  final RouteHandler<Object?> handler;

  /// Folder of static files, or `null`.
  final String? publicDir;

  /// Gzip text responses when the client accepts it.
  final bool compress;

  /// Largest request body (a form with its files) in bytes: 1 MB by
  /// default; a bigger one is a `413`. Raise it for uploads.
  final int maxBodyBytes;

  /// Longest a request body may take to arrive, whole: 30 seconds by
  /// default. A client that trickles bytes under [maxBodyBytes] (slowloris)
  /// gets a `408` and the connection is closed. It does not apply to
  /// streamed responses.
  final Duration bodyReadTimeout;

  /// Longest a connection may sit without finishing a request: dart:io
  /// closes a keep-alive connection that is idle this long, and the same
  /// timer is the only deadline for request *headers* that trickle in
  /// (slowloris; measured: a byte every 400 ms is cut at 1 to 2 times this
  /// value; the body has [bodyReadTimeout]). 75 s by default (dart:io's is
  /// 120 s). Behind a proxy that keeps connections open to the app (nginx
  /// upstream keepalive: 60 s, an AWS ALB: 60 s) keep it above the proxy's
  /// own timeout, or the proxy may reuse a connection just closed; with
  /// nothing in front, a short one (15 to 30 s) shrinks the window.
  final Duration idleTimeout;

  /// Path of the health check hosts poll (Docker `HEALTHCHECK`, Fly,
  /// Railway, Render): `200` while serving, `503` while shutting down;
  /// `null` turns it off. Under `/_thor/`, a prefix no app route uses.
  final String? healthPath;

  /// The hosts this server answers to in production (the `Host` header,
  /// without the port): `['example.com', '*.example.com']` (a `*.` entry
  /// matches subdomains, not the bare domain). Any other `Host` gets a
  /// `400`, so a forged one never reaches a page that builds links, a cache
  /// key or a password-reset URL from it. The health check ([healthPath])
  /// is exempt: a host's probe calls the internal address. `null` (the
  /// default) accepts any host. Under `thor dev` it is ignored (the dev
  /// host check applies).
  ///
  /// Behind a proxy: only `Host` is checked, and `X-Forwarded-Host` is
  /// ignored (the app sees the URL of the `Host` that passed, so a client
  /// cannot forge another through that header). A proxy that rewrites `Host`
  /// to an internal name must keep the public one (nginx
  /// `proxy_set_header Host $host`) or set [publicOrigin].
  final List<String>? allowedHosts;

  /// The site's public origin (`https://example.com`). When set, every
  /// request is seen as made to it, whatever `Host` the proxy forwarded:
  /// `og:url`, canonical links, `sitemap.xml`, `robots.txt`, redirects, the
  /// same-origin check of forms and queries (the request's `Host` is its
  /// authority) and the page cache keys all use it, and cookies are
  /// `Secure` when it is `https`. Under `thor dev` it is ignored.
  ///
  /// It names one origin: leave it unset for an app that answers on several
  /// subdomains (`allowedHosts: ['*.example.com']`): a form posted from
  /// another subdomain would carry an `Origin` that is not this one and be
  /// refused (list it in `trustedOrigins` or leave this unset).
  final Uri? publicOrigin;

  /// Headers put on every response that doesn't set them: pages, static
  /// files, the health check, host refusals and the global 500. `null`
  /// (the default) adds none; a `securityHeaders` middleware on a route
  /// group still covers that group's pages.
  ///
  /// `SecurityHeaders(frameAncestors: ['https://editor.example'])` is how an
  /// app lets one origin frame it (the default is no framing at all); it
  /// also drops the `X-Frame-Options: SAMEORIGIN` that `dart:io` adds to
  /// responses the server writes by itself.
  final SecurityHeaders? securityHeaders;

  final StaticFiles? _files;

  ThorResponse _secured(ThorResponse r) => securityHeaders?.apply(r) ?? r;

  // Whether `Host` is one of [allowedHosts].
  bool _hostAllowed(HttpRequest http) =>
      allowedHosts == null ||
      hostAllowed(http.headers.value('host'), allowedHosts!);

  // This isolate is shutting down (a signal arrived): health answers 503.
  static bool _draining = false;

  /// Handles one `dart:io` request.
  Future<void> handleHttp(HttpRequest http) async {
    final res = http.response;
    try {
      final method = HttpMethod.tryParse(http.method);
      if (method == null) {
        // web: 501 is HTTP's answer to a method the server doesn't know.
        _write(
          res,
          _secured(
            ThorResponse(
              StatusCode.notImplemented,
              headers: const {
                HttpHeader.contentType: 'text/plain; charset=utf-8',
              },
              body: utf8.encode('Not Implemented'),
            ),
          ),
          head: false,
        );
        await res.close();
        return;
      }
      if (ThorDev.enabled) {
        final refusal = ThorDev.hosts.check(http);
        if (refusal != null) {
          res
            ..statusCode = HttpStatus.forbidden
            ..headers.contentType = ContentType.text
            ..write(refusal);
          await res.close();
          return;
        }
      }
      final path = http.uri.path;
      final production = !ThorDev.enabled;
      final healthCheck = path == healthPath && method.isRead;
      if (production && !healthCheck && !_hostAllowed(http)) {
        _write(
          res,
          _secured(
            ThorResponse(
              400,
              headers: const {
                HttpHeader.contentType: 'text/plain; charset=utf-8',
                HttpHeader.cacheControl: 'no-store',
              },
              body: utf8.encode('Bad Request: unknown host'),
            ),
          ),
          head: method == HttpMethod.head,
        );
        await res.close();
        return;
      }
      if (path == healthPath && method.isRead) {
        final body = _draining ? _stopping : _ok;
        _write(
          res,
          _secured(
            ThorResponse(
              _draining ? 503 : 200,
              headers: const {
                HttpHeader.contentType: 'application/json',
                HttpHeader.cacheControl: 'no-store',
              },
              body: body,
            ),
          ),
          head: method == HttpMethod.head,
        );
        await res.close();
        return;
      }
      if (method.isRead && _files != null) {
        final file = await _files.lookup(
          path,
          _joined(http.headers, 'accept-encoding'),
          _joined(http.headers, 'if-none-match'),
          range: _joined(http.headers, 'range'),
          ifRange: _joined(http.headers, 'if-range'),
        );
        if (file != null) {
          final secured = _secured(file);
          if (secured.stream case final stream?) {
            await _writeFile(
              res,
              secured,
              stream,
              head: method == HttpMethod.head,
            );
          } else {
            _write(res, secured, head: method == HttpMethod.head);
          }
          await res.close();
          return;
        }
      }
      final request = PageRequest(
        method: method,
        uri: _requestUri(http),
        headers: {
          for (final MapEntry(key: k, value: v) in _headers(
            http.headers,
          ).entries)
            k: v,
          // Behind a proxy that rewrites `Host`, the same-origin checks
          // compare `Origin` with the public authority.
          if (publicOrigin != null && !ThorDev.enabled)
            HttpHeader.host: publicOrigin!.authority,
        },
        body: http,
        maxBodyBytes: maxBodyBytes,
        bodyReadTimeout: bodyReadTimeout,
        remoteAddress: http.connectionInfo?.remoteAddress.address,
      );
      var response = _secured(await handler.handle(request));
      if (response.stream == null &&
          (request.bodyRefused ||
              // A page that never reads the body (a 404, a GET) would wait
              // for gigabytes `dart:io` drains before it answers.
              http.contentLength > _maxDrainedBody)) {
        // A body announced far over the limit is never read: answer now and
        // close, instead of waiting for gigabytes `dart:io` would drain.
        await _answerAndClose(http, response);
        return;
      }
      if (response.stream case final stream? when _isEventStream(response)) {
        await _writeEventStream(
          http,
          response,
          stream,
          chunked: http.protocolVersion != '1.0',
        );
        return;
      }
      if (response.stream case final stream?) {
        await _writeStream(
          res,
          response,
          stream,
          head: method == HttpMethod.head,
          gzip:
              compress &&
              _compressible(response) &&
              acceptsGzip(_joined(http.headers, 'accept-encoding')),
          vary: compress && _compressible(response),
          chunked: http.protocolVersion != '1.0',
        );
        return;
      }
      // A page big enough to compress has two representations: caches
      // key them by Accept-Encoding (a 304 says what its 200 would).
      if (compress &&
          _compressible(response) &&
          (response.body.length > 1024 || response.status == 304)) {
        final headers = {...response.headers};
        final vary = headers.remove(_key(headers, 'vary'));
        headers[HttpHeader.vary] = _addVary(vary, 'Accept-Encoding');
        final gzipped =
            response.body.length > 1024 &&
            acceptsGzip(_joined(http.headers, 'accept-encoding'));
        if (gzipped) {
          headers[HttpHeader.contentEncoding] = 'gzip';
          // Other bytes, same content: a strong tag would claim they are
          // identical to the plain ones. Weak (`W/`) still matches in
          // If-None-Match, so one hash validates both.
          final key = _key(headers, 'etag');
          final etag = headers[key];
          if (etag != null && !etag.startsWith('W/')) headers[key] = 'W/$etag';
        }
        response = ThorResponse(
          response.status,
          headers: headers,
          cookies: response.cookies,
          body: gzipped ? response.gzipped : response.body,
        );
      }
      _write(res, response, head: method == HttpMethod.head);
    } catch (e, st) {
      stderr.writeln('[thor] ${http.method} ${http.uri}: $e\n$st');
      try {
        res.statusCode = 500;
        securityHeaders?.headers.forEach(res.headers.set);
      } on StateError {
        // The headers already went out: nothing to add.
      }
    }
    await res.close();
  }

  // The URI the app sees: the public origin's when there is one.
  Uri _requestUri(HttpRequest http) {
    final origin = publicOrigin;
    if (ThorDev.enabled) return http.requestedUri;
    if (origin == null) {
      // dart:io builds `requestedUri` from `X-Forwarded-Host` before `Host`:
      // only the `Host` names the site, with or without a host list (a
      // sitemap built from a forged one is cacheable).
      final host = http.headers.value('host');
      if (host == null) return http.requestedUri;
      final scheme = http.requestedUri.scheme;
      final path = http.uri.path.isEmpty ? '/' : http.uri.path;
      final query = http.uri.hasQuery ? '?${http.uri.query}' : '';
      return Uri.tryParse('$scheme://$host$path$query') ?? http.requestedUri;
    }
    final query = http.uri.hasQuery ? '?${http.uri.query}' : '';
    final path = http.uri.path.isEmpty ? '/' : http.uri.path;
    return Uri.parse('${origin.origin}$path$query');
  }

  /// What `PageRequest` drains of an unwanted body before dropping the
  /// connection instead (the same 64 MB).
  static const _maxDrainedBody = 64 << 20;

  /// Writes [r] straight to the socket (`Connection: close`) without
  /// waiting for the request's body.
  static Future<void> _answerAndClose(HttpRequest http, ThorResponse r) async {
    final socket = await http.response.detachSocket(writeHeaders: false);
    final body = r.body;
    final head = StringBuffer('HTTP/1.1 ${r.status} ${_reason(r.status)}\r\n');
    for (final MapEntry(:key, :value) in r.headers.entries) {
      final k = key.toLowerCase();
      if (k == 'content-length' || k == 'connection') continue;
      head.write('$key: ${value.replaceAll(RegExp(r'[\r\n]'), ' ')}\r\n');
    }
    for (final c in r.cookies) {
      head.write('set-cookie: ${c.replaceAll(RegExp(r'[\r\n]'), ' ')}\r\n');
    }
    head.write('content-length: ${body.length}\r\nconnection: close\r\n\r\n');
    socket.add(utf8.encode(head.toString()));
    if (http.method != 'HEAD') socket.add(body);
    await socket.flush();
    await socket.close();
    socket.destroy();
  }

  static String _reason(int status) => switch (status) {
    200 => 'OK',
    301 => 'Moved Permanently',
    302 => 'Found',
    303 => 'See Other',
    307 => 'Temporary Redirect',
    308 => 'Permanent Redirect',
    400 => 'Bad Request',
    401 => 'Unauthorized',
    403 => 'Forbidden',
    404 => 'Not Found',
    408 => 'Request Timeout',
    405 => 'Method Not Allowed',
    413 => 'Payload Too Large',
    500 => 'Internal Server Error',
    _ => 'Status',
  };

  static void _write(HttpResponse res, ThorResponse r, {required bool head}) {
    res.statusCode = r.status;
    res.headers.clear();
    r.headers.forEach(res.headers.set);
    for (final c in r.cookies) {
      res.headers.add('set-cookie', c);
    }
    res.headers.contentLength = r.body.length;
    if (!head) res.add(r.body);
  }

  /// A file read from disk as it is sent (a range or a big file): its
  /// length is known (`Content-Length` among the headers), so no chunks.
  static Future<void> _writeFile(
    HttpResponse res,
    ThorResponse r,
    Stream<List<int>> stream, {
    required bool head,
  }) async {
    res.statusCode = r.status;
    res.headers.clear();
    r.headers.forEach(res.headers.set);
    if (!head) await res.addStream(stream);
  }

  /// A body that comes in chunks ([ThorResponse.stream], a page answered
  /// early): status and headers now, each chunk as it arrives (gzip with a
  /// sync flush per chunk, so what was sent can be read), then the end.
  static Future<void> _writeStream(
    HttpResponse res,
    ThorResponse r,
    Stream<List<int>> stream, {
    required bool head,
    required bool gzip,
    required bool vary,
    bool chunked = true,
  }) async {
    res.statusCode = r.status;
    res.headers.clear();
    // The length is unknown: chunks, so the client knows where it ends. An
    // HTTP/1.0 client has no chunks: the end is the connection closing.
    if (chunked) res.headers.chunkedTransferEncoding = true;
    // Each chunk leaves when it is added (buffered, the first one would
    // wait for the rest: the browser reads the headers only with it).
    res.bufferOutput = false;
    final headers = {...r.headers};
    if (vary) {
      headers[HttpHeader.vary] = _addVary(
        headers.remove(_key(headers, 'vary')),
        'Accept-Encoding',
      );
    }
    if (gzip) headers[HttpHeader.contentEncoding] = 'gzip';
    headers.forEach(res.headers.set);
    for (final c in r.cookies) {
      res.headers.add('set-cookie', c);
    }
    final filter = gzip ? RawZLibFilter.deflateFilter(gzip: true) : null;
    void write(List<int> chunk, {bool end = false}) {
      if (filter == null) {
        if (chunk.isNotEmpty) res.add(chunk);
        return;
      }
      filter.process(chunk, 0, chunk.length);
      List<int>? out;
      while ((out = filter.processed(end: end)) != null) {
        res.add(out!);
      }
    }

    try {
      await for (final chunk in stream) {
        if (head) continue;
        write(chunk);
        await res.flush();
      }
      if (!head) write(const [], end: true);
    } catch (e, st) {
      // The client left (a visitor who follows a link while the page is
      // still arriving: normal, not logged), or the body failed after the
      // headers went out: nothing to answer anymore.
      if (e is! SocketException && e is! HttpException) {
        // The error text may carry request data: control characters are
        // escaped so it cannot forge terminal lines or colors.
        stderr.writeln(
          '[thor] streamed body: ${ThorDev.terminalSafe('$e', 300)}\n'
          '${ThorDev.terminalSafe('$st', 4000).replaceAll(r'\x0a', '\n')}',
        );
      }
    }
    await res.close();
  }

  /// Whether [r] is worth gzipping: text and the structured text types, not
  /// what is compressed already (images, fonts as woff/woff2, video, zip,
  /// pdf: gzip costs CPU and may even grow them), and not a body that
  /// carries a `Content-Encoding` of its own (it would be encoded twice).
  static bool _compressible(ThorResponse r) {
    String? type;
    for (final MapEntry(:key, :value) in r.headers.entries) {
      final k = key.toLowerCase();
      if (k == 'content-encoding' && value.toLowerCase() != 'identity') {
        return false;
      }
      if (k == 'content-type') type = value.toLowerCase();
    }
    // No type (a 304, an error): what the page would be, text.
    if (type == null) return true;
    final mime = type.split(';').first.trim();
    return mime.startsWith('text/') ||
        mime.endsWith('+json') ||
        mime.endsWith('+xml') ||
        mime.startsWith('font/') &&
            !mime.endsWith('woff') &&
            !mime.endsWith('woff2') ||
        const {
          'application/json',
          'application/xml',
          'application/javascript',
          'application/ecmascript',
          'application/x-javascript',
          'application/wasm',
          'application/x-ndjson',
          'application/x-www-form-urlencoded',
          'application/vnd.ms-fontobject',
          'application/manifest+json',
          'application/rtf',
          'application/xhtml+xml',
          'application/rss+xml',
          'application/atom+xml',
        }.contains(mime);
  }

  static bool _isEventStream(ThorResponse r) => r.headers.entries.any(
    (e) =>
        e.key.toLowerCase() == 'content-type' &&
        e.value.toLowerCase().startsWith('text/event-stream'),
  );

  /// A server-sent event stream ([ThorResponse.events]). It takes the
  /// socket from `dart:io`, because `dart:io` tells a handler nothing when
  /// the client leaves an idle response (no `done`, no error until the next
  /// write): here the socket's own end ends the stream and cancels its
  /// source at once. Never compressed (a compressor holds bytes back) and
  /// the connection closes with it.
  static Future<void> _writeEventStream(
    HttpRequest http,
    ThorResponse r,
    Stream<List<int>> stream, {
    required bool chunked,
  }) async {
    final socket = await http.response.detachSocket(writeHeaders: false);
    final gone = Completer<bool>();
    // Anything the client sends after its request is ignored; its end (or
    // an error) is what matters.
    socket.listen(
      (_) {},
      onDone: () => gone.isCompleted ? null : gone.complete(false),
      onError: (Object _) => gone.isCompleted ? null : gone.complete(false),
      cancelOnError: true,
    );
    final head = StringBuffer('HTTP/1.1 ${r.status} ${_reason(r.status)}\r\n');
    for (final MapEntry(:key, :value) in r.headers.entries) {
      final k = key.toLowerCase();
      if (const {
        'content-length',
        'connection',
        'transfer-encoding',
      }.contains(k)) {
        continue;
      }
      head.write('$key: ${value.replaceAll(RegExp(r'[\r\n]'), ' ')}\r\n');
    }
    for (final c in r.cookies) {
      head.write('set-cookie: ${c.replaceAll(RegExp(r'[\r\n]'), ' ')}\r\n');
    }
    if (chunked) head.write('transfer-encoding: chunked\r\n');
    head.write('connection: close\r\n\r\n');
    final chunks = StreamIterator(stream);
    // A shutdown ends the stream the same way: no more events, the last
    // chunk, the connection closed (the browser's EventSource reconnects,
    // to the next instance). Without it a stop would wait for a stream
    // that never ends, up to its timeout.
    final stopping = Completer<bool>();
    _eventStreams.add(stopping);
    try {
      socket.add(utf8.encode(head.toString()));
      if (http.method != 'HEAD') {
        while (await Future.any([
          chunks.moveNext(),
          gone.future,
          stopping.future,
        ])) {
          final chunk = chunks.current;
          if (chunk.isEmpty) continue;
          if (chunked) {
            socket.add(utf8.encode('${chunk.length.toRadixString(16)}\r\n'));
            socket.add(chunk);
            socket.add(const [13, 10]);
          } else {
            socket.add(chunk);
          }
          await socket.flush();
        }
        if (chunked && !gone.isCompleted) {
          socket.add(utf8.encode('0\r\n\r\n'));
          await socket.flush();
        }
      }
    } on Object catch (e, st) {
      // The client left mid-write: normal. Anything else is the source's.
      if (e is! SocketException && e is! HttpException) {
        stderr.writeln(
          '[thor] event stream: ${ThorDev.terminalSafe('$e', 300)}\n'
          '${ThorDev.terminalSafe('$st', 4000).replaceAll(r'\x0a', '\n')}',
        );
      }
    } finally {
      _eventStreams.remove(stopping);
      await chunks.cancel();
      socket.destroy();
    }
  }

  /// The event streams open in this isolate, each ended by a stop.
  static final _eventStreams = <Completer<bool>>{};

  static Map<HttpHeader, String> _headers(HttpHeaders h) {
    final out = <HttpHeader, String>{};
    h.forEach(
      (name, values) =>
          out[HttpHeader(name)] = values.join(name == 'cookie' ? '; ' : ', '),
    );
    return out;
  }

  /// The spelling of header [name] in [headers] (apps may write `Vary`).
  static HttpHeader _key(Map<HttpHeader, String> headers, String name) =>
      headers.keys.firstWhere(
        (k) => k.toLowerCase() == name,
        orElse: () => HttpHeader(name),
      );

  static String _addVary(String? vary, String name) {
    if (vary == null || vary.isEmpty) return name;
    final has = vary
        .split(',')
        .any((v) => v.trim().toLowerCase() == name.toLowerCase());
    return has ? vary : '$vary, $name';
  }

  static final _ok = utf8.encode('{"status":"ok"}');
  static final _stopping = utf8.encode('{"status":"stopping"}');

  // A client may repeat a list header (RFC 9110): `HttpHeaders.value`
  // throws on the second line, so read them joined.
  static String? _joined(HttpHeaders h, String name) => h[name]?.join(', ');

  static final _isolateSetUps = <void Function()>[];

  /// Runs [setUp] now, in this isolate, and in every isolate [serve]
  /// starts afterwards (each isolate has its own statics). It must be a
  /// top-level or static function: it is sent to them. thor's generated
  /// entry registers the app's states with it (`ThorState.register`), so a
  /// worker isolate renders them too. Adding the same function twice keeps
  /// one.
  ///
  /// Under `thor dev` a hot reload runs it again with the new code
  /// ([ThorDev.onReassemble]): a state's added or removed member is
  /// registered without a restart.
  static void setUpIsolates(void Function() setUp) {
    if (!_isolateSetUps.contains(setUp)) _isolateSetUps.add(setUp);
    if (ThorDev.enabled) ThorDev.onReassemble(setUp);
    setUp();
  }

  /// Listens on [port] with the server [create] makes, in [isolates]
  /// isolates sharing the port (each with its own state; a write in one
  /// clears the page cache of all: see `CacheBus`). By default on every interface, IPv4 and IPv6
  /// (`localhost` may be `::1`).
  ///
  /// The isolates share one heap and its young-generation collections stop
  /// all of them, so without a larger young generation more isolates stop
  /// helping after about four (RealWorld with a session: 4 → 1 481 req/s,
  /// 8 → 945, and 1.4 GB with 14). Hence the default: one per core, at
  /// most 4. For more, pass [isolates] and run with
  /// `DART_VM_OPTIONS=--new_gen_semi_max_size=256` (8 isolates: 2 196
  /// req/s); a line on startup says so when the flag is missing.
  ///
  /// [onShutdown] is the app's own cleanup (stopping child processes,
  /// flushing a queue): on `SIGINT` or `SIGTERM` it runs first, in this
  /// isolate, while the server still answers; the server closes once it
  /// completes. It gets [shutdownTimeout] (a hook that throws or does not
  /// finish in time is reported on stderr and the stop goes on, so a hook
  /// can't keep the process alive), and the close its own [shutdownTimeout]
  /// after it. Under `thor dev`, which otherwise exits at once, a server with
  /// an [onShutdown] also waits for it on those signals; it does not run when
  /// `thor dev` closes the server's stdin (the editor went away).
  static Future<void> serve(
    ThorServer Function() create, {
    Object? address,
    int port = 8080,
    int? isolates,
    Duration shutdownTimeout = const Duration(seconds: 8),
    Future<void> Function()? onShutdown,
  }) async {
    isolates = max(1, isolates ?? min(Platform.numberOfProcessors, 4));
    _checkRenderClock();
    // A release listens where the app said (every interface by
    // default); `thor dev` only on the loopback.
    address = ThorDev.bindAddress(address);
    final workers = <SendPort>[];
    // Each isolate's cache-bus inbox (the first is this one's).
    final inboxes = <SendPort>[CacheBus.inbox];
    for (var i = 1; i < isolates; i++) {
      final hello = ReceivePort();
      await Isolate.spawn(_worker, (
        create,
        address,
        port,
        hello.sendPort,
        [..._isolateSetUps],
      ), debugName: 'thor-$i');
      final (stop, inbox) = await hello.first as (SendPort, SendPort);
      workers.add(stop);
      inboxes.add(inbox);
    }
    // A write in one isolate clears the page cache of all the others.
    CacheBus.connect(inboxes.skip(1));
    for (var i = 0; i < workers.length; i++) {
      workers[i].send([
        for (var j = 0; j < inboxes.length; j++)
          if (j != i + 1) inboxes[j],
      ]);
    }
    final close = await _listen(create, address, port);
    ThorDev.exitWithParent();
    Future<void> hook() async {
      if (onShutdown == null) return;
      try {
        await onShutdown().timeout(shutdownTimeout);
      } on TimeoutException {
        stderr.writeln(
          'thor: onShutdown did not finish in ${shutdownTimeout.inSeconds} s; '
          'stopping anyway',
        );
      } catch (e, st) {
        stderr.writeln('thor: onShutdown failed: $e\n$st');
      }
    }

    // `thor dev` stops and restarts the server itself: there the default
    // (exit at once) is what it needs, unless the app has a hook to wait for.
    if (!ThorDev.enabled) {
      _stopOnSignals(() async {
        await hook();
        await Future.wait([
          close(shutdownTimeout),
          for (final worker in workers) _stopWorker(worker, shutdownTimeout),
        ]);
      });
    } else if (onShutdown != null) {
      _stopOnSignals(hook);
    }
    stdout.writeln(
      'thor: http://localhost:$port ($isolates isolate${isolates == 1 ? '' : 's'})',
    );
    if (isolates > 4 &&
        !(Platform.environment['DART_VM_OPTIONS'] ?? '').contains(
          'new_gen_semi_max_size',
        )) {
      stdout.writeln(
        'thor: several isolates share one heap; for throughput set '
        'DART_VM_OPTIONS=--new_gen_semi_max_size=256',
      );
    }
  }

  /// `THOR_NOW` (thor_ui's render clock) freezes the date every page is
  /// rendered with: a value that is not an ISO 8601 date-time stops the
  /// server here (not on the first page with a date picker), and outside
  /// `thor dev` a valid one is said on startup, so a release that inherited
  /// it by accident is noticed.
  static void _checkRenderClock() {
    final v = Platform.environment['THOR_NOW'];
    if (v == null || v.isEmpty) return;
    if (DateTime.tryParse(v) == null) {
      throw FormatException(
        'THOR_NOW is not an ISO 8601 date-time (2026-01-15T12:00:00)',
        v,
      );
    }
    if (!ThorDev.enabled) {
      stderr.writeln(
        'thor: warning: THOR_NOW=$v: every page renders with that date as '
        '"today" (date pickers). Unset it unless this is a test or a golden.',
      );
    }
  }

  /// `SIGTERM` (what Docker, Fly, Railway and Render send before a
  /// deploy replaces the machine) and `SIGINT` (Ctrl-C): [stop], then exit
  /// 0. A second signal while stopping exits at once (1).
  static void _stopOnSignals(Future<void> Function() stop) {
    var stopping = false;
    Future<void> onSignal(ProcessSignal signal) async {
      if (stopping) exit(1);
      stopping = true;
      stdout.writeln('thor: $signal, finishing the requests in flight');
      await stop();
      exit(0);
    }

    ProcessSignal.sigint.watch().listen(onSignal);
    // Windows has no SIGTERM to watch.
    if (!Platform.isWindows) ProcessSignal.sigterm.watch().listen(onSignal);
  }

  static Future<void> _stopWorker(SendPort worker, Duration timeout) async {
    final done = ReceivePort();
    worker.send((done.sendPort, timeout.inMicroseconds));
    await done.first.timeout(
      timeout + const Duration(seconds: 1),
      onTimeout: () => null,
    );
    done.close();
  }

  static Future<void> _worker(
    (ThorServer Function(), Object, int, SendPort, List<void Function()>) args,
  ) async {
    for (final setUp in args.$5) {
      setUpIsolates(setUp);
    }
    final stop = ReceivePort();
    args.$4.send((stop.sendPort, CacheBus.inbox));
    final close = await _listen(args.$1, args.$2, args.$3);
    stop.listen((message) async {
      if (message is List) {
        CacheBus.connect(message.cast<SendPort>());
        return;
      }
      final (reply, micros) = message as (SendPort, int);
      await close(Duration(microseconds: micros));
      reply.send(null);
      stop.close();
    });
  }

  /// Binds and serves; the function it returns stops this isolate's
  /// server: health turns 503, no new connections, the requests in flight
  /// finish (then, past [Duration], the rest are cut).
  static Future<Future<void> Function(Duration)> _listen(
    ThorServer Function() create,
    Object address,
    int port,
  ) async {
    var server = create();
    final http = await HttpServer.bind(
      address,
      port,
      shared: true,
      v6Only: false,
    );
    http.autoCompress = false;
    http.serverHeader = null;
    // `dart:io` stamps `X-Frame-Options: SAMEORIGIN` on every response that
    // keeps its default headers (the 500 of a failed write, the dev host
    // refusal), which a `frame-ancestors` policy would contradict.
    if (server.securityHeaders?.frameAncestors.isNotEmpty ?? false) {
      http.defaultResponseHeaders.removeAll('x-frame-options');
    }
    http.idleTimeout = server.idleTimeout;
    // Counted, so a stop waits for them (HttpServer.close only stops
    // listening: its future doesn't wait for the requests being answered).
    var inFlight = 0;
    Completer<void>? idle;
    http.listen((request) async {
      inFlight++;
      try {
        await server.handleHttp(request);
      } finally {
        if (--inFlight == 0 && !(idle?.isCompleted ?? true)) idle!.complete();
      }
    });
    if (ThorDev.enabled) {
      // After a hot reload (`thor dev`): the server again, from the new
      // code (routes, renderer, an empty page cache).
      developer.registerExtension('ext.thor.reassemble', (_, _) async {
        ThorDev.reassembled();
        server = create();
        return developer.ServiceExtensionResponse.result(
          ThorDev.reassembledResult,
        );
      });
    }
    return (Duration timeout) async {
      _draining = true;
      await http.close();
      for (final stream in [..._eventStreams]) {
        if (!stream.isCompleted) stream.complete(false);
      }
      if (inFlight > 0) {
        idle = Completer<void>();
        await idle!.future.timeout(timeout, onTimeout: () {});
      }
      await http.close(force: true);
    };
  }
}
