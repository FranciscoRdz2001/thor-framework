import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'http_guard.dart' as guard;
import 'http_guard.dart' show guardedConnection;
import 'http_transport.dart';
import 'http_types.dart';
import 'http_wire.dart';
import 'results.dart';

/// An HTTP client for `load`, actions and guards: the backend calls a page
/// makes, with defaults that suit a server talking to an API.
///
/// - Idle keep-alive sockets close after [idleTimeout] (4 s), before the
///   usual backend's own keep-alive (Node: 5 s): otherwise a reused socket
///   can be closed by the backend under a request.
/// - A `GET` or `HEAD` that fails before the response starts because the
///   connection was closed or reset (a stale keep-alive socket) is retried
///   once. Other methods are never retried: they may not be idempotent.
/// - Every call has a deadline ([timeout], 10 s, retry included); past it
///   the request is aborted and an [UpstreamError] `504` is thrown.
/// - A body larger than [maxResponseBytes] (8 MB) is cut off: `502`.
/// - Any other failure (refused, reset mid-body, invalid JSON) is a `502`.
///
/// - At most [maxRedirects] (5) redirects are followed.
/// - With `allowPrivateNetworks: false` it connects only to public addresses
///   (see below).
///
/// [UpstreamError] is an [HttpError]: thrown from `load`, the error page
/// of the nearest group (`Group(error:)`) renders it with a generic message (the visitor never
/// sees the backend's URL or error) and the route handler reports the
/// details to its `onError`.
///
/// Non-2xx answers are not errors for [send], [get], [post], [put] and
/// [delete] (read [ThorHttpResponse.statusCode], e.g. to map a 404 to
/// `NotFound` or a 422 to form errors); [getJson] and
/// [ThorHttpResponse.ensureOk] turn them into a `502`.
///
/// ### URLs a visitor chose (SSRF)
///
/// By default the client reaches anything the server can reach: apps call
/// internal APIs. A URL that comes from a visitor (a webhook, an image to
/// import, a link preview) makes the server fetch what the visitor points at,
/// so use a client that refuses the private network for it:
///
/// ```dart
/// final fetcher = ThorHttpClient(allowPrivateNetworks: false);
/// ```
///
/// It resolves the host, refuses loopback, link-local (the cloud metadata
/// services at `169.254.169.254`), private, carrier-grade NAT and reserved
/// addresses ([isPrivateAddress], IPv6 forms that carry an IPv4 included),
/// connects to the address it checked (a DNS answer that changes between the
/// check and the connection does nothing) and checks again on every redirect.
/// The refusal is an [UpstreamError] `502`, before any byte is sent. It
/// does not use a proxy (the proxy would be the one that connects), and a
/// test transport ([runWithThorHttpTransport]) replaces the network, guard
/// included.
///
/// ```dart
/// final api = ThorHttpClient(headers: {HttpHeader.accept: 'application/json'});
///
/// Future<Item> load(PageRequest request) async {
///   final json = await api.getJson('https://api.example.com/items/1');
///   return Item.fromJson(json! as Map<String, Object?>);
/// }
/// ```
class ThorHttpClient {
  /// A client. [headers] go with every request (a call's own headers win).
  /// [maxRedirects] bounds the redirects one call follows (more is a `502`).
  /// [allowPrivateNetworks] `false` refuses every private, loopback,
  /// link-local and metadata address (see the class); the default reaches
  /// them, as an app that calls its own backends needs.
  /// [maxConnectionsPerHost] bounds the sockets open to one backend (the
  /// rest wait for one to free up). [warmUp] is a list of backend URLs
  /// (`String` or `Uri`) to [preconnect] to as the client is built, without
  /// waiting for them: one connection per distinct origin, at most 8 opening
  /// at once, invalid URLs skipped.
  ThorHttpClient({
    this.timeout = const Duration(seconds: 10),
    this.idleTimeout = const Duration(seconds: 4),
    this.maxResponseBytes = 8 << 20,
    int maxConnectionsPerHost = 32,
    this.headers = const {},
    this.maxRedirects = 5,
    this.allowPrivateNetworks = true,
    Iterable<Object> warmUp = const [],
  }) : _client = HttpClient()
         ..idleTimeout = idleTimeout
         // A connect that outlives the deadline is not left hanging.
         ..connectionTimeout = timeout
         ..maxConnectionsPerHost = maxConnectionsPerHost,
       // web: the guarded client checks every address through dart:io's
       // connection factory; the rest go over plain sockets.
       _wire = allowPrivateNetworks
           ? WirePool(
               idleTimeout: idleTimeout,
               maxConnectionsPerHost: maxConnectionsPerHost,
               connectionTimeout: timeout,
             )
           : null {
    if (!allowPrivateNetworks) {
      _client
        // A proxy would be the one that connects: no address to check.
        ..findProxy = ((_) => 'DIRECT')
        ..connectionFactory = guardedConnection();
    }
    // Not awaited: the server starts at once, the sockets open meanwhile.
    unawaited(_warm(warmUp));
  }

