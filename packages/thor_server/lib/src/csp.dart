import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'handler.dart';
import 'http_types.dart';
import 'middleware.dart';
import 'request.dart';
import 'routes.dart';

/// One source of a [ContentSecurityPolicy] directive: a keyword
/// ([CspSource.self]), a scheme ([CspSource.data]), a host
/// ([CspSource.host]) or a hash ([CspSource.hash]). Typed so a typo in a
/// quote (`self` for `'self'`) cannot silently turn a keyword into a host.
final class CspSource {
  const CspSource._(this.value);

  /// A host source: `https://cdn.example.com`, `*.example.com`,
  /// `example.com:8443`. Throws on a character that would end the source
  /// or the directive (space, `;`, `,`, quotes).
  factory CspSource.host(String host) {
    if (host.isEmpty || RegExp(r'''[\s;,'"]''').hasMatch(host)) {
      throw ArgumentError.value(host, 'host', 'not a valid CSP host source');
    }
    return CspSource._(host);
  }

  /// A scheme source (`https`, `wss`): `https:`.
  factory CspSource.scheme(String scheme) {
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9+.\-]*$').hasMatch(scheme)) {
      throw ArgumentError.value(scheme, 'scheme', 'not a valid URL scheme');
    }
    return CspSource._('${scheme.toLowerCase()}:');
  }

  /// The base64 digest of an inline script, style or handler.
  factory CspSource.hash(CspHashAlgorithm algorithm, String base64Digest) {
    if (!RegExp(r'^[A-Za-z0-9+/\-_]+={0,2}$').hasMatch(base64Digest)) {
      throw ArgumentError.value(base64Digest, 'base64Digest', 'not base64');
    }
    return CspSource._("'${algorithm.name}-$base64Digest'");
  }

  /// The page's own origin.
  static const self = CspSource._("'self'");

  /// Nothing at all.
  static const none = CspSource._("'none'");

  /// Any inline script or style. With a nonce in the same directive
  /// browsers ignore it; for `style-src-attr` it allows `style="..."`.
  static const unsafeInline = CspSource._("'unsafe-inline'");

  /// `eval` and friends.
  static const unsafeEval = CspSource._("'unsafe-eval'");

  /// Lets a hash allow an inline event handler attribute.
  static const unsafeHashes = CspSource._("'unsafe-hashes'");

  /// Scripts a trusted (nonce or hash) script loads are trusted too.
  static const strictDynamic = CspSource._("'strict-dynamic'");

  /// WebAssembly compilation without allowing `eval`.
  static const wasmUnsafeEval = CspSource._("'wasm-unsafe-eval'");

  /// Violation reports carry the first characters of the code.
  static const reportSample = CspSource._("'report-sample'");

  /// `data:` URLs.
  static const data = CspSource._('data:');

  /// `blob:` URLs.
  static const blob = CspSource._('blob:');

  /// Any `https:` URL.
  static const https = CspSource._('https:');

  /// The hashes of the inline event handlers Thor's widgets write: the
  /// `TextField(maxLength:)` counter (`oninput`), `Image(errorBuilder:,
  /// loadingBuilder:)` (`onerror`, `onload`) and `closeOnNavigate` of
  /// `Drawer`, `Popover` and `MenuAnchor` (`onclick`). With
  /// [unsafeHashes] in [ContentSecurityPolicy.scriptSrcAttr] they keep
  /// working under a strict policy. `csp_hashes_test` keeps the list in
  /// sync with the widgets.
  ///
  /// ```dart
  /// const ContentSecurityPolicy(
  ///   scriptSrcAttr: [CspSource.unsafeHashes, ...CspSource.thorHandlers],
  /// )
  /// ```
  static const thorHandlers = [
    CspSource._("'sha256-d1k8y4HZiUcsRf7/fSwzLY3eloLLZikspOpQ2YrXhHs='"),
    CspSource._("'sha256-yMxl8xCTUafbfCLCfCzjwjSLtzTIs2YxOZEF/a/1y/M='"),
    CspSource._("'sha256-8bvL4iOwjjseCopvPb3HpKMRh3VhhhOLSaXO6KWVG7c='"),
    CspSource._("'sha256-L/gjp/lXf1b++Z++rgw+P1gwp3nzVwoiQxErAc/1Brc='"),
    CspSource._("'sha256-RyS7b/uVe1C+1Gd8n4HR1kH+n+01SmpZRn+mOR9CJUk='"),
  ];

  /// The text in the header.
  final String value;

  @override
  String toString() => value;
}

/// Hash algorithms of a [CspSource.hash].
enum CspHashAlgorithm {
  /// SHA-256.
  sha256,

  /// SHA-384.
  sha384,

  /// SHA-512.
  sha512,
}

