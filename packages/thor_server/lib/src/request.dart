import 'dart:async';
import 'dart:collection' show MapView;
import 'dart:convert';
import 'dart:io' show File;
import 'dart:math' show Random;
import 'dart:typed_data';

import 'cache_control.dart';
import 'cookies.dart';
import 'errors.dart';
import 'http_types.dart';
import 'locale.dart';
import 'multipart.dart';
import 'results.dart';
import 'route_url.dart';

export 'multipart.dart' show UploadedFile;

const _exportKey = 'thor.export';

/// The request a page's `load`, `actions` and `redirect` receive, with the
/// response being built next to it ([response]).
///
/// ```dart
/// Future<ArticleData> load(PageRequest request) async {
///   final slug = request.pathParameters['slug']!;
///   final user = request.locals['user'] as User?;
///   ...
/// }
/// ```
class PageRequest {
  /// A request for [uri]. [headers] keys are case-insensitive (stored
  /// lowercase); [body] is read once, by [form] or [text].
  PageRequest({
    required this.method,
    required this.uri,
    Map<HttpHeader, String> headers = const {},
    Stream<List<int>>? body,
    this.maxBodyBytes = 1 << 20,
    this.bodyReadTimeout = const Duration(seconds: 30),
    this.remoteAddress,
  }) : headers = {
         for (final e in headers.entries)
           HttpHeader(e.key.toLowerCase()): e.value,
       },
       _body = body;

  /// The request method (`HttpMethod.get`, `HttpMethod.post`…).
  final HttpMethod method;

  /// The full URL (scheme and host as the server sees them).
  final Uri uri;

  /// The socket's peer address (behind a reverse proxy, the proxy's), or
  /// `null` when unknown (tests). `RateLimit.clientIp` reads it.
  final String? remoteAddress;

  /// Request headers, lowercase keys (first value of each).
  final Map<HttpHeader, String> headers;

  /// Largest body [form] and [text] accept (1 MiB by default; files sent
  /// with a form count); a bigger one is a `413`. The handler sets it to the
  /// page's own `maxBodyBytes` when it has one, before any code reads the
  /// body.
  int maxBodyBytes;

  /// Longest the whole body may take to arrive; past it, a `408`.
  final Duration bodyReadTimeout;

  /// The path a site is published under when it isn't the origin's root
  /// (`/thor` for `https://example.com/thor`), with no trailing slash;
  /// empty otherwise. [uri] stays the app's own (`/guia/x`): this is only
  /// what the absolute URLs a page builds for itself (`og:url`,
  /// `og:image`) go under. `exportSite` sets it from its `baseUrl`.
  String publicPathPrefix = '';

  /// Whether the page being answered may be prefetched (set from its route:
  /// `PageRoute.prefetch`). A renderer reads it to leave out inline rules.
  bool prefetch = true;

  /// The `Last-Event-ID` a browser's `EventSource` sends when it reconnects:
  /// the `id` of the last `ServerEvent` it got, or null on a first
  /// connection. Resume from the event after it.
  String? get lastEventId {
    final id = headers['last-event-id'];
    return id == null || id.isEmpty ? null : id;
  }

  /// Whether the body was refused by its declared length without reading
  /// any of it (internal: the server answers and closes the connection).
  bool bodyRefused = false;

  final Stream<List<int>>? _body;
  Future<Uint8List>? _bytes;

  /// Values of the route's `[param]` segments (`/article/[slug]` →
  /// `{'slug': …}`), decoded.
  Map<String, String> pathParameters = const {};

  /// The route's `:name` parameter (`ThorRoute('/article/:slug', …)` →
  /// `param('slug')`), decoded. A name the route doesn't have is a
  /// mistake in the app: THOR-P015.
  String param(String name) =>
      pathParameters[name] ??
      (throw StateError(
        thorError(
          'THOR-P015',
          'no :$name in this route (it has '
              '${pathParameters.keys.map((k) => ':$k').join(', ')})',
        ),
      ));

  /// [param] as an `int`; a value that isn't one (`/item/abc`) is a 404.
  /// A `:name:int` segment is checked by the router before any `load`.
  int paramInt(String name) {
    final raw = param(name);
    return int.tryParse(raw) ?? (throw const NotFound());
  }