  /// At most this many warm-up connections are opening at once.
  static const _warmUpParallel = 8;

  /// Warms each distinct origin of [urls] once (the pool is per host: more
  /// than one `HEAD` to the same backend only loads it), a few at a time.
  Future<void> _warm(Iterable<Object> urls) async {
    final queue = <Object>[];
    final seen = <String>{};
    for (final url in urls) {
      try {
        final uri = url is Uri ? url : Uri.parse(url as String);
        if (seen.add('${uri.scheme}://${uri.host}:${uri.port}')) {
          queue.add(uri);
        }
      } on Object {
        // web: best-effort, an invalid URL is skipped like a failed one.
      }
    }
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        await preconnect(queue.removeAt(0));
      }
    }

    await Future.wait([
      for (var i = 0; i < _warmUpParallel && i < queue.length; i++) worker(),
    ]);
  }

  /// Deadline of a whole call: connecting, sending, the response headers
  /// and its body, and the retry if there is one.
  final Duration timeout;

  /// How long an unused keep-alive socket stays open. Keep it shorter than
  /// the backend's keep-alive timeout.
  final Duration idleTimeout;

  /// Largest response body, in bytes (after decompression).
  final int maxResponseBytes;

  /// Headers sent with every request (e.g. `accept`).
  final Map<HttpHeader, String> headers;

  /// The most redirects a call follows.
  final int maxRedirects;

  /// Whether the client may connect to private networks (loopback, link-local,
  /// `10/8`, `172.16/12`, `192.168/16`, cloud metadata). `false` is the
  /// setting for a URL a visitor chose.
  final bool allowPrivateNetworks;

  /// Whether [address] belongs to a private network: what a client with
  /// `allowPrivateNetworks: false` refuses. IPv6 forms that carry an IPv4
  /// address (`::ffff:127.0.0.1`, NAT64, 6to4) are judged by it.
  static bool isPrivateAddress(InternetAddress address) =>
      guard.isPrivateAddress(address);

  final HttpClient _client;

  // HTTP/1.1 over a `Socket`: what `HttpClient` does for an API call at a
  // fraction of its cost (a server calls its backend on every page).
  final WirePool? _wire;

  // Whether [uri] goes over [_wire] (null with `allowPrivateNetworks: false`;
  // a URL with credentials or another scheme stays on `HttpClient`).
  WirePool? _wireFor(Uri uri) =>
      _wire != null &&
          (uri.isScheme('http') || uri.isScheme('https')) &&
          uri.userInfo.isEmpty &&
          uri.host.isNotEmpty
      ? _wire
      : null;

  /// Opens a connection to [url]'s backend (TLS included) and leaves it in
  /// the keep-alive pool, so the first real call finds it open instead of
  /// paying the handshake (a cold TLS connection is 100 to 300 ms and a
  /// whole round trip more). It sends a `HEAD` to [url]: pass a cheap path.
  /// Best-effort: it never throws (a refused, slow or invalid URL is
  /// ignored) and ends within [timeout].
  ///
  /// It only helps while the socket stays open: after [idleTimeout] with no
  /// call the pool closes it, so it warms the first request after boot (or
  /// after a quiet spell shorter than [idleTimeout]), not a later one.
  /// Under a test transport ([runWithThorHttpTransport]) it does nothing.
  Future<void> preconnect(Object url) async {
    if (Zone.current[thorHttpTransportKey] is ThorHttpTransport) return;
    try {
      final uri = url is Uri ? url : Uri.parse(url as String);
      if (_wireFor(uri) case final wire?) {
        final call = WireCall();
        // A HEAD whose answer leaves the socket in the pool.
        await wire
            .send(
              call,
              'HEAD',
              uri,
              {for (final e in headers.entries) e.key.toLowerCase(): e.value},
              null,
              maxRedirects: maxRedirects,
              maxResponseBytes: maxResponseBytes,
            )
            .timeout(
              timeout,
              onTimeout: () {
                call.abort();
                throw TimeoutException(null);
              },
            );
        return;
      }
      final call = _Attempt();
      var gaveUp = false;
      await (() async {
        final request = call.request = await _client.openUrl('HEAD', uri);
        if (gaveUp) {
          // Opened after the timeout: nobody waits for it, nothing keeps it.
          request.abort();
          return;
        }
        headers.forEach(request.headers.set);
        final response = await request.close();
        // Drained so the socket goes back to the pool.
        await response.drain<void>();
      })().timeout(
        timeout,
        onTimeout: () {
          gaveUp = true;
          call.request?.abort();
        },
      );
    } on Object {
      // web: best-effort, a warm-up that fails changes nothing.
    }
  }

  /// Sends [method] to [url] (a `String` or a `Uri`). [json] is encoded as
  /// the body (`application/json`); [body] is sent as is (set its
  /// `content-type` in [headers]). Returns every status; throws
  /// [UpstreamError] only when no complete response arrives.
  Future<ThorHttpResponse> send(
    HttpMethod method,
    Object url, {
    Map<HttpHeader, String> headers = const {},
    Object? json,
    List<int>? body,
  }) async {
    final uri = url is Uri ? url : Uri.parse(url as String);
    final payload = json != null ? utf8.encode(jsonEncode(json)) : body;
    // web: a test swaps the network for a fake through the zone, so an app
    // with a global client needs no change. One zone lookup is all a real
    // call pays.
    final transport = Zone.current[thorHttpTransportKey];
    if (transport is ThorHttpTransport) {
      // The deadline covers a fake too: one that never answers fails the
      // call like a backend that does not.
      return Future<ThorHttpResponse>.sync(
        () => transport(
          ThorHttpRequest(
            method,
            uri,
            {
              if (json != null) HttpHeader.contentType: 'application/json',
              for (final e in this.headers.entries)
                HttpHeader(e.key.toLowerCase()): e.value,
              for (final e in headers.entries)
                HttpHeader(e.key.toLowerCase()): e.value,
            },
            payload == null ? Uint8List(0) : Uint8List.fromList(payload),
            () => _network(method, uri, headers, payload, json != null),
          ),
        ),
      ).timeout(
        timeout,
        onTimeout: () => throw UpstreamError(
          504,
          method: method,
          uri: uri,
          reason: 'no response within ${timeout.inMilliseconds} ms',
        ),
      );
    }
    return _network(method, uri, headers, payload, json != null);
  }

  Future<ThorHttpResponse> _network(
    HttpMethod method,
    Uri uri,
    Map<HttpHeader, String> headers,
    List<int>? payload,
    bool isJson,
  ) async {
    // Only these may be repeated without asking (RFC 9110 §9.2.2): a POST
    // that reached the backend and lost its answer must not run twice.
    final idempotent = method.isRead;
    final clock = Stopwatch()..start();
    for (var attempt = 1; ; attempt++) {
      final call = _Attempt();
      try {
        return await _attempt(
          call,
          method,
          uri,
          headers,
          payload,
          isJson,
        ).timeout(
          timeout - clock.elapsed,
          onTimeout: () {
            call.abort();
            throw UpstreamError(
              504,
              method: method,
              uri: uri,
              reason: 'no response within ${timeout.inMilliseconds} ms',
            );
          },
        );
      } on UpstreamError {
        rethrow;
      } on Exception catch (e) {
        if (idempotent && attempt == 1 && !call.started && _isStale(e)) {
          continue;
        }
        throw UpstreamError(502, method: method, uri: uri, reason: '$e');
      }
    }
  }

  Future<ThorHttpResponse> _attempt(
    _Attempt call,
    HttpMethod method,
    Uri uri,
    Map<HttpHeader, String> callHeaders,
    List<int>? payload,
    bool isJson,
  ) async {
    if (_wireFor(uri) case final wire?) {
      return _wireAttempt(
        wire,
        call,
        method,
        uri,
        callHeaders,
        payload,
        isJson,
      );
    }
    final request = call.request = await _client.openUrl(method.token, uri);
    request.maxRedirects = maxRedirects;
    if (isJson) request.headers.contentType = ContentType.json;
    headers.forEach(request.headers.set);
    callHeaders.forEach(request.headers.set);
    if (payload != null) {
      request.contentLength = payload.length;
      request.add(payload);
    }
    final response = await request.close();
    call.started = true;
    if (response.contentLength > maxResponseBytes) {
      // Don't read it: the socket is closed, not reused.
      request.abort();
      throw _tooLarge(method, uri);
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response) {
      bytes.add(chunk);
      if (bytes.length > maxResponseBytes) {
        request.abort();
        throw _tooLarge(method, uri);
      }
    }
    final out = <HttpHeader, String>{};
    response.headers.forEach(
      (name, values) => out[HttpHeader(name)] = values.join(', '),
    );
    return ThorHttpResponse(
      uri: uri,
      method: method,
      statusCode: response.statusCode,
      headers: out,
      bytes: bytes.takeBytes(),
    );
  }

  Future<ThorHttpResponse> _wireAttempt(
    WirePool wire,
    _Attempt call,
    HttpMethod method,
    Uri uri,
    Map<HttpHeader, String> callHeaders,
    List<int>? payload,
    bool isJson,
  ) async {
    final wireCall = call.wire = WireCall();
    // As `HttpClient.headers.set`: lower-case names, the call's own last.
    final sent = <String, String>{
      if (isJson) 'content-type': 'application/json; charset=utf-8',
      for (final e in headers.entries) e.key.toLowerCase(): e.value,
      for (final e in callHeaders.entries) e.key.toLowerCase(): e.value,
    };
    final WireResponse response;
    try {
      response = await wire.send(
        wireCall,
        method.token,
        uri,
        sent,
        payload,
        maxRedirects: maxRedirects,
        maxResponseBytes: maxResponseBytes,
      );
    } on WireTooLarge {
      throw _tooLarge(method, uri);
    }
    return ThorHttpResponse(
      uri: uri,
      method: method,
      statusCode: response.status,
      headers: {
        for (final e in response.headers.entries) HttpHeader(e.key): e.value,
      },
      bytes: response.body,
    );
  }

  UpstreamError _tooLarge(HttpMethod method, Uri uri) => UpstreamError(
    502,
    method: method,
    uri: uri,
    reason: 'response larger than $maxResponseBytes bytes',
  );

  /// The backend closed or reset a connection before answering: what a
  /// keep-alive socket it had already closed looks like.
  static bool _isStale(Exception e) => switch (e) {
    // dart:io reports a reset as an HttpException too.
    HttpException(:final message) =>
      message.startsWith('Connection closed') ||
          message.contains('Connection reset'),
    // ECONNRESET (Linux, macOS, Windows) and EPIPE.
    SocketException(:final osError?) => const {
      104,
      54,
      10054,
      32,
    }.contains(osError.errorCode),
    _ => false,
  };

  /// `GET` [url].
  Future<ThorHttpResponse> get(
    Object url, {
    Map<HttpHeader, String> headers = const {},
  }) => send(HttpMethod.get, url, headers: headers);

  /// `GET` [url] and decode its JSON (`null` for an empty body). A non-2xx
  /// status or invalid JSON throws a `502` [UpstreamError].
  Future<Object?> getJson(
    Object url, {
    Map<HttpHeader, String> headers = const {},
  }) async => (await get(url, headers: headers)).ensureOk().json();

  /// `POST` [url] with a [json] (or raw [body]) payload. Never retried.
  Future<ThorHttpResponse> post(
    Object url, {
    Map<HttpHeader, String> headers = const {},
    Object? json,
    List<int>? body,
  }) => send(HttpMethod.post, url, headers: headers, json: json, body: body);

  /// `PUT` [url] with a [json] (or raw [body]) payload. Never retried.
  Future<ThorHttpResponse> put(
    Object url, {
    Map<HttpHeader, String> headers = const {},
    Object? json,
    List<int>? body,
  }) => send(HttpMethod.put, url, headers: headers, json: json, body: body);

  /// `DELETE` [url]. Never retried.
  Future<ThorHttpResponse> delete(
    Object url, {
    Map<HttpHeader, String> headers = const {},
  }) => send(HttpMethod.delete, url, headers: headers);

  /// Closes idle sockets; with [force], in-flight requests too.
  void close({bool force = false}) {
    _client.close(force: force);
    _wire?.close(force: force);
  }
}

