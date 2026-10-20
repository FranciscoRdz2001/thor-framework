import 'dart:async';

import 'errors.dart';
import 'handler.dart' show ThorResponse;
import 'http_types.dart';
import 'results.dart';
import 'route_url.dart';
import 'routes.dart';

/// [middleware] with [name]: what an error names when it throws (THOR-P016).
/// A top-level function is named already (`requireUser`); a middleware a
/// function returns (`requireRole('admin')`) is a closure without one:
///
/// ```dart
/// Middleware requireRole(String role) => namedMiddleware(
///   'requireRole($role)',
///   (request, next) { … },
/// );
/// ```
Middleware namedMiddleware(String name, Middleware middleware) {
  _names[middleware] = name;
  return middleware;
}

final _names = Expando<String>('thor middleware name');

/// The name of [middleware]: given with [namedMiddleware], else the name
/// of a top-level or static function (`requireUser`), else null.
String? middlewareName(Middleware middleware) =>
    _names[middleware] ??
    RegExp(r"from Function '([^'@]+)").firstMatch('$middleware')?[1];

/// A middleware of a list threw: which one, and what ([error]).
final class MiddlewareError extends Error {
  /// [error] from the middleware at [position] (from 1) of [owner].
  MiddlewareError({
    required this.name,
    required this.position,
    required this.count,
    required this.owner,
    required this.error,
  });

  /// Its function's name, or null (a closure without [namedMiddleware]).
  final String? name;

  /// Its place in the list, from 1.
  final int position;

  /// How many the list has.
  final int count;

  /// Where the list is (`Group(layout: AppLayout)`, `ThorRoute('/admin')`).
  final String owner;

  /// What it threw.
  final Object error;

  @override
  String toString() => thorError(
    'THOR-P016',
    'middleware ${name == null ? '#$position' : '`$name`'} ($position of '
        '$count in $owner) threw: $error',
  );
}

/// One [Middleware] that runs [list] left to right, each one's `next` the
/// one after it (the last one's, [Next] of the whole). Built once, when the
/// route table is: a request pays one call per middleware and nothing else.
///
/// An error a middleware throws itself (not one from below its `next()`,
/// and not a [Redirect] or an [HttpError], which end the request as usual)
/// becomes a [MiddlewareError] naming it, at [owner], with its stack; so
/// does calling `next()` twice (THOR-P004).
Middleware? chainMiddleware(List<Middleware> list, {required String owner}) {
  if (list.isEmpty) return null;
  Middleware link(int i) {
    final middleware = list[i];
    final rest = i + 1 < list.length ? link(i + 1) : null;
    return (request, next) async {
      var called = false;
      try {
        return await middleware(request, () {
          if (called) {
            throw StateError(
              thorError(
                'THOR-P004',
                'next() called twice: call it once and keep its response',
              ),
            );
          }
          called = true;
          final below = rest == null
              ? next()
              : Future.sync(() => rest(request, next));
          // What fails below keeps its own type and name: marked on the
          // way up, so this middleware lets it through.
          return below.catchError((Object e, StackTrace st) {
            _markBelow(e);
            Error.throwWithStackTrace(e, st);
          });
        });
      } on Redirect {
        rethrow;
      } on HttpError {
        rethrow;
      } on MiddlewareError {
        rethrow;
      } catch (e, st) {
        if (_isBelow(e)) rethrow;
        Error.throwWithStackTrace(
          MiddlewareError(
            name: middlewareName(middleware),
            position: i + 1,
            count: list.length,
            owner: owner,
            error: e,
          ),
          st,
        );
      }
    };
  }

  return link(0);
}

final _fromBelow = Expando<bool>('thor error from below a middleware');

// A string or a number can't be marked: it is taken as this middleware's.
void _markBelow(Object e) {
  try {
    _fromBelow[e] = true;
  } on ArgumentError {
    // Not markable.
  }
}

bool _isBelow(Object e) {
  try {
    return _fromBelow[e] ?? false;
  } on ArgumentError {
    return false;
  }
}

