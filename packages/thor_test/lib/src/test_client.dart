/// An HTTP client for tests: `handler.client()` talks to a [RouteHandler]
/// without opening a port, the way a browser does (cookies, the same-origin
/// headers a `POST` needs, redirects on request).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:matcher/matcher.dart'
    show Description, Matcher, equals, wrapMatcher;
import 'package:thor_engine/thor_engine.dart';
import 'package:thor_server/thor_server.dart';

import 'http_fixtures.dart';

/// Adds [client] to a [RouteHandler].
extension ThorTestClientOf<P> on RouteHandler<P> {
  /// A client for this handler with an empty cookie jar: `final app =
  /// appHandler().client();`. Each call makes a new visitor.
  ///
  /// [origin] is the site the client visits (its host and `Origin` go in the
  /// requests: an `https` one makes the server mark cookies `Secure`);
  /// [maxRedirects] bounds a chain followed with `follow`; [now] is the
  /// clock cookies expire by (a test moves it instead of waiting);
  /// [httpOverrides] answers the `ThorHttpClient` calls the pages make
  /// instead of the network.
  ThorTestClient client({
    String origin = 'http://localhost',
    int maxRedirects = 10,
    DateTime Function()? now,
    MockTransport? httpOverrides,
  }) => ThorTestClient(
    this,
    origin: origin,
    maxRedirects: maxRedirects,
    now: now,
    httpOverrides: httpOverrides,
  );
}

/// A visitor of a [RouteHandler] in a test: keeps the cookies the server
/// sets and sends them back, sends what a browser's same-origin request
/// carries (`Host`, and `Origin` on a `POST`, so the CSRF check passes
/// exactly as it does for a real form), and follows redirects when asked.
///
/// ```dart
/// final app = appHandler().client();
/// final login = await app.post('/login?/signin', form: {'user': 'ana'});
/// expect(login, redirectsTo('/account'));
/// final account = await app.get('/account'); // with the session cookie
/// expect(account.html.querySelector('h1')!.text, 'Ana');
/// ```
///
/// Not covered: `multipart/form-data` (build a `PageRequest` with the body
/// by hand for a file upload), and the browser's own rules for `Secure`
/// (the jar keeps and sends every cookie over the fake connection),
/// `HttpOnly`, `SameSite` and `Domain` (ignored: one host).
class ThorTestClient {
  /// A client of [handler]; see [ThorTestClientOf.client].
  ThorTestClient(
    this.handler, {
    String origin = 'http://localhost',
    this.maxRedirects = 10,
    DateTime Function()? now,
    this.httpOverrides,
  }) : origin = _parseOrigin(origin),
       _now = now ?? DateTime.now;

  /// Answers the `ThorHttpClient` calls of every request this client makes
  /// (a global client included), instead of the network. A call it does not
  /// answer fails the request with [UnmockedHttpRequest].
  final MockTransport? httpOverrides;

  /// What the client talks to.
  final RouteHandler<Object?> handler;

  /// The site it visits (`http://localhost`).
  final Uri origin;

  /// The most redirects one `follow` goes through before failing (a loop).
  final int maxRedirects;

  final DateTime Function() _now;