/// State of one try, shared with the deadline that may abort it.
class _Attempt {
  // Closed by the attempt itself; kept here only to abort it.
  // ignore: close_sinks
  HttpClientRequest? request;

  /// The same, over [WirePool].
  WireCall? wire;

  bool _started = false;

  /// The response headers arrived (a failure after this is not a stale
  /// socket).
  bool get started => _started || (wire?.started ?? false);
  set started(bool value) => _started = value;

  /// Stops the try (the deadline passed).
  void abort() {
    request?.abort();
    wire?.abort();
  }
}

/// A complete response from a backend.
class ThorHttpResponse {
  /// A response to [method] [uri].
  ThorHttpResponse({
    required this.uri,
    required this.method,
    required this.statusCode,
    required this.bytes,
    this.headers = const {},
  });

  /// What was requested.
  final Uri uri;

  /// The request's method.
  final HttpMethod method;

  /// HTTP status.
  final int statusCode;

  /// Headers, lower-case names, repeated values joined with `, `.
  final Map<HttpHeader, String> headers;

  /// The body.
  final Uint8List bytes;

  /// Whether the status is 2xx.
  bool get ok => statusCode >= 200 && statusCode < 300;

  /// The body as UTF-8 text; invalid UTF-8 is a `502` [UpstreamError].
  String get text {
    try {
      return utf8.decode(bytes);
    } on FormatException catch (e) {
      throw UpstreamError(502, method: method, uri: uri, reason: '$e');
    }
  }