/// Headers most pages should carry, added to every response below that
/// doesn't set its own: `X-Content-Type-Options: nosniff`, a
/// `Referrer-Policy`, `X-Frame-Options` and `Cross-Origin-Opener-Policy`
/// against framing and window handles, a `Permissions-Policy` that turns
/// off the camera, microphone and location, and, with [hsts], HTTPS only
/// for that long. A null argument leaves that header out.
///
/// The arguments are the header values as text; [SecurityHeaders] takes the
/// same choices as enums (`SecurityHeaders(frameOptions: FrameOptions.deny)`)
/// and its [SecurityHeaders.middleware] is this middleware.
///
/// A page that must be framed by another origin (an editor embedding the
/// app) lists it in [frameAncestors]: see [frameAncestorsPolicy]. Without
/// it, nobody frames the page.
///
/// ```dart
/// Group(middleware: [securityHeaders(hsts: const Duration(days: 365))], …)
/// ```
Middleware securityHeaders({
  String? frameOptions = 'DENY',
  String? referrerPolicy = 'strict-origin-when-cross-origin',
  String? openerPolicy = 'same-origin',
  String? permissionsPolicy = 'camera=(), microphone=(), geolocation=()',
  Duration? hsts,
  List<String> frameAncestors = const [],
}) => _headersMiddleware({
  HttpHeader.xContentTypeOptions: 'nosniff',
  if (frameAncestors.isEmpty)
    HttpHeader.xFrameOptions: ?frameOptions
  else
    HttpHeader.contentSecurityPolicy: frameAncestorsPolicy(frameAncestors),
  HttpHeader.referrerPolicy: ?referrerPolicy,
  const HttpHeader('cross-origin-opener-policy'): ?openerPolicy,
  const HttpHeader('permissions-policy'): ?permissionsPolicy,
  if (hsts != null)
    HttpHeader.strictTransportSecurity:
        'max-age=${hsts.inSeconds}; includeSubDomains',
});

/// The `Content-Security-Policy` that lets only the page's own origin and
/// [origins] put it in a frame: `frame-ancestors 'self' https://editor.example`.
/// `X-Frame-Options` can only say nobody or the same origin, so a page framed
/// by another origin carries this instead.
///
/// Each of [origins] is a plain `http` or `https` origin (`scheme://host`,
/// with a port when it is not the default). A path, query, credentials, a
/// wildcard (`*`, `https://*.example.com`), another scheme or anything that
/// would add a directive is an [ArgumentError]: framing is allowed per
/// origin, never by pattern. An empty list is an [ArgumentError] too (no
/// origins means no framing: leave the argument out).
String frameAncestorsPolicy(Iterable<String> origins) {
  final list = origins.toList();
  if (list.isEmpty) {
    throw ArgumentError.value(
      list,
      'frameAncestors',
      'is empty: leave it out to allow no framing',
    );
  }
  return "frame-ancestors 'self' ${list.map(_frameOrigin).toSet().join(' ')}";
}

String _frameOrigin(String origin) {
  final uri = Uri.tryParse(origin.trim());
  final ok =
      uri != null &&
      !RegExp(r'''[\s;,*'"]''').hasMatch(origin.trim()) &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      (uri.path.isEmpty || uri.path == '/') &&
      !uri.hasQuery &&
      !uri.hasFragment;
  if (!ok) {
    throw ArgumentError.value(
      origin,
      'frameAncestors',
      'is not an origin (`https://editor.example`, `http://localhost:4700`): '
          'no path, wildcard or other characters',
    );
  }
  return uri.origin;
}

Middleware _headersMiddleware(Map<HttpHeader, String> headers) {
  final config = SecurityHeaders._(headers);
  return namedMiddleware(
    'securityHeaders',
    (request, next) async => config.apply(await next()),
  );
}

/// `X-Frame-Options`: who may put the page in a frame.
enum FrameOptions {
  /// Nobody.
  deny('DENY'),

  /// Pages of the same origin.
  sameOrigin('SAMEORIGIN');

  const FrameOptions(this.value);

  /// The header value.
  final String value;
}

/// `Referrer-Policy`: how much of the page's URL a request leaves in
/// `Referer`.
enum ReferrerPolicy {
  /// Never.
  noReferrer('no-referrer'),

  /// Not from `https` to `http`.
  noReferrerWhenDowngrade('no-referrer-when-downgrade'),

  /// Only the origin.
  origin('origin'),

  /// The whole URL to the same origin, the origin to the rest.
  originWhenCrossOrigin('origin-when-cross-origin'),

  /// The whole URL to the same origin only.
  sameOrigin('same-origin'),

  /// Only the origin, and not from `https` to `http`.
  strictOrigin('strict-origin'),

  /// The browser default: the whole URL to the same origin, the origin to
  /// the rest, nothing from `https` to `http`.
  strictOriginWhenCrossOrigin('strict-origin-when-cross-origin'),

  /// Always the whole URL.
  unsafeUrl('unsafe-url');

  const ReferrerPolicy(this.value);

  /// The header value.
  final String value;
}