  /// The page's locale (one of `LocaleRouting.supportedLocales`), or
  /// `null` when the app has no `RouteHandler(locales:)`.
  Locale? locale;

  /// The app's locale routing, when it has one.
  LocaleRouting? localeRouting;

  /// The path the router matched: [uri]'s path without its locale prefix
  /// (`/es/about` → `/about`).
  late String routePath = uri.path;

  /// [path] (`/about`) in [locale] (this page's by default): `/es/about`
  /// with `LocaleStrategy.prefix`, [path] itself otherwise. A language
  /// switcher links `localizedPath(request.routePath, locale: Locale('en'))`.
  RouteUrl localizedPath(String path, {Locale? locale}) {
    final routing = localeRouting;
    final target = locale ?? this.locale;
    if (routing == null || target == null) return RouteUrl(path);
    return RouteUrl(routing.pathFor(target, path));
  }

  /// The query string (`?page=2`) as a map (the last value of each repeated key).
  ///
  /// A query that doesn't decode (invalid UTF-8, a broken `%` escape) is
  /// the client's error: an [HttpError] 400.
  Map<String, String> get queryParameters =>
      _decoded(() => uri.queryParameters, 'Malformed query string');

  /// The query string with every value of a repeated key
  /// (`?f=a&f=b` → `{'f': ['a', 'b']}`); [queryParameters] keeps only the
  /// last one. The reading side of `ThorRoute.link(…, {'f': ['a', 'b']})`.
  ///
  /// A malformed query is an [HttpError] 400, as in [queryParameters].
  Map<String, List<String>> get queryParametersAll =>
      _decoded(() => uri.queryParametersAll, 'Malformed query string');

  late final Map<String, String> _cookies = parseCookies(headers['cookie']);
  late final _ReadCookies _readCookies = _ReadCookies(_cookies);

  /// The request's cookies, by name (values percent-decoded).
  ///
  /// A page whose content depends on a cookie is the visitor's: reading
  /// one that the request carries (`request.cookies['store']` finds a
  /// value) keeps the page out of the shared page cache (`cache:`) and
  /// answers it `Cache-Control: private, no-cache`, as a [ContextKey]
  /// value does. Asking for one the request lacks keeps the page shared,
  /// but only with visitors that lack it too: a visitor who has it gets
  /// the page drawn for them. A route declared `personalized: false` is
  /// shared whatever cookies it reads (a guard that only checks that a
  /// session is there, say).
  ///
  /// ```dart
  /// load: (request) => stores.find(request.cookies['store'] ?? 'main'),
  /// ```
  Map<String, String> get cookies => _readCookies;

  /// The request's cookies without making the page the visitor's
  /// (internal: the framework's own reads, such as the locale, a flash, a
  /// persisted page state; an app reads [cookies]).
  Map<String, String> get frameworkCookies => _cookies;

  /// Whether the request carries a page state the browser persisted
  /// (`state(…, cookie:)`, a `thor-s.` cookie): the page renders with it,
  /// so it is this visitor's and skips the shared page cache.
  late final bool carriesPersistedState = _cookies.keys.any(
    (name) => name.startsWith(persistedStateCookiePrefix),
  );

  /// Whether the page is this visitor's: a [ContextKey.personal] value in
  /// [context], a persisted page state ([carriesPersistedState]) or a
  /// cookie of the request that [cookies] gave the app.
  bool get isPersonal =>
      context.isPersonal ||
      carriesPersistedState ||
      (_readCookies.found && !_readCookies.shared);

  /// Data the app attaches to the request (the signed-in user, set by
  /// `onRequest`), visible to every `load`, action and guard.
  final Map<String, Object?> locals = {};

  /// Whether the page is being written as a static file (`exportSite`): no
  /// server will answer a later request for a part of it (a `LazyPiece`).
  bool get isExport => locals[_exportKey] == true;

  /// Marks this request as the draw of a page for a static file.
  void markExport() => locals[_exportKey] = true;

  /// Typed values a middleware (`Group(middleware:)`) sets for every page
  /// of its group (the session, the company), read by `load`, actions and
  /// guards. A page that reads it is never stored in the shared page cache:
  /// its content may depend on the visitor.
  final RequestContext context = RequestContext._();