  static Uri _parseOrigin(String origin) {
    final uri = Uri.parse(origin);
    if (!uri.hasAuthority || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw ArgumentError.value(
        origin,
        'origin',
        'use an http(s) origin such as http://localhost',
      );
    }
    // Only the origin: a user, a path or a query would leak into `Host`.
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    );
  }

  /// [path] on the client's site: an empty path is `/` and the fragment
  /// stays home, as in a browser. Another site is an [ArgumentError] (the
  /// jar and the `Origin` are this site's).
  Uri _resolve(String path) {
    final uri = _clean(origin.resolve(path));
    if (!_sameSite(uri)) {
      throw ArgumentError.value(
        path,
        'path',
        'is not on $origin: the client visits one site (make another with '
            'handler.client(origin: …))',
      );
    }
    return uri;
  }

  static Uri _clean(Uri uri) {
    final bare = uri.hasFragment ? uri.removeFragment() : uri;
    return bare.path.isEmpty ? bare.replace(path: '/') : bare;
  }

  bool _sameSite(Uri uri) =>
      uri.scheme == origin.scheme &&
      uri.host == origin.host &&
      uri.port == origin.port;

  // ---- requests ----------------------------------------------------------

  /// `GET path`. With [follow] the redirects go through (see [follow]).
  Future<ThorTestResponse> get(
    String path, {
    Map<HttpHeader, String?> headers = const {},
    bool follow = false,
  }) => send(HttpMethod.get, path, headers: headers, follow: follow);

  /// `POST path`: [form] as `application/x-www-form-urlencoded` (a list
  /// value repeats the field, a `null` one leaves it out), or [json] as
  /// `application/json`; neither is an empty form. [headers] win over the
  /// ones the client sets, and a `null` value takes one off (a request
  /// without an `Origin`).
  ///
  /// A form action is `?/name` in the path: `post('/login?/signin', …)`.
  Future<ThorTestResponse> post(
    String path, {
    Map<String, Object?>? form,
    Object? json,
    Map<HttpHeader, String?> headers = const {},
    bool follow = false,
  }) {
    if (form != null && json != null) {
      throw ArgumentError('post takes form: or json:, not both');
    }
    if (json != null) {
      return send(
        HttpMethod.post,
        path,
        body: utf8.encode(_encodeJson(json)),
        contentType: 'application/json',
        headers: headers,
        follow: follow,
      );
    }
    return send(
      HttpMethod.post,
      path,
      body: utf8.encode(_encodeForm(form ?? const {})),
      contentType: 'application/x-www-form-urlencoded',
      headers: headers,
      follow: follow,
    );
  }

  /// A request with any [method] (`PUT`, `DELETE`, `OPTIONS`…) and a raw
  /// [body].
  Future<ThorTestResponse> send(
    HttpMethod method,
    String path, {
    List<int>? body,
    String? contentType,
    Map<HttpHeader, String?> headers = const {},
    bool follow = false,
  }) async {
    final response = await _once(
      method,
      _resolve(path),
      body ?? const [],
      contentType,
      headers,
    );
    if (follow && response.isRedirect) return this.follow(response);
    _arrived(response);
    return response;
  }

  /// Follows the redirects of [response] until a page: a `POST` after a `301`
  /// or `302`, and any method but `GET` or `HEAD` after a `303`, becomes a
  /// `GET`; the others keep the method and the body (a `307`, a `308`). The
  /// cookies of every hop go in the jar. A chain longer than [maxRedirects]
  /// is a [StateError] naming it. A redirect to another site is not
  /// followed: it is what comes back.
  Future<ThorTestResponse> follow(ThorTestResponse response) async {
    if (!response.isRedirect) {
      throw StateError(
        'follow: ${response.method} ${response.uri.path} answered '
        '${response.status}, not a redirect',
      );
    }
    var current = response;
    final hops = <String>[];
    while (current.isRedirect) {
      final Uri target;
      try {
        target = _clean(current.uri.resolve(current.location!));
      } on FormatException catch (e) {
        throw StateError(
          'the ${current.status} of ${current.uri.path} has a Location that '
          'is not a URL (${current.location}): ${e.message}',
        );
      }
      // Another site (or `javascript:`, `mailto:`…): what comes back.
      if (!_sameSite(target)) break;
      if (hops.length >= maxRedirects) {
        throw StateError(
          'more than $maxRedirects redirects: ${response.uri.path} → '
          '${hops.join(' → ')}; a loop? (ThorTestClient(maxRedirects:) '
          'raises the limit)',
        );
      }
      hops.add(_relative(target));
      // The Fetch standard (the browser): a POST after a 301 or 302, and
      // anything but a GET or HEAD after a 303, becomes a GET without its
      // body; every other redirect repeats the request as it was.
      final toGet =
          ((current.status == 301 || current.status == 302) &&
              current.method == HttpMethod.post) ||
          (current.status == 303 &&
              current.method != HttpMethod.get &&
              current.method != HttpMethod.head);
      final keeps = !toGet;
      final method = toGet ? HttpMethod.get : current.method;
      // The request's own headers go along (a browser keeps them); the
      // ones about a body only with the body.
      current = await _once(
        method,
        target,
        keeps ? current._body : const [],
        keeps ? current._contentType : null,
        {
          for (final e in current._headers.entries)
            if (keeps || e.key.toLowerCase() != 'content-type') e.key: e.value,
        },
      );
    }
    _arrived(current);
    return current._withRedirects([...response.redirects, ...hops]);
  }

  // ---- query and command -------------------------------------------------

  /// The page the client is on: the last one a request answered (not a
  /// redirect), without its `?/action`. `query` and `command` go to it.
  Uri? get location => _location;
  Uri? _location;

  void _arrived(ThorTestResponse response) {
    if (response.isRedirect) return;
    final params = response.uri.query
        .split('&')
        .where((p) => p.isNotEmpty && !p.startsWith('/'))
        .join('&');
    final page = response.uri.toString().split('?').first;
    _location = Uri.parse(params.isEmpty ? page : '$page?$params');
  }

  /// Puts the client on [path] without asking the server: the page `query`
  /// and `command` go to next (a page you know, or one that redirects a
  /// guest away and would not be [location]).
  void goTo(String path) => _location = _resolve(path);

  /// Asks the server for [query] the way the browser does on `refresh`, on
  /// the page the client is on ([location]). [arg] is the argument of a
  /// `queryWith`. The answer's [ThorCallResponse.data] is the query's JSON;
  /// a query the page does not use is a `404`, as in the browser.
  ///
  /// [query] is a field of a state (the app's `profile.info`, or one the
  /// test creates): its id is found among the states that exist. For
  /// another page, a hostile argument or headers of your own use
  /// [callQuery].
  Future<ThorCallResponse> query<A, T>(ServerQuery<A, T> query, [A? arg]) =>
      callQuery(idOf(query), arg: arg, hasArg: query.hasArg);

  /// Runs [command] the way the browser does on `run`, with [arg] for a
  /// `commandWith`. The answer's [ThorCallResponse.result] is what the
  /// command returned and [ThorCallResponse.queries] the fresh values of
  /// the page's queries (the ones `invalidates:` names, or all). To say
  /// which queries the browser has on its page use [callCommand]
  /// (`queries:`); left out, every one of the route refreshes.
  Future<ThorCallResponse> command<A, R>(
    ServerCommandBase<A, R> command, [
    A? arg,
  ]) => callCommand(idOf(command), arg: arg, hasArg: command.hasArg);

  /// The id (`ProfileState.orders`) of a query or a command that is a field
  /// of a state: what the browser sends in `x-thor-query`. An
  /// [ArgumentError] when it belongs to no state.
  String idOf(Object queryOrCommand) {
    final known = queryOrCommand is ServerQuery
        ? ServerQuery.of(ThorState.all)
        : queryOrCommand is ServerCommandBase
        ? ServerCommandBase.of(ThorState.all)
        : const <String, Object?>{};
    for (final e in known.entries) {
      if (identical(e.value, queryOrCommand)) return e.key;
    }
    throw ArgumentError.value(
      queryOrCommand,
      'queryOrCommand',
      'not a query or a command that is a field of a state: create the '
          'state first, or call it by its id with callQuery / callCommand',
    );
  }

  /// [query] by id (`ProfileState.orders`), with [arg] in the body when
  /// [hasArg]. Or the whole JSON [body] (a `String` is sent as written,
  /// for a body that is not JSON): the way to send what the typed call
  /// would not. The [headers] win over the client's (a `null` value sends
  /// none: no `Origin`).
  Future<ThorCallResponse> callQuery(
    String id, {
    Object? arg,
    bool hasArg = true,
    Object? body,
    String? path,
    Map<HttpHeader, String?> headers = const {},
  }) => _call(
    'x-thor-query',
    id,
    body ?? {if (hasArg) 'arg': arg},
    path,
    headers,
  );

  /// [command] by id (`CartState.add`); see [callQuery].
  Future<ThorCallResponse> callCommand(
    String id, {
    Object? arg,
    bool hasArg = true,
    Map<String, Object?>? queries,
    Object? body,
    String? path,
    Map<HttpHeader, String?> headers = const {},
  }) => _call(
    'x-thor-command',
    id,
    body ?? {if (hasArg) 'arg': arg, 'queries': ?queries},
    path,
    headers,
  );

  Future<ThorCallResponse> _call(
    String header,
    String id,
    Object body,
    String? path,
    Map<HttpHeader, String?> headers,
  ) async {
    final page = path == null ? _location : _resolve(path);
    if (page == null) {
      throw StateError(
        'no page to ask: get() one first, or pass path: (a query or a '
        'command is a call to the page that uses it)',
      );
    }
    final response = await _once(
      HttpMethod.post,
      page,
      utf8.encode(body is String ? body : _encodeJson(body)),
      'application/json',
      {HttpHeader(header): id, ...headers},
    );
    return ThorCallResponse._(response);
  }

  // ---- cookies -----------------------------------------------------------

  final _jar = <String, _Cookie>{};
  var _seq = 0;

  /// The cookies the jar holds now, name → value (decoded); when two paths
  /// have the same name, the one with the longest path.
  Map<String, String> get cookies {
    _dropExpired();
    final sorted = _jar.values.toList()
      ..sort((a, b) => a.path.length.compareTo(b.path.length));
    return {for (final c in sorted) c.name: _decode(c.value)};
  }

  /// The cookie [name], or `null`.
  String? cookie(String name) => cookies[name];

  /// Puts a cookie in the jar as if the server had set it (a session a test
  /// signs itself).
  void setCookie(String name, String value, {String path = '/'}) {
    // The name check of a real Set-Cookie.
    SetCookie(name, value);
    _put(_Cookie(name, path, Uri.encodeComponent(value), null, ++_seq));
  }

  /// Empties the jar (a visitor who cleared their cookies).
  void clearCookies() => _jar.clear();

  // A cookie that replaces another keeps the old one's place in the
  // `Cookie` header: RFC 6265 §5.3 step 11 keeps its creation time.
  void _put(_Cookie c) {
    final key = '${c.name}\u0000${c.path}';
    final old = _jar[key];
    _jar[key] = old == null
        ? c
        : _Cookie(c.name, c.path, c.value, c.expires, old.seq);
  }

  void _dropExpired() {
    final now = _now();
    _jar.removeWhere((_, c) => c.expires != null && !c.expires!.isAfter(now));
  }

  String? _cookieHeader(Uri uri) {
    _dropExpired();
    final matching =
        _jar.values.where((c) => _pathMatches(uri.path, c.path)).toList()
          ..sort((a, b) {
            final byPath = b.path.length.compareTo(a.path.length);
            return byPath != 0 ? byPath : a.seq.compareTo(b.seq);
          });
    if (matching.isEmpty) return null;
    return matching.map((c) => '${c.name}=${c.value}').join('; ');
  }

  void _store(Uri requestUri, List<String> lines) {
    for (final line in lines) {
      final parts = line.split(';');
      final pair = parts.first;
      final eq = pair.indexOf('=');
      if (eq <= 0) continue;
      final name = pair.substring(0, eq).trim();
      if (name.isEmpty) continue;
      final value = pair.substring(eq + 1).trim();
      String? path;
      int? maxAge;
      DateTime? expires;
      for (final attribute in parts.skip(1)) {
        final at = attribute.indexOf('=');
        final key = (at < 0 ? attribute : attribute.substring(0, at))
            .trim()
            .toLowerCase();
        final v = at < 0 ? '' : attribute.substring(at + 1).trim();
        switch (key) {
          case 'path':
            if (v.startsWith('/')) path = v;
          case 'max-age':
            // `-?digits` only; one that does not fit an int is as far away
            // (or as long gone) as a browser takes it.
            if (RegExp(r'^-?\d+$').hasMatch(v)) {
              final n = BigInt.parse(v);
              maxAge = n > _farAway ? _farAway.toInt() : n.toInt();
            }
          case 'expires':
            // An unreadable date leaves a session cookie.
            expires = _parseCookieDate(v) ?? expires;
        }
      }
      // Max-Age wins over Expires (RFC 6265 §5.3).
      final until = maxAge != null
          ? (maxAge <= 0
                ? DateTime.fromMillisecondsSinceEpoch(0)
                : _now().add(Duration(seconds: maxAge)))
          : expires;
      final cookie = _Cookie(
        name,
        path ?? _defaultPath(requestUri.path),
        value,
        until,
        ++_seq,
      );
      if (until != null && !until.isAfter(_now())) {
        _jar.remove('${cookie.name}\u0000${cookie.path}');
      } else {
        _put(cookie);
      }
    }
  }

  static final _farAway = BigInt.from(1 << 32);

  static const _months = [
    'jan', 'feb', 'mar', 'apr', 'may', 'jun', //
    'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
  ];

  /// RFC 6265 §5.1.1: the lenient cookie-date every browser reads
  /// (`Thu, 01-Jan-1970 00:00:00 GMT`, `Thursday, 01-Jan-70 …`, a date
  /// without a weekday or a zone), which `HttpDate` does not.
  static DateTime? _parseCookieDate(String value) {
    int? hour, minute, second, day, month, year;
    for (final token in value.split(
      RegExp(r'[\x09\x20-\x2F\x3B-\x40\x5B-\x60\x7B-\x7E]+'),
    )) {
      if (token.isEmpty) continue;
      final time = RegExp(
        r'^(\d{1,2}):(\d{1,2}):(\d{1,2})(?:\D|$)',
      ).firstMatch(token);
      if (hour == null && time != null) {
        hour = int.parse(time[1]!);
        minute = int.parse(time[2]!);
        second = int.parse(time[3]!);
      } else if (day == null && RegExp(r'^\d{1,2}(?:\D|$)').hasMatch(token)) {
        day = int.parse(RegExp(r'^\d{1,2}').stringMatch(token)!);
      } else if (month == null &&
          token.length >= 3 &&
          _months.contains(token.substring(0, 3).toLowerCase())) {
        month = _months.indexOf(token.substring(0, 3).toLowerCase()) + 1;
      } else if (year == null && RegExp(r'^\d{2,4}(?:\D|$)').hasMatch(token)) {
        year = int.parse(RegExp(r'^\d{2,4}').stringMatch(token)!);
      }
    }
    if (hour == null || day == null || month == null || year == null) {
      return null;
    }
    if (year >= 70 && year <= 99) year += 1900;
    if (year >= 0 && year <= 69) year += 2000;
    if (day < 1 ||
        day > 31 ||
        year < 1601 ||
        hour > 23 ||
        minute! > 59 ||
        second! > 59) {
      return null;
    }
    return DateTime.utc(year, month, day, hour, minute, second);
  }

  static String _defaultPath(String path) {
    if (!path.startsWith('/')) return '/';
    final last = path.lastIndexOf('/');
    return last <= 0 ? '/' : path.substring(0, last);
  }

  static bool _pathMatches(String requestPath, String cookiePath) {
    if (requestPath == cookiePath) return true;
    if (!requestPath.startsWith(cookiePath)) return false;
    return cookiePath.endsWith('/') || requestPath[cookiePath.length] == '/';
  }

  static String _decode(String value) {
    try {
      return Uri.decodeComponent(value);
    } on ArgumentError {
      return value;
    }
  }

  // ---- the request itself ------------------------------------------------

  Future<ThorTestResponse> _once(
    HttpMethod method,
    Uri uri,
    List<int> body,
    String? contentType,
    Map<HttpHeader, String?> extra,
  ) async {
    final cookie = _cookieHeader(uri);
    final headers = <HttpHeader, String>{
      HttpHeader.host: _authority(uri),
      // What a browser sends on a same-origin POST; a GET carries none.
      if (!method.isRead) HttpHeader.origin: origin.origin,
      HttpHeader.contentType: ?contentType,
      HttpHeader.cookie: ?cookie,
    };
    for (final e in extra.entries) {
      // A `null` value takes the header off: a request without an `Origin`.
      if (e.value == null) {
        headers.remove(e.key.toLowerCase());
      } else {
        headers[HttpHeader(e.key.toLowerCase())] = e.value!;
      }
    }
    Future<(ThorResponse, Uint8List)> run() async {
      final raw = await handler.handle(
        PageRequest(
          method: method,
          uri: uri,
          headers: headers,
          body: body.isEmpty ? null : Stream.value(body),
        ),
        // The page a visitor ends up with: a page that defers values is
        // answered complete, not in pieces.
        stream: false,
      );
      return (raw, await _read(raw));
    }

    final mock = httpOverrides;
    // The zone covers the whole answer, deferred values and the stream
    // included.
    final (raw, bytes) = mock == null
        ? await run()
        : await runWithThorHttpTransport(mock.call, run);
    mock?.verify();
    _store(uri, raw.cookies);
    return ThorTestResponse._(
      status: raw.status,
      headers: {
        for (final e in raw.headers.entries)
          HttpHeader(e.key.toLowerCase()): e.value,
      },
      cookies: raw.cookies,
      bodyBytes: bytes,
      method: method,
      uri: uri,
      requestBody: body,
      requestContentType: contentType,
      requestHeaders: extra,
      redirects: const [],
    );
  }

  static Future<Uint8List> _read(ThorResponse raw) async {
    final stream = raw.stream;
    if (stream == null) return Uint8List.fromList(raw.body);
    final out = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      out.add(chunk);
    }
    return out.takeBytes();
  }

  static String _encodeJson(Object? value) {
    try {
      return jsonEncode(value);
    } on JsonUnsupportedObjectError catch (e) {
      throw ArgumentError.value(
        e.unsupportedObject,
        'json',
        'is not JSON (a browser sends numbers, strings, booleans, lists and '
            'maps): convert it first, or send the raw text with body: a String',
      );
    }
  }

  static String _encodeForm(Map<String, Object?> form) {
    final out = <String>[];
    for (final e in form.entries) {
      final values = switch (e.value) {
        null => const <Object?>[],
        final Iterable<Object?> l => l,
        final v => [v],
      };
      for (final v in values) {
        if (v == null) continue;
        out.add(
          '${Uri.encodeQueryComponent(e.key)}='
          '${Uri.encodeQueryComponent('$v')}',
        );
      }
    }
    return out.join('&');
  }

  // `host[:port]`: no user info, `[…]` around an IPv6 address.
  static String _authority(Uri uri) {
    final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
    return uri.hasPort ? '$host:${uri.port}' : host;
  }

  static String _relative(Uri uri) =>
      uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
}

