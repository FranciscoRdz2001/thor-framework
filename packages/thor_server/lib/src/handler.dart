import 'dart:async';
import 'dart:convert';
import 'dart:io' show GZipCodec, stderr;
import 'dart:typed_data';

import '../server_messages.dart';
import 'cache_bus.dart';
import 'confirm_page.dart';
import 'csp.dart' show CspNonce, cspNonceToken;
import 'dev.dart';
import 'env.dart';
import 'errors.dart';
import 'events.dart';
import 'flash.dart';
import 'http_client.dart' show UpstreamError;
import 'http_types.dart';
import 'list_query.dart' show queryWithoutAction, safeLocation, sitePath;
import 'locale.dart';
import 'request.dart';
import 'results.dart';
import 'route_url.dart';
import 'router.dart';
import 'routes.dart';
import 'upload_results.dart';

/// Draws a page (a `P`, e.g. a widget tree) as a full HTML document. The
/// only point where thor_server meets a render engine.
abstract interface class PageRenderer<P> {
  /// The document for [page], as UTF-8 bytes (what the engine produces:
  /// no decoding and re-encoding per request).
  FutureOr<List<int>> render(P page, RenderContext context);

  /// A plain error page, when no group's `error` page handles [state].
  P errorPage(ErrorState state);
}

/// A [PageRenderer] whose pages read request-scoped values (the page states
/// of `thor_ui`): [RouteHandler] runs each request — middleware, loads,
/// actions and the render — inside [inRequestScope], so what one request
/// writes (a cart read in a `load`) never reaches another, even across
/// `await`s of concurrent requests.
abstract interface class RequestScopedRenderer {
  /// Runs [body] with values of its own.
  Future<T> inRequestScope<T>(Future<T> Function() body);
}

/// The header that names the query a browser asks for (`x-thor-query:
/// ProfileState.info`), on a `POST` to the page that uses it.
const queryHeader = 'x-thor-query';

/// The header of a form's upload sent by `XMLHttpRequest` (the progress bar):
/// the answer carries it back, and a redirect comes as a `200` with
/// the target in [_uploadLocation] (the request would follow it silently,
/// consuming the flash and the one-time state of the page it leads to).
const _uploadHeader = 'x-thor-upload';
const _uploadLocation = 'x-thor-location';

/// The header of a `Form(stay: true)` the browser posts with `fetch`: the
/// answer carries it back and says what happened in headers instead of
/// navigating (a redirect to the page the form is on is a `200` with the
/// flash in [_stayFlash], a failed action keeps its status and its message
/// there; a redirect anywhere else is a `200` with [_uploadLocation]).
const _stayHeader = 'x-thor-stay';
const _stayFlash = 'x-thor-flash';
const _stayFlashKind = 'x-thor-flash-kind';

/// A [PageRenderer] whose pages hold server queries (`query(fn)` in a
/// `ThorState`, thor_ui's `WidgetRenderer`): it runs them before drawing,
/// says which ones each render used, and answers the browser's calls.
abstract interface class ServerQueries {
  /// The ids (`ProfileState.info`) of the queries the render of [context]
  /// used: the handler answers a query only on a route whose pages used it.
  Set<String> queriesFound(RenderContext context);

  /// What the queries of the render of [context] threw (reported like a
  /// load's error; the page still draws, with the query's `error`).
  List<(Object, StackTrace)> queryErrorsFound(RenderContext context);

  /// The value of query [id] called with [arg] (decoded JSON) for
  /// [request], JSON-encodable. Throws what the query throws; a `400`
  /// [HttpError] when [arg] is not what the query takes (before it runs)
  /// and a [NotFound] when [id] names no query.
  Future<Object?> runQuery(PageRequest request, String id, Object? arg);

  /// The texts of the errors of a call (the app's
  /// `ThorApp(serverMessages:)`): the handler writes the ones of its own
  /// answers (`401`, `400`, `404`, `500`, an `HttpError` with no message)
  /// with them.
  ServerMessages get serverMessages;
}

/// A [ServerQueries] that knows every query and command id the app has,
/// from the build (thor_ui's `WidgetRenderer`, with the generated
/// registry): a call naming another id is a `404` before the page is drawn
/// to learn what it uses, like a server function missing from a build
/// manifest.
abstract interface class ServerCallIds {
  /// Whether [id] (`CartState.add`) may name a query or a command of the
  /// app.
  bool declaresCall(String id);
}

/// The header that names the command a browser runs (`x-thor-command:
/// CartState.add`), on a `POST` to the page that uses it.
const commandHeader = 'x-thor-command';

/// A [ServerQueries] renderer whose pages also hold server commands
/// (`command(fn)` in a `ThorState`): it runs them for the browser and then
/// the page's queries, so the answer carries the fresh values. Its
/// [ServerQueries.queriesFound] lists the commands a render used too (the
/// handler's allowlist per route).
abstract interface class ServerCommands implements ServerQueries {
  /// Runs command [id] with [arg] (decoded JSON) for [request], then the
  /// queries [refresh] (the ones the route's pages use and the browser has
  /// on its page; the renderer narrows them to the command's
  /// `invalidates:`) with the argument
  /// the browser sent for each in [queryArgs] (its current one; a query
  /// not there runs with its initial one). Throws what the command throws;
  /// a `400` [HttpError] when [arg] or an argument in [queryArgs] is not
  /// what it should be (before anything runs), and a [NotFound] when [id]
  /// names no command.
  Future<CommandAnswer> runCommand(
    PageRequest request,
    String id,
    Object? arg, {
    required Set<String> refresh,
    required Map<String, Object?> queryArgs,
  });
}

/// What a command answered ([ServerCommands.runCommand]).
final class CommandAnswer {
  /// The command's [result], the new values of the page's [queries] (by
  /// id), the visitor's message and the kind of each query that failed
  /// ([errors], [kinds]) and what those threw ([thrown], reported like a
  /// load's error).
  const CommandAnswer({
    required this.result,
    this.queries = const {},
    this.errors = const {},
    this.kinds = const {},
    this.thrown = const [],
    this.writes = true,
  });

  /// What the command returned, JSON-encodable.
  final Object? result;

  /// The page's queries after the command, by id, JSON-encodable.
  final Map<String, Object?> queries;

  /// The message of each query that failed after the command, by id.
  final Map<String, String> errors;

  /// Why each of those failed, by id: a name of the browser's
  /// `ServerErrorKind` (`forbidden`, `server`…).
  final Map<String, String> kinds;

  /// What the failed queries threw.
  final List<(Object, StackTrace)> thrown;

  /// Whether the command wrote (`command(writes:)`): false keeps the page
  /// cache and the browser's prefetches.
  final bool writes;
}

/// Files a [PageRenderer] makes itself and the pages it draws link to (the
/// shared stylesheets): served by [RouteHandler] under
/// [rendererAssetsDir] and written by `exportSite` next to the pages.
///
/// A path names its content (a hash in the name), so a response is
/// `immutable`. Every isolate of a server must answer the same bytes for
/// the same path: a page rendered by one isolate links a file another one
/// may serve, so the content comes from the code, never from the traffic.
abstract interface class RendererAssets {
  /// The file at [path] (`/_thor/base.<hash>.css`), or null when the
  /// renderer has none (then the path is an ordinary 404).
  FutureOr<RendererAsset?> asset(String path);

  /// Every path [asset] answers (what an export writes).
  FutureOr<Iterable<String>> assetPaths();
}

/// A file a [RendererAssets] serves.
final class RendererAsset {
  /// [body] as [contentType].
  const RendererAsset(this.contentType, this.body);

  /// A stylesheet.
  RendererAsset.css(String text)
    : this('text/css; charset=utf-8', utf8.encode(text));

  /// `Content-Type`.
  final String contentType;

  /// The bytes.
  final List<int> body;
}

/// Where a [RendererAssets]' files live, under the site root (the same
/// folder a static build shares its stylesheets in).
const rendererAssetsDir = '/_thor/';

/// A file the pages of a request link, for the browser to fetch before it
/// reads the document: one entry of the `Link` header of the response.
/// A proxy that sends `103 Early Hints` (a CDN) turns these
/// into hints before the page; with `earlyHints` the server sends them
/// itself ahead of a slow page.
final class LinkHint {
  /// [href] with [rel] (`preload` by default), [as], [type] and whether it
  /// is fetched [crossOrigin] (fonts must be).
  const LinkHint(
    this.href, {
    this.rel = 'preload',
    this.as,
    this.type,
    this.crossOrigin = false,
    this.imageSrcset,
    this.imageSizes,
    this.media,
    this.highPriority = false,
  });

  /// A stylesheet the page links.
  const LinkHint.style(String href) : this(href, as: 'style');

  /// The page's speculation rules, as a file the browser fetches instead of
  /// an inline `<script type="speculationrules">` (a strict CSP refuses it):
  /// sent as the `Speculation-Rules` response header, not in `Link`. [href]
  /// is served as `application/speculationrules+json`.
  const LinkHint.speculationRules(String href)
    : this(href, rel: 'speculationrules');

  /// A font the page uses (fetched in CORS mode, like `@font-face`).
  const LinkHint.font(String href, {String type = 'font/woff2'})
    : this(href, as: 'font', type: type, crossOrigin: true);

  /// The page's main image (its LCP, `Image(priority: true)`): [href] is
  /// the fallback, [srcset]/[sizes] what its `<img>` or `<source>` has,
  /// [type] that source's (`image/avif`), [media] the theme it is for.
  const LinkHint.image(
    String href, {
    String? srcset,
    String? sizes,
    String? type,
    String? media,
  }) : this(
         href,
         as: 'image',
         type: type,
         imageSrcset: srcset,
         imageSizes: sizes,
         media: media,
         highPriority: true,
       );

  /// The URL.
  final String href;

  /// `preload`, `modulepreload`, `preconnect`…
  final String rel;

  /// What it is (`style`, `font`, `script`, `image`).
  final String? as;

  /// Its media type.
  final String? type;

  /// Whether it is fetched in CORS mode.
  final bool crossOrigin;

  /// `imagesrcset`: the widths of an image to preload.
  final String? imageSrcset;

  /// `imagesizes`: how wide that image is drawn.
  final String? imageSizes;

  /// The media query it is for (`(prefers-color-scheme: dark)`).
  final String? media;

  /// `fetchpriority=high`.
  final bool highPriority;

  /// `</x.css>; rel=preload; as=style`. A URL or a value that could end
  /// the entry (`<`, `>`, a quote, a comma, a semicolon, a line break) is
  /// an error: it would forge another header or another hint.
  String get header {
    // Built and checked once per distinct hint: the same links go on every
    // page (the shared stylesheets), and the checks are regular expressions.
    final key = (
      href,
      rel,
      as,
      type,
      crossOrigin,
      imageSrcset,
      imageSizes,
      media,
      highPriority,
    );
    final known = _headers[key];
    if (known != null) return known;
    final built = _buildHeader();
    if (_headers.length >= 1024) _headers.clear();
    return _headers[key] = built;
  }

  static final _headers =
      <
        (
          String,
          String,
          String?,
          String?,
          bool,
          String?,
          String?,
          String?,
          bool,
        ),
        String
      >{};

  /// Whether this goes in the `Speculation-Rules` header ([LinkHint.speculationRules]).
  bool get isSpeculationRules => rel == 'speculationrules';

  String _buildHeader() {
    if (href.contains(_badHref)) {
      throw ArgumentError.value(href, 'href', 'not a URL for a Link header');
    }
    if (isSpeculationRules) return '"$href"';
    for (final token in [rel, ?as, ?type]) {
      if (!_token.hasMatch(token)) {
        throw ArgumentError.value(token, 'LinkHint', 'not a token');
      }
    }
    String quoted(String name, String value) {
      // Inside quotes a comma is fine (a srcset has them); a quote, a
      // backslash or a line break would end the value or the header.
      if (value.contains(_badQuoted)) {
        throw ArgumentError.value(value, name, 'not a Link header value');
      }
      return '$name="$value"';
    }

    return [
      '<$href>',
      'rel=$rel',
      if (as != null) 'as=$as',
      if (type != null) 'type=$type',
      if (crossOrigin) 'crossorigin',
      if (imageSrcset case final v?) quoted('imagesrcset', v),
      if (imageSizes case final v?) quoted('imagesizes', v),
      if (media case final v?) quoted('media', v),
      if (highPriority) 'fetchpriority=high',
    ].join('; ');
  }

  static final _badHref = RegExp('[<>"\'\\s,;]');
  static final _badQuoted = RegExp('["\\\\\r\n]');
  static final _token = RegExp(r'^[a-z0-9][a-z0-9+./-]*$');
}

/// A [PageRenderer] that knows, before a page is rendered, the files it
/// will link (its shared stylesheets): the `Link` header of every page it
/// draws, and what `earlyHints` sends ahead of a slow one.
abstract interface class EarlyHints {
  /// The files a page of [request] under [layouts] links.
  FutureOr<List<LinkHint>> linksFor(
    PageRequest request,
    List<LayoutRoute<Object?, Object?>> layouts,
  );
}

/// A [PageRenderer] that finds, while it draws a page, files worth
/// fetching early that it couldn't know before (the page's main image).
/// The handler adds them to the `Link` header of that response and, for a
/// page every visitor sees alike, remembers them for the next request of
/// the same path: its early answer and a CDN's `103 Early Hints` get them
/// before the render.
abstract interface class DiscoveredLinks {
  /// What the render of [context] found (read once, after the render).
  List<LinkHint> linksFound(RenderContext context);
}

/// What a [PageRenderer] needs besides the page.
class RenderContext {
  /// For [request], answered with [status].
  const RenderContext({
    required this.request,
    required this.meta,
    required this.status,
    this.stream = false,
    this.deferTimeout = const Duration(seconds: 30),
    this.reportDeferred,
    this.devWarning,
    this.cspNonceToken,
  });

  /// The request.
  final PageRequest request;

  /// Merged metadata (layouts, then the page).
  final PageMeta meta;

  /// HTTP status.
  final int status;

