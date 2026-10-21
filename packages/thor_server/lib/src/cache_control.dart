/// The `Cache-Control` a public page offers browsers and CDNs
/// (`ThorPage(cacheControl:)`).
library;

/// How long a browser or a CDN may keep a page that is the same for every
/// visitor, and how long it may keep serving it while it fetches a new copy:
///
/// ```dart
/// ThorPage(
///   cacheControl: CacheControl(
///     maxAge: Duration(seconds: 60),
///     staleWhileRevalidate: Duration(minutes: 10),
///   ), // public, max-age=60, stale-while-revalidate=600
///   ...
/// )
/// ```
///
/// It is the answer to the *browser*; `cache:` is the server's own copy of
/// the page. They combine: a CDN in front of a server that caches.
///
/// `// web:` Flutter has no HTTP cache for its pages. Only a page that is
/// public gets it: one that is `personalized`, reads a cookie of the visitor,
/// sets a cookie, redirects or fails stays `private, no-cache` (or whatever
/// the load put in `request.response.headers`, which always wins).
final class CacheControl {
  /// A page kept for [maxAge], and served stale for [staleWhileRevalidate]
  /// (and [staleIfError] when the server fails) while a new copy is fetched.
  const CacheControl({
    required this.maxAge,
    this.sharedMaxAge,
    this.staleWhileRevalidate,
    this.staleIfError,
  });

  /// How long a copy is fresh (`max-age`).
  final Duration maxAge;

  /// How long a shared cache (a CDN) keeps it, when that differs
  /// (`s-maxage`).
  final Duration? sharedMaxAge;

  /// How long past [maxAge] a copy may be served while a fresh one is being
  /// fetched (`stale-while-revalidate`).
  final Duration? staleWhileRevalidate;

  /// How long past [maxAge] a copy may be served when the server answers
  /// with an error (`stale-if-error`).
  final Duration? staleIfError;

  /// The header value: `public, max-age=60, stale-while-revalidate=600`.
  String get header => [
    'public',
    'max-age=${maxAge.inSeconds}',
    if (sharedMaxAge case final d?) 's-maxage=${d.inSeconds}',
    if (staleWhileRevalidate case final d?)
      'stale-while-revalidate=${d.inSeconds}',
    if (staleIfError case final d?) 'stale-if-error=${d.inSeconds}',
  ].join(', ');

  @override
  bool operator ==(Object other) =>
      other is CacheControl && other.header == header;

  @override
  int get hashCode => header.hashCode;

  @override
  String toString() => 'CacheControl($header)';
}