  /// The body as JSON (`null` when empty); invalid JSON is a `502`
  /// [UpstreamError].
  Object? json() {
    if (bytes.isEmpty) return null;
    try {
      // Parsed from the bytes: no body-sized string in between.
      return _utf8Json.convert(bytes);
    } on FormatException catch (e) {
      throw UpstreamError(502, method: method, uri: uri, reason: '$e');
    }
  }

  static final _utf8Json = utf8.decoder.fuse(const JsonDecoder());

  /// This response when [ok]; otherwise throws a `502` [UpstreamError].
  ThorHttpResponse ensureOk() => ok
      ? this
      : throw UpstreamError(
          502,
          method: method,
          uri: uri,
          reason: 'answered $statusCode',
        );
}

/// A backend call failed: timed out (`504`), or no usable response
/// (`502`). An [HttpError] with no message: the error page says only that
/// something failed; [reason], [method] and [uri] are for the logs (the
/// route handler passes this error to its `onError`).
class UpstreamError extends HttpError {
  /// A failed call to [method] [uri], answered to the visitor with
  /// [status].
  const UpstreamError(
    super.status, {
    required this.method,
    required this.uri,
    required this.reason,
  });

  /// The backend request's method.
  final HttpMethod method;

  /// The backend URL.
  final Uri uri;

  /// What went wrong, for the logs.
  final String reason;

  @override
  String toString() {
    // No query string or credentials in logs (tokens travel there).
    final port = uri.hasPort ? ':${uri.port}' : '';
    final where = '${uri.scheme}://${uri.host}$port${uri.path}';
    return 'UpstreamError($status, $method $where: $reason)';
  }
}