/// A Content-Security-Policy, typed (use it with [contentSecurityPolicy]).
///
/// With [nonce] (the default) every request gets a fresh random nonce,
/// added to `script-src` and `style-src`. The renderer writes a
/// placeholder as the `nonce` of the `<script>` and `<style>` elements it
/// emits itself (the engine loader, the theme and form scripts, the
/// generated styles, your `html.script`) and the middleware swaps it for
/// the nonce on the way out. Text that merely holds `<script>` (an
/// escaping failure, a markdown renderer) is not an element Thor emitted:
/// it gets no nonce and the policy blocks it. The page cache keeps the
/// placeholder, never a real nonce, so a cached page never repeats one.
///
/// A page stamped with a nonce is answered with no `ETag` (its body
/// changes on every request) and `Cache-Control: private` where it said
/// `public`: do not put it behind a shared cache. The fragments of a
/// `LazyPiece` are inserted with the page's nonce by the loader script.
/// The policy covers the pages below the group, not the static files,
/// the 404 outside it or the global 500.
///
/// What a nonce cannot cover, and how Thor handles it (the inline event
/// handler attributes; a nonce never applies to attributes, and with no
/// `script-src-attr` they fall back to `script-src`, so they are blocked
/// and every one degrades without breaking the page):
/// * `oninput` of the `TextField(maxLength:)` counter: the counter keeps
///   the count of the render.
/// * `onerror` and `onload` of `Image(errorBuilder:, loadingBuilder:)`:
///   no fallback, and the placeholder is not removed (the browser shows
///   its broken image with the `alt`).
/// * `onclick` of `Drawer`, `Popover` and `MenuAnchor` with
///   `closeOnNavigate: true`: they do not close with the navigation. Pass
///   `closeOnNavigate: false`.
///
/// To keep all of them put [CspSource.unsafeHashes] and
/// [CspSource.thorHandlers] (the hash of each; the deploy guide lists
/// them too) in [scriptSrcAttr].
///
/// `style="..."` attributes (Thor sets CSS variables with them) are covered
/// by the default `style-src-attr 'unsafe-inline'`, which allows attributes
/// only, never `<style>` elements.
///
/// ```dart
/// Group(
///   middleware: [contentSecurityPolicy(const ContentSecurityPolicy())],
///   children: [...],
/// )
///
/// // Try it first without blocking anything:
/// contentSecurityPolicy(ContentSecurityPolicy(reportOnly: true,
///     reportUri: Uri.parse('/csp-report')))
/// ```
final class ContentSecurityPolicy {
  /// A policy. The defaults are strict: everything from the site itself,
  /// no plugins, no framing, `<base>` and forms to the site only.
  const ContentSecurityPolicy({
    this.defaultSrc = const [CspSource.self],
    this.scriptSrc = const [CspSource.self],
    this.scriptSrcAttr,
    this.styleSrc = const [CspSource.self],
    this.styleSrcAttr = const [CspSource.unsafeInline],
    this.imgSrc = const [CspSource.self, CspSource.data],
    this.fontSrc = const [CspSource.self],
    this.connectSrc = const [CspSource.self],
    this.mediaSrc,
    this.frameSrc,
    this.workerSrc,
    this.manifestSrc,
    this.objectSrc = const [CspSource.none],
    this.baseUri = const [CspSource.self],
    this.formAction = const [CspSource.self],
    this.frameAncestors = const [CspSource.none],
    this.upgradeInsecureRequests = false,
    this.nonce = true,
    this.reportOnly = false,
    this.reportUri,
  });

  /// `default-src`: what the directives below that are null fall back to.
  final List<CspSource>? defaultSrc;

  /// `script-src`, plus the nonce.
  final List<CspSource>? scriptSrc;

  /// `script-src-attr`: inline event handler attributes.
  final List<CspSource>? scriptSrcAttr;

  /// `style-src`, plus the nonce.
  final List<CspSource>? styleSrc;

  /// `style-src-attr`: `style="..."` attributes.
  final List<CspSource>? styleSrcAttr;

  /// `img-src`.
  final List<CspSource>? imgSrc;

  /// `font-src`.
  final List<CspSource>? fontSrc;

  /// `connect-src`: `fetch`, `EventSource`, WebSocket.
  final List<CspSource>? connectSrc;

  /// `media-src`.
  final List<CspSource>? mediaSrc;

  /// `frame-src`.
  final List<CspSource>? frameSrc;

  /// `worker-src`.
  final List<CspSource>? workerSrc;

  /// `manifest-src`.
  final List<CspSource>? manifestSrc;

  /// `object-src`.
  final List<CspSource>? objectSrc;

  /// `base-uri`.
  final List<CspSource>? baseUri;

  /// `form-action`.
  final List<CspSource>? formAction;

