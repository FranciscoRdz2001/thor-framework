import 'dart:async';

import 'cache_control.dart' show CacheControl;
import 'handler.dart' show ThorResponse;
import 'http_types.dart' show HttpMethod;
import 'locale.dart' show Locale;
import 'request.dart';
import 'route_url.dart';
import 'seo.dart';

/// Loads a route's data before it renders.
typedef Loader<T> = FutureOr<T> Function(PageRequest request);

/// Handles a form `POST` (`<form method=post action="?/name">`). Returns a
/// `Redirect`, an `ActionResult` or `null` (= redirect back to the page).
typedef FormAction = FutureOr<Object?> Function(PageRequest request);

/// Runs before `load`: a path to redirect to (e.g. `/login`), or `null`.
typedef Guard = FutureOr<RouteUrl?> Function(PageRequest request);

/// The rest of the request below a [Middleware]: the middleware of the
/// groups below, the page cache, guards, the form action, loads and the
/// render. Call it at most once.
typedef Next = Future<ThorResponse> Function();

/// Wraps every request to the pages of a `Group` of the route table
/// (`Group(middleware: [session])`), outermost group first: read the session
/// into `request.context`, end the request early (throw a `Redirect` or an `HttpError`, or return a response
/// without calling [Next]), or change the response [Next] returns
/// (`response.withHeaders(…)`).
///
/// Runs on every request, a cached page's too (the cache sits below it).
typedef Middleware =
    FutureOr<ThorResponse> Function(PageRequest request, Next next);

/// A node of the route tree the route table (`ThorRouter`) builds: a
/// [PageRoute] or a [LayoutRoute].
///
/// [path] is relative to the parent, in the tree's own pattern syntax (the
/// table writes `/article/:slug` as `article/[slug]` and `/docs/*rest` as
/// `docs/[...rest]`; `(group)` adds no URL segment).
sealed class RouteNode<P> {
  const RouteNode(this.path);

  /// Path pattern, relative to the parent layout.
  final String path;
}

/// A page: what a `ThorRoute` of the route table (`lib/router.dart`)
/// becomes.
class PageRoute<P, T> extends RouteNode<P> {
  /// A page at [path].
  const PageRoute({
    String path = '',
    this.load,
    required this.build,
    this.actions = const {},
    this.redirect,
    this.meta,
    this.cache,
    this.cacheControl,
    this.personalized,
    this.prerender,
    this.earlyHints,
    this.maxBodyBytes,
    this.tags = const [],
    this.invalidateOnWrite = true,
    this.prefetch,
    this.forLayouts,
  }) : super(path);

  /// What the page hands the layouts above it (`ThorPage.forLayouts`): read
  /// there with `PageState.fromPage`.
  final List<Object> Function(PageState<T> state)? forLayouts;

  /// Largest request body this page's form actions accept, in bytes; `null`
  /// keeps the server's (`ThorServer(maxBodyBytes:)`, 1 MiB). Raise it on
  /// the page that takes an upload, so the rest of the site keeps the
  /// small limit; a bigger body is a `413`.
  final int? maxBodyBytes;

  /// Whether the browser may fetch this page ahead of a click (speculation
  /// rules). `false` for a page whose `GET` is costly or has effects: it
  /// sends no `Speculation-Rules` header and its own page has no inline
  /// rules, so links inside it do not prefetch either. `null`: the nearest
  /// layout's (`LayoutRoute.prefetch`), else `true`.
  final bool? prefetch;

  /// Names for the page in the shared cache (`cache:`): `revalidateTag('cart')`
  /// (in an action, a command, a webhook) drops the pages that have the tag,
  /// in every isolate. Tags add a way to revalidate; they do not replace the
  /// rest: every successful write still clears the page too, unless
  /// [invalidateOnWrite] is `false`.
  final List<String> tags;

  /// Whether a successful write (any action or command) clears this page from
  /// the shared cache, as it does every cached page. `false`, together with
  /// [tags], is an explicit opt-in for a costly page that only a known event
  /// changes: it then stays until `revalidateTag` names one of its tags or its
  /// `cache` time passes. A bug in the tags then shows stale data; leave it
  /// `true` unless every write that matters calls `revalidateTag`.
  final bool invalidateOnWrite;

  /// Its data (`state.data`); runs in parallel with the layouts' `load`.
  final Loader<T>? load;

  /// The page.
  final P Function(PageState<T> state) build;

  /// Form actions by name (`default` for a plain `<form method=post>`).
  final Map<String, FormAction> actions;

  /// Guard, after the layouts' guards.
  final Guard? redirect;