class _Cookie {
  _Cookie(this.name, this.path, this.value, this.expires, this.seq);
  final String name;
  final String path;
  final String value;
  final DateTime? expires;
  final int seq;
}

/// What the server answered to a [ThorTestClient] request.
class ThorTestResponse {
  ThorTestResponse._({
    required this.status,
    required this.headers,
    required this.cookies,
    required this.bodyBytes,
    required this.method,
    required this.uri,
    required List<int> requestBody,
    required String? requestContentType,
    required Map<HttpHeader, String?> requestHeaders,
    required this.redirects,
  }) : _body = requestBody,
       _contentType = requestContentType,
       _headers = requestHeaders;

  ThorTestResponse._copy(ThorTestResponse r)
    : this._(
        status: r.status,
        headers: r.headers,
        cookies: r.cookies,
        bodyBytes: r.bodyBytes,
        method: r.method,
        uri: r.uri,
        requestBody: r._body,
        requestContentType: r._contentType,
        requestHeaders: r._headers,
        redirects: r.redirects,
      );

  ThorTestResponse _withRedirects(List<String> redirects) => ThorTestResponse._(
    status: status,
    headers: headers,
    cookies: cookies,
    bodyBytes: bodyBytes,
    method: method,
    uri: uri,
    requestBody: _body,
    requestContentType: _contentType,
    requestHeaders: _headers,
    redirects: redirects,
  );