  /// `frame-ancestors`: who may frame the page.
  final List<CspSource>? frameAncestors;

  /// `upgrade-insecure-requests`.
  final bool upgradeInsecureRequests;

  /// Whether each request gets a nonce, added to `script-src` and
  /// `style-src` and stamped on the inline scripts and styles of its HTML.
  final bool nonce;

  /// Send `Content-Security-Policy-Report-Only`: violations are reported,
  /// nothing is blocked.
  final bool reportOnly;

  /// Where the browser posts violation reports (`report-uri`).
  final Uri? reportUri;

  /// The header name.
  String get headerName => reportOnly
      ? 'content-security-policy-report-only'
      : 'content-security-policy';

  /// The header value for a request whose nonce is [requestNonce].
  String headerValue(String? requestNonce) {
    String? directive(
      String name,
      List<CspSource>? sources, {
      bool withNonce = false,
    }) {
      final stamp = withNonce && nonce && requestNonce != null;
      // A null script-src or style-src keeps falling back to default-src:
      // the nonce must not turn it into a nonce-only directive.
      final base = sources ?? (stamp ? defaultSrc : null);
      if (base == null) return null;
      return [
        name,
        ...base.map((s) => s.value),
        if (stamp) "'nonce-$requestNonce'",
      ].join(' ');
    }

    return [
      directive('default-src', defaultSrc),
      directive('script-src', scriptSrc, withNonce: true),
      directive('script-src-attr', scriptSrcAttr),
      directive('style-src', styleSrc, withNonce: true),
      directive('style-src-attr', styleSrcAttr),
      directive('img-src', imgSrc),
      directive('font-src', fontSrc),
      directive('connect-src', connectSrc),
      directive('media-src', mediaSrc),
      directive('frame-src', frameSrc),
      directive('worker-src', workerSrc),
      directive('manifest-src', manifestSrc),
      directive('object-src', objectSrc),
      directive('base-uri', baseUri),
      directive('form-action', formAction),
      directive('frame-ancestors', frameAncestors),
      if (upgradeInsecureRequests) 'upgrade-insecure-requests',
      // A `;` or a space would add a directive of the app's choosing.
      if (reportUri case final uri?)
        'report-uri ${uri.toString().replaceAll(RegExp(r'[;\s,]'), '')}',
    ].nonNulls.join('; ');
  }
}

const _nonceKey = 'thor.csp.nonce';

/// The nonce of the request's Content-Security-Policy (set by
/// [contentSecurityPolicy]); the `<script>` and `<style>` Thor emits get it
/// without the app doing anything, this is for code that builds its own
/// (a response written by hand: stamp it yourself).
extension CspNonce on PageRequest {
  /// The nonce, or `null` outside [contentSecurityPolicy] or without
  /// [ContentSecurityPolicy.nonce].
  String? get cspNonce => locals[_nonceKey] as String?;
}

/// Adds [policy] to the pages below, with a fresh nonce per request.
///
/// A response that already has the header is left alone. Only
/// `text/html` bodies (streamed ones too) are stamped: the renderer's
/// placeholder becomes the nonce. In `reportOnly` mode the nonce is still
/// stamped, so the report shows what a blocking policy would do to the
/// page.
///
/// ```dart
/// Group(middleware: [contentSecurityPolicy(const ContentSecurityPolicy())], …)
/// ```
Middleware contentSecurityPolicy([
  ContentSecurityPolicy policy = const ContentSecurityPolicy(),
]) {
  return namedMiddleware('contentSecurityPolicy', (request, next) async {
    final nonce = policy.nonce ? newCspNonce() : null;
    if (nonce != null) request.locals[_nonceKey] = nonce;
    final ThorResponse response;
    try {
      response = await next();
    } catch (_) {
      // The error page is rendered above this middleware, without the
      // policy: it must not carry the placeholder, a secret of the process
      // that would give every later page's nonce away.
      request.locals.remove(_nonceKey);
      rethrow;
    }
    final isHtml = response.headers.entries.any(
      (e) =>
          e.key.toLowerCase() == 'content-type' &&
          e.value.toLowerCase().startsWith('text/html'),
    );
    if (response.headers.keys.any(
      (k) => k.toLowerCase() == policy.headerName,
    )) {
      // The app's own policy wins, but the placeholder still never leaves.
      return nonce == null || !isHtml
          ? response
          : _stamped(response, NonceInjector(nonce));
    }
    final header = <HttpHeader, String>{
      HttpHeader(policy.headerName): policy.headerValue(nonce),
      // A `LazyPiece` fragment is its own response: its `<style>` carries
      // this nonce, and the loader re-nonces only the styles that carry
      // exactly it (text that arrives in the fragment cannot know it).
      if (nonce != null &&
          isHtml &&
          request.headers.keys.any((k) => k.toLowerCase() == 'x-thor-piece'))
        const HttpHeader('x-thor-piece-nonce'): nonce,
    };
    if (nonce == null || !isHtml) return response.withHeaders(header);
    return _stamped(response.withHeaders(header), NonceInjector(nonce));
  });
}