  /// Whether the document goes out in pieces ([ThorResponse.stream]): a
  /// renderer that is a [DeferredRender] may then answer with the page
  /// without the values that are still on their way and send them after
  /// ([DeferredRender.lateOf]). `false` (a page kept in the cache, an
  /// export, a test client): the document must be complete.
  final bool stream;

  /// How long a late value may take ([RouteHandler.deferTimeout]).
  final Duration deferTimeout;

  /// Reports an error of a late value (like the one of a load: the
  /// handler's `onError`, and the `thor dev` overlay).
  final void Function(Object error, StackTrace stack)? reportDeferred;

  /// Under `thor dev` only: a hint about code that compiles and runs but
  /// probably doesn't do what its author meant (one line for the terminal).
  /// Null in a release: nothing is checked for it.
  final void Function(String message)? devWarning;

  /// Under `contentSecurityPolicy` with a nonce: the placeholder a
  /// renderer writes as `nonce="…"` on the `<script>` and `<style>`
  /// elements it emits itself (and only those: never on text that happens
  /// to hold the tag). The middleware turns it into the request's nonce on
  /// the way out, so the page, and the cache, never hold a real nonce.
  /// `null` without a policy: write no `nonce`.
  final String? cspNonceToken;
}

/// A [PageRenderer] that can answer with the page first and the values
/// that are still loading after it (streaming SSR).
///
/// With [RenderContext.stream] its [PageRenderer.render] returns the
/// document up to where the late pieces go (no `</body></html>`), and
/// [lateOf] the rest: each late piece when its value arrives, then the end
/// of the document. Without it, the document is complete.
abstract interface class DeferredRender {
  /// The pieces that follow the document the render of [context] returned,
  /// in the order they are ready, ending with the closing tags; `null` when
  /// the page holds nothing late (the document is then complete).
  Stream<List<int>>? lateOf(RenderContext context);
}

/// A response, ready to write to the socket (or to a file).
class ThorResponse {
  /// A response with [status].
  ThorResponse(
    this.status, {
    this.headers = const {},
    this.cookies = const [],
    this.body = const [],
    this.stream,
  });

  /// A JSON answer for a resource route (`ThorRoute.resource`): [data] as
  /// UTF-8 JSON (`<` escaped, so it is never HTML whatever sniffs it), with
  /// an `ETag` (a matching `If-None-Match` gets a `304`) and `Cache-Control`:
  /// `public, max-age=` [maxAge], or `private` for [private]; without
  /// [maxAge] the browser keeps it but asks again every time (`no-cache`,
  /// cheap with the `ETag`).
  factory ThorResponse.json(
    Object? data, {
    int status = 200,
    Duration? maxAge,
    bool private = false,
    Map<HttpHeader, String> headers = const {},
  }) => ThorResponse.bytes(
    utf8.encode(jsonEncode(data).replaceAll('<', r'\u003c')),
    contentType: 'application/json; charset=utf-8',
    status: status,
    maxAge: maxAge,
    private: private,
    headers: headers,
  );

  /// Bytes for a resource route (an image, a file made on demand) as
  /// [contentType], with an `ETag` and `Cache-Control` like [ThorResponse.json];
  /// [immutable] says the bytes at this URL never change (a hashed name).
  /// `X-Content-Type-Options: nosniff`: the browser never guesses another
  /// type.
  factory ThorResponse.bytes(
    List<int> body, {
    required String contentType,
    int status = 200,
    Duration? maxAge,
    bool private = false,
    bool immutable = false,
    Map<HttpHeader, String> headers = const {},
  }) => ThorResponse(
    status,
    headers: {
      HttpHeader.contentType: contentType,
      HttpHeader.cacheControl: [
        private ? 'private' : (maxAge == null ? null : 'public'),
        if (maxAge == null) 'no-cache' else 'max-age=${maxAge.inSeconds}',
        if (immutable) 'immutable',
      ].nonNulls.join(', '),
      HttpHeader.xContentTypeOptions: 'nosniff',
      HttpHeader.etag: etagOf(body),
      ...headers,
    },
    body: body,
  );

  /// A server-sent event stream (`text/event-stream`, for an `EventSource`):
  /// each [ServerEvent] of [events] goes out as it is added; a
  /// `: heartbeat` comment every [heartbeat] of silence keeps proxies from
  /// closing it (`Duration.zero`: none). Never cached, compressed or
  /// buffered by a proxy (`X-Accel-Buffering: no`). When the client leaves,
  /// the subscription to [events] is cancelled at once: put the cleanup
  /// (a `finally`, `onCancel`) there. The stream ends when [events] does.
  ///
  /// A guard or middleware of the route runs before it, like for any page.
  factory ThorResponse.events(
    Stream<ServerEvent> events, {
    Duration heartbeat = const Duration(seconds: 15),
    Map<HttpHeader, String> headers = const {},
  }) => ThorResponse(
    200,
    headers: {
      HttpHeader.contentType: 'text/event-stream; charset=utf-8',
      HttpHeader.cacheControl: 'no-store',
      const HttpHeader('x-accel-buffering'): 'no',
      ...headers,
    },
    stream: eventStreamBytes(events, heartbeat),
  );

  /// HTTP status.
  final int status;

  /// Headers (one value each).
  final Map<HttpHeader, String> headers;

  /// `Set-Cookie` values.
  final List<String> cookies;

  /// Body bytes.
  final List<int> body;

  /// A body written as it comes, after the status and the headers (a page
  /// answered early); [body] is empty then. The server sends each
  /// chunk when it arrives; there is no `Content-Length` and no `ETag`.
  final Stream<List<int>>? stream;

  /// The body as text.
  String get text => utf8.decode(body);

  List<int>? _gzipped;

  // The response this one is a copy of with the same body (headers or
  // cookies added): its compressed bytes, and whether it is kept in the
  // cache, are the original's, so a middleware does not make every hit
  // compress the page again.
  ThorResponse? _bytesFrom;

  void _keep() {
    for (ThorResponse? r = this; r != null; r = r._bytesFrom) {
      r._reused = true;
    }
  }

  // Kept in the page cache: compressed once, sent many times.
  bool _reused = false;

  /// The body gzip-compressed, computed once. A page kept in the cache
  /// gets the smallest body (level 6: compressed once, sent many times); a
  /// page rendered for one request, the fastest (level 1, nginx's default:
  /// level 6 costs about twice the CPU for some 10 % fewer bytes).
  /// A body up to 8 KB is always compressed small: there level 6 costs some
  /// 20 µs more for 10 to 18 % fewer bytes (measured; level 4 was never a
  /// better trade than 1 or 6).
  List<int> get gzipped =>
      _bytesFrom?.gzipped ??
      (_gzipped ??=
          (_reused || body.length <= _smallBody ? _smallest : _fastest).encode(
            body,
          ));

  static const _smallBody = 8192;

  static final _fastest = GZipCodec(level: 1);
  static final _smallest = GZipCodec(level: 6);

  /// This response with [headers] added (replacing those of the same name,
  /// whatever their case). What a middleware returns to change a response.
  ThorResponse withHeaders(Map<HttpHeader, String> headers) {
    final names = {for (final k in headers.keys) k.toLowerCase()};
    return ThorResponse(
      status,
      headers: {
        for (final MapEntry(:key, :value) in this.headers.entries)
          if (!names.contains(key.toLowerCase())) key: value,
        ...headers,
      },
      cookies: cookies,
      body: body,
      stream: stream,
    ).._bytesFrom = this;
  }
}

/// Handles requests for a route tree: guards, form actions, data loading,
/// rendering and error pages. The HTTP server feeds it; tests call [handle]
/// directly.
class RouteHandler<P> {
  /// Handles [routes], drawing pages with [renderer].
  ///
  /// [onRequest] runs first for every page request (read the session into
  /// `request.locals`). [secureCookies] decides `Secure` for the cookies
  /// that don't choose: `null` (the default) adds it when the request came
  /// over HTTPS, `true`/`false` for every request. [trustedOrigins] may post forms
  /// besides the site itself. [onError] receives unexpected exceptions
  /// (default: printed to stderr); the visitor only sees a 500 page.
  /// [locales] gives every request a locale (`PageRequest.locale`).
  RouteHandler({
    required List<RouteNode<P>> routes,
    required this.renderer,
    this.locales,
    this.onRequest,
    this.secureCookies,
    this.trustedOrigins = const {},
    this.onError = _printError,
    this.maxCacheBytes = 32 << 20,
    this.personalized,
    this.earlyHintsAfter = const Duration(milliseconds: 20),
    this.deferTimeout = const Duration(seconds: 30),
    this.headBotBudget = const Duration(seconds: 3),
  }) : router = RouteIndex(routes),
       _root = routes
           .whereType<LayoutRoute<P, Object?>>()
           .where((l) => l.path.isEmpty)
           .firstOrNull {
    // Another isolate wrote: this one's cached pages may be stale.
    CacheBus.listen(_onPeerWrite);
    CacheBus.listenTags(_onTags);
    UploadResults.wire();
  }

  /// The matcher (for listing routes, e.g. to pre-render them).
  final RouteIndex<P> router;

  /// Draws pages.
  final PageRenderer<P> renderer;

  /// The app's languages and how a request picks one, or `null` for an app
  /// in one language. With it every page is cached per locale, and with
  /// `LocaleStrategy.prefix` a URL without a locale redirects to the
  /// visitor's (a `302` that varies by `Accept-Language` and `Cookie`).
  final LocaleRouting? locales;

  /// Runs before guards and loads.
  final FutureOr<void> Function(PageRequest request)? onRequest;

  /// Whether cookies default to `Secure`. `null` (the default): when the
  /// request came over HTTPS, straight or behind a proxy that says so
  /// (`X-Forwarded-Proto` or `Forwarded`, its first hop), so a login over
  /// HTTPS is never sent over plain HTTP and `thor dev` on
  /// `http://localhost` still keeps its session. `true` or `false` decide
  /// for every request (`false` wins over a proxy's header).
  ///
  /// The proxy header needs no trusted-proxy list: it only sets a flag on
  /// the answer to the very request that carries it, so a client that
  /// forges it changes nothing but its own cookies.
  final bool? secureCookies;

  /// Whether the cookies [request] gets default to `Secure`.
  bool _secure(PageRequest request) {
    final forced = secureCookies;
    if (forced != null) return forced;
    if (request.uri.scheme == 'https') return true;
    final forwarded = request.headers['x-forwarded-proto'];
    if (forwarded != null) return _firstHop(forwarded) == 'https';
    final standard = request.headers['forwarded'];
    if (standard != null) {
      for (final pair in standard.split(',').first.split(';')) {
        final kv = pair.split('=');
        if (kv.length == 2 && kv[0].trim().toLowerCase() == 'proto') {
          return _firstHop(kv[1].replaceAll('"', '')) == 'https';
        }
      }
    }
    return false;
  }

  static String _firstHop(String list) =>
      list.split(',').first.trim().toLowerCase();

  /// Other origins allowed to post forms (`https://app.example.com`).
  final Set<String> trustedOrigins;

  /// Largest total size of cached pages (32 MB by default); the least
  /// recently used go first. Bounded because the key includes the query
  /// string, which a client controls.
  final int maxCacheBytes;

  /// Whether a request gets a page of its own (it carries a session
  /// cookie): it skips the page cache. With it, a page with `cache:` may
  /// show the visitor (a header with their name, their favorites) as long
  /// as every visitor it returns false for sees the same page. Runs before
  /// [onRequest], on every request: keep it cheap (a cookie lookup).
  final bool Function(PageRequest request)? personalized;

  /// Reports an unexpected exception (a bug or an outage).
  final void Function(PageRequest request, Object error, StackTrace? stack)
  onError;

  /// How long a page with `earlyHints` may load before the status and the
  /// headers (with the renderer's `Link` preloads) go out without it: a
  /// page whose data comes sooner is answered whole, with its own status
  /// and `ETag`.
  final Duration earlyHintsAfter;

  /// How long a value a page defers (`FutureBuilder`) may take once the
  /// page went out: past it the builder gets a `TimeoutException` as its
  /// error and the response ends. 30 seconds by default.
  final Duration deferTimeout;

  /// How long a link-preview or search bot (one that reads the `<head>` of
  /// the document and does not run JavaScript: `facebookexternalhit`,
  /// `WhatsApp`, `Twitterbot`, `Bingbot`…) waits for a head future that has an
  /// opt-in budget (`defer(f, head: true, headBudget:)`), instead of that
  /// budget when it is shorter: its preview must be the real one. It only
  /// matters for those: a head future with no budget is awaited for good by
  /// everyone, and the page then does not vary by `User-Agent`. 3 seconds by
  /// default.
  final Duration headBotBudget;

  // Requests whose answer must be complete (a page kept in the cache, a
  // `handle(stream: false)`): the renderer settles what it would defer.
  final _settled = Expando<bool>('thor settled');

  /// Requests whose opt-in head budget ran out: the page streams a 200 that
  /// may be a missing resource, so its head says `noindex`.
  final _budgetExpired = Expando<bool>('thor head budget expired');

  // A page with `cache:` streams to the visitor who finds it missing; when
  // the late pieces are all out, this stores the complete page for the
  // next ones (it renders again, with every value already in hand).
  final _cacheTee = Expando<void Function(ThorResponse)>('thor cache tee');

  final LayoutRoute<P, Object?>? _root;
  // Insertion order = recency (a hit is moved to the end).
  final _cache = <String, _Cached>{};
  var _cacheBytes = 0;

  /// URLs whose page is cached (for tests and diagnostics).
  Iterable<String> get cachedPaths => _cache.keys;

  /// Total size of the cached pages.
  int get cachedBytes => _cacheBytes;

  void _store(
    String key,
    PageRequest request,
    ThorResponse r,
    List<String> tags,
    bool pinned,
  ) {
    final old = _cache.remove(key);
    if (old != null) _cacheBytes -= old.response.body.length;
    if (r.body.length > maxCacheBytes) return;
    r._keep();
    _cache[key] = _Cached(r, tags, pinned, cookieReadsFit(request));
    _cacheBytes += r.body.length;
    while (_cacheBytes > maxCacheBytes && _cache.isNotEmpty) {
      final oldest = _cache.keys.first;
      _cacheBytes -= _cache.remove(oldest)!.response.body.length;
    }
  }