  /// HTTP status.
  final int status;

  /// Headers, names in lowercase.
  final Map<HttpHeader, String> headers;

  /// The `Set-Cookie` lines of this response.
  final List<String> cookies;

  /// The body.
  final Uint8List bodyBytes;

  /// The method of the request that got this response (after redirects, the
  /// last one).
  final HttpMethod method;

  /// The URL of that request.
  final Uri uri;

  /// The redirects `follow` went through to get here (paths as the server
  /// wrote them); empty when none.
  final List<String> redirects;

  final List<int> _body;
  final String? _contentType;
  final Map<HttpHeader, String?> _headers;

  /// The body as text.
  late final String text = utf8.decode(bodyBytes, allowMalformed: true);

  /// The body decoded as JSON (a [FormatException] when it is not).
  Object? get json => jsonDecode(text);

  /// The body parsed as an HTML document: `html.querySelector('h1')`,
  /// `html.querySelectorAll('a[href]')`.
  late final dom.Document html = html_parser.parse(text);

  /// The `Location` of a redirect, or `null`.
  String? get location => headers['location'];

  /// Whether this is a redirect: `301`, `302`, `303`, `307` or `308` with a
  /// `Location`.
  bool get isRedirect =>
      const {301, 302, 303, 307, 308}.contains(status) && location != null;

