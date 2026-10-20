/// The vocabulary of HTTP as types: methods, status codes and header names.
library;

import 'package:thor_server/src/request.dart' show PageRequest;

/// An HTTP request method.
///
/// ```dart
/// if (request.method.isRead) { … }
/// PageRequest(method: HttpMethod.post, uri: uri)
/// ```
///
/// `// web:` no Flutter counterpart (`dart:io` spells methods as `String`s).
/// A method outside this list is [tryParse]d to `null`; the server answers
/// it `501`.
enum HttpMethod {
  /// `GET`: read a resource.
  get('GET'),

  /// `HEAD`: `GET` without the body.
  head('HEAD'),

  /// `POST`: send data (a form, an action, a query or a command).
  post('POST'),

  /// `PUT`: replace a resource.
  put('PUT'),

  /// `PATCH`: change part of a resource.
  patch('PATCH'),

  /// `DELETE`: remove a resource.
  delete('DELETE'),

  /// `OPTIONS`: what a resource accepts (CORS preflights).
  options('OPTIONS'),

  /// `TRACE`: echo the request.
  trace('TRACE'),

  /// `CONNECT`: open a tunnel.
  connect('CONNECT');

  const HttpMethod(this.token);

  /// The method as the request line spells it: `GET`.
  final String token;

  /// Whether the request only reads (`GET`, `HEAD`): no body, no change,
  /// cacheable, safe to redirect with a `302`.
  bool get isRead => this == get || this == head;

  /// The method [token] names (`GET`, case-sensitive as HTTP is), or `null`
  /// when it is none of [values].
  static HttpMethod? tryParse(String token) {
    for (final method in values) {
      if (method.token == token) return method;
    }
    return null;
  }

  @override
  String toString() => token;
}

/// An HTTP status code: the typed constants of the ones thor answers with
/// (`StatusCode.notFound`), usable wherever an `int` is.
///
/// ```dart
/// throw HttpError(StatusCode.forbidden, 'Not yours');
/// ThorResponse(StatusCode.noContent)
/// ```
///
/// `// web:` no Flutter counterpart. It *is* an `int` (a status the list
/// lacks is `StatusCode(418)`), so an API that takes a status keeps taking
/// a plain number too.
extension type const StatusCode(int code) implements int {
  /// `200`.
  static const ok = StatusCode(200);

  /// `201`.
  static const created = StatusCode(201);

  /// `202`.
  static const accepted = StatusCode(202);

  /// `204`: success with no body.
  static const noContent = StatusCode(204);

  /// `301`: moved for good (browsers may keep asking the old URL's `GET`).
  static const movedPermanently = StatusCode(301);

  /// `302`: found, at another URL for now.
  static const found = StatusCode(302);

  /// `303`: see other (the answer to a `POST`, read with a `GET`).
  static const seeOther = StatusCode(303);

  /// `304`: the cached copy is current.
  static const notModified = StatusCode(304);

  /// `307`: temporary redirect keeping the method.
  static const temporaryRedirect = StatusCode(307);

  /// `308`: permanent redirect keeping the method.
  static const permanentRedirect = StatusCode(308);

  /// `400`.
  static const badRequest = StatusCode(400);

  /// `401`: no valid credentials.
  static const unauthorized = StatusCode(401);

  /// `403`: known, and not allowed.
  static const forbidden = StatusCode(403);

  /// `404`.
  static const notFound = StatusCode(404);

  /// `405`: the method is not allowed here.
  static const methodNotAllowed = StatusCode(405);

  /// `408`: the request took too long to arrive.
  static const requestTimeout = StatusCode(408);

  /// `409`: the request clashes with the resource's state.
  static const conflict = StatusCode(409);

  /// `410`: gone for good.
  static const gone = StatusCode(410);

  /// `413`: the body is too big.
  static const contentTooLarge = StatusCode(413);

  /// `422`: well formed, but not valid.
  static const unprocessableContent = StatusCode(422);

  /// `429`: too many requests.
  static const tooManyRequests = StatusCode(429);

  /// `500`.
  static const internalServerError = StatusCode(500);

  /// `501`: the method is not implemented.
  static const notImplemented = StatusCode(501);

  /// `502`: the upstream answered badly.
  static const badGateway = StatusCode(502);

  /// `503`: not available now.
  static const serviceUnavailable = StatusCode(503);

  /// `504`: the upstream took too long.
  static const gatewayTimeout = StatusCode(504);

  /// Whether this is a `2xx`.
  bool get isSuccess => code >= 200 && code < 300;

  /// Whether this is a `3xx`.
  bool get isRedirect => code >= 300 && code < 400;