/// `Cross-Origin-Opener-Policy`: whether windows opened from or to other
/// origins keep a handle on this one.
enum OpenerPolicy {
  /// The page shares a browsing context group with nobody from another
  /// origin.
  sameOrigin('same-origin'),

  /// As [sameOrigin], but the page keeps the handle of the popups it opens.
  sameOriginAllowPopups('same-origin-allow-popups'),

  /// The browser default: no isolation.
  unsafeNone('unsafe-none');

  const OpenerPolicy(this.value);

  /// The header value.
  final String value;
}

/// The headers of [securityHeaders] as a value, for what no route
/// middleware wraps: `ThorServer(securityHeaders: SecurityHeaders(...))`
/// puts them on static files, the health check, host refusals and the
/// global 500, besides every page.
///
/// ```dart
/// ThorServer(
///   handler: handler,
///   securityHeaders: const SecurityHeaders(hsts: Duration(days: 365)),
/// )
/// ```
class SecurityHeaders {
  /// The headers of [securityHeaders]; a null argument leaves that one out.
  const SecurityHeaders({
    FrameOptions? frameOptions = FrameOptions.deny,
    ReferrerPolicy? referrerPolicy = ReferrerPolicy.strictOriginWhenCrossOrigin,
    OpenerPolicy? openerPolicy = OpenerPolicy.sameOrigin,
    this.permissionsPolicy = 'camera=(), microphone=(), geolocation=()',
    this.hsts,
    this.frameAncestors = const [],
  }) : _frameOptions = frameOptions,
       _referrerPolicy = referrerPolicy,
       _openerPolicy = openerPolicy,
       _raw = null;

  const SecurityHeaders._(Map<HttpHeader, String> raw)
    : _raw = raw,
      _frameOptions = null,
      _referrerPolicy = null,
      _openerPolicy = null,
      permissionsPolicy = null,
      hsts = null,
      frameAncestors = const [];

  final FrameOptions? _frameOptions;
  final ReferrerPolicy? _referrerPolicy;
  final OpenerPolicy? _openerPolicy;
  final Map<HttpHeader, String>? _raw;

  /// `X-Frame-Options`.
  FrameOptions? get frameOptions => _frameOptions;

  /// `Referrer-Policy`.
  ReferrerPolicy? get referrerPolicy => _referrerPolicy;

  /// `Cross-Origin-Opener-Policy`.
  OpenerPolicy? get openerPolicy => _openerPolicy;

  /// `Permissions-Policy`, as the header's own text
  /// (`camera=(), geolocation=(self)`).
  // web: no typed twin: Flutter has no such concept, and the directive list
  // is open-ended.
  final String? permissionsPolicy;

  /// `Strict-Transport-Security` `max-age`, or none.
  final Duration? hsts;

  /// The origins (`https://editor.example`) that may frame the pages, besides
  /// their own. Empty (the default): [frameOptions] decides, `DENY` unless
  /// changed. With some, `X-Frame-Options` (which cannot name an origin) is
  /// left out and `Content-Security-Policy: frame-ancestors 'self' …` says
  /// who may ([frameAncestorsPolicy] checks each: no wildcards). A response
  /// with its own `Content-Security-Policy` (`ContentSecurityPolicy.
  /// frameAncestors`) keeps it: this one only fills the responses that have
  /// none.
  // web: no Flutter twin; embedding is a browser concept.
  final List<String> frameAncestors;

  /// The middleware that adds these headers below it.
  Middleware get middleware => _headersMiddleware(headers);

  /// The headers, lowercase names.
  Map<HttpHeader, String> get headers =>
      _raw ??
      {
        HttpHeader.xContentTypeOptions: 'nosniff',
        if (frameAncestors.isEmpty)
          HttpHeader.xFrameOptions: ?_frameOptions?.value
        else
          HttpHeader.contentSecurityPolicy: frameAncestorsPolicy(
            frameAncestors,
          ),
        HttpHeader.referrerPolicy: ?_referrerPolicy?.value,
        const HttpHeader('cross-origin-opener-policy'): ?_openerPolicy?.value,
        const HttpHeader('permissions-policy'): ?permissionsPolicy,
        if (hsts != null)
          HttpHeader.strictTransportSecurity:
              'max-age=${hsts!.inSeconds}; includeSubDomains',
      };

  /// [response] with the headers it doesn't set itself.
  ThorResponse apply(ThorResponse response) {
    final present = {for (final k in response.headers.keys) k.toLowerCase()};
    final missing = {
      for (final MapEntry(:key, :value) in headers.entries)
        if (!present.contains(key)) key: value,
    };
    return missing.isEmpty ? response : response.withHeaders(missing);
  }
}