  @override
  String toString() => '$method ${uri.path} → $status';
}

/// The answer to a query or a command ([ThorTestClient.query],
/// [ThorTestClient.command]): the JSON the browser's engine reads.
class ThorCallResponse extends ThorTestResponse {
  ThorCallResponse._(super.r) : super._copy();

  Map<String, Object?> get _map {
    try {
      return switch (jsonDecode(text)) {
        final Map<String, Object?> m => m,
        _ => const {},
      };
    } on FormatException {
      return const {};
    }
  }

  /// A query's value (JSON), or `null`.
  Object? get data => _map['data'];

  /// A command's result (JSON), or `null`.
  Object? get result => _map['result'];

  /// The fresh values of the page's queries a command's answer carries
  /// (id → value); empty when none.
  Map<String, Object?> get queries => switch (_map['queries']) {
    final Map<String, Object?> m => m,
    _ => const {},
  };

  /// The queries that failed while a command refreshed them (id → message).
  Map<String, Object?> get errors => switch (_map['errors']) {
    final Map<String, Object?> m => m,
    _ => const {},
  };

  /// The message of a failed call (`{"error": …}`), or `null`.
  String? get error => switch (_map['error']) {
    final String s => s,
    _ => null,
  };
}

// ---- matchers -------------------------------------------------------------