  /// What the response will carry besides the page (status, headers,
  /// cookies).
  final ResponseDraft response = ResponseDraft();

  /// The request a query function (`query(fn)` in a `ThorState`) runs
  /// for: its cookies, `context` (the session a middleware put there),
  /// `locals`. A query is a function without parameters so any repository
  /// method fits; this is how it reaches the request.
  ///
  /// Only while a query or a command runs (drawing a page, or answering
  /// the browser); anywhere else a [StateError].
  static PageRequest get current => switch (Zone.current[queryRequestKey]) {
    final PageRequest r => r,
    _ => throw StateError(
      thorError(
        'THOR-P019',
        'PageRequest.current only works inside a query or command '
            'function (query(fn), command(fn) in a ThorState); a load or an '
            'action gets the request as its parameter',
      ),
    ),
  };

  List<Object?> _loadedData = const [];

  /// What the loads of this request returned, outermost layout first and the
  /// page last (internal: the handler sets it once they all settled, before
  /// the page draws).
  // ignore: use_setters_to_change_properties
  void setLoaded(List<Object?> data) => _loadedData = data;

  /// What the page (or, failing that, the nearest layout) loaded, as [D]: the
  /// data the page draws, for the code that only reaches the request with
  /// [current] (a query's function, `events(initial:)`, a command).
  ///
  /// ```dart
  /// // events<Draft>('/draft/stream', initial: () => PageRequest.current.loaded<Doc>().draft)
  /// ```
  ///
  /// The nearest level whose `load` returned a [D] (by its value, so ask
  /// for the class, not for `Future<…>`). Only once the loads are in: while
  /// the page draws and its queries run. A command or a `refresh` that the
  /// browser asks for is its own request, where nothing was loaded: the
  /// call is a [StateError] (THOR-P037), also when no level loaded a [D].
  D loaded<D>() {
    for (var i = _loadedData.length - 1; i >= 0; i--) {
      if (_loadedData[i] case final D d) return d;
    }
    throw StateError(
      thorError(
        'THOR-P037',
        _loadedData.isEmpty
            ? 'loaded<$D>() found no loaded data: it works while the page '
                  'draws and its queries run, not in a command or a refresh '
                  'the browser asked for (read the request there, or pass the '
                  'value as the argument)'
            : 'loaded<$D>() found no load that returned a $D (they returned '
                  '${[for (final d in _loadedData) d.runtimeType].join(', ')})',
      ),
    );
  }

  /// What the nearest layout above loads, as [D]: a page's (or a nested
  /// layout's) `load` waits for the one level it needs instead of loading it
  /// again. Loads still start together; only the caller waits.
  ///
  /// ```dart
  /// // Group(layout: const CompanyLayout(), children: [clientsRoute])
  /// class ClientsPage extends ThorPage<List<Client>> {
  ///   @override
  ///   Future<List<Client>> load(PageRequest request) async {
  ///     // What CompanyLayout (a ThorLayout<Company>) loads.
  ///     final company = await request.parent<Company>();
  ///     return api.clients(company.id);
  ///   }
  /// }
  /// ```
  ///
  /// Only inside a `load`. The nearest layout whose `load` returns a [D]
  /// (by its declared type; an untyped one by its value); a [StateError]
  /// listing what the layouts above load when none does. If that layout's
  /// load fails, so does this call.
  Future<D> parent<D>() {
    final scope = Zone.current[loadScopeKey];
    if (scope is! LoadScope) {
      throw StateError(
        thorError(
          'THOR-P006',
          "parent<$D>() only works inside a load (a page's or a layout's)",
        ),
      );
    }
    return scope.parent<D>();
  }

  /// The raw body as text (UTF-8).
  Future<String> text() async =>
      utf8.decode(await bytes(), allowMalformed: true);

  /// The raw body, read once (at most [maxBodyBytes]).
  Future<Uint8List> bytes() {
    if (_piped) throw StateError(_readTwice);
    return _bytes ??= _readBytes();
  }

  static const _readTwice =
      'The request body was already read (bytes, text, form, pipeBody or '
      'saveBody): it can be read once';

  bool _piped = false;