  /// Title, description and meta tags.
  final PageMeta Function(PageState<T> state)? meta;

  /// Keep the rendered page for this long and serve it to every visitor
  /// (refreshed in the background once it expires; rendered again if it is
  /// older than twice this). Only for pages that don't depend on the
  /// visitor, or whose visitor-specific requests `RouteHandler.personalized`
  /// sends past the cache. A successful form action clears the cache.
  /// `null`: the nearest layout's.
  final Duration? cache;

  /// What the page tells browsers and CDNs about keeping it
  /// (`public, max-age=60, stale-while-revalidate=600`), when it is the same
  /// for every visitor. Not the server's own copy ([cache]): both can be
  /// set. A personal page, one that sets a cookie or fails keeps
  /// `private, no-cache`, and a `Cache-Control` the load wrote in
  /// `request.response.headers` wins. `null`: the nearest layout's, else the
  /// page is asked again on every visit (`no-cache`).
  final CacheControl? cacheControl;

  /// Whether the page belongs to its visitor: never in the shared cache,
  /// `Cache-Control: private`. `false` shares it even when
  /// `RouteHandler.personalized` says the visitor has a session. `null`:
  /// the nearest layout's, else `RouteHandler.personalized`.
  final bool? personalized;

  /// Whether `RouteIndex.prerenderPaths` lists the page (static generation).
  /// `null`: the nearest layout's.
  final bool? prerender;

  /// Whether the page may answer before its data is loaded: when its loads
  /// take longer than `RouteHandler.earlyHintsAfter`, the status (`200`)
  /// and the headers go out first, with the renderer's `Link` preloads
  /// (the stylesheets), and the document follows when it is rendered. A
  /// load that fails after that answers its error page with `200` and
  /// `noindex`; one that redirects answers a page that redirects. `null`:
  /// the nearest layout's, else false.
  final bool? earlyHints;

  /// Runs [load] (typed).
  Future<Object?> runLoad(PageRequest request) async =>
      load == null ? null : await load!(request);

  /// Builds with an untyped state (the handler doesn't know `T`).
  P buildWith(PageState<Object?> state) => build(state.cast<T>());

  /// Meta with an untyped state.
  PageMeta? metaWith(PageState<Object?> state) => meta?.call(state.cast<T>());

  /// What the page hands its layouts, with an untyped state.
  List<Object> forLayoutsWith(PageState<Object?> state) =>
      forLayouts?.call(state.cast<T>()) ?? const [];
}

/// A route that answers something other than a page (a file, XML, text,
/// JSON) at a place of the route tree: the layouts' middleware and guards
/// run around it, but no `load`, no render and no page cache (it sets its
/// own `cache-control`). `GET` and `HEAD`, plus its [methods].
///
/// A `SitemapRoute` and a `RobotsRoute` of the route table become
/// [ResourceRoute.sitemap] and [ResourceRoute.robots].
class ResourceRoute<P> extends PageRoute<P, void> {
  /// [respond] at [path].
  const ResourceRoute({
    super.path,
    required this.respond,
    super.redirect,
    this.methods = const {},
  }) : super(build: _noPage);

  /// `/sitemap.xml` from [sitemap].
  factory ResourceRoute.sitemap(
    FutureOr<Sitemap> Function(PageRequest request) sitemap,
  ) => ResourceRoute(
    path: 'sitemap.xml',
    respond: (request) async => (await sitemap(request)).response(request),
  );

  /// `/robots.txt` from [robots].
  factory ResourceRoute.robots(
    FutureOr<Robots> Function(PageRequest request) robots,
  ) => ResourceRoute(
    path: 'robots.txt',
    respond: (request) async => (await robots(request)).response(request),
  );

  /// The answer.
  final FutureOr<ThorResponse> Function(PageRequest request) respond;

  /// The methods it answers besides `GET` and `HEAD` (`POST`, `PUT`,
  /// `PATCH`, `DELETE`).
  final Set<HttpMethod> methods;

  static Never _noPage(PageState<void> state) =>
      throw StateError('a ResourceRoute has no page');
}

/// A layout: what a `Group(layout:)` of the route table becomes. Wraps
/// every page below it.
class LayoutRoute<P, T> extends RouteNode<P> {
  /// A layout at [path] with its [children].
  const LayoutRoute({
    String path = '',
    this.load,
    required this.build,
    this.redirect,
    this.meta,
    this.error,
    this.notFound,
    this.errorMeta,
    this.notFoundMeta,
    this.middleware,
    this.cache,
    this.cacheControl,
    this.personalized,
    this.prerender,
    this.earlyHints,
    this.prefetch,
    required this.children,
  }) : super(path);