/// Cross-origin requests from [origins] (`https://app.example.com`; `*`
/// for any): a preflight (`OPTIONS` with `Access-Control-Request-Method`)
/// is answered here with `204` and what they may send ([methods],
/// [headers], for [maxAge]); any other request from an allowed origin gets
/// `Access-Control-Allow-Origin` (the origin itself with [credentials],
/// never `*`) and `Vary: Origin`. An origin not in the list gets no CORS
/// headers (the browser blocks it), only `Vary: Origin`, so a shared cache
/// keeps the two answers apart.
///
/// [methods] defaults to what Thor routes serve (`GET`, `HEAD`, `POST`).
/// `origins: ['*']` together with `credentials: true` throws an
/// [ArgumentError]: browsers reject it, and reflecting any origin with
/// credentials would let every site read a signed-in user's answers.
///
/// ```dart
/// ThorRoute('/api/items', const ItemsJson(),
///     middleware: [cors(origins: ['https://app.example.com'])])
/// ```
Middleware cors({
  required List<String> origins,
  List<HttpMethod> methods = const [
    HttpMethod.get,
    HttpMethod.head,
    HttpMethod.post,
  ],
  List<String> headers = const [],
  bool credentials = false,
  Duration maxAge = const Duration(hours: 1),
}) {
  final any = origins.contains('*');
  if (any && credentials) {
    throw ArgumentError.value(
      origins,
      'origins',
      "cors(): '*' cannot be combined with credentials: true; "
          'list the allowed origins',
    );
  }
  final allowed = {for (final o in origins) o.toLowerCase()};
  return namedMiddleware('cors', (request, next) async {
    final origin = request.headers['origin'];
    if (origin == null || !(any || allowed.contains(origin.toLowerCase()))) {
      // No CORS headers, but the answer still depends on `Origin`: a shared
      // cache must not hand this one to an allowed origin.
      return _varyOrigin(await next());
    }
    final allowOrigin = any ? '*' : origin;
    final common = <HttpHeader, String>{
      HttpHeader.accessControlAllowOrigin: allowOrigin,
      if (credentials) HttpHeader.accessControlAllowCredentials: 'true',
    };
    if (request.method == HttpMethod.options &&
        request.headers.containsKey('access-control-request-method')) {
      return ThorResponse(
        204,
        headers: {
          ...common,
          HttpHeader.accessControlAllowMethods: [
            for (final m in methods) m.token,
          ].join(', '),
          if (headers.isNotEmpty)
            HttpHeader.accessControlAllowHeaders: headers.join(', '),
          HttpHeader.accessControlMaxAge: '${maxAge.inSeconds}',
          HttpHeader.vary: 'Origin',
        },
      );
    }
    return _varyOrigin(await next(), common);
  });
}

ThorResponse _varyOrigin(
  ThorResponse response, [
  Map<HttpHeader, String> extra = const {},
]) {
  final vary = response.headers.entries
      .where((e) => e.key.toLowerCase() == 'vary')
      .map((e) => e.value)
      .firstOrNull;
  if (vary != null &&
      vary
          .split(',')
          .any((v) => v.trim().toLowerCase() == 'origin' || v.trim() == '*')) {
    return extra.isEmpty ? response : response.withHeaders(extra);
  }
  return response.withHeaders({
    ...extra,
    HttpHeader.vary: vary == null || vary.isEmpty ? 'Origin' : '$vary, Origin',
  });
}

/// Turns the `401` of what runs below it into a redirect to the sign-in page
/// (`/login?next=/orders`), the way a Flutter route guard sends someone with
/// no session to the login screen.
///
/// A repository throws `HttpError(401)` (never a `Redirect`: where to go is
/// not the data layer's call); a `load`, an action, a query or a command that
/// lets it through ends as a `401` page, and this middleware, in the
/// group's `middleware:`, changes that page into the redirect. The page the
/// visitor wanted travels in the [next] query parameter (its path and query,
/// never another site: read it back with `safeNext`). Query and command calls
/// get the `401` JSON that carries the `redirect`, as with any redirect of a
/// middleware.
///
/// ```dart
/// Group(middleware: [session, signInOn401('/login')], children: [ordersRoute])
/// ```
Middleware signInOn401(String signIn, {String next = 'next'}) {
  return namedMiddleware('signInOn401', (request, below) async {
    final response = await below();
    if (response.status != 401) return response;
    final uri = request.uri;
    final wanted = '${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
    final separator = signIn.contains('?') ? '&' : '?';
    throw Redirect(
      RouteUrl('$signIn$separator$next=${Uri.encodeQueryComponent(wanted)}'),
    );
  });
}