  /// Whether this is a `4xx`.
  bool get isClientError => code >= 400 && code < 500;

  /// Whether this is a `5xx`.
  bool get isServerError => code >= 500 && code < 600;
}

/// The name of an HTTP header: the key type of every header map (a
/// request's [PageRequest.headers], a response's `headers`, a client
/// call's), with typed constants for the common ones in the lowercase
/// spelling those maps use.
///
/// ```dart
/// request.headers[HttpHeader.acceptLanguage]
/// ThorResponse(StatusCode.ok, headers: {HttpHeader.cacheControl: 'no-store'})
/// ThorResponse(StatusCode.ok, headers: {HttpHeader('x-request-id'): id})
/// ```
///
/// `// web:` no Flutter counterpart. It *is* a `String` (HTTP is open: a
/// header the list lacks is `HttpHeader('x-request-id')`, lowercase), so a
/// header map still reads with a plain name (`headers['cookie']`) and its
/// keys still work as strings.
extension type const HttpHeader(String name) implements String {
  /// `accept`.
  static const accept = HttpHeader('accept');

  /// `accept-encoding`.
  static const acceptEncoding = HttpHeader('accept-encoding');

  /// `accept-language`.
  static const acceptLanguage = HttpHeader('accept-language');

  /// `access-control-allow-credentials`.
  static const accessControlAllowCredentials = HttpHeader(
    'access-control-allow-credentials',
  );

  /// `access-control-allow-headers`.
  static const accessControlAllowHeaders = HttpHeader(
    'access-control-allow-headers',
  );

  /// `access-control-allow-methods`.
  static const accessControlAllowMethods = HttpHeader(
    'access-control-allow-methods',
  );

  /// `access-control-allow-origin`.
  static const accessControlAllowOrigin = HttpHeader(
    'access-control-allow-origin',
  );

  /// `access-control-max-age`.
  static const accessControlMaxAge = HttpHeader('access-control-max-age');

  /// `access-control-request-method`.
  static const accessControlRequestMethod = HttpHeader(
    'access-control-request-method',
  );

  /// `allow`.
  static const allow = HttpHeader('allow');

  /// `authorization`.
  static const authorization = HttpHeader('authorization');

  /// `cache-control`.
  static const cacheControl = HttpHeader('cache-control');

  /// `content-disposition`.
  static const contentDisposition = HttpHeader('content-disposition');

  /// `content-encoding`.
  static const contentEncoding = HttpHeader('content-encoding');

  /// `content-length`.
  static const contentLength = HttpHeader('content-length');

  /// `content-security-policy`.
  static const contentSecurityPolicy = HttpHeader('content-security-policy');

  /// `content-type`.
  static const contentType = HttpHeader('content-type');

  /// `cookie`.
  static const cookie = HttpHeader('cookie');

  /// `etag`.
  static const etag = HttpHeader('etag');

  /// `expires`.
  static const expires = HttpHeader('expires');

  /// `host`.
  static const host = HttpHeader('host');

  /// `if-modified-since`.
  static const ifModifiedSince = HttpHeader('if-modified-since');

  /// `if-none-match`.
  static const ifNoneMatch = HttpHeader('if-none-match');

  /// `last-modified`.
  static const lastModified = HttpHeader('last-modified');

  /// `link`.
  static const link = HttpHeader('link');

  /// `location`.
  static const location = HttpHeader('location');

  /// `origin`.
  static const origin = HttpHeader('origin');

  /// `referer`.
  static const referer = HttpHeader('referer');

  /// `referrer-policy`.
  static const referrerPolicy = HttpHeader('referrer-policy');

  /// `retry-after`.
  static const retryAfter = HttpHeader('retry-after');

  /// `set-cookie`.
  static const setCookie = HttpHeader('set-cookie');

  /// `strict-transport-security`.
  static const strictTransportSecurity = HttpHeader(
    'strict-transport-security',
  );

  /// `user-agent`.
  static const userAgent = HttpHeader('user-agent');

  /// `vary`.
  static const vary = HttpHeader('vary');

  /// `x-content-type-options`.
  static const xContentTypeOptions = HttpHeader('x-content-type-options');

  /// `x-forwarded-for`.
  static const xForwardedFor = HttpHeader('x-forwarded-for');

  /// `x-forwarded-host`.
  static const xForwardedHost = HttpHeader('x-forwarded-host');

  /// `x-forwarded-proto`.
  static const xForwardedProto = HttpHeader('x-forwarded-proto');

  /// `x-frame-options`.
  static const xFrameOptions = HttpHeader('x-frame-options');
}