  /// Its data; runs in parallel with the page's `load`.
  final Loader<T>? load;

  /// Wraps every request to the pages below (`Group(middleware:)`), after
  /// the middleware of the groups above.
  final Middleware? middleware;

  /// The layout around `child` (the page, or a nested layout).
  final P Function(PageState<T> state, P child) build;

  /// Guard for every page below.
  final Guard? redirect;

  /// Default meta for the pages below (a page's own meta wins).
  final PageMeta Function(PageState<T> state)? meta;

  /// The error page for the pages below (`Group(error:)`), rendered inside
  /// this layout.
  final P Function(ErrorState state)? error;

  /// The page for a `404` below (`Group(notFound:)`): a URL under this
  /// group that no page matches, or a `NotFound` thrown by a load. Wins
  /// over [error] at the same level.
  final P Function(ErrorState state)? notFound;

  /// The `<head>` of [error]'s page (its title, description, `robots`,
  /// `alternates`…), over the default one (`title: '<status>'`).
  final PageMeta Function(ErrorState state)? errorMeta;

  /// The `<head>` of [notFound]'s page, like [errorMeta].
  final PageMeta Function(ErrorState state)? notFoundMeta;

  /// Default `cache` of the pages below (a page's own wins).
  final Duration? cache;

  /// Default `cacheControl` of the pages below (see [PageRoute.cacheControl]).
  final CacheControl? cacheControl;

  /// Default `personalized` of the pages below (see [PageRoute.personalized]).
  final bool? personalized;

  /// Default `prerender` of the pages below.
  final bool? prerender;

  /// Default `earlyHints` of the pages below (see [PageRoute.earlyHints]).
  final bool? earlyHints;

  /// Default `prefetch` of the pages below (see [PageRoute.prefetch]): `false`
  /// takes a whole section out of speculation (an admin area).
  final bool? prefetch;

  /// Pages and nested layouts.
  final List<RouteNode<P>> children;

  /// Runs [load] (typed).
  Future<Object?> runLoad(PageRequest request) async =>
      load == null ? null : await load!(request);

  /// Whether [load] is declared to return a [D] (`request.parent<D>()`).
  bool loads<D>() => load != null && <T>[] is List<D>;

  /// Whether [load] has no useful declared type (`dynamic`, `Object?`):
  /// `parent()` checks its value instead.
  bool get loadsUntyped => load != null && <Object?>[] is List<T>;

  /// What [load] returns (for error messages).
  Type get dataType => T;

  /// Builds with an untyped state.
  P buildWith(PageState<Object?> state, P child) =>
      build(state.cast<T>(), child);

  /// Meta with an untyped state.
  PageMeta? metaWith(PageState<Object?> state) => meta?.call(state.cast<T>());
}

/// What a page (or layout) builds from.
class PageState<T> {
  /// The state of one route level.
  const PageState({
    required this.request,
    required this.data,
    this.form,
    this.status = 200,
    this.levels = const [],
    this.pageValues = const [],
  });

  /// The request.
  final PageRequest request;

  /// What this route's `load` returned.
  final T data;

  /// What the form action returned (`ActionResult.data`), after a `POST`.
  final Object? form;

  /// HTTP status of the response.
  final int status;

  /// Data of every level (layouts, then the page), root first.
  final List<Object?> levels;

  /// What the page handed its layouts (`ThorPage.forLayouts`); empty in the
  /// page's own state and in an error page.
  final List<Object> pageValues;

  /// The first value of type [V] the page handed its layouts, or null: how
  /// a layout reads what one route asks of it (hide the footer, change the
  /// width) while it builds around `child`.
  ///
  /// ```dart
  /// if (state.fromPage<HideFooter>() == null) const Footer(),
  /// ```
  // web: Flutter reads this from the route's `settings` or an inherited
  // widget below the layout; a layout here is built after the page, so it
  // reads a value the page declared by type.
  V? fromPage<V extends Object>() {
    for (final v in pageValues) {
      if (v is V) return v;
    }
    return null;
  }

  /// Path parameters (`[slug]`).
  Map<String, String> get pathParameters => request.pathParameters;

  /// The URL.
  Uri get uri => request.uri;

  /// The nearest data of type [D] in this route's chain (a layout's data
  /// seen from a page).
  D? dataOf<D>() {
    for (final d in levels.reversed) {
      if (d is D) return d;
    }
    return null;
  }

  /// This state with [data] typed as [D].
  PageState<D> cast<D>() => PageState<D>(
    request: request,
    data: data as D,
    form: form,
    status: status,
    levels: levels,
    pageValues: pageValues,
  );
}