/// Matches a response whose status matches [status] (a number, or a matcher
/// such as `inInclusiveRange(200, 299)`). When it fails it says what came:
/// the request, the status, the `Location` of a redirect and the start of
/// the page's text.
///
/// ```dart
/// expect(await app.post('/login', form: {}), hasStatus(422));
/// ```
Matcher hasStatus(Object? status) => _HasStatus(wrapMatcher(status));

/// Matches a redirect (`3xx` with a `Location`) to [location]: a path
/// (`/account`) or a URL; an absolute URL of the same path matches too.
/// [status] narrows it (`redirectsTo('/x', status: 302)`).
Matcher redirectsTo(String location, {Object? status}) =>
    _RedirectsTo(location, status == null ? null : wrapMatcher(status));

/// What the two matchers read from a response.
(int, String?, String) _readResponse(Object? item) => switch (item) {
  final ThorTestResponse r => (r.status, r.location, _summary(r)),
  final ThorResponse r => (
    r.status,
    r.headers.entries
        .where((e) => e.key.toLowerCase() == 'location')
        .map((e) => e.value)
        .firstOrNull,
    'status ${r.status}',
  ),
  _ => (-1, null, 'not a response'),
};

String _summary(ThorTestResponse r) {
  final b = StringBuffer('${r.method} ${r.uri.path} answered ${r.status}');
  if (r.location != null) b.write(', Location: ${r.location}');
  var text = r.text;
  if ((r.headers['content-type'] ?? '').contains('html')) {
    text = r.html.body?.text ?? text;
  }
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isNotEmpty) {
    b.write(
      '; body: ${text.length > 300 ? '${text.substring(0, 300)}…' : text}',
    );
  }
  return b.toString();
}