  /// Answers [request].
  ///
  /// A `GET` or `HEAD` page answered `200` carries a strong `ETag` (a hash
  /// of the body, computed once per render, so once per cached page), and
  /// an `If-None-Match` that matches it gets a `304` without a body. Not
  /// for responses that set cookies (they must reach the browser, and a
  /// `304` may not carry them through every cache), error pages or other
  /// methods.
  ///
  /// A page that defers values (`FutureBuilder`) answers in pieces: the
  /// page, then each value as it arrives ([ThorResponse.stream]). With
  /// [stream] `false` (an export, a test) the answer is complete instead:
  /// the values are awaited before the page is drawn.
  Future<ThorResponse> handle(PageRequest request, {bool stream = true}) async {
    if (!stream) _settled[request] = true;
    if (request.method == HttpMethod.get &&
        request.uri.path.startsWith(UploadResults.path)) {
      return _uploadResult(request);
    }
    return _asUploadAnswer(
      request,
      _conditional(
        request,
        _withLateCookies(
          request,
          _withDevErrors(
            request,
            _withoutLeaks(
              request,
              _keepPrefetched(
                request,
                _asQueryAnswer(request, await _scoped(request)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A `POST` the browser sent by `XMLHttpRequest` for the upload progress
  /// ([_uploadHeader]): the request can show nothing, so every answer
  /// that is a page becomes the address of one the browser navigates to.
  ///
  /// - A redirect is not followed there (the `GET` it leads to would run
  ///   twice, the first would use up a flash): it is a `200` with its target
  ///   in `x-thor-location`, cookies kept.
  /// - A page (`2xx`, a `422`, a `5xx`) is kept ([UploadResults]: single use,
  ///   a minute, bounded, the visitor's cookie) and answered the same way,
  ///   `x-thor-location: /_thor/upload-result/<token>`; the navigation gets
  ///   the page with the status it had. No second upload, no second post.
  /// - Anything else (a file, JSON, a `204`, a page over the limit) goes as it
  ///   is.
  ///
  /// Every answer carries the header back (the script knows the server speaks
  /// the protocol).
  Future<ThorResponse> _asUploadAnswer(
    PageRequest request,
    ThorResponse r,
  ) async {
    if (request.method != HttpMethod.post ||
        !request.headers.containsKey(_uploadHeader)) {
      return r;
    }
    final location = _header(r.headers, 'location');
    if (r.status >= 300 && r.status < 400 && location != null) {
      return ThorResponse(
        200,
        headers: {
          const HttpHeader(_uploadHeader): '1',
          const HttpHeader(_uploadLocation): safeLocation(location),
          HttpHeader.cacheControl: 'no-store',
        },
        cookies: r.cookies,
      );
    }
    final isPage =
        r.status != 204 &&
        r.status != 304 &&
        (_header(r.headers, 'content-type')?.startsWith('text/html') ??
            false) &&
        _header(r.headers, 'content-disposition') == null;
    if (!isPage) return r.withHeaders({const HttpHeader(_uploadHeader): '1'});
    var body = r.body;
    if (r.stream case final s?) {
      body = [await for (final chunk in s) ...chunk];
    }
    final headers = {
      for (final MapEntry(:key, :value) in r.headers.entries)
        if (!_notKept.contains(key.toLowerCase())) key: value,
    };
    final token = UploadResults.newToken();
    if (!UploadResults.store(token, r.status, headers, body)) {
      return ThorResponse(
        r.status,
        headers: {...r.headers, const HttpHeader(_uploadHeader): '1'},
        cookies: r.cookies,
        body: body,
      );
    }
    final secure = _secure(request) ? '; Secure' : '';
    return ThorResponse(
      200,
      headers: {
        const HttpHeader(_uploadHeader): '1',
        const HttpHeader(_uploadLocation): '${UploadResults.path}$token',
        HttpHeader.cacheControl: 'no-store',
      },
      cookies: [
        ...r.cookies,
        [
          '${UploadResults.cookie}=$token',
          'Path=${UploadResults.path}',
          'Max-Age=${UploadResults.ttl.inSeconds}',
          'HttpOnly',
          'SameSite=Lax$secure',
        ].join('; '),
      ],
    );
  }

  /// Headers of a kept page that belong to the answer that carried it.
  static const _notKept = {
    'content-length',
    'content-encoding',
    'transfer-encoding',
    'etag',
    'set-cookie',
    _uploadHeader,
    _uploadLocation,
  };

  /// `GET /_thor/upload-result/<token>`: the page an upload was answered
  /// with, once, to the visitor whose cookie holds the token. Any other
  /// request (a second visit, the back button, another visitor, an expired
  /// or another host's result) is sent to the page the form was on.
  ThorResponse _uploadResult(PageRequest request) {
    final token = request.uri.path.substring(UploadResults.path.length);
    final mine = request.frameworkCookies[UploadResults.cookie] == token;
    final clear = [
      '${UploadResults.cookie}=',
      'Path=${UploadResults.path}',
      'Max-Age=0',
      'HttpOnly',
      'SameSite=Lax',
    ].join('; ');
    if (mine ? UploadResults.take(token) : null case final page?) {
      return ThorResponse(
        page.status,
        headers: {...page.headers, HttpHeader.cacheControl: 'no-store'},
        cookies: [clear],
        body: page.body,
      );
    }
    var back = '/';
    if (Uri.tryParse(request.headers['referer'] ?? '') case final ref?
        when ref.host == request.uri.host &&
            ref.port == request.uri.port &&
            ref.path.startsWith('/') &&
            !ref.path.startsWith(UploadResults.path)) {
      back = safeLocation(ref.hasQuery ? '${ref.path}?${ref.query}' : ref.path);
    }
    return ThorResponse(
      303,
      headers: {HttpHeader.location: back, HttpHeader.cacheControl: 'no-store'},
      cookies: [if (mine) clear],
    );
  }

  /// How long a page fetched ahead stays usable without asking again.
  static const _prefetchedFor = Duration(seconds: 5);

  /// A page the browser fetched ahead (`Sec-Purpose: prefetch`, Firefox's
  /// `<link rel=prefetch>`) is answered `private, max-age=5` instead of
  /// `no-cache`, so the click that follows uses it and does not revalidate
  /// (a 304 still renders the page on the server). Only a plain `200` HTML
  /// `GET` that nothing of the visitor's is in: no cookie set, no cache
  /// header of its own (a personal page says `private, no-cache`), no
  /// `Clear-Site-Data`. The visit itself is answered `no-cache` as always, so
  /// the copy lives seconds, not until the next visit.
  ThorResponse _keepPrefetched(PageRequest request, ThorResponse r) {
    if (request.method != HttpMethod.get ||
        r.status != 200 ||
        !_prefetching(request) ||
        request.isPersonal ||
        r.cookies.isNotEmpty ||
        _header(r.headers, 'cache-control')?.trim().toLowerCase() !=
            'no-cache' ||
        _header(r.headers, 'set-cookie') != null ||
        _header(r.headers, 'clear-site-data') != null ||
        !(_header(r.headers, 'content-type')?.startsWith('text/html') ??
            false)) {
      return r;
    }
    final headers = <HttpHeader, String>{...r.headers};
    headers.removeWhere((k, _) => k.toLowerCase() == 'cache-control');
    headers[HttpHeader.cacheControl] =
        'private, max-age=${_prefetchedFor.inSeconds}';
    return ThorResponse(
      r.status,
      headers: headers,
      body: r.body,
      stream: r.stream,
      cookies: r.cookies,
    ).._bytesFrom = r;
  }

  /// Whether [request] is a browser's call to a query.
  static bool _isQuery(PageRequest request) =>
      request.method == HttpMethod.post &&
      request.headers.containsKey(queryHeader);

  /// Whether [request] is a browser's call to a command.
  static bool _isCommand(PageRequest request) =>
      request.method == HttpMethod.post &&
      request.headers.containsKey(commandHeader);

  /// Whether [request] is a browser's call to a query or a command.
  static bool _isCall(PageRequest request) =>
      _isQuery(request) || _isCommand(request);

  /// A query call answers JSON, whatever stopped it before the query ran: a
  /// middleware's redirect (no session) is a `401` with `redirect` (a
  /// `fetch` would follow a `302` silently), an error page its status.
  ThorResponse _asQueryAnswer(PageRequest request, ThorResponse r) {
    if (!_isCall(request) ||
        (_header(r.headers, 'content-type')?.startsWith('application/json') ??
            false)) {
      return r;
    }
    final location = _header(r.headers, 'location');
    if (r.status >= 300 && r.status < 400 && location != null) {
      return _json(401, {
        'error': _messagesFor(request).signIn,
        'redirect': safeLocation(location),
      });
    }
    if (r.status == 429) {
      final wait = _header(r.headers, 'retry-after');
      return _json(429, {
        'error': _messagesFor(request).forStatus(429),
        'retryAfter': ?int.tryParse(wait ?? ''),
      }).withHeaders({HttpHeader.retryAfter: ?wait});
    }
    return _json(r.status < 400 ? 500 : r.status, {
      'error': r.status == 404
          ? _messagesFor(request).notFound
          : _messagesFor(request).forStatus(r.status),
    });
  }

  /// The texts of the call errors: the renderer's (the app's), else the
  /// defaults, in the language of [request].
  ServerMessages _messagesFor(PageRequest request) => (switch (renderer) {
    final ServerQueries q => q.serverMessages,
    _ => const ServerMessages(),
  }).forLocale(request.locale);

  static ThorResponse _json(int status, Object? body) => ThorResponse(
    status,
    headers: const {
      HttpHeader.contentType: 'application/json; charset=utf-8',
      HttpHeader.cacheControl: 'no-store',
    },
    // `<` escaped like the page's state: never HTML, whatever sniffs it.
    body: utf8.encode(jsonEncode(body).replaceAll('<', r'\u003c')),
  );

  Future<ThorResponse> _scoped(PageRequest request) => switch (renderer) {
    final RequestScopedRenderer r => r.inRequestScope(() => _handle(request)),
    _ => _handle(request),
  };

  /// Under `thor dev`: a response whose body or headers contain a loaded
  /// [Secret] is a 500 that names the variable's problem, not the value
  /// (THOR-P012). A release server skips the scan.
  ThorResponse _withoutLeaks(PageRequest request, ThorResponse response) {
    if (!ThorDev.enabled || response.stream != null) return response;
    final text = utf8.decode(response.body, allowMalformed: true);
    final headers = response.headers.values.join('\n');
    if (Secret.leakIn(text) == null && Secret.leakIn(headers) == null) {
      return response;
    }
    final error = StateError(
      thorError(
        'THOR-P012',
        'the response to ${request.method} ${request.uri.path} contains the '
            'value of a secret from the environment',
      ),
    );
    _report(request, error, StackTrace.current, 'render');
    return _plain(
      500,
      'A secret from the environment reached this page (THOR-P012).',
    );
  }

  /// Under `thor dev`: the exceptions this request reported, per request.
  final _devErrors = Expando<List<String>>('thor dev errors');

  /// Reports an unexpected exception ([onError]) and, under `thor dev`,
  /// keeps it for the page ([ThorDev.errorBlock]).
  void _report(
    PageRequest request,
    Object error,
    StackTrace? stack,
    String phase,
  ) {
    if (!ThorDev.enabled) {
      onError(request, error, stack);
      return;
    }
    // web: under `thor dev` the terminal gets one line (method, path,
    // error, the app's top frame) whatever `onError` does; the default
    // `onError` would print the whole stack again.
    ThorDev.logRequestError(
      method: request.method.token,
      path: request.uri.path,
      error: error,
      stack: stack,
    );
    if (!identical(onError, _printError)) onError(request, error, stack);
    (_devErrors[request] ??= []).add(
      ThorDev.errorBlock(
        phase: phase,
        where: '${request.method} ${request.uri.path}',
        error: error,
        stack: stack,
      ),
    );
  }

  ThorResponse _withDevErrors(PageRequest request, ThorResponse response) {
    final blocks = _devErrors[request];
    // A page answered early reports in its own document.
    if (blocks == null ||
        response.stream != null ||
        !(_header(response.headers, 'content-type')?.contains('text/html') ??
            false)) {
      return response;
    }
    return ThorResponse(
      response.status,
      headers: response.headers,
      cookies: response.cookies,
      body: utf8.encode(ThorDev.withBlocks(response.text, blocks)),
    );
  }

  /// `request.response.cookies` is the one list of cookies a request sets:
  /// the ones set after `next()` in a middleware (or on a cached page) join
  /// the response here, after whatever built it. A response a middleware
  /// made itself keeps its own cookies too.
  ThorResponse _withLateCookies(PageRequest request, ThorResponse r) {
    final set = request.response.cookies;
    if (set.isEmpty) return r;
    final headers = [
      for (final c in set) c.toHeader(secureByDefault: _secure(request)),
    ];
    final missing = [
      for (final h in headers)
        if (!r.cookies.contains(h)) h,
    ];
    if (missing.isEmpty) return r;
    return _clearSpeculations(
      ThorResponse(
        r.status,
        headers: r.headers,
        body: r.body,
        stream: r.stream,
        cookies: [...r.cookies, ...missing],
      ).._bytesFrom = r,
    );
  }

  Future<ThorResponse> _handle(PageRequest request) async {
    final path = request.uri.path;
    if (path.startsWith(rendererAssetsDir) && request.method.isRead) {
      if (renderer case final RendererAssets assets) {
        final asset = await assets.asset(path);
        if (asset != null) {
          return ThorResponse(
            200,
            headers: {
              HttpHeader.contentType: asset.contentType,
              // The name changes with the content: never revalidated.
              HttpHeader.cacheControl: 'public, max-age=31536000, immutable',
              HttpHeader.etag: etagOf(asset.body),
            },
            body: asset.body,
          );
        }
      }
    }
    if (path.length > 1 && path.endsWith('/')) {
      // One URL per page: `/about/` → `/about`.
      final trimmed = sitePath(path.replaceFirst(RegExp(r'/+$'), ''));
      final query = request.uri.hasQuery ? '?${request.uri.query}' : '';
      return _redirect(
        request,
        Redirect.permanent(
          RouteUrl('${trimmed.isEmpty ? '/' : trimmed}$query'),
        ),
      );
    }
    var routePath = path;
    final locales = this.locales;
    Map<String, List<String>>? switchQuery;
    if (locales != null && request.method.isRead) {
      try {
        switchQuery = request.queryParametersAll;
      } on HttpError catch (e) {
        // A query that does not decode is the client's error (400).
        return _error(request, const [], const [], e, _root);
      }
    }
    if (locales != null &&
        switchQuery != null &&
        switchQuery.containsKey(LocaleRouting.switchParameter)) {
      // A language switcher link: remember the choice, then the page in
      // that locale without the parameter (a tag the app doesn't speak
      // only loses the parameter).
      final rest = {...switchQuery}..remove(LocaleRouting.switchParameter);
      final query = rest.isEmpty ? '' : '?${Uri(queryParameters: rest).query}';
      final chosen = locales.supportedLocaleOf(
        switchQuery[LocaleRouting.switchParameter]!.last,
      );
      var target = path;
      if (chosen != null) {
        request.response.setCookie(
          locales.cookieName,
          chosen.toLanguageTag(),
          maxAge: const Duration(days: 365),
        );
        target = locales.pathFor(chosen, locales.resolve(path).path);
      }
      _putIfAbsent(request.response.headers, 'cache-control', 'no-store');
      return _redirect(
        request,
        Redirect(RouteUrl('${sitePath(target)}$query')),
      );
    }
    if (locales != null) {
      final resolved = locales.resolve(
        path,
        cookie: request.frameworkCookies[locales.cookieName],
        acceptLanguage: request.headers['accept-language'],
      );
      request
        ..locale = resolved.locale
        ..localeRouting = locales
        ..routePath = resolved.path;
      routePath = resolved.path;
      final query = request.uri.hasQuery ? '?${request.uri.query}' : '';
      final isRead = request.method.isRead;
      final canonical = locales.canonicalOfDefaultPrefix(path);
      if (locales.strategy == LocaleStrategy.negotiate) {
        // One URL, several languages: shared caches must key by both.
        _addVary(request.response.headers, 'Accept-Language, Cookie');
      } else if (canonical != null && isRead) {
        // The default locale has one URL, without its prefix.
        return _redirect(
          request,
          Redirect.permanent(RouteUrl('$canonical$query')),
        );
      } else if (!resolved.prefixed && isRead && router.match(path) != null) {
        // A page without its locale: to the visitor's. Only for a page
        // that exists (an unknown path is a 404 in the visitor's locale).
        // Without a prefix for the default, only the root asks.
        final asks = locales.strategy == LocaleStrategy.prefix || path == '/';
        if (asks) _addVary(request.response.headers, 'Accept-Language, Cookie');
        if (locales.redirectsUnprefixed(path, resolved.locale)) {
          return _redirect(
            request,
            Redirect.found(
              RouteUrl('${locales.pathFor(resolved.locale, path)}$query'),
            ),
          );
        }
      }
    }
    // A URL no page matches is the 404 of the group that owns it: inside
    // its layouts, after its middleware and guards.
    final match = router.match(routePath) ?? router.matchNotFound(routePath);
    if (match == null) {
      return _error(request, const [], const [], const NotFound(), _root);
    }
    request.pathParameters = match.pathParameters;
    final entry = match.entry;
    // The page's own body limit, before anything (middleware, a guard, an
    // action) can read the body.
    request.prefetch = entry.prefetch;
    // A route that says its page is the same for everyone keeps it so
    // whatever cookies its guards and loads read.
    if (entry.personalized == false) shareCookieReads(request);
    if (entry.page.maxBodyBytes case final limit?) {
      request.maxBodyBytes = limit;
    }
    // A 404 runs no action, whatever the method.
    final isPost = request.method == HttpMethod.post && !entry.notFound;
    final chain = entry.middleware;
    // An OPTIONS request goes through the middleware (`cors` answers a
    // preflight); what none answers is a 405.
    final options =
        request.method == HttpMethod.options &&
        !entry.notFound &&
        chain.isNotEmpty;
    final resource = entry.page is ResourceRoute<P>
        ? entry.page as ResourceRoute<P>
        : null;
    final allow = resource == null ? 'GET, HEAD, POST' : _allowed(resource);
    final resourceMethod = resource?.methods.contains(request.method) ?? false;
    if (!entry.notFound &&
        !isPost &&
        !options &&
        !resourceMethod &&
        !request.method.isRead) {
      return _plain(405, 'Method not allowed', {HttpHeader.allow: allow});
    }
    if (isPost && _isCall(request) && !_sameOriginQuery(request)) {
      return _json(403, {
        'error': _isCommand(request)
            ? 'Cross-site command is forbidden'
            : 'Cross-site query is forbidden',
      });
    }
    if (isPost && !_sameOrigin(request)) {
      return _plain(403, 'Cross-site form submission is forbidden');
    }
    if (chain.isEmpty) return _serve(request, entry, isPost);
    try {
      return await _through(
        chain,
        0,
        request,
        options
            ? () async =>
                  _plain(405, 'Method not allowed', {HttpHeader.allow: allow})
            : () => _serve(request, entry, isPost),
      );
    } on Redirect catch (r) {
      return _redirect(request, r);
    } on HttpError catch (e, st) {
      if (e is UpstreamError) _report(request, e, st, 'middleware');
      return _error(request, const [], const [], e, _root);
    } catch (e, st) {
      _report(request, e, st, 'middleware');
      return _error(request, const [], const [], const HttpError(500), _root);
    }
  }

  /// Runs [chain] from [i], then [last].
  static Future<ThorResponse> _through(
    List<Middleware> chain,
    int i,
    PageRequest request,
    Next last,
  ) async {
    if (i == chain.length) return last();
    var called = false;
    return chain[i](request, () {
      if (called) {
        throw StateError(
          thorError(
            'THOR-P004',
            'next() called twice in a middleware: call it once and keep '
                'its response',
          ),
        );
      }
      called = true;
      return _through(chain, i + 1, request, last);
    });
  }

  /// The page cache, then the pipeline ([_run]).
  /// A [ResourceRoute]: its guards, then its answer (no load, render or
  /// page cache).
  Future<ThorResponse> _resource(
    PageRequest request,
    RouteEntry<P> entry,
    ResourceRoute<P> resource,
  ) async {
    if (!request.method.isRead && !resource.methods.contains(request.method)) {
      return _plain(405, 'Method not allowed', {
        HttpHeader.allow: _allowed(resource),
      });
    }
    try {
      for (final guard in [
        ...entry.layouts.map((l) => l.redirect),
        resource.redirect,
      ]) {
        // Most guards (every page class has one) answer null at once: no
        // microtask for them.
        final pending = guard?.call(request);
        final to = pending is Future<RouteUrl?> ? await pending : pending;
        if (to != null) return _redirect(request, Redirect.found(to));
      }
      return await resource.respond(request);
    } on Redirect catch (r) {
      return _redirect(request, r);
    } on HttpError catch (e, st) {
      if (e is UpstreamError) _report(request, e, st, 'load');
      return _plain(e.status, e.message ?? 'Error ${e.status}');
    } catch (e, st) {
      _report(request, e, st, 'load');
      return _plain(500, 'Internal server error');
    }
  }

  /// The `Allow` of a resource: `GET, HEAD` and its methods.
  static String _allowed(ResourceRoute<Object?> resource) => [
    'GET, HEAD',
    for (final m in resource.methods) m.name.toUpperCase(),
  ].join(', ');

  Future<ThorResponse> _serve(
    PageRequest request,
    RouteEntry<P> entry,
    bool isPost,
  ) async {
    if (entry.page case final ResourceRoute<P> resource) {
      return _resource(request, entry, resource);
    }
    // A command first: a request naming both is a command (it never runs
    // as a query that skips the write's cache clear).
    if (isPost && _isCommand(request)) return _command(request, entry);
    if (isPost && _isQuery(request)) return _query(request, entry);
    final cache = entry.cache;
    // A flash waiting for this visitor (a redirect just set it) is theirs
    // alone: never from the shared cache, never into it.
    final flashed =
        !isPost && request.frameworkCookies.containsKey(flashCookie);
    if (flashed && _prefetching(request)) {
      // A page fetched ahead of the visit would take the message and show it
      // to nobody: decline, and the browser loads it when the visitor goes.
      return _plain(503, 'Not now', {HttpHeader.cacheControl: 'no-store'});
    }
    // A visitor's value in the context (the session a middleware read)
    // makes the page this visitor's, whatever the route says.
    final personal = request.isPersonal || flashed ? true : entry.personalized;
    if (personal ?? false) {
      _putIfAbsent(
        request.response.headers,
        'cache-control',
        'private, no-cache',
      );
    }
    final shared =
        cache != null &&
        !isPost &&
        !(personal ?? personalized?.call(request) ?? false);
    // The cache keeps the finished page, never one that waits for its data.
    // A `GET` that finds none still streams (the visitor doesn't wait for
    // the slowest value): the finished page is stored when the stream ends
    // ([_cacheTee]). `HEAD` has no body to stream.
    if (shared && request.method != HttpMethod.get) _settled[request] = true;
    // Per locale: with negotiation one URL has a page per language.
    final key = locales == null
        ? request.uri.toString()
        : '${request.locale} ${request.uri}';
    // A render only fills the cache if no clear that reaches its page came
    // while it ran: a write clears every page (but a tagged one that asked
    // not to), a revalidation the pages with the tag.
    final generation = _generation;
    final tagGeneration = _tagGeneration;
    final pinned = entry.tags.isNotEmpty && !entry.invalidateOnWrite;
    bool fresh() =>
        (pinned || generation == _generation) &&
        (entry.tags.isEmpty || tagGeneration == _tagGeneration);
    if (shared) {
      // Not to a visitor with a cookie the page asked for and did not find
      // when it was drawn: their page may differ (it is drawn for them).
      final hit = switch (_cache[key]) {
        final h? when h.fits(request) => _cache.remove(key),
        _ => null,
      };
      if (hit != null) {
        _cacheBytes -= hit.response.body.length;
        final age = hit.age;
        // Stale-while-revalidate, but never older than twice the TTL (an
        // idle page is rendered again instead of served from long ago).
        if (age <= cache * 2) {
          _cache[key] = hit; // most recently used
          _cacheBytes += hit.response.body.length;
          if (age > cache && !hit.refreshing) {
            hit.refreshing = true;
            // Nobody waits for this render: it is complete, to be stored.
            _settled[request] = true;
            unawaited(
              // The full pipeline (onRequest, guards), like a miss.
              _run(request, entry, false, early: false)
                  .then((r) {
                    if (_cacheable(r) && fresh() && !request.isPersonal) {
                      _store(key, request, r, entry.tags, pinned);
                    }
                  })
                  .whenComplete(() => hit.refreshing = false),
            );
          }
          return hit.response;
        }
      }
    }
    if (shared && _settled[request] != true) {
      _cacheTee[request] = (r) {
        // The same conditions as a page stored after a plain render.
        if (_cacheable(r) && fresh() && !request.isPersonal) {
          _store(key, request, r, entry.tags, pinned);
        }
      };
    }
    // A shared page comes from the cache: never answered early.
    var response = await _run(
      request,
      entry,
      isPost,
      early: !shared && entry.earlyHints,
    );
    // A form action changed data: what this isolate cached may show it
    // stale (a new article, a counter).
    // (A confirm page changed nothing: the action has not run.)
    final changed = isPost && response.status < 400 && _asked[response] != true;
    if (changed) _clearCache();
    // The same for what the browser fetched ahead (speculation rules): a
    // page prefetched before a logout would otherwise be shown signed in
    // after the redirect. Also when cookies change (a sign-in, a session
    // set by a GET).
    if (changed || response.cookies.isNotEmpty) {
      response = _clearSpeculations(response);
    }
    // Not if an action cleared the cache while this rendered: its data may
    // predate the change.
    // Nor a page that got a visitor's value in the context after the
    // lookup (in `onRequest` or a load): it may show the visitor.
    if (shared &&
        response.stream == null &&
        _cacheable(response) &&
        fresh() &&
        !request.isPersonal) {
      _store(key, request, response, entry.tags, pinned);
    }
    return response;
  }

  /// The queries and commands each route's pages used (learned when they
  /// draw, per isolate): one is answered only on a route whose page uses
  /// it, so a public page can't reach the query or the command of a state
  /// behind a middleware.
  final _queriesOf = Expando<Set<String>>('thor queries');

  /// What drawing each route to learn a call found nothing for: one mark
  /// per (id, visitor), each lasting [learnWindow], and [_learnLimit]
  /// alive at most. The visitor is what their cookies and `Authorization`
  /// say, so the same visitor asking again doesn't draw the page again,
  /// while another one (an admin, whose page shows the query) still learns
  /// it once. Ids the build doesn't list never get here (a `404` before).
  final _missingOf = Expando<_Missing>('thor missing calls');

  static const _learnLimit = 8;

  /// Answers query [request]'s `x-thor-query` for the page of [entry],
  /// after its middleware (already run), `onRequest` and guards: the same
  /// gate the page has. A query reads: no cache clear, no
  /// `Clear-Site-Data`.
  Future<ThorResponse> _query(PageRequest request, RouteEntry<P> entry) {
    final id = request.headers[queryHeader]!;
    return _call(request, entry, id, 'query', (body, _) async {
      final queries = renderer as ServerQueries;
      final data = await queries.runQuery(request, id, body['arg']);
      return _json(200, {'data': data});
    });
  }

  /// Answers command [request]'s `x-thor-command` for the page of [entry],
  /// through the same gate as a query. After it succeeds the page's
  /// queries run again (with the arguments the browser sent in
  /// `queries`) and their values go in the same answer: `{"result": …,
  /// "queries": {id: value}, "errors": {id: message}}`. A command that writes
  /// (the default) clears the page cache and the browser's speculations,
  /// like a form action; one made with `writes: false` (a read the visitor
  /// asks for) keeps both.
  Future<ThorResponse> _command(PageRequest request, RouteEntry<P> entry) {
    final id = request.headers[commandHeader]!;
    return _call(request, entry, id, 'command', (body, allowed) async {
      final commands = switch (renderer) {
        final ServerCommands c => c,
        _ => throw const NotFound(),
      };
      final Map<String, Object?> args;
      switch (body['queries']) {
        case null:
          args = const {};
        case final Map<String, Object?> m:
          args = m;
        default:
          return _json(400, {'error': _messagesFor(request).badRequest});
      }
      // Only the queries the browser has on its page (and the route uses):
      // a route's queries also hold ones drawn for another visitor. No
      // `queries` at all (a client that doesn't say): every one of the route.
      final answer = await commands.runCommand(
        request,
        id,
        body['arg'],
        refresh: body['queries'] == null
            ? allowed
            : allowed.intersection(args.keys.toSet()),
        queryArgs: args,
      );
      if (answer.writes) _clearCache();
      for (final (e, st) in answer.thrown) {
        if (e is HttpError && e is! UpstreamError) continue;
        _report(request, e, st, 'query');
      }
      final json = _json(200, {
        'result': answer.result,
        if (answer.queries.isNotEmpty) 'queries': answer.queries,
        if (answer.errors.isNotEmpty) 'errors': answer.errors,
        if (answer.kinds.isNotEmpty) 'kinds': answer.kinds,
      });
      return answer.writes ? _clearSpeculations(json) : json;
    });
  }

  /// A query's or a command's ([kind]) gate: `onRequest`, the page's guards, the
  /// JSON body, and the allowlist of the route (what [id] names must be
  /// something the route's pages use); then [answer] with the body and
  /// that allowlist. Errors become JSON: a redirect a `401`, an
  /// [HttpError] its status and message, anything else a generic `500`.
  Future<ThorResponse> _call(
    PageRequest request,
    RouteEntry<P> entry,
    String id,
    String kind,
    Future<ThorResponse> Function(Map<String, Object?> body, Set<String> used)
    answer,
  ) async {
    if (renderer is! ServerQueries) {
      return _json(404, {'error': _messagesFor(request).notFound});
    }
    try {
      await onRequest?.call(request);
      for (final guard in [
        ...entry.layouts.map((l) => l.redirect),
        entry.page.redirect,
      ]) {
        final pending = guard?.call(request);
        final to = pending is Future<RouteUrl?> ? await pending : pending;
        if (to != null) {
          return _json(401, {
            'error': _messagesFor(request).signIn,
            'redirect': safeLocation(to),
          });
        }
      }
      final Object? body;
      try {
        body = jsonDecode(await request.text());
      } on FormatException {
        return _json(400, {'error': _messagesFor(request).badRequest});
      }
      if (body is! Map<String, Object?>) {
        return _json(400, {'error': _messagesFor(request).badRequest});
      }
      // Not drawn here yet (this isolate), or drawn for another visitor
      // (a state only an admin's page shows): draw the page to learn what
      // it uses, under this request (its middleware already ran). Drawing
      // runs the page's loads and queries, never a command, so it happens
      // once per id and visitor in a window and a few times per route: a
      // made-up id must not make every call draw the page again.
      if (!(_queriesOf[entry]?.contains(id) ?? false)) {
        // Not a query or command of the app at all: nothing to learn.
        if (renderer case final ServerCallIds ids when !ids.declaresCall(id)) {
          ThorDev.warnUndeclaredCall(id);
          return _json(404, {'error': _messagesFor(request).notFound});
        }
        // Marked before drawing; concurrent calls of the same visitor wait
        // for that one drawing and don't each draw it.
        final missing = _missingOf[entry] ??= _Missing();
        final visitor = Object.hash(
          request.headers['cookie'],
          request.headers['authorization'],
        );
        final drawing = missing.drawing[visitor];
        if (drawing != null) {
          // The same visitor's page is being drawn for another call: wait
          // for it, it teaches this id too (the check below decides).
          await drawing;
        } else {
          if (!missing.mark(id, visitor)) {
            return _json(404, {'error': _messagesFor(request).notFound});
          }
          final done = Completer<void>();
          missing.drawing[visitor] = done.future;
          try {
            await _render(request, entry, null, early: false);
          } finally {
            unawaited(missing.drawing.remove(visitor)!);
            done.complete();
          }
          if (_queriesOf[entry]?.contains(id) ?? false) {
            missing.unmark(id, visitor);
          }
        }
      }
      final used = _queriesOf[entry];
      if (used == null || !used.contains(id)) {
        return _json(404, {'error': _messagesFor(request).notFound});
      }
      return await answer(body, used);
    } on Redirect catch (r) {
      return _json(401, {
        'error': _messagesFor(request).signIn,
        'redirect': safeLocation(r.location),
      });
    } on HttpError catch (e, st) {
      if (e is UpstreamError) _report(request, e, st, kind);
      return _json(e.status, {
        'error': e.message ?? _messagesFor(request).forStatus(e.status),
        if (e is TooManyRequests) 'retryAfter': e.retryAfterSeconds,
      }).withHeaders({
        if (e is TooManyRequests)
          HttpHeader.retryAfter: '${e.retryAfterSeconds}',
      });
    } catch (e, st) {
      _report(request, e, st, kind);
      // `thor dev` only: the overlay shows the detail with the stack's
      // file:line, and its first line says why the page has no message.
      String? detail;
      if (ThorDev.enabled) {
        final why = thorError(
          'THOR-P034',
          'the $kind threw ${e.runtimeType}: $e. The page shows only its '
              'generic message, never an exception\'s: throw '
              'HttpError(status, message) to show one',
        );
        stderr.writeln('[thor] ${ThorDev.terminalSafe(why, 600)}');
        detail = '$why\n${e.runtimeType}: $e\n$st';
      }
      return _json(500, {
        'error': _messagesFor(request).generic,
        'detail': ?detail,
      });
    }
  }

  /// Bumped by every clear: a render only fills the cache if no clear
  /// happened since it started.
  var _generation = 0;

  /// A write here: clear this isolate's cache and tell the other isolates
  /// of the server to clear theirs ([CacheBus], coalesced and without
  /// waiting). A cache in front of the server (a CDN) is not reached: it
  /// needs its own purge.
  void _clearCache() {
    _clearLocal();
    CacheBus.announce();
  }

  // A write clears every page but the pinned ones (tags, invalidateOnWrite:
  // false), which wait for their tag.
  void _clearLocal() {
    _cache.removeWhere((_, c) {
      if (c.pinned) return false;
      _cacheBytes -= c.response.body.length;
      return true;
    });
    _generation++;
  }

  var _tagGeneration = 0;

  void _revalidateLocal(List<String> tags) {
    final all = tags.contains(CacheBus.allTags);
    _cache.removeWhere((_, c) {
      if (c.tags.isEmpty || !(all || c.tags.any(tags.contains))) return false;
      _cacheBytes -= c.response.body.length;
      return true;
    });
    _tagGeneration++;
  }

  late final void Function(List<String>) _onTags = _revalidateLocal;

  // Held by the handler: the bus keeps its listeners weakly.
  late final void Function() _onPeerWrite = _clearLocal;

  Future<ThorResponse> _run(
    PageRequest request,
    RouteEntry<P> entry,
    bool isPost, {
    required bool early,
  }) async {
    var phase = 'request';
    try {
      await onRequest?.call(request);
      phase = 'guard';
      for (final guard in [
        ...entry.layouts.map((l) => l.redirect),
        entry.page.redirect,
      ]) {
        // Most guards (every page class has one) answer null at once: no
        // microtask for them.
        final pending = guard?.call(request);
        final to = pending is Future<RouteUrl?> ? await pending : pending;
        if (to != null) {
          return _redirect(request, isPost ? Redirect(to) : Redirect.found(to));
        }
      }
      ActionResult? result;
      if (isPost) {
        phase = 'action';
        final outcome = await _action(request, entry.page);
        if (outcome is ThorResponse) return outcome;
        result = outcome as ActionResult;
      }
      phase = 'build';
      return await _render(request, entry, result, early: early && !isPost);
    } on Redirect catch (r) {
      return _redirect(request, r);
    } on HttpError catch (e, st) {
      if (e is UpstreamError) _report(request, e, st, phase);
      return _failed(request, entry, e, afterAction: phase == 'action');
    } catch (error, st) {
      // Calls awaited together (`(a, b).wait`) fail as one error: its cause
      // decides, as if it had been thrown alone.
      final e = causeOf(error);
      if (e is Redirect) return _redirect(request, e);
      if (e is HttpError && e is! UpstreamError) {
        return _failed(request, entry, e, afterAction: phase == 'action');
      }
      _report(request, e, st, phase);
      return _failed(
        request,
        entry,
        const HttpError(500),
        afterAction: phase == 'action',
      );
    }
  }

  /// The error page for [error], thrown before the page's loads ran. After
  /// an action (every guard passed) the layouts load first, so the error
  /// renders like one from a load: the nearest error page, inside its
  /// layouts and with their data.
  Future<ThorResponse> _failed(
    PageRequest request,
    RouteEntry<P> entry,
    HttpError error, {
    required bool afterAction,
  }) async {
    if (!afterAction || entry.layouts.isEmpty) {
      return _error(request, entry.layouts, const [], error, null);
    }
    final outcomes = await _loadAll(request, [
      for (final l in entry.layouts) l.runLoad,
    ], entry.layouts);
    // Only the levels above the first failed load wrap the error.
    final data = [
      for (final o in outcomes.takeWhile((o) => o is _Ok)) (o as _Ok).value,
    ];
    return _error(request, entry.layouts, data, error, null);
  }

  /// Starts every loader now, each in its own zone (`request.parent<T>()`
  /// finds the futures of the levels above it), and settles them.
  Future<List<Object?>> _loadAll(
    PageRequest request,
    List<Future<Object?> Function(PageRequest)> loaders,
    List<LayoutRoute<P, Object?>> layouts,
  ) {
    final futures = <Future<Object?>>[];
    // What each load marked as needed by the head (`defer(f, head: true)`).
    final heads = <List<(Future<Object?>, Duration?)>>[];
    for (var i = 0; i < loaders.length; i++) {
      final scope = _LoadScope(layouts.take(i).toList(), futures);
      final head = <(Future<Object?>, Duration?)>[];
      heads.add(head);
      futures.add(
        runZoned(
          () => loaders[i](request),
          zoneValues: {
            loadScopeKey: scope,
            headWaitKey: (Future<Object?> f, Duration? budget) =>
                head.add((f, budget)),
          },
        ),
      );
    }
    return Future.wait([
      for (var i = 0; i < futures.length; i++)
        _settle(request, futures[i], heads[i]),
    ]);
  }

  /// How [load] ended; when it holds, the futures it marked for the head
  /// ([head]) are awaited: one that fails with an [HttpError] or a [Redirect]
  /// fails the load as if it had been awaited there (the real status, the
  /// redirect, the error page), however long it takes. Only a future with an
  /// opt-in budget (`defer(f, head: true, headBudget:)`) stops being awaited
  /// when that runs out: the page streams, and a later status failure is
  /// warned about under `thor dev` (THOR-S038).
  Future<Object?> _settle(
    PageRequest request,
    Future<Object?> load,
    List<(Future<Object?>, Duration?)> head,
  ) async {
    final Object? value;
    try {
      value = await load;
    } catch (e, st) {
      return _Failed(e, st);
    }
    if (head.isEmpty) return _Ok(value);
    // A page that has to be complete (kept in the cache, exported) waits for
    // them as long as its body will: a fallback title must not be kept.
    final complete = _settled[request] == true;
    // A prefix of the header: bot names are short, and the check must cost
    // the same for any User-Agent.
    final agent = request.headers['user-agent'] ?? '';
    final bot = _htmlBots.hasMatch(
      agent.length > 512 ? agent.substring(0, 512) : agent,
    );
    Duration? budgetOf(Duration? budget) => complete || budget == null
        ? null
        : bot && headBotBudget > budget
        ? headBotBudget
        : budget;
    // The bots get more time on a budget, so the head they read depends on
    // the User-Agent: shared caches must key by it. Without a budget nobody
    // waits less than anybody else and nothing varies.
    if (!complete && head.any((h) => h.$2 != null && headBotBudget > h.$2!)) {
      _addVary(request.response.headers, 'User-Agent');
    }
    return _awaitHead(request, value, head, budgetOf);
  }

  /// [value] once every future in [head] is in, or the first failure that
  /// settles the response, as soon as it happens: a status failure
  /// (`NotFound`, `HttpError`, `Redirect`) always does, and so does any other
  /// error of a future with no budget (a 500, never a 200 that depends on
  /// the backend's mood). A slow future is not waited for once another
  /// settled the answer. Waiting is bounded: a future with no budget by
  /// [deferTimeout] (a 504), one with an opt-in budget by that budget (the
  /// page streams, noindex, and a later status failure warns under `thor
  /// dev`, THOR-S038).
  Future<Object?> _awaitHead(
    PageRequest request,
    Object? value,
    List<(Future<Object?>, Duration?)> head,
    Duration? Function(Duration?) budgetOf,
  ) {
    final result = Completer<Object?>();
    final timers = <Timer>[];
    var open = head.length;
    void settle(Object? outcome) {
      if (result.isCompleted) return;
      result.complete(outcome);
      for (final timer in timers) {
        timer.cancel();
      }
    }

    for (final (future, budget) in head) {
      final limit = budgetOf(budget);
      var over = false;
      Timer? timer;
      void ended(Object? error, StackTrace? stack) {
        timer?.cancel();
        final status =
            error != null &&
            (causeOf(error) is HttpError || causeOf(error) is Redirect);
        if (over) {
          // Past its budget: the page already streams 200.
          if (status && ThorDev.enabled) {
            ThorDev.warnLateHeadStatus(
              method: request.method.token,
              path: request.uri.path,
            );
          }
          return;
        }
        if (error != null && (status || limit == null)) {
          settle(_Failed(error, stack ?? StackTrace.current));
        } else if (--open == 0) {
          settle(_Ok(value));
        }
      }

      future.then<void>((_) => ended(null, null), onError: ended);
      timer = Timer(limit ?? deferTimeout, () {
        if (limit == null) {
          settle(
            _Failed(
              UpstreamError(
                504,
                method: request.method,
                uri: request.uri,
                reason:
                    'a defer(head: true) future did not finish within '
                    'deferTimeout ($deferTimeout)',
              ),
              StackTrace.current,
            ),
          );
          return;
        }
        over = true;
        if (!result.isCompleted) _budgetExpired[request] = true;
        if (--open == 0) settle(_Ok(value));
      });
      timers.add(timer);
    }
    return result.future;
  }

  /// Runs the form action: a response (redirect) or the result to render.
  Future<Object> _action(
    PageRequest request,
    PageRoute<P, Object?> page,
  ) async {
    if (page.actions.isEmpty) {
      return _plain(405, 'This page has no form actions', {
        HttpHeader.allow: 'GET, HEAD',
      });
    }
    // `/thor-ask` is a confirm's question (confirm_page.dart), not an action.
    final named = request.queryParameters.keys
        .where((k) => k.startsWith('/') && k != askQueryKey)
        .firstOrNull;
    final name = named?.substring(1) ?? _keylessAction(page.actions);
    final action = page.actions[name];
    if (action == null) throw HttpError(404, 'No action "$name"');
    // A control with `confirm:` whose question nobody answered (JavaScript
    // off): the page that asks, and the action waits for the second post.
    if (await _unanswered(request) case final asked?) return asked;
    final outcome = await action(request);
    return switch (outcome) {
      Redirect() => _redirect(request, outcome),
      ActionResult() => _stayed(request, outcome),
      ActionOutcome() => _stayed(request, outcome.actionResult),
      // Post/redirect/get: back to the page, without the action key.
      null => _redirect(request, Redirect(_withoutAction(request.uri))),
      // Anything else used to render as a success without its data: a
      // failed form returned as is answered 200 and lost its messages.
      _ => throw StateError(
        thorError(
          'THOR-P009',
          'action "$name" returned a ${outcome.runtimeType}: return a '
              'Redirect, an ActionResult, an ActionOutcome or null',
        ),
      ),
    };
  }

  /// What a `Form(stay: true)` gets for the page [result] an action asked
  /// to draw: no page (the browser stays where it is), only its status and
  /// the sentence the result carries ([ActionMessage], a `String` or a
  /// `message` / `error` entry of a `Map`; a failure with none says the
  /// generic message). Any other request gets [result] to render.
  Object _stayed(PageRequest request, ActionResult result) {
    if (!request.headers.containsKey(_stayHeader)) return result;
    final failed = result.status >= 400;
    final text = _stayMessage(result.data)?.trim();
    final message = text != null && text.isNotEmpty
        ? text
        : failed
        ? _messagesFor(request).generic
        : null;
    return _finish(
      request,
      ThorResponse(
        result.status,
        headers: {
          const HttpHeader(_stayHeader): '1',
          HttpHeader.cacheControl: 'no-store',
          ..._flashHeaders(
            message == null
                ? null
                : FlashMessage(
                    message,
                    failed ? FlashKind.error : FlashKind.success,
                  ),
          ),
        },
      ),
    );
  }

  static String? _stayMessage(Object? data) => switch (data) {
    ActionMessage() => data.actionMessage,
    String() => data,
    Map() =>
      (data['message'] ?? data['error']) is String
          ? (data['message'] ?? data['error']) as String
          : null,
    _ => null,
  };

  /// A flash as headers (the message percent-encoded: a header is ASCII).
  static Map<HttpHeader, String> _flashHeaders(FlashMessage? flash) => {
    if (flash != null) ...{
      const HttpHeader(_stayFlashKind): flash.kind.name,
      const HttpHeader(_stayFlash): Uri.encodeComponent(flash.message),
    },
  };

  /// The action a POST without a key (`POST /login`) runs: `default` (the
  /// page's action of that name), else the page's only one (without
  /// having to name it), else `default` again, which
  /// is a 404 (several actions need `?/name`).
  static String _keylessAction(Map<String, FormAction> actions) =>
      actions.containsKey('default') || actions.length != 1
      ? 'default'
      : actions.keys.single;

  /// The page that asks the question [request] carries (see
  /// [confirmationFor]), or null when it carries none or it was answered.
  Future<ThorResponse?> _unanswered(PageRequest request) async {
    final type = (request.headers['content-type'] ?? '')
        .split(';')
        .first
        .trim()
        .toLowerCase();
    FormData? form;
    if (type == 'application/x-www-form-urlencoded' ||
        type == 'multipart/form-data') {
      try {
        form = await request.form();
      } on HttpError {
        // A body that doesn't read (too big, malformed): the action says so
        // with its own error, as it always did.
        return null;
      }
    }
    final asked = confirmationFor(
      request,
      form,
      _messagesFor(request),
      trustedOrigins: trustedOrigins,
    );
    if (asked != null) _asked[asked] = true;
    return asked;
  }

  /// The pages that ask a question instead of running an action.
  final _asked = Expando<bool>('confirm pages');

  Future<ThorResponse> _render(
    PageRequest request,
    RouteEntry<P> entry,
    ActionResult? result, {
    required bool early,
  }) async {
    final links = _merge(switch (renderer) {
      final EarlyHints hints => [
        for (final l in await hints.linksFor(request, entry.layouts))
          // A page that opted out of prefetch sends no rules.
          if (entry.prefetch || !l.isSpeculationRules) l,
      ],
      _ => const <LinkHint>[],
    }, _learnedFor(request.uri.path, entry));
    final settled = _loadAll(request, [
      ...entry.layouts.map((l) => l.runLoad),
      entry.page.runLoad,
    ], entry.layouts);
    // Data slower than [earlyHintsAfter]: status and headers first, so the
    // browser fetches the stylesheets while the data loads.
    if (early && links.isNotEmpty && request.method == HttpMethod.get) {
      final inTime = await Future.any([
        settled.then((_) => true),
        Future.delayed(earlyHintsAfter, () => false),
      ]);
      if (!inTime) return _early(request, entry, settled, links);
    }
    return _loaded(request, entry, result, await settled, links);
  }

  /// The page (or its error page, or its redirect) once every load of
  /// [entry] has its [outcomes]. [committed]: the status already went out
  /// (see [_early]).
  Future<ThorResponse> _loaded(
    PageRequest request,
    RouteEntry<P> entry,
    ActionResult? result,
    List<Object?> outcomes,
    List<LinkHint> links, {
    bool committed = false,
  }) async {
    final failed = outcomes.whereType<_Failed>().firstOrNull;
    if (failed != null) {
      final e = causeOf(failed.error);
      if (e is Redirect) return _redirect(request, e);
      final level = outcomes.indexOf(failed);
      // A backend outage is reported too; a 404 or a 403 is not a fault.
      if (e is! HttpError || e is UpstreamError) {
        _report(request, e, failed.stack, 'load');
      }
      final data = [for (final o in outcomes.take(level)) (o as _Ok).value];
      return _error(
        request,
        entry.layouts.take(level).toList(),
        data,
        e is HttpError ? e : const HttpError(500),
        null,
        noindex: committed,
      );
    }
    final data = [for (final o in outcomes) (o as _Ok).value];
    request.setLoaded(data);
    final status = result?.status ?? request.response.status ?? 200;
    PageState<Object?> stateAt(int i) => PageState(
      request: request,
      data: data[i],
      form: result?.data,
      status: status,
      levels: data.sublist(0, i + 1),
    );

    final pageState = stateAt(entry.layouts.length);
    var page = entry.page.buildWith(pageState);
    final fromPage = entry.page.forLayoutsWith(pageState);
    PageState<Object?> layoutStateAt(int i) => fromPage.isEmpty
        ? stateAt(i)
        : PageState(
            request: request,
            data: data[i],
            form: result?.data,
            status: status,
            levels: data.sublist(0, i + 1),
            pageValues: fromPage,
          );
    // The nearest template above a level shows that level's title.
    PageMeta metaNow() {
      var meta = const PageMeta();
      String? template;
      for (var i = 0; i <= entry.layouts.length; i++) {
        final level = i < entry.layouts.length
            ? entry.layouts[i].metaWith(stateAt(i))
            : entry.page.metaWith(pageState);
        if (level == null) continue;
        meta = meta.merge(level.templated(template));
        template = level.titleTemplate ?? template;
      }
      return meta;
    }

    var meta = metaNow();
    // web: a head budget that ran out streams a 200 that may be a missing
    // resource, kept out of indexes.
    if (_budgetExpired[request] == true) {
      meta = meta.merge(PageMeta(robotsMeta: _withNoindex(meta.robotsContent)));
    }
    for (var i = entry.layouts.length - 1; i >= 0; i--) {
      page = entry.layouts[i].buildWith(layoutStateAt(i), page);
    }
    // Only a page every visitor sees alike teaches its links to the next
    // request: a visitor's image must never reach another one's header.
    final alike =
        status == 200 &&
        request.method == HttpMethod.get &&
        !request.isPersonal &&
        entry.personalized != true;
    return _document(
      request,
      page,
      meta,
      status,
      links: links,
      learnAs: alike ? (path: request.uri.path, entry: entry) : null,
      queriesOf: entry,
      // The copy a cache keeps is drawn once every future is done: its
      // head reads the values the streamed head could not wait for.
      metaAgain: metaNow,
    );
  }

  /// The answer to a page whose loads outlast [earlyHintsAfter]: `200`,
  /// the headers set so far with the `Link` of [links], and a body whose
  /// first chunk (`<!DOCTYPE html>`, what every document starts with) sends
  /// them; the document follows when [settled] and the render are done.
  /// Then the status can't change: a failed load answers its error page
  /// with `noindex`, a redirect a page that redirects, and a cookie set
  /// after this point is reported (THOR-P010) and never sent.
  ThorResponse _early(
    PageRequest request,
    RouteEntry<P> entry,
    Future<List<Object?>> settled,
    List<LinkHint> links,
  ) {
    final sent = request.response.cookies.length;
    final headers = <HttpHeader, String>{
      HttpHeader.contentType: 'text/html; charset=utf-8',
      HttpHeader.cacheControl: 'no-cache',
      ...request.response.headers,
    };
    _addLinks(headers, links);
    Future<ThorResponse> document() async {
      ThorResponse r;
      try {
        r = await _loaded(
          request,
          entry,
          null,
          await settled,
          links,
          committed: true,
        );
      } catch (e, st) {
        _report(request, e, st, 'build');
        r = await _error(
          request,
          entry.layouts,
          const [],
          const HttpError(500),
          null,
          noindex: true,
        );
      }
      if (request.response.cookies.length > sent) {
        _report(
          request,
          StateError(
            thorError(
              'THOR-P010',
              'a cookie was set after the page answered early (earlyHints): '
                  'set it in a middleware (Group(middleware: [...])), a guard or '
                  'an action',
            ),
          ),
          null,
          'build',
        );
      }
      if (r.status >= 300 && r.status < 400) {
        return ThorResponse(
          200,
          body: utf8.encode(_redirectDocument(r.headers['location'] ?? '/')),
        );
      }
      return r;
    }

    Stream<List<int>> body() async* {
      yield _doctype;
      final r = await document();
      var first = true;
      // A page with late values comes in pieces: the early answer only
      // takes the doctype off the first one.
      await for (final bytes in r.stream ?? Stream.value(r.body)) {
        if (!first) {
          yield bytes;
          continue;
        }
        first = false;
        yield _startsWith(bytes, _doctype)
            ? bytes.sublist(_doctype.length)
            : bytes;
      }
    }

    return _finish(
      request,
      ThorResponse(200, headers: headers, stream: body()),
    );
  }

  /// [robots] with `noindex` in it: a page's own `index` goes, its other
  /// directives (`nofollow`…) stay.
  static RobotsMeta _withNoindex(String? robots) =>
      RobotsMeta.parse(robots).copyWith(index: false);

  static final _doctype = utf8.encode('<!DOCTYPE html>');

  static bool _startsWith(List<int> bytes, List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }

  /// What a redirect becomes once the status went out: a page that goes to
  /// [location] (with and without JS), never indexed.
  static String _redirectDocument(String location) {
    final to = const HtmlEscape(HtmlEscapeMode.attribute).convert(location);
    return '<!DOCTYPE html><html><head><meta name="robots" content="noindex">'
        '<meta http-equiv="refresh" content="0;url=$to"></head>'
        '<body><a href="$to">$to</a></body></html>';
  }

  // Path → what its last render found (DiscoveredLinks), for the next
  // request of that path. Insertion-ordered: the oldest path goes first.
  final _learned = <String, List<LinkHint>>{};

  // Route pattern (`/article/[slug]`) → what every path of it rendered so
  // far found alike. A pattern teaches its other paths only once two
  // different paths agreed: an image that depends on the parameter (the
  // article's own cover) differs between them and never spreads.
  final _learnedByPattern = <String, _PatternLinks>{};
  static const _learnedMax = 256;

  List<LinkHint> _learnedFor(String path, RouteEntry<P> entry) {
    final exact = _learned[path] ?? const <LinkHint>[];
    if (entry.isStatic) return exact;
    final shared = _learnedByPattern[entry.pattern];
    if (shared == null || !shared.confirmed) return exact;
    return _merge(exact, shared.links);
  }

  void _learn(({String path, RouteEntry<P> entry}) at, List<LinkHint> found) {
    _remember(_learned, at.path, found);
    if (at.entry.isStatic) return;
    final key = at.entry.pattern;
    final before = _learnedByPattern.remove(key);
    final next = before == null
        ? _PatternLinks(at.path, found, confirmed: false)
        : before.after(at.path, found);
    if (next.links.isEmpty && next.confirmed) return;
    if (_learnedByPattern.length >= _learnedMax) {
      _learnedByPattern.remove(_learnedByPattern.keys.first);
    }
    _learnedByPattern[key] = next;
  }

  static void _remember(
    Map<String, List<LinkHint>> map,
    String key,
    List<LinkHint> found,
  ) {
    map.remove(key);
    if (found.isEmpty) return;
    if (map.length >= _learnedMax) map.remove(map.keys.first);
    map[key] = found;
  }

  /// [a] then what of [b] isn't in it (same header entry).
  static List<LinkHint> _merge(List<LinkHint> a, List<LinkHint> b) {
    if (b.isEmpty) return a;
    final seen = {for (final l in a) l.header};
    return [
      ...a,
      for (final l in b)
        if (seen.add(l.header)) l,
    ];
  }

  /// Adds `links` to the `Link` header of [headers] (after the app's own); the
  /// speculation rules go in their own header.
  static void _addLinks(Map<HttpHeader, String> headers, List<LinkHint> all) {
    if (all.isEmpty) return;
    final rules = all.where((l) => l.isSpeculationRules).toList();
    if (rules.isNotEmpty) {
      // A structured list of strings: the URLs of the rules files.
      headers[const HttpHeader('speculation-rules')] = rules
          .map((l) => l.header)
          .join(', ');
    }
    final links = all.where((l) => !l.isSpeculationRules).toList();
    if (links.isEmpty) return;
    final key = headers.keys.firstWhere(
      (k) => k.toLowerCase() == 'link',
      orElse: () => HttpHeader.link,
    );
    final current = headers[key];
    final have = current == null || current.trim().isEmpty ? '' : current;
    // A reverse proxy reads all the response headers into one small buffer
    // (nginx: 4 or 8 KB): a `Link` of tens of KB (many fonts) turns every page
    // into a 502. The hints are in priority order (styles, fonts, the app's):
    // the ones that do not fit in the budget are left out, whole.
    final value = StringBuffer();
    var size = have.length;
    for (final l in links) {
      final h = l.header;
      final next = size + h.length + (size == 0 ? 0 : 2);
      if (next > linkHeaderBudget) continue;
      if (value.isNotEmpty) value.write(', ');
      value.write(h);
      size = next;
    }
    if (value.isEmpty) return;
    headers[key] = have.isEmpty ? '$value' : '$have, $value';
  }

  /// Most bytes of the `Link` header the server builds from hints.
  static const linkHeaderBudget = 2000;

  /// The error page inside the deepest [layouts] level that has one (all
  /// of whose data is in [data]), or the renderer's plain error page.
  Future<ThorResponse> _error(
    PageRequest request,
    List<LayoutRoute<P, Object?>> layouts,
    List<Object?> data,
    HttpError error,
    LayoutRoute<P, Object?>? fallbackLayout, {
    bool noindex = false,
  }) async {
    final status = error.status;
    if (error is TooManyRequests) {
      request.response.headers[HttpHeader.retryAfter] =
          '${error.retryAfterSeconds}';
    }
    // After an early answer the status is 200: robots must not keep it.
    var meta = PageMeta(
      title: '$status',
      robotsMeta: noindex ? RobotsMeta.noindex : null,
    );
    final state = ErrorState(
      request: request,
      status: status,
      message: status >= 500 ? 'Internal error' : error.message,
    );
    var chain = layouts;
    var chainData = data;
    // An unmatched URL (or a failed first load) still gets the root layout
    // when its own data loads.
    if (chain.isEmpty && fallbackLayout != null) {
      try {
        await onRequest?.call(request);
        chainData = [await fallbackLayout.runLoad(request)];
        chain = [fallbackLayout];
      } catch (_) {
        chain = const [];
      }
    }
    if (chainData.length < chain.length) {
      // Only layouts whose data loaded can wrap the error.
      chain = chain.take(chainData.length).toList();
    }
    // The deepest level with a page for it: its `notFound` for a 404,
    // else its `error`.
    bool handles(LayoutRoute<P, Object?> l) =>
        l.error != null || (status == 404 && l.notFound != null);
    var level = chain.length - 1;
    while (level >= 0 && !handles(chain[level])) {
      level--;
    }
    try {
      if (level < 0) {
        return _document(request, renderer.errorPage(state), meta, status);
      }
      PageState<Object?> stateAt(int i) => PageState(
        request: request,
        data: chainData[i],
        status: status,
        levels: chainData.sublist(0, i + 1),
      );
      final at = chain[level];
      final isNotFound = status == 404 && at.notFound != null;
      // The page's own `<head>` (a title that says what failed) over the
      // default one; a `noindex` after an early answer stays.
      final own = (isNotFound ? at.notFoundMeta : at.errorMeta)?.call(state);
      if (own != null) {
        meta = meta.merge(own);
        if (noindex) {
          meta = meta.merge(
            PageMeta(robotsMeta: _withNoindex(own.robotsContent)),
          );
        }
      }
      var page = isNotFound ? at.notFound!(state) : at.error!(state);
      for (var i = level; i >= 0; i--) {
        page = chain[i].buildWith(stateAt(i), page);
      }
      return _document(request, page, meta, status);
    } catch (e, st) {
      _report(request, e, st, 'error page');
      return _plain(status, status == 404 ? 'Not found' : 'Internal error');
    }
  }

  Future<ThorResponse> _document(
    PageRequest request,
    P page,
    PageMeta meta,
    int status, {
    List<LinkHint> links = const [],
    ({String path, RouteEntry<P> entry})? learnAs,
    RouteEntry<P>? queriesOf,
    PageMeta Function()? metaAgain,
  }) async {
    final stream =
        status == 200 &&
        request.method == HttpMethod.get &&
        _settled[request] != true &&
        renderer is DeferredRender;
    // A value that failed: the page drew its error state, not worth keeping.
    var deferredFailed = false;
    final context = RenderContext(
      request: request,
      meta: meta,
      status: status,
      stream: stream,
      deferTimeout: deferTimeout,
      cspNonceToken: request.cspNonce == null ? null : cspNonceToken,
      reportDeferred: (e, st) {
        deferredFailed = true;
        if (e is HttpError && e is! UpstreamError) return;
        _report(request, e, st, 'defer');
      },
      devWarning: ThorDev.enabled
          ? (message) => ThorDev.errorSink(
              '[thor] warning ${request.method} ${request.uri.path}: '
              '$message',
            )
          : null,
    );
    final List<int> html;
    try {
      html = await renderer.render(page, context);
    } on HttpError catch (e, st) {
      // What a `LazyPiece`'s load throws (`NotFound`, a `403`) answers its
      // fragment's request with that status; the browser keeps its fallback.
      if (e is UpstreamError) _report(request, e, st, 'render');
      return _finish(
        request,
        _plain(e.status, e.message ?? 'Error ${e.status}'),
      );
    }
    final late = stream ? (renderer as DeferredRender).lateOf(context) : null;
    if (renderer case final ServerQueries queries) {
      final used = queries.queriesFound(context);
      if (queriesOf != null && used.isNotEmpty) {
        (_queriesOf[queriesOf] ??= {}).addAll(used);
      }
      for (final (e, st) in queries.queryErrorsFound(context)) {
        if (e is HttpError && e is! UpstreamError) continue;
        _report(request, e, st, 'query');
      }
    }
    final found = switch (renderer) {
      final DiscoveredLinks d => d.linksFound(context),
      _ => const <LinkHint>[],
    };
    if (learnAs != null) _learn(learnAs, found);
    // What the page read while it drew (a cookie the visitor sent, a
    // context value a load set) can make it the visitor's after the cache
    // lookup: say so, as the lookup does for what it already knew.
    if (request.isPersonal) {
      _putIfAbsent(
        request.response.headers,
        'cache-control',
        'private, no-cache',
      );
    }
    final headers = <HttpHeader, String>{
      HttpHeader.contentType: 'text/html; charset=utf-8',
      HttpHeader.cacheControl: 'no-cache',
      ...request.response.headers,
    };
    _addLinks(headers, _merge(links, found));
    if (late != null) {
      // The body is not known yet: no `ETag`, no `Content-Length`. A proxy
      // that buffers would hold the page until the end: say it must not.
      headers[const HttpHeader('x-accel-buffering')] = 'no';
      final tee = _cacheTee[request];
      return _finish(
        request,
        ThorResponse(
          status,
          headers: headers,
          stream: _joined(
            html,
            late,
            after: tee == null
                ? null
                : () async {
                    if (deferredFailed) return;
                    // Every value is out and its future is done: drawing
                    // the page complete asks nothing of the backend again.
                    try {
                      final complete = await renderer.render(
                        page,
                        RenderContext(
                          request: request,
                          meta: metaAgain?.call() ?? meta,
                          status: status,
                          stream: false,
                          deferTimeout: deferTimeout,
                          cspNonceToken: context.cspNonceToken,
                        ),
                      );
                      final done = <HttpHeader, String>{
                        ...headers,
                        HttpHeader.etag: etagOf(complete),
                      }..remove('x-accel-buffering');
                      tee(
                        _finish(
                          request,
                          ThorResponse(status, headers: done, body: complete),
                        ),
                      );
                    } catch (e, st) {
                      // The page was sent: a failed copy is not the visitor's.
                      _report(request, e, st, 'render');
                    }
                  },
          ),
        ),
      );
    }
    if (status == 200 &&
        request.method.isRead &&
        request.response.cookies.isEmpty &&
        _header(headers, 'etag') == null &&
        !(_header(headers, 'cache-control')?.contains('no-store') ?? false)) {
      headers[HttpHeader.etag] = etagOf(html);
    }
    return _finish(request, ThorResponse(status, headers: headers, body: html));
  }

  /// [first], then [late]. A failure of the late pieces ends the document
  /// (reported by the renderer): the browser gets what was sent.
  ///
  /// [after] runs once the last piece is out (not when the client left).
  static Stream<List<int>> _joined(
    List<int> first,
    Stream<List<int>> late, {
    Future<void> Function()? after,
  }) async* {
    yield first;
    yield* late;
    if (after != null) await after();
  }

  /// A `304 Not Modified` when [request]'s `If-None-Match` matches the
  /// `ETag` of [r] (a `200` to a `GET` or `HEAD`, no cookies); [r]
  /// otherwise.
  static ThorResponse _conditional(PageRequest request, ThorResponse r) {
    if (r.status != 200 || r.cookies.isNotEmpty || !request.method.isRead) {
      return r;
    }
    final etag = _header(r.headers, 'etag');
    final ifNoneMatch = request.headers['if-none-match'];
    if (etag == null || ifNoneMatch == null) return r;
    final matched = matchIfNoneMatch(ifNoneMatch, etag);
    if (matched == null) return r;
    return ThorResponse(
      304,
      headers: {
        // What a 200 would say about caching (Cache-Control, Vary…), but
        // no representation metadata (RFC 9110 §15.4.5).
        for (final MapEntry(:key, :value) in r.headers.entries)
          if (!const {
            'content-type',
            'content-length',
            'content-encoding',
            'etag',
          }.contains(key.toLowerCase()))
            key: value,
        // The tag the client holds (`W/` or not): its stored copy is valid.
        HttpHeader.etag: matched,
      },
    );
  }

  /// Adds [names] to the `Vary` of [headers] (whatever its spelling).
  static void _addVary(Map<HttpHeader, String> headers, String names) {
    final key = headers.keys.firstWhere(
      (k) => k.toLowerCase() == 'vary',
      orElse: () => HttpHeader.vary,
    );
    final current = headers[key];
    if (current == null || current.trim().isEmpty) {
      headers[key] = names;
      return;
    }
    final have = current.toLowerCase().split(',').map((v) => v.trim());
    final missing = [
      for (final n in names.split(','))
        if (!have.contains(n.trim().toLowerCase())) n.trim(),
    ];
    if (missing.isNotEmpty) headers[key] = '$current, ${missing.join(', ')}';
  }

  /// Sets [name] unless [headers] has it (whatever its case).
  static void _putIfAbsent(
    Map<HttpHeader, String> headers,
    String name,
    String value,
  ) {
    if (_header(headers, name) == null) headers[HttpHeader(name)] = value;
  }

  static String? _header(Map<HttpHeader, String> headers, String name) {
    final exact = headers[name];
    if (exact != null) return exact;
    for (final MapEntry(:key, :value) in headers.entries) {
      if (key.toLowerCase() == name) return value;
    }
    return null;
  }

  ThorResponse _redirect(PageRequest request, Redirect r) {
    // A `Form(stay: true)`: the redirect back to the page the form is on is
    // not followed (the page stays), and its flash does not wait for a next
    // page: it comes in headers. A redirect anywhere else is a `200` with
    // the place to go; its flash rides the cookie as usual.
    if (request.headers.containsKey(_stayHeader)) {
      final target = safeLocation(r.location);
      final to = Uri.tryParse(target);
      final here =
          to != null &&
          !to.hasScheme &&
          !to.hasAuthority &&
          _noSlash(to.path.isEmpty ? request.uri.path : to.path) ==
              _noSlash(request.uri.path);
      if (here) {
        return _finish(
          request,
          ThorResponse(
            200,
            headers: {
              const HttpHeader(_stayHeader): '1',
              HttpHeader.cacheControl: 'no-store',
              ..._flashHeaders(r.flashMessage),
            },
          ),
        );
      }
      if (r.flashMessage case final flash?) {
        request.response.setCookie(
          flashCookie,
          flash.cookieValue,
          maxAge: flashLifetime,
        );
      }
      return _finish(
        request,
        ThorResponse(
          200,
          headers: {
            const HttpHeader(_stayHeader): '1',
            const HttpHeader(_uploadLocation): target,
            HttpHeader.cacheControl: 'no-store',
          },
        ),
      );
    }
    // A flash rides to the next page that draws: this response is not it.
    if (r.flashMessage case final flash?) {
      request.response.setCookie(
        flashCookie,
        flash.cookieValue,
        maxAge: flashLifetime,
      );
    }
    final target = safeLocation(r.location);
    // The tab that posted left its mark in a cookie; the landing page of that
    // tab (and no other) resets when it reads it back. The script reads it
    // (so not `HttpOnly`) and removes it; a value that is not a mark (a
    // forged cookie) is not echoed.
    final tab = request.frameworkCookies[scrollTabCookie];
    if (r.resetScroll && tab != null && _tabMark.hasMatch(tab)) {
      request.response.setCookie(
        scrollResetCookie,
        tab,
        maxAge: const Duration(seconds: 20),
        httpOnly: false,
      );
    }
    return _finish(
      request,
      ThorResponse(
        // A status that is not a redirect (200, 399, 1000) would send a
        // `Location` the browser ignores, or a broken status line.
        const {301, 302, 303, 307, 308}.contains(r.status) ? r.status : 303,
        headers: {HttpHeader.location: target, ...request.response.headers},
      ),
    );
  }

  static String _noSlash(String path) => path.length > 1 && path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;

  static final _tabMark = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  /// `Clear-Site-Data` types that drop the pages the browser fetched or
  /// rendered ahead, nothing else (no cookies, no HTTP cache).
  static const _clearSpeculationsValue = '"prefetchCache", "prerenderCache"';

  static ThorResponse _clearSpeculations(ThorResponse r) {
    final headers = {...r.headers};
    final key = headers.keys.firstWhere(
      (k) => k.toLowerCase() == 'clear-site-data',
      orElse: () => const HttpHeader('clear-site-data'),
    );
    final current = headers[key];
    headers[key] = current == null || current.trim().isEmpty
        ? _clearSpeculationsValue
        : current.contains('"*"') || current.contains('prefetchCache')
        ? current
        : '$current, $_clearSpeculationsValue';
    return ThorResponse(
      r.status,
      headers: headers,
      body: r.body,
      stream: r.stream,
      cookies: r.cookies,
    ).._bytesFrom = r;
  }

  ThorResponse _finish(PageRequest request, ThorResponse r) => ThorResponse(
    r.status,
    headers: r.headers,
    body: r.body,
    stream: r.stream,
    cookies: [
      for (final c in request.response.cookies)
        c.toHeader(secureByDefault: _secure(request)),
    ],
  ).._bytesFrom = r;

  static ThorResponse _plain(
    int status,
    String text, [
    Map<HttpHeader, String> headers = const {},
  ]) => ThorResponse(
    status,
    headers: {HttpHeader.contentType: 'text/plain; charset=utf-8', ...headers},
    body: utf8.encode(text),
  );

  /// Forms may only be posted from the site itself (CSRF): the browser's
  /// `Origin` must be this host's (or a trusted one).
  /// A query call comes from the site's own pages: an `Origin` of this
  /// host (or a trusted one) always, JSON, and the `x-thor-query` header
  /// (a custom header: another origin can't send it without a CORS
  /// preflight no route of thor answers).
  bool _sameOriginQuery(PageRequest request) {
    final origin = request.headers['origin'];
    final type = request.headers['content-type'] ?? '';
    if (origin == null || !type.toLowerCase().startsWith('application/json')) {
      return false;
    }
    return _ownOrigin(request, origin);
  }

  /// Whether [origin] (the request's `Origin`) is this site's or a trusted
  /// one. `Sec-Fetch-Site: cross-site` next to the site's own origin is a
  /// forgery (a browser never sends that pair: the site's host is always
  /// same-site), so it is refused; a trusted origin may be cross-site.
  bool _ownOrigin(PageRequest request, String origin) {
    if (trustedOrigins.contains(origin)) return true;
    final host = request.headers['host'];
    final o = Uri.tryParse(origin);
    if (o == null || host == null || !o.hasAuthority || o.authority != host) {
      return false;
    }
    return request.headers['sec-fetch-site']?.toLowerCase() != 'cross-site';
  }

  /// Whether the browser asks for the page ahead of a visit (speculation
  /// rules, `<link rel=prefetch>`): `Sec-Purpose: prefetch` or `prerender`.
  static bool _prefetching(PageRequest request) {
    // `Purpose` and `X-moz` are what older Chrome and Firefox send.
    final purpose =
        '${request.headers['sec-purpose']} ${request.headers['purpose']} '
                '${request.headers['x-moz']}'
            .toLowerCase();
    return purpose.contains('prefetch') || purpose.contains('prerender');
  }

  bool _sameOrigin(PageRequest request) {
    final origin = request.headers['origin'];
    if (origin == null) {
      // Non-browser clients (no Origin) only when they don't send a form.
      final type = (request.headers['content-type'] ?? '').toLowerCase();
      return !(type.startsWith('application/x-www-form-urlencoded') ||
          type.startsWith('multipart/form-data') ||
          type.startsWith('text/plain'));
    }
    return _ownOrigin(request, origin);
  }

  static RouteUrl _withoutAction(Uri uri) {
    final query = queryWithoutAction(uri.query);
    final path = sitePath(uri.path);
    return RouteUrl(query.isEmpty ? path : '$path?$query');
  }

  static bool _cacheable(ThorResponse r) =>
      r.status == 200 && r.cookies.isEmpty;

  /// What [onError] is when the app does not set one: the exception and its
  /// stack on stderr.
  static const onErrorDefault = _printError;

  static void _printError(
    PageRequest request,
    Object error,
    StackTrace? stack,
  ) {
    stderr.writeln('[thor] ${request.method} ${request.uri.path}: $error');
    if (stack != null) stderr.writeln(stack);
  }
}

/// A strong entity tag for [body]: `"<length>-<hash>"`, both base 16.
///
/// The hash is a 64-bit multiply-xorshift over 8-byte words, in two
/// lanes (even and odd words) so the multiplications don't wait on each
/// other (~2 µs for 22 KB, far cheaper than SHA-1: it runs on every
/// uncached render). Each step, and the final mix of the lanes, is a
/// bijection of one lane, so bodies of the same length that differ in a
/// single word always get different tags; it is a validator, not a
/// signature (a visitor can only fool their own cache).
String etagOf(List<int> body) {
  final bytes = body is Uint8List ? body : Uint8List.fromList(body);
  final data = ByteData.sublistView(bytes);
  final pairs = bytes.length >> 4;
  // 0x27d4eb2f165667c5 and 0x9e3779b97f4a7c15, written so dart2js's front
  // end accepts the library (thor_ui imports it into a dart2js oracle
  // build; the browser never runs this).
  var a = (0x27d4eb2f << 32 | 0x165667c5) ^ bytes.length;
  var b = (0x9e3779b9 << 32 | 0x7f4a7c15) ^ bytes.length;
  for (var i = 0; i < pairs; i++) {
    final at = i << 4;
    a = (a ^ data.getUint64(at, Endian.little)) * 0x100000001b3;
    b = (b ^ data.getUint64(at + 8, Endian.little)) * 0x100000001b3;
    a ^= a >>> 32;
    b ^= b >>> 32;
  }
  var h = (a ^ b * 0x100000001b3) * 0x100000001b3;
  for (var i = pairs << 4; i < bytes.length; i++) {
    h = (h ^ bytes[i]) * 0x100000001b3;
    h ^= h >>> 32;
  }
  String hex(int v) => v.toRadixString(16).padLeft(8, '0');
  return '"${bytes.length.toRadixString(16)}-${hex(h >>> 32)}${hex(h & 0xffffffff)}"';
}

/// The entity tag of [ifNoneMatch] (`*`, or a list of tags) that matches
/// [etag] under the weak comparison `If-None-Match` uses (RFC 9110
/// §13.1.2: `W/"x"` matches `"x"`), or `null`. For `*`, [etag] itself.
String? matchIfNoneMatch(String ifNoneMatch, String etag) {
  if (ifNoneMatch.trim() == '*') return etag;
  final opaque = etag.startsWith('W/') ? etag.substring(2) : etag;
  for (final m in _entityTag.allMatches(ifNoneMatch)) {
    if (m.group(2) == opaque) return m.group(0);
  }
  return null;
}

final _entityTag = RegExp(r'(W/)?("[^"]*")');

/// The layouts above one level, and the loads of every level.
final class _LoadScope implements LoadScope {
  _LoadScope(this.layouts, this.futures);

  final List<LayoutRoute<Object?, Object?>> layouts;
  final List<Future<Object?>> futures;

  @override
  Future<D> parent<D>() async {
    for (var i = layouts.length - 1; i >= 0; i--) {
      if (layouts[i].loads<D>()) return await futures[i] as D;
    }
    for (var i = layouts.length - 1; i >= 0; i--) {
      if (!layouts[i].loadsUntyped) continue;
      final value = await futures[i];
      if (value is D) return value;
    }
    final loaded = [
      for (final l in layouts)
        if (l.load != null) '${l.dataType}',
    ];
    throw StateError(
      thorError(
        'THOR-P006',
        'parent<$D>(): no layout above this route loads a $D '
            '(${loaded.isEmpty ? 'no layout above has a load' : 'they load ${loaded.join(', ')}'})',
      ),
    );
  }
}

/// The bots that read the `<head>` of the document and don't run
/// JavaScript, so a title or a status that arrives later is lost to them
/// (the list other frameworks use to block the render for them).
final _htmlBots = RegExp(
  r'[\w-]-Google|Google-[\w-]|Chrome-Lighthouse|Slurp|DuckDuckBot|'
  r'baiduspider|yandex|sogou|bitlybot|tumblr|vkShare|quora link preview|'
  r'redditbot|ia_archiver|Bingbot|BingPreview|applebot|facebookexternalhit|'
  r'facebookcatalog|Twitterbot|LinkedInBot|Slackbot|Discordbot|WhatsApp|'
  r'SkypeUriPreview|Yeti|googleweblight',
  caseSensitive: false,
);

/// Zone key of the `void Function(Future, Duration)` a `load` marks the
/// futures its head needs with (internal: `defer(head: true)` of thor_ui
/// reads it, the handler sets it).
const headWaitKey = #thor.headWait;

final class _Ok {
  const _Ok(this.value);
  final Object? value;
}

final class _Failed {
  const _Failed(this.error, this.stack);
  final Object error;
  final StackTrace stack;
}

class _Cached {
  _Cached(this.response, this.tags, this.pinned, this.fits)
    : at = DateTime.now();
  final ThorResponse response;
  final List<String> tags;

  /// Whether the page fits a request: it lacks the cookies the page asked
  /// for and did not find.
  final bool Function(PageRequest request) fits;

  /// Tagged and not cleared by a write (`PageRoute.invalidateOnWrite`).
  final bool pinned;
  final DateTime at;
  bool refreshing = false;
  Duration get age => DateTime.now().difference(at);
}

/// Drops the cached pages that declare [tag] (`PageRoute.tags`,
/// `ThorPage(tags:)`) in every isolate of the server: call it from an
/// action or a command after the data those pages show changed.
///
/// ```dart
/// Future<ActionResult?> add(PageRequest request) async {
///   await cart.add(item);
///   revalidateTag('cart'); // `CartPage(tags: ['cart'])` renders again
///   return null;
/// }
/// ```
///
/// Tags add this way to revalidate; a successful write still clears every page
/// (a page with `invalidateOnWrite: false` only waits for its tag or its
/// `cache` time). A cache in front of the server (a CDN) needs its own purge.
void revalidateTag(String tag) => CacheBus.revalidate([tag]);

/// What the paths of one route pattern found alike: [links] are those every
/// path rendered so far agreed on; [confirmed] once a second path did.
class _PatternLinks {
  const _PatternLinks(this.firstPath, this.links, {required this.confirmed});

  final String firstPath;
  final List<LinkHint> links;
  final bool confirmed;

  /// After [path] rendered and found [found].
  _PatternLinks after(String path, List<LinkHint> found) {
    // The same path again, before a second one agreed: it just renews.
    if (!confirmed && path == firstPath) {
      return _PatternLinks(path, found, confirmed: false);
    }
    final kept = {for (final l in found) l.header};
    return _PatternLinks(firstPath, [
      for (final l in links)
        if (kept.contains(l.header)) l,
    ], confirmed: true);
  }
}

/// What made [error] fail: for the error of calls awaited together
/// (`(a, b).wait`, `[a, b].wait`, a `ParallelWaitError`), a [Redirect]
/// first, then an [HttpError], then the first error; anything else is its
/// own cause.
Object causeOf(Object error) {
  if (error is! ParallelWaitError) return error;
  final causes = [
    for (final f in _fields(error.errors))
      if (f case AsyncError(:final error)) error else ?f,
  ];
  return causes.whereType<Redirect>().firstOrNull ??
      causes.whereType<HttpError>().firstOrNull ??
      causes.firstOrNull ??
      error;
}

/// The values of a list or of a record of up to nine positional fields
/// (the shapes `.wait` fails with).
Iterable<Object?> _fields(Object? v) => switch (v) {
  final Iterable<Object?> list => list,
  (final a, final b) => [a, b],
  (final a, final b, final c) => [a, b, c],
  (final a, final b, final c, final d) => [a, b, c, d],
  (final a, final b, final c, final d, final e) => [a, b, c, d, e],
  (final a, final b, final c, final d, final e, final f) => [a, b, c, d, e, f],
  (final a, final b, final c, final d, final e, final f, final g) => [
    a,
    b,
    c,
    d,
    e,
    f,
    g,
  ],
  (final a, final b, final c, final d, final e, final f, final g, final h) => [
    a,
    b,
    c,
    d,
    e,
    f,
    g,
    h,
  ],
  (
    final a,
    final b,
    final c,
    final d,
    final e,
    final f,
    final g,
    final h,
    final i,
  ) =>
    [a, b, c, d, e, f, g, h, i],
  _ => const [],
};

/// How long a mark in `_missingOf` lasts, and so how often one visitor's
/// call for an id its page doesn't show draws the route again. Not exported:
/// tests shorten it.
Duration learnWindow = const Duration(seconds: 10);

/// The (id, visitor) pairs a route was drawn for without finding the id,
/// each for [learnWindow].
class _Missing {
  static final _clock = Stopwatch()..start();
  final _until = <(String, int), int>{};

  /// The drawing in flight for each visitor: calls that arrive meanwhile
  /// wait for it instead of being refused (it may teach them their id).
  final drawing = <int, Future<void>>{};

  /// Marks the pair. `false` when it is already marked, or when the route
  /// has as many live marks as it may draw for.
  bool mark(String id, int visitor) {
    final now = _clock.elapsedMilliseconds;
    _until.removeWhere((_, until) => until <= now);
    if (_until.containsKey((id, visitor))) return false;
    if (_until.length >= RouteHandler._learnLimit) return false;
    _until[(id, visitor)] = now + learnWindow.inMilliseconds;
    return true;
  }

  void unmark(String id, int visitor) => _until.remove((id, visitor));
}