/// State of an error page.
class ErrorState {
  /// An error with [status].
  const ErrorState({required this.request, required this.status, this.message});

  /// The request.
  final PageRequest request;

  /// HTTP status.
  final int status;

  /// Text for the user (never an exception message from a 500).
  final String? message;
}

// web: no Flutter equivalent: a Flutter app has no `<head>`. This is what
// search engines and link previews read (title, description, robots, Open
// Graph).
/// Title, description and tags of the page's `<head>`.
class PageMeta {
  /// Page metadata.
  const PageMeta({
    this.title,
    this.description,
    this.meta = const {},
    this.properties = const {},
    this.canonical,
    this.robotsMeta,
    this.titleTemplate,
    this.openGraph,
    this.jsonLd = const [],
    this.alternates,
  });

  /// `<title>`.
  final String? title;

  /// How the levels below show their [title]: `'%s · Acme'`. Applies to a
  /// title set by a page or a nested layout, not to this level's own
  /// [title] (the default). The nearest template wins.
  final String? titleTemplate;

  /// `<meta name="description">`.
  final String? description;

  /// More `<meta name=… content=…>`.
  final Map<String, String> meta;

  /// `<meta property=… content=…>` (Open Graph).
  final Map<String, String> properties;

  /// `<link rel="canonical">`.
  final RouteUrl? canonical;

  // web: no such thing in Flutter: a page is a document a crawler reads.
  /// `<meta name="robots">`, typed: `PageMeta(robotsMeta: RobotsMeta.noindex)`
  /// keeps a private page out of search results. A nearer level wins over a
  /// farther one.
  final RobotsMeta? robotsMeta;

  /// The content of `<meta name="robots">` this meta ends up with
  /// ([robotsMeta]), or null when it sets none.
  String? get robotsContent => robotsMeta?.content;

  /// Open Graph (and the matching `twitter:card`), typed. A key in
  /// [properties] wins over the same key from here.
  final OpenGraph? openGraph;

  /// Structured data: one `<script type="application/ld+json">` each (a
  /// layout's `Organization` plus a page's `Article`: the levels add up).
  /// Only JSON values; `<` is escaped so the text can't end the script.
  final List<Map<String, Object?>> jsonLd;

  /// Whether the page declares its `hreflang` alternates (one
  /// `<link rel="alternate" hreflang>` per locale of `RouteHandler(locales:)`).
  /// Null leaves the default: yes for a page that answers 200, no for an
  /// error page (a 404 is the translation of nothing). `true` forces them
  /// on an error page, `false` takes them off a page.
  final bool? alternates;

  /// [other]'s fields over this one's.
  PageMeta merge(PageMeta? other) => other == null
      ? this
      : PageMeta(
          title: other.title ?? title,
          description: other.description ?? description,
          meta: {...meta, ...other.meta},
          properties: {...properties, ...other.properties},
          canonical: other.canonical ?? canonical,
          // The nearest level that says anything about robots wins whole.
          robotsMeta: other.robotsContent != null
              ? other.robotsMeta
              : robotsMeta,
          titleTemplate: other.titleTemplate ?? titleTemplate,
          openGraph: openGraph == null
              ? other.openGraph
              : openGraph!.merge(other.openGraph),
          jsonLd: [...jsonLd, ...other.jsonLd],
          alternates: other.alternates ?? alternates,
        );

  /// This meta with [title] shown through [template] (`%s` → the title).
  PageMeta templated(String? template) => template == null || title == null
      ? this
      : PageMeta(
          title: template.replaceAll('%s', title!),
          description: description,
          meta: meta,
          properties: properties,
          canonical: canonical,
          robotsMeta: robotsMeta,
          titleTemplate: titleTemplate,
          openGraph: openGraph,
          jsonLd: jsonLd,
          alternates: alternates,
        );
}

/// What crawlers may do with a page: `<meta name="robots">`.
///
/// ```dart
/// PageMeta(robotsMeta: RobotsMeta.noindex)
/// PageMeta(robotsMeta: RobotsMeta(index: true, follow: false))
/// ```
// web: no such thing in Flutter.
class RobotsMeta {
  /// Directives; by default a page may be indexed and its links followed.
  const RobotsMeta({
    this.index = true,
    this.follow = true,
    this.explicitFollow = false,
    this.noArchive = false,
    this.noSnippet = false,
    this.noImageIndex = false,
    this.other = const [],
  });

  /// Keep the page out of search results (`noindex`; `follow` is the
  /// default and is left out, see [explicitFollow]).
  static const noindex = RobotsMeta(index: false);