  /// The body, chunk by chunk, to [sink] as it arrives: an upload never
  /// sits whole in memory. Returns the bytes written; [sink] is not
  /// closed (the caller owns it). The limits are the page's: more than
  /// [maxBodyBytes] is a `413` (refused at once when `Content-Length` says
  /// so) and a body that takes longer than the server's `bodyReadTimeout`
  /// is a `408`; the sink keeps what it got before either. A slow sink
  /// slows the client down (the read pauses while it writes). The body is
  /// read once: no [bytes], [text] or [form] before or after.
  ///
  /// Raise the limit on the page that takes the upload
  /// (`ThorPage(maxBodyBytes:)`).
  Future<int> pipeBody(StreamSink<List<int>> sink) async {
    if (_piped || _bytes != null) throw StateError(_readTwice);
    _piped = true;
    return _consume((chunk) => sink.addStream(Stream<List<int>>.value(chunk)));
  }

  /// [pipeBody] into [file] (created, or replaced). The bytes go to a temp
  /// file beside it (`<name>.<random>.part`, made exclusively, so another
  /// upload or a planted file cannot be written through) that is renamed over
  /// [file] when the whole body arrived: [file] never shows half an upload,
  /// two at once leave one whole upload (the last to finish), and a body that
  /// fails (too large, too slow, a client that left, a full disk) leaves
  /// neither a partial file nor a damaged earlier one. Returns the bytes
  /// written.
  ///
  /// ```dart
  /// final saved = await request.saveBody(File('uploads/${id}.bin'));
  /// ```
  Future<int> saveBody(File file) async {
    if (_piped || _bytes != null) throw StateError(_readTwice);
    _piped = true;
    final temp = File('${file.path}.${_randomName()}.part')
      ..createSync(exclusive: true);
    final sink = temp.openWrite();
    try {
      final total = await _consume(
        (chunk) => sink.addStream(Stream<List<int>>.value(chunk)),
      );
      await sink.close();
      await temp.rename(file.path);
      return total;
    } on Object {
      try {
        await sink.close();
        // ignore: avoid_catches_without_on_clauses
      } catch (_) {}
      try {
        if (temp.existsSync()) temp.deleteSync();
        // ignore: avoid_catches_without_on_clauses
      } catch (_) {}
      rethrow;
    }
  }

  static final _secure = Random.secure();