ThorResponse _withoutValidator(ThorResponse r) {
  final headers = <HttpHeader, String>{};
  for (final MapEntry(:key, :value) in r.headers.entries) {
    switch (key.toLowerCase()) {
      case 'etag' || 'last-modified':
        continue;
      case 'cache-control':
        headers[key] = value
            .replaceAll(RegExp(r'\bpublic\b', caseSensitive: false), 'private')
            .replaceAll(RegExp(r',?\s*s-maxage=\d+', caseSensitive: false), '');
      default:
        headers[key] = value;
    }
  }
  return ThorResponse(
    r.status,
    headers: headers,
    cookies: r.cookies,
    body: r.body,
    stream: r.stream,
  );
}

/// [response] with the placeholder replaced by [injector]'s nonce.
ThorResponse _stamped(ThorResponse response, NonceInjector injector) {
  // The body is not the one the ETag was computed from (the nonce changes
  // it for every request) and a 304 would pair the stored body with this
  // request's policy: no validator, and no shared cache keeps a page whose
  // nonce would be repeated to every visitor.
  final stamped = _withoutValidator(response);
  if (response.stream case final stream?) {
    return ThorResponse(
      stamped.status,
      headers: stamped.headers,
      cookies: stamped.cookies,
      stream: _stamp(stream, injector),
    );
  }
  return ThorResponse(
    stamped.status,
    headers: stamped.headers,
    cookies: stamped.cookies,
    body: utf8.encode(
      injector.feed(
        utf8.decode(response.body, allowMalformed: true),
        end: true,
      ),
    ),
  );
}

Stream<List<int>> _stamp(Stream<List<int>> source, NonceInjector injector) {
  late StreamController<List<int>> controller;
  StreamSubscription<String>? sub;
  controller = StreamController<List<int>>(
    onListen: () {
      sub = source
          .transform(utf8.decoder)
          .listen(
            (chunk) {
              final out = injector.feed(chunk);
              if (out.isNotEmpty) controller.add(utf8.encode(out));
            },
            onError: controller.addError,
            onDone: () {
              final rest = injector.feed('', end: true);
              if (rest.isNotEmpty) controller.add(utf8.encode(rest));
              controller.close();
            },
          );
    },
    onPause: () => sub?.pause(),
    onResume: () => sub?.resume(),
    onCancel: () => sub?.cancel(),
  );
  return controller.stream;
}

final _random = Random.secure();

/// A new nonce: 128 random bits in base64.
String newCspNonce() =>
    base64.encode([for (var i = 0; i < 16; i++) _random.nextInt(256)]);

/// The placeholder Thor's renderer writes as `nonce="…"` on the
/// `<script>` and `<style>` elements it emits itself ([RenderContext
/// .cspNonceToken]). A secret of this process: markup an app lets through
/// by mistake (an unescaped string, a markdown renderer) cannot guess it,
/// so it never gets a real nonce.
final String cspNonceToken = 'thor-nonce-${_secret()}';

String _secret() =>
    base64Url.encode([for (var i = 0; i < 24; i++) _random.nextInt(256)]);

/// Replaces [cspNonceToken] with [nonce] in the HTML it is fed (in chunks,
/// which may split anywhere). Only the exact secret token is replaced: a
/// `<script>` in the page that the renderer did not emit has none, so it
/// keeps no nonce and the policy blocks it.
final class NonceInjector {
  /// An injector that writes [nonce] where the renderer left its token.
  NonceInjector(this.nonce, {String? token}) : token = token ?? cspNonceToken;

  /// The nonce.
  final String nonce;

  /// The placeholder it replaces.
  final String token;

  String _carry = '';

  /// The text for [chunk]; the tail that could be the start of a token
  /// waits for the next call (or [end]).
  String feed(String chunk, {bool end = false}) {
    final s = _carry + chunk;
    _carry = '';
    final replaced = s.replaceAll(token, nonce);
    if (end) return replaced;
    // A token cut by the chunk boundary: hold back what may begin one,
    // after the last whole token (its own end may begin another one).
    final last = s.lastIndexOf(token);
    final free = last < 0 ? s.length : s.length - last - token.length;
    for (var keep = min(token.length - 1, free); keep > 0; keep--) {
      if (token.startsWith(s.substring(s.length - keep))) {
        // Replace in the part that stays; the held tail is raw.
        final head = s.substring(0, s.length - keep).replaceAll(token, nonce);
        _carry = s.substring(s.length - keep);
        return head;
      }
    }
    return replaced;
  }
}