  /// Keep the page out of search results and say that its links count
  /// (`noindex, follow`).
  static const noindexFollow = RobotsMeta(index: false, explicitFollow: true);

  /// Keep the page out of search results and do not follow its links.
  static const none = RobotsMeta(index: false, follow: false);

  /// Reads the content of a `robots` meta (`'noindex, nofollow'`). A
  /// directive it does not know goes to [other].
  factory RobotsMeta.parse(String? content) {
    var index = true;
    var follow = true;
    var explicitFollow = false;
    var noArchive = false;
    var noSnippet = false;
    var noImageIndex = false;
    final other = <String>[];
    for (final raw in (content ?? '').split(',')) {
      final t = raw.trim();
      switch (t.toLowerCase()) {
        case '':
          break;
        case 'index':
          index = true;
        case 'noindex':
          index = false;
        case 'follow':
          follow = true;
          explicitFollow = true;
        case 'nofollow':
          follow = false;
        case 'none':
          index = false;
          follow = false;
        case 'noarchive':
          noArchive = true;
        case 'nosnippet':
          noSnippet = true;
        case 'noimageindex':
          noImageIndex = true;
        default:
          other.add(t);
      }
    }
    return RobotsMeta(
      index: index,
      follow: follow,
      explicitFollow: explicitFollow,
      noArchive: noArchive,
      noSnippet: noSnippet,
      noImageIndex: noImageIndex,
      other: other,
    );
  }

  /// Whether the page may be indexed (`index` / `noindex`).
  final bool index;

  /// Whether its links may be followed (`follow` / `nofollow`).
  final bool follow;

  /// Whether `follow` is written out when it is the default: a `noindex`
  /// page then says `noindex, follow`, as some sites and tools expect. An
  /// `index` page always says `index, follow`.
  final bool explicitFollow;

  /// `noarchive`: no cached copy.
  final bool noArchive;

  /// `nosnippet`: no text excerpt in the results.
  final bool noSnippet;

  /// `noimageindex`: do not index the page's images.
  final bool noImageIndex;

  /// Any other directive, as written (`max-snippet:50`).
  final List<String> other;

  /// The same directives with the given changes.
  RobotsMeta copyWith({bool? index, bool? follow}) => RobotsMeta(
    index: index ?? this.index,
    follow: follow ?? this.follow,
    explicitFollow: explicitFollow,
    noArchive: noArchive,
    noSnippet: noSnippet,
    noImageIndex: noImageIndex,
    other: other,
  );

  /// The value of the `content` attribute: `follow` is the default, so a
  /// `noindex` page says just that.
  String get content => [
    index ? 'index' : 'noindex',
    if (!follow) 'nofollow' else if (index || explicitFollow) 'follow',
    if (noArchive) 'noarchive',
    if (noSnippet) 'nosnippet',
    if (noImageIndex) 'noimageindex',
    ...other,
  ].join(', ');

  @override
  String toString() => content;
}

/// The Open Graph tags of a page (`og:*`), plus `twitter:card`.
class OpenGraph {
  /// Open Graph data; unset fields are left out.
  const OpenGraph({
    this.title,
    this.description,
    this.url,
    this.image,
    this.imageAlt,
    this.type,
    this.siteName,
    this.locale,
    this.twitterCard,
  });

  /// `og:title`.
  final String? title;

  /// `og:description`.
  final String? description;

  /// `og:url` (absolute).
  final String? url;

  /// `og:image` (absolute).
  final String? image;

  /// `og:image:alt`.
  final String? imageAlt;

  /// `og:type` (`website`, `article`…).
  final String? type;

  /// `og:site_name`.
  final String? siteName;

  /// `og:locale` (`es_MX`).
  final Locale? locale;

  /// `twitter:card` (`summary`, `summary_large_image`).
  final String? twitterCard;

  /// [other]'s fields over this one's.
  OpenGraph merge(OpenGraph? other) => other == null
      ? this
      : OpenGraph(
          title: other.title ?? title,
          description: other.description ?? description,
          url: other.url ?? url,
          image: other.image ?? image,
          imageAlt: other.imageAlt ?? imageAlt,
          type: other.type ?? type,
          siteName: other.siteName ?? siteName,
          locale: other.locale ?? locale,
          twitterCard: other.twitterCard ?? twitterCard,
        );

  /// `<meta property=…>` pairs.
  Map<String, String> get properties => {
    'og:title': ?title,
    'og:description': ?description,
    'og:url': ?url,
    'og:image': ?image,
    'og:image:alt': ?imageAlt,
    'og:type': ?type,
    'og:site_name': ?siteName,
    'og:locale': ?locale?.toString(),
  };
}