bool _isResponse(Object? item) =>
    item is ThorTestResponse || item is ThorResponse;

class _HasStatus extends Matcher {
  const _HasStatus(this._status);
  final Matcher _status;

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) =>
      _isResponse(item) && _status.matches(_readResponse(item).$1, matchState);

  @override
  Description describe(Description description) =>
      _status.describe(description.add('a response with status '));

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<Object?, Object?> matchState,
    bool verbose,
  ) => mismatchDescription.add(
    _isResponse(item) ? _readResponse(item).$3 : 'is not a response',
  );
}

class _RedirectsTo extends Matcher {
  const _RedirectsTo(this._location, this._status);
  final String _location;
  final Matcher? _status;

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) {
    if (!_isResponse(item)) return false;
    final (status, location, _) = _readResponse(item);
    if (location == null) return false;
    if (_status != null
        ? !_status.matches(status, matchState)
        : status < 300 || status > 399) {
      return false;
    }
    return location == _location || _sameTarget(location, _location);
  }

  // `http://localhost/account` is `/account` when the expected one is a path.
  static bool _sameTarget(String actual, String expected) {
    final a = Uri.tryParse(actual);
    if (a == null || !a.hasAuthority || expected.startsWith('http')) {
      return false;
    }
    return equals(expected).matches(
      a.hasQuery ? '${a.path}?${a.query}' : a.path,
      <Object?, Object?>{},
    );
  }

  @override
  Description describe(Description description) =>
      description.add('a redirect to $_location');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<Object?, Object?> matchState,
    bool verbose,
  ) => mismatchDescription.add(
    _isResponse(item) ? _readResponse(item).$3 : 'is not a response',
  );
}