  /// 128 random bits, hex: not a name anyone can guess.
  static String _randomName() => [
    for (var i = 0; i < 16; i++)
      _secure.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();

  Future<Uint8List> _readBytes() async {
    final out = BytesBuilder(copy: false);
    await _consume((chunk) {
      out.add(chunk);
      return null;
    });
    return out.takeBytes();
  }

  /// Reads the body once, giving [onChunk] each chunk while the total stays
  /// within [maxBodyBytes] (a slow one pauses the read until it is done);
  /// returns how many bytes it was given.
  Future<int> _consume(Future<void>? Function(List<int> chunk) onChunk) async {
    final body = _body;
    if (body == null) return 0;
    // A declared length over the limit is refused without keeping a byte;
    // one over what is worth draining, without reading any (the connection
    // is closed after the 413).
    final declared = int.tryParse(headers['content-length'] ?? '');
    // `Expect: 100-continue` has not sent the body yet and will not until
    // told to: refuse it too, instead of waiting for bytes that never come.
    final awaitsContinue = (headers['expect'] ?? '').toLowerCase().contains(
      '100-continue',
    );
    if (declared != null &&
        (declared > _maxDrained ||
            (awaitsContinue && declared > maxBodyBytes))) {
      bodyRefused = true;
      throw _tooLarge();
    }
    var dropped = declared != null && declared > maxBodyBytes ? 1 : 0;
    var kept = 0;
    // One deadline for the whole body: a client that sends a byte just
    // before each gap would pass a per-chunk timeout forever (slowloris).
    // The subscription is paused, not cancelled, on timeout: cancelling a
    // request body destroys the connection before the 408 can be written.
    final done = Completer<void>();
    // Paused or drained, never cancelled (see above).
    // ignore: cancel_subscriptions
    late final StreamSubscription<List<int>> sub;
    void fail(Object e, [StackTrace? st]) {
      if (done.isCompleted) return;
      sub.pause();
      done.completeError(e, st);
    }

    final timer = Timer(bodyReadTimeout, () => fail(_timedOut()));
    sub = body.listen(
      (chunk) {
        if (dropped > 0 || kept + chunk.length > maxBodyBytes) {
          // Over the limit: read the rest without keeping it, so the client
          // gets the 413 (leaving the stream early drops the connection
          // before the response), up to a bound.
          dropped += chunk.length;
          if (dropped > _maxDrained && !done.isCompleted) {
            sub.pause();
            done.complete();
          }
          return;
        }
        kept += chunk.length;
        try {
          if (onChunk(chunk) case final pending?) {
            sub.pause();
            pending.then((_) {
              if (!done.isCompleted) sub.resume();
            }, onError: fail);
          }
          // The consumer's own failure (a full disk) fails the read.
          // ignore: avoid_catches_without_on_clauses
        } catch (e, st) {
          fail(e, st);
        }
      },
      onError: (Object e, StackTrace st) {
        if (!done.isCompleted) done.completeError(e, st);
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    try {
      await done.future;
    } finally {
      timer.cancel();
    }
    if (dropped > 0) throw _tooLarge();
    return kept;
  }

  HttpError _timedOut() {
    // The rest of the body is still on the wire: answer and close.
    bodyRefused = true;
    return const HttpError(408, 'Request body took too long to arrive');
  }

  HttpError _tooLarge() =>
      HttpError(413, 'Payload too large: the limit is $maxBodyBytes bytes');

  /// How much of a body over [maxBodyBytes] is read and dropped before the
  /// connection is dropped instead.
  static const _maxDrained = 64 << 20;

  /// The submitted form: `application/x-www-form-urlencoded`, or
  /// `multipart/form-data` (a form with `enctype="multipart/form-data"`,
  /// which can carry files: [FormData.files]).
  Future<FormData> form() async {
    final type = headers['content-type'] ?? '';
    final mime = type.split(';').first.trim().toLowerCase();
    if (mime == 'multipart/form-data') {
      final boundary = _param(type, 'boundary');
      if (boundary == null) {
        throw const HttpError(400, 'Multipart form without a boundary');
      }
      final parsed = parseMultipart(await bytes(), boundary);
      return FormData(parsed.fields, files: parsed.files);
    }
    if (type.isNotEmpty && mime != 'application/x-www-form-urlencoded') {
      throw const HttpError(415, 'Unsupported form encoding');
    }
    return FormData.parse(await text());
  }

  /// The [name] parameter of a header value (`…; boundary="x"`), unquoted.
  static String? _param(String value, String name) {
    for (final part in value.split(';').skip(1)) {
      final eq = part.indexOf('=');
      if (eq < 0) continue;
      if (part.substring(0, eq).trim().toLowerCase() != name) continue;
      var v = part.substring(eq + 1).trim();
      if (v.length >= 2 && v.startsWith('"') && v.endsWith('"')) {
        v = v.substring(1, v.length - 1);
      }
      return v;
    }
    return null;
  }
}

/// Zone key of the [LoadScope] a `load` runs in (internal: the handler
/// sets it).
const loadScopeKey = #thor.loadScope;

/// Zone key of the request a query function runs for (internal: see
/// [PageRequest.current]).
const queryRequestKey = #thor.queryRequest;

/// Runs [body] as a query function of [request] ([PageRequest.current]).
Future<T> runQueryFor<T>(PageRequest request, Future<T> Function() body) =>
    runZoned(body, zoneValues: {queryRequestKey: request});

/// The loads of the levels above the running one (internal).
abstract interface class LoadScope {
  /// See [PageRequest.parent].
  Future<D> parent<D>();
}

/// The key of a typed value in [RequestContext]: declare it once, next to
/// the middleware that sets it.
///
/// ```dart
/// const session = ContextKey<Session>('session');
/// const repos = ContextKey<Repos>('repos', personal: false);
/// ```
///
/// A value is the visitor's by default ([personal]): a request that
/// carries one skips the shared page cache (neither served from it nor
/// stored), like a `personalized` page. A request without any (a guest)
/// uses the cache as usual, even if its page asks for the key and finds
/// nothing. Mark keys whose value is the same for every visitor (a
/// repository, a config) `personal: false`.
final class ContextKey<T> {
  /// A key; [name] shows in errors.
  const ContextKey(this.name, {this.personal = true});

  /// Shown in errors (`no session in the request context`).
  final String name;

  /// Whether a value depends on the visitor (see the class docs).
  final bool personal;

  @override
  String toString() => 'ContextKey<$T>($name)';
}

/// Typed values of one request, by [ContextKey] (identity: two keys with
/// the same name are different keys).
final class RequestContext {
  RequestContext._();

  final _values = <ContextKey<Object?>, Object?>{};

  /// Whether a [ContextKey.personal] value was set: the page is this
  /// visitor's and skips the shared page cache.
  bool get isPersonal => _personal;
  var _personal = false;

  /// Sets [key] (replacing a value a middleware above set).
  void set<T>(ContextKey<T> key, T value) {
    if (key.personal) _personal = true;
    _values[key] = value;
  }

  /// The value of [key]; a [StateError] naming it when no middleware set it.
  T get<T>(ContextKey<T> key) {
    if (!_values.containsKey(key)) {
      throw StateError(
        thorError(
          'THOR-P005',
          'no ${key.name} in the request context: set it in a middleware of '
              'a Group above this route (request.context.set(${key.name}, …))',
        ),
      );
    }
    return _values[key] as T;
  }

  /// The value of [key], or `null` when none was set.
  T? maybeGet<T>(ContextKey<T> key) => _values[key] as T?;

  /// Whether [key] was set.
  bool has(ContextKey<Object?> key) => _values.containsKey(key);
}

/// A submitted form: every field with all its values, in order, and the
/// files of its file inputs.
class FormData {
  /// Wraps [fields] (and [files]).
  const FormData(this.fields, {this.files = const {}});

  /// Parses an `application/x-www-form-urlencoded` body.
  ///
  /// A body that doesn't decode (invalid UTF-8, a broken `%` escape) is an
  /// [HttpError] 400.
  factory FormData.parse(String body) =>
      _decoded(() => FormData._parse(body), 'Malformed form body');

  factory FormData._parse(String body) {
    final fields = <String, List<String>>{};
    for (final pair in body.split('&')) {
      if (pair.isEmpty) continue;
      final eq = pair.indexOf('=');
      final key = Uri.decodeQueryComponent(
        eq < 0 ? pair : pair.substring(0, eq),
      );
      final value = eq < 0
          ? ''
          : Uri.decodeQueryComponent(pair.substring(eq + 1));
      (fields[key] ??= []).add(value);
    }
    return FormData(fields);
  }

  /// Field name → its values.
  final Map<String, List<String>> fields;

  /// File input name → the files sent with it (empty for a form without
  /// `enctype="multipart/form-data"`).
  final Map<String, List<UploadedFile>> files;

  /// The first file of [name] (`null` when none was chosen).
  UploadedFile? file(String name) => files[name]?.first;

  /// Every file of [name] (`<input type="file" multiple>`).
  List<UploadedFile> filesOf(String name) => files[name] ?? const [];

  /// The first value of [name] (`null` when absent).
  String? operator [](String name) => fields[name]?.first;

  /// Every value of [name] (repeated inputs, checkboxes).
  List<String> all(String name) => fields[name] ?? const [];

  /// First value of each field (what a page re-fills a form with).
  Map<String, String> toMap() => {
    for (final e in fields.entries) e.key: e.value.first,
  };
}

/// The response being prepared while a request is handled.
class ResponseDraft {
  /// Status to send (the page's `200` when not set; a failed action or an
  /// error set their own).
  int? status;

  /// Extra headers.
  final Map<HttpHeader, String> headers = {};

  /// Cookies to set.
  final List<SetCookie> cookies = [];

  /// Tells browsers and CDNs not to keep this response (`Cache-Control:
  /// no-store`), and keeps it out of the page cache (`cache:`) too. For a
  /// page whose cache policy depends on its data: a `load` that could not
  /// reach the backend calls it, and the page it draws is not kept even
  /// though `PageRoute.cacheControl` says it is public.
  void noStore() => headers[HttpHeader.cacheControl] = 'no-store';

  /// Replaces the page's `cacheControl` for this response only (a shorter
  /// freshness for a page that answered with partial data). Wins over
  /// `PageRoute.cacheControl`.
  void cacheControl(CacheControl control) =>
      headers[HttpHeader.cacheControl] = control.header;

  /// Sets cookie [name]. Secure defaults: `HttpOnly`, `SameSite=Lax`,
  /// `Path=/`; `Secure` is added by the server in production.
  void setCookie(
    String name,
    String value, {
    Duration? maxAge,
    String path = '/',
    bool httpOnly = true,
    String sameSite = 'Lax',
    bool? secure,
  }) => cookies.add(
    SetCookie(
      name,
      value,
      maxAge: maxAge,
      path: path,
      httpOnly: httpOnly,
      sameSite: sameSite,
      secure: secure,
    ),
  );

  /// Removes cookie [name].
  void deleteCookie(String name, {String path = '/'}) =>
      setCookie(name, '', maxAge: Duration.zero, path: path);
}

/// [decode], with a decoding failure (`Uri`'s `FormatException` for
/// invalid UTF-8, `ArgumentError` for a broken `%` escape) as a 400.
T _decoded<T>(T Function() decode, String message) {
  try {
    return decode();
  } on FormatException {
    throw HttpError(400, message);
  } on ArgumentError {
    throw HttpError(400, message);
  }
}

/// Whether a page drawn for [request] fits another request as well: the
/// other lacks every cookie that [request]'s app code asked for and did
/// not find, so the page would read the same (internal: the shared page
/// cache checks it before serving a stored page). Taken when the page is
/// stored: later reads don't change it.
bool Function(PageRequest other) cookieReadsFit(PageRequest request) {
  final reads = request._readCookies;
  if (reads.shared) return (_) => true;
  if (reads.anyAbsent) return (other) => other._cookies.isEmpty;
  if (reads.absent.isEmpty) return (_) => true;
  final absent = {...reads.absent};
  return (other) => !absent.any(other._cookies.containsKey);
}

/// Makes [request]'s cookie reads leave the page shared: its route says
/// it is the same for every visitor (`personalized: false`; internal: the
/// handler calls it once it matched the route).
void shareCookieReads(PageRequest request) =>
    request._readCookies.shared = true;

/// [PageRequest.cookies]: the parsed cookies, noting what the app read. A
/// read that finds a cookie makes the page the visitor's ([found]); one
/// that finds none is remembered ([absent], or [anyAbsent] for a look at
/// the whole map while it is empty), so a stored page only goes to
/// visitors who lack them too.
final class _ReadCookies extends MapView<String, String> {
  _ReadCookies(this._map) : super(_map);

  final Map<String, String> _map;

  /// Whether a read gave the app one of the request's cookies.
  bool found = false;

  /// Names the app asked for that the request lacks.
  final Set<String> absent = {};

  /// Whether the app looked at every cookie while there were none.
  bool anyAbsent = false;

  /// Whether the route shares its page whatever the app reads.
  bool shared = false;

  void _name(Object? key) {
    if (_map.containsKey(key)) {
      found = true;
    } else if (key is String) {
      absent.add(key);
    }
  }

  void _all() {
    if (_map.isEmpty) {
      anyAbsent = true;
    } else {
      found = true;
    }
  }

  @override
  String? operator [](Object? key) {
    _name(key);
    return super[key];
  }

  @override
  bool containsKey(Object? key) {
    _name(key);
    return super.containsKey(key);
  }

  @override
  bool containsValue(Object? value) {
    _all();
    return super.containsValue(value);
  }

  @override
  Iterable<String> get keys {
    _all();
    return super.keys;
  }

  @override
  Iterable<String> get values {
    _all();
    return super.values;
  }

  @override
  Iterable<MapEntry<String, String>> get entries {
    _all();
    return super.entries;
  }

  @override
  int get length {
    _all();
    return super.length;
  }

  @override
  bool get isEmpty {
    _all();
    return super.isEmpty;
  }

  @override
  bool get isNotEmpty {
    _all();
    return super.isNotEmpty;
  }

  @override
  void forEach(void Function(String key, String value) action) {
    _all();
    super.forEach(action);
  }

  @override
  Map<K2, V2> map<K2, V2>(
    MapEntry<K2, V2> Function(String key, String value) convert,
  ) {
    _all();
    return super.map(convert);
  }

  @override
  Map<RK, RV> cast<RK, RV>() {
    _all();
    return super.cast();
  }

  @override
  String toString() {
    _all();
    return super.toString();
  }
}
