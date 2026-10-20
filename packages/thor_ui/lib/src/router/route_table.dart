import 'dart:async';
import 'dart:collection';

import 'package:thor_server/thor_server.dart';

import '../../router.dart' show routeLayout, routePage;
import '../core/core.dart';
import '../foundation/css_rules.dart' show StyleRule;
import '../foundation/errors.dart';
import '../foundation/page_navigation.dart' show PageTransition;
import '../foundation/style_registry.dart' show PageTransitionScope;
import 'page_actions.dart' show notePage, notePageRoute, pageActionMethods;

/// A page: what a [ThorRoute] shows.
///
/// [T] is what [load] returns and what [build] and [meta] read in
/// `state.data`; the compiler checks the three agree. A page without data
/// extends `ThorPage<void>` and has no [load].
///
/// ```dart
/// class ArticlePage extends ThorPage<Article> {
///   const ArticlePage() : super(cache: const Duration(minutes: 1));
///
///   @override
///   Future<Article> load(PageRequest request) =>
///       api.article(request.param('slug'));
///
///   @override
///   PageMeta meta(PageState<Article> state) =>
///       PageMeta(title: state.data.title);
///
///   @override
///   Widget build(BuildContext context, PageState<Article> state) => …;
/// }
/// ```
///
/// A page is one `const` instance the route table holds and every request
/// shares: keep per-request values in [load], never in fields. Its
/// settings ([cache], [personalized], [prerender], [earlyHints]) go in the
/// `super(…)` call as constants (`const Duration(…)`: a const
/// constructor's initializers are not a const context).
abstract class ThorPage<T> {
  /// A page with its settings.
  const ThorPage({
    this.cache,
    this.personalized,
    this.prerender,
    this.earlyHints,
    this.transition,
    this.maxBodyBytes,
    this.tags = const [],
    this.invalidateOnWrite = true,
    this.prefetch,
  });

  /// How long the rendered page stays in the shared cache (inherited from
  /// the groups above when null).
  final Duration? cache;

  /// Whether the page differs per visitor (never shared-cached).
  final bool? personalized;

  /// Whether `thor export` writes it as a static file.
  final bool? prerender;

  /// Whether a slow page answers its head first.
  final bool? earlyHints;

  /// How the page enters from another page of the app (over its layouts'
  /// and the app's `PageNavigation(transition:)`); null keeps theirs.
  final PageTransition? transition;

  /// Largest body its form actions accept, in bytes; null keeps the
  /// server's (`ThorServer(maxBodyBytes:)`, 1 MiB). Raise it only on the
  /// page that takes an upload; a bigger body is a `413`.
  ///
  /// ```dart
  /// const AvatarPage() : super(maxBodyBytes: 5 << 20);
  /// ```
  ///
  /// `// web:` Flutter has no request body to bound; here it is a
  /// page setting, checked against `Content-Length` before reading and
  /// counted while streaming.
  final int? maxBodyBytes;

  /// Whether the browser may fetch the page ahead of a click (speculation
  /// rules). `false` for a page whose `GET` is costly or has effects (a
  /// report, a logout link target): it sends no `Speculation-Rules` header
  /// and has no inline rules, so the links inside it do not prefetch.
  /// Links *to* it are kept out with `Link(prefetch: false)` or
  /// `PageNavigation(exclude:)`. `null`: the layout's, else `true`.
  final bool? prefetch;

  /// Names of the page in the shared cache: `revalidateTag('cart')` (from
  /// an action or a command) drops the pages that have the tag, in every
  /// isolate. Tags add a way to revalidate: every successful write still
  /// clears the page too, unless [invalidateOnWrite] is `false`.
  ///
  /// ```dart
  /// const CartPage() : super(cache: Duration(minutes: 5), tags: ['cart']);
  /// ```
  ///
  /// `// web:` the tags belong to the page, since the cache is of the
  /// rendered page.
  final List<String> tags;

  /// Whether a successful write clears the page from the shared cache, like
  /// every cached page. `false` (with [tags]) is an explicit opt-in for a
  /// costly page that only a known event changes: it then stays until
  /// `revalidateTag` names one of its tags or its [cache] time passes, and a
  /// write that forgot to call it leaves stale data.
  final bool invalidateOnWrite;

  /// The page's data (runs before [build] and [meta]). A page with data
  /// (`ThorPage<Article>`) must override it; a `ThorPage<void>` has none.
  FutureOr<T> load(PageRequest request) => throw StateError(
    thorError(
      'THOR-P013',
      '$runtimeType extends ThorPage<$T> but has no load: override `load` or '
          'extend `ThorPage<void>`',
    ),
  );

  /// The page, from its data.
  Widget build(BuildContext context, PageState<T> state);

  /// Title, description and the rest of the `<head>` (what it leaves
  /// null comes from the groups above).
  PageMeta meta(PageState<T> state) => const PageMeta();

  /// A path to send the visitor to instead of this page, or null (a `302`;
  /// a `303` for a form `POST`).
  ///
  /// To choose another status, throw a `Redirect` instead of returning a
  /// path: `throw Redirect.permanent('/new')` (`308`), `Redirect.temporary`
  /// (`307`) or `Redirect(path, status: 301)`. Any target is cleaned so it
  /// cannot leave the site by accident (`//host`, `/\host`).
  ///
  /// `// web:` go_router's `redirect` returns a location only; here the
  /// target can also carry the HTTP status.
  FutureOr<RouteUrl?> redirect(PageRequest request) => null;

  // Built here, where T is the page's own type (a `ThorPage<Article>` seen as
  // a `ThorPage<Object?>` would fail the runtime check of `build`).
  PageRoute<Widget, T> _route(String path) {
    // Its tear-offs are what a `Form(onPost:)` names.
    notePage(this);
    return _routeOf(path);
  }

  PageRoute<Widget, T> _routeOf(String path) => routePage<T>(
    path: path,
    load: _hasData<T>() ? load : null,
    build: transition == null
        ? build
        : (context, state) => PageTransitionScope(
            transition: transition!,
            child: build(context, state),
          ),
    actions: _PageActions(this),
    redirect: redirect,
    meta: meta,
    cache: cache,
    personalized: personalized,
    prerender: prerender,
    earlyHints: earlyHints,
    maxBodyBytes: maxBodyBytes,
    tags: tags,
    invalidateOnWrite: invalidateOnWrite,
    prefetch: prefetch,
  );
}

/// The page's actions: its registered action methods. Read from the
/// page and the registry on every use: the table is built once, and a hot
/// reload (`thor dev`) that adds or changes an action must reach the next
/// POST, like `build` (a tear-off) does.
final class _PageActions extends UnmodifiableMapBase<String, FormAction> {
  _PageActions(this._page);

  final ThorPage<Object?> _page;

  @override
  FormAction? operator [](Object? key) {
    for (final m in pageActionMethods(_page)) {
      if (m.name == key) return (request) => m.run(_page, request);
    }
    return null;
  }

  @override
  Iterable<String> get keys => {
    for (final m in pageActionMethods(_page)) m.name,
  };

  @override
  bool get isEmpty => pageActionMethods(_page).isEmpty;

  @override
  bool containsKey(Object? key) =>
      pageActionMethods(_page).any((m) => m.name == key);
}

/// A layout: the frame a [Group] puts around its pages ([build]'s
/// `child`). Like [ThorPage]: [T] is its [load]'s data (a page below reads it
/// with `request.parent<T>()`), one const instance, settings in
/// `super(…)`; the pages below inherit them.
abstract class ThorLayout<T> {
  /// A layout with its settings.
  const ThorLayout({
    this.cache,
    this.personalized,
    this.prerender,
    this.earlyHints,
    this.transition,
    this.prefetch,
  });

  /// See [ThorPage.cache]: the pages below inherit it.
  final Duration? cache;

  /// See [ThorPage.personalized]: the pages below inherit it.
  final bool? personalized;

  /// See [ThorPage.prerender]: the pages below inherit it.
  final bool? prerender;

  /// See [ThorPage.earlyHints]: the pages below inherit it.
  final bool? earlyHints;

  /// See [ThorPage.prefetch]: the pages below inherit it (a page's own wins).
  /// `false` takes the whole section out of speculation.
  final bool? prefetch;

  /// How the pages below enter (a page's own [ThorPage.transition] wins).
  final PageTransition? transition;

  /// The layout's data; a `ThorLayout<void>` has none.
  FutureOr<T> load(PageRequest request) => throw StateError(
    thorError(
      'THOR-P013',
      '$runtimeType extends ThorLayout<$T> but has no load: override `load` or '
          'extend `ThorLayout<void>`',
    ),
  );

  /// The frame around [child], the page.
  Widget build(BuildContext context, PageState<T> state, Widget child);

  /// The `<head>` values the pages below start from.
  PageMeta meta(PageState<T> state) => const PageMeta();

  /// A path to send the visitor to instead of any page below, or null.
  FutureOr<RouteUrl?> redirect(PageRequest request) => null;

  LayoutRoute<Widget, T> _route(
    Group group,
    List<RouteNode<Widget>> children,
    String path,
  ) => routeLayout<T>(
    path: path,
    load: _hasData<T>() ? load : null,
    build: transition == null
        ? build
        : (context, state, child) => PageTransitionScope(
            transition: transition!,
            child: build(context, state, child),
          ),
    redirect: redirect,
    meta: meta,
    error: group.error?.build,
    notFound: group.notFound?.build,
    errorMeta: group.error?.meta,
    notFoundMeta: group.notFound?.meta,
    middleware: chainMiddleware(group.middleware, owner: group._owner),
    styles: group.styles,
    cache: group.cache ?? cache,
    personalized: group.personalized ?? personalized,
    prerender: group.prerender ?? prerender,
    earlyHints: group.earlyHints ?? earlyHints,
    prefetch: group.prefetch ?? prefetch,
    children: children,
  );
}

/// The page a [Group] shows when something below it fails: a `NotFound`
/// from a `load`, a URL with no route, an exception. Like [ThorPage] and
/// [ThorLayout], one const instance in the table; it renders inside the
/// group's layout, with the failure in [ErrorState] (`status`,
/// `message`).
///
/// ```dart
/// class AppErrorPage extends ErrorPage {
///   const AppErrorPage();
///
///   @override
///   Widget build(BuildContext context, ErrorState state) => Text(
///     state.status == 404 ? 'We could not find that page' : 'Something went wrong',
///   );
/// }
///
/// Group(layout: const AppLayout(), error: const AppErrorPage(), children: …)
/// ```
abstract class ErrorPage {
  /// An error page.
  const ErrorPage();

  /// The page for the failure in [state].
  Widget build(BuildContext context, ErrorState state);

  /// The `<head>` of this page: a title that says what failed
  /// (`PageMeta(title: 'Page not found')`), a description, `robots`.
  /// It goes over the default (`title: '404'`). An error page declares no
  /// `hreflang` alternates unless `PageMeta(alternates: true)`.
  ///
  /// ```dart
  /// @override
  /// PageMeta meta(ErrorState state) => PageMeta(
  ///   title: state.status == 404 ? 'Page not found' : 'Error',
  /// );
  /// ```
  PageMeta meta(ErrorState state) => const PageMeta();
}

/// A node of the route table ([ThorRouter]): a [ThorRoute], a [Group], a
/// [SitemapRoute] or a [RobotsRoute].
sealed class RouteTableNode {
  const RouteTableNode();
}

/// A page at a URL: `ThorRoute('/article/:slug', const ArticlePage())`.
///
/// The path is the whole URL (a [Group] adds nothing to it): static
/// segments, `:name` (a segment, a `String`), `:name:int` (an `int`: any
/// other value is a 404 before a `load` runs) and a last `*name` (the rest
/// of the path). The page reads them with `request.param('slug')` and
/// `request.paramInt('id')`.
///
/// Keep the route in a top-level `final` and link to it with [link]: the
/// table and every link share one definition of the URL.
///
/// ```dart
/// final articleRoute = ThorRoute('/article/:slug', const ArticlePage());
/// Link(href: articleRoute.link({'slug': article.slug}), child: …)
/// ```
final class ThorRoute<T> extends RouteTableNode {
  /// [page] at [path]. A malformed [path] is THOR-P014 (at startup, where
  /// the table is built).
  ThorRoute(this.path, this.page, {this.middleware = const []})
    : methods = const {},
      _segments = _parse(path);

  /// A route that answers something other than a page (JSON, bytes, a
  /// file made on demand): [respond] gets the request (its [path]
  /// parameters included) and returns a `ThorResponse`, usually
  /// `ThorResponse.json(…)` or `ThorResponse.bytes(…)` with their `ETag` and
  /// `Cache-Control`. The middleware and guards of its groups run around it;
  /// there is no `load`, no render and no page cache. It answers `GET` and
  /// `HEAD`, plus the [methods] it names (any other is a `405` with an
  /// `Allow` header). It is no page: not in [ThorRouter.pages], the sitemap
  /// or `thor export`.
  ///
  /// ```dart
  /// final itemRoute = ThorRoute<void>.resource(
  ///   '/api/items/:id:int',
  ///   (request) async => ThorResponse.json(
  ///     await items.find(request.paramInt('id')),
  ///     maxAge: const Duration(minutes: 1),
  ///   ),
  /// );
  /// ```
  ///
  /// A route that takes a body (a JSON API) names its [methods]; the handler
  /// reads it with `request.text()`, `request.bytes()` or `request.form()`.
  /// A `POST` keeps the same-origin check of a form `POST` (a cross-site one
  /// is a `403`; a client with no `Origin` header, like `curl`, passes).
  ///
  /// ```dart
  /// final agentRoute = ThorRoute<void>.resource(
  ///   '/api/agent/:tool',
  ///   (request) async => ThorResponse.json(
  ///     await agent.run(request.param('tool'), jsonDecode(await request.text())),
  ///   ),
  ///   methods: {HttpMethod.post},
  /// );
  /// ```
  ///
  /// `// web:` no Flutter counterpart: an HTTP endpoint that lives next to
  /// the pages.
  ThorRoute.resource(
    this.path,
    FutureOr<ThorResponse> Function(PageRequest request) respond, {
    this.methods = const {},
    this.middleware = const [],
  }) : page = _ResourcePage<T>(respond),
       _segments = _parse(path);

  /// A server-sent events endpoint (`text/event-stream`): [events] returns
  /// the stream for each request, and every [ServerEvent] reaches the
  /// browser's `EventSource` as it is added. A `: heartbeat` comment every
  /// [heartbeat] of silence keeps proxies from closing the connection.
  /// When the client leaves, the subscription to [events] is cancelled at
  /// once: an `async*` function's `finally` runs. Read `Last-Event-ID`
  /// from `request.headers` to resume.
  ///
  /// ```dart
  /// ThorRoute<void>.stream('/events', (request) async* {
  ///   await for (final order in orders.created()) {
  ///     yield ServerEvent(jsonEncode(order), event: 'order');
  ///   }
  /// });
  /// ```
  ///
  /// `// web:` Flutter's `Stream`/`StreamBuilder` over a socket; here the
  /// browser's own `EventSource` (reconnects by itself) over plain HTTP.
  ThorRoute.stream(
    String path,
    Stream<ServerEvent> Function(PageRequest request) events, {
    Duration heartbeat = const Duration(seconds: 15),
    List<Middleware> middleware = const [],
  }) : this.resource(
         path,
         (request) =>
             ThorResponse.events(events(request), heartbeat: heartbeat),
         middleware: middleware,
       );

  /// The methods besides `GET` and `HEAD` a [ThorRoute.resource] answers
  /// (empty for a page and for a resource that only reads).
  final Set<HttpMethod> methods;

  /// The URL pattern (`/article/:slug`).
  final String path;

  /// What it shows.
  final ThorPage<T> page;

  /// Runs around every request to this route, left to right, after the
  /// middleware of its groups (`[requireRole('admin')]`).
  final List<Middleware> middleware;

  final List<_Segment> _segments;

  /// The names of its parameters, in order (`['slug']`).
  List<String> get params => [
    for (final s in _segments)
      if (s.kind != _Kind.static) s.name,
  ];

  /// The URL of this route with [values] for its parameters (and an
  /// optional [query]), each segment encoded. A missing or unknown
  /// parameter, or a value of the wrong type (`:id:int` takes an `int`), is
  /// THOR-P014.
  ///
  /// A [query] value is a `String` or, for a repeated key
  /// (`?f=a&f=b`), an `Iterable<String>` (an empty one writes nothing);
  /// the server reads them back with `request.queryParametersAll`.
  ///
  /// ```dart
  /// searchRoute.link({}, {'q': 'shoes', 'f': ['red', 'size-9']})
  /// // /search?q=shoes&f=red&f=size-9
  /// ```
  RouteUrl link([
    Map<String, Object> values = const {},
    Map<String, Object>? query,
  ]) {
    final unknown = values.keys.where((k) => !params.contains(k)).toList();
    if (unknown.isNotEmpty) {
      throw ArgumentError(
        thorError(
          'THOR-P014',
          '$path has no ${unknown.map((k) => ':$k').join(', ')}',
        ),
      );
    }
    final out = StringBuffer();
    for (final s in _segments) {
      out.write('/');
      switch (s.kind) {
        case _Kind.static:
          out.write(Uri.encodeComponent(s.name));
        case _Kind.string || _Kind.integer || _Kind.rest:
          final value =
              values[s.name] ??
              (throw ArgumentError(
                thorError('THOR-P014', '$path needs :${s.name}'),
              ));
          if (s.kind == _Kind.integer && value is! int) {
            throw ArgumentError(
              thorError(
                'THOR-P014',
                ':${s.name} of $path is an int, not ${value.runtimeType}',
              ),
            );
          }
          if (s.kind != _Kind.integer && value is! String) {
            throw ArgumentError(
              thorError(
                'THOR-P014',
                ':${s.name} of $path is a String, not ${value.runtimeType}',
              ),
            );
          }
          out.write(
            s.kind == _Kind.rest
                ? (value as String)
                      .split('/')
                      .map(Uri.encodeComponent)
                      .join('/')
                : Uri.encodeComponent('$value'),
          );
      }
    }
    final url = out.isEmpty ? '/' : '$out';
    final pairs = <String, Iterable<String>>{};
    for (final MapEntry(:key, :value)
        in query?.entries ?? const <MapEntry<String, Object>>[]) {
      pairs[key] = switch (value) {
        final String v => [v],
        final Iterable<String> v => v,
        _ => throw ArgumentError(
          thorError(
            'THOR-P014',
            'query "$key" of $path is a String or an Iterable<String>, '
                'not ${value.runtimeType}',
          ),
        ),
      };
    }
    pairs.removeWhere((_, v) => v.isEmpty);
    return RouteUrl(
      pairs.isEmpty ? url : '$url?${Uri(queryParameters: pairs).query}',
    );
  }

  /// Whether [urlPath] (a request's path) is a URL of this route.
  bool _matches(String urlPath) {
    final parts = [
      for (final p in urlPath.split('/'))
        if (p.isNotEmpty) _decode(p),
    ];
    for (final (i, s) in _segments.indexed) {
      if (s.kind == _Kind.rest) return parts.length > i;
      if (i >= parts.length) return false;
      if (s.kind == _Kind.static && parts[i] != s.name) return false;
      if (s.kind == _Kind.integer && !_isInt(parts[i])) return false;
    }
    return parts.length == _segments.length;
  }

  RouteNode<Widget> _node(int base) {
    final segments = _serverSegments.skip(base).join('/');
    final resource = page;
    final RouteNode<Widget> route = resource is _ResourcePage<T>
        ? ResourceRoute<Widget>(
            path: segments,
            respond: resource.respond,
            methods: methods,
          )
        : page._route(segments);
    final chain = chainMiddleware(middleware, owner: "ThorRoute('$path')");
    // Its own middleware: [a] node around it that adds no UI.
    return chain == null
        ? route
        : routeLayout<void>(middleware: chain, children: [route]);
  }

  // The router's pattern: `article/[slug]`, `item/[id=int]`,
  // `docs/[...rest]`.
  late final List<String> _serverSegments = [
    for (final s in _segments)
      switch (s.kind) {
        _Kind.static => s.name,
        _Kind.string => '[${s.name}]',
        _Kind.integer => '[${s.name}=int]',
        _Kind.rest => '[...${s.name}]',
      },
  ];

  static List<_Segment> _parse(String path) {
    Never bad(String why) =>
        throw ArgumentError(thorError('THOR-P014', 'ThorRoute($path): $why'));
    if (!path.startsWith('/')) bad('a path starts with /');
    if (path == '/') return const [];
    final parts = path.substring(1).split('/');
    final names = <String>{};
    final segments = <_Segment>[];
    for (final (i, part) in parts.indexed) {
      if (part.isEmpty) bad('an empty segment (//)');
      final _Segment segment;
      if (part.startsWith(':') || part.startsWith('*')) {
        final rest = part.startsWith('*');
        final spec = part.substring(1).split(':');
        final name = spec.first;
        if (!RegExp(r'^[A-Za-z_]\w*$').hasMatch(name)) {
          bad('`$part`: a parameter name is an identifier');
        }
        if (!names.add(name)) bad(':$name twice');
        if (rest && i != parts.length - 1) bad('*$name must be the last');
        final type = spec.length > 1 ? spec[1] : null;
        if (spec.length > 2 || (type != null && (type != 'int' || rest))) {
          bad('`$part`: the only parameter type is :name:int');
        }
        segment = _Segment(
          name,
          rest
              ? _Kind.rest
              : type == 'int'
              ? _Kind.integer
              : _Kind.string,
        );
      } else {
        if (RegExp(r'[\[\]()*:]').hasMatch(part)) {
          bad('`$part`: a static segment has no [ ] ( ) * or :');
        }
        segment = _Segment(part, _Kind.static);
      }
      segments.add(segment);
    }
    return segments;
  }
}

/// Routes that share what a folder used to give: a [layout] around them,
/// a [middleware], the [error] and [notFound] pages, a stylesheet
/// ([styles]) and settings the pages below inherit. It adds nothing to
/// the URL.
///
/// ```dart
/// Group(
///   layout: const AppLayout(),
///   middleware: [session],
///   notFound: const NotFoundPage(),
///   children: [homeRoute, articleRoute,
///     Group(middleware: [requireUser], children: [editorRoute])],
/// )
/// ```
final class Group extends RouteTableNode {
  /// Routes and groups with what they share.
  const Group({
    this.layout,
    this.prefix,
    this.middleware = const [],
    this.error,
    this.notFound,
    this.styles,
    this.cache,
    this.personalized,
    this.prerender,
    this.earlyHints,
    this.prefetch,
    required this.children,
  });

  /// The frame around every page below.
  final ThorLayout<Object?>? layout;

  /// The URLs the group owns (`'/item'`): its 404 and its layout answer
  /// under them, with their parameters (`'/profile/:user'`). Every route
  /// below must start with it (THOR-P014). `null`: the part of the URL all
  /// its routes share. It adds nothing to the routes' URLs.
  final String? prefix;

  /// Runs around every request to the routes below, left to right; an
  /// outer group's before an inner one's, and those before a route's own.
  /// The chain is built once, with the table (`chainMiddleware`).
  final List<Middleware> middleware;

  // Where the list is, for an error's message (THOR-P016).
  String get _owner => layout != null
      ? 'Group(layout: ${layout.runtimeType})'
      : 'Group(${[for (final c in children)
          if (c is ThorRoute) c.path].take(2).join(', ')})';

  /// The page for errors below (the nearest group's wins).
  final ErrorPage? error;

  /// The page for URLs with no route below (default: [error]).
  final ErrorPage? notFound;

  /// The stylesheet of the pages below (after the groups' above).
  final List<StyleRule>? styles;

  /// See [ThorPage.cache] (wins over the layout's).
  final Duration? cache;

  /// See [ThorPage.personalized] (wins over the layout's).
  final bool? personalized;

  /// See [ThorPage.prerender] (wins over the layout's).
  final bool? prerender;

  /// See [ThorPage.earlyHints] (wins over the layout's).
  final bool? earlyHints;

  /// See [ThorPage.prefetch] (wins over the layout's).
  final bool? prefetch;

  /// What it holds.
  final List<RouteTableNode> children;
}

/// `/sitemap.xml`, from [sitemap] (only in the table's top level).
final class SitemapRoute extends RouteTableNode {
  /// The sitemap [sitemap] returns for each request.
  const SitemapRoute(this.sitemap);

  /// The sitemap.
  final FutureOr<Sitemap> Function(PageRequest request) sitemap;
}

/// `/robots.txt`, from [robots] (only in the table's top level).
final class RobotsRoute extends RouteTableNode {
  /// The robots rules [robots] returns for each request.
  const RobotsRoute(this.robots);

  /// The rules.
  final FutureOr<Robots> Function(PageRequest request) robots;
}

/// The app's routes, written in code: what `RouteHandler(routes:)` serves.
///
/// ```dart
/// final homeRoute = ThorRoute('/', const HomePage());
/// final articleRoute = ThorRoute('/article/:slug', const ArticlePage());
///
/// final router = ThorRouter([
///   Group(layout: const AppLayout(), notFound: const NotFoundPage(), children: [
///     homeRoute,
///     articleRoute,
///   ]),
/// ]);
///
/// RouteHandler(routes: router.routes, renderer: WidgetRenderer())
/// ```
///
/// Nothing is generated: the table is the source of truth, checked when
/// it is built (a malformed path is THOR-P014, two routes for the same URL
/// THOR-P001).
final class ThorRouter {
  /// The table of [children]. Its languages, theme and navigation are the
  /// app's (`ThorApp.router(routerConfig: router, supportedLocales: …)`).
  ThorRouter(this.children) {
    for (final c in children) {
      if (c is SitemapRoute || c is RobotsRoute) continue;
      _collect(c, pages);
    }
    routes = [for (final c in children) ..._nodes(c, 0)];
  }

  /// What the app wrote.
  final List<RouteTableNode> children;

  /// Every [ThorRoute], in table order.
  final pages = <ThorRoute<Object?>>[];

  /// The router's tree (what `RouteHandler(routes:)` takes).
  late final List<RouteNode<Widget>> routes;

  /// The paths of the routes without parameters (a sitemap starts here).
  List<String> get staticPaths => [
    for (final r in pages)
      if (r.params.isEmpty) r.path,
  ];

  static void _collect(RouteTableNode node, List<ThorRoute<Object?>> into) {
    switch (node) {
      case ThorRoute() when node.page is _ResourcePage:
        // An endpoint, not a page: no sitemap, no export, no page links.
        break;
      case ThorRoute():
        into.add(node);
        notePageRoute(node.page, (
          path: node.path,
          hasParams: node.params.isNotEmpty,
          matches: node._matches,
        ), owner: into);
      case Group(:final children):
        for (final c in children) {
          _collect(c, into);
        }
      case SitemapRoute() || RobotsRoute():
        throw ArgumentError(
          thorError(
            'THOR-P014',
            'SitemapRoute and RobotsRoute go in the top level of '
                'ThorRouter([…])',
          ),
        );
    }
  }

  // Each group's node takes the URL segments all its routes share (their
  // common prefix), and its children are relative to it: the tree folders
  // gave. A group's 404 then owns the URLs under that prefix, with its
  // parameters (`/profile/:user/…` reaches the layout that loads the user).
  static List<RouteNode<Widget>> _nodes(RouteTableNode node, int base) =>
      switch (node) {
        ThorRoute() => [node._node(base)],
        Group() => [_group(node, base)],
        SitemapRoute(:final sitemap) => [
          ResourceRoute<Widget>.sitemap(sitemap),
        ],
        RobotsRoute(:final robots) => [ResourceRoute<Widget>.robots(robots)],
      };

  static RouteNode<Widget> _group(Group group, int base) {
    final prefix = _prefixOf(group);
    final length = prefix == null || prefix.length < base
        ? base
        : prefix.length;
    final path = prefix == null ? '' : prefix.sublist(base, length).join('/');
    final children = [for (final c in group.children) ..._nodes(c, length)];
    final layout = group.layout;
    if (layout != null) return layout._route(group, children, path);
    return routeLayout<void>(
      path: path,
      error: group.error?.build,
      notFound: group.notFound?.build,
      errorMeta: group.error?.meta,
      notFoundMeta: group.notFound?.meta,
      middleware: chainMiddleware(group.middleware, owner: group._owner),
      styles: group.styles,
      cache: group.cache,
      personalized: group.personalized,
      prerender: group.prerender,
      earlyHints: group.earlyHints,
      prefetch: group.prefetch,
      children: children,
    );
  }
}

/// The segments a group owns: its [Group.prefix], checked against its
/// routes, else the ones they share.
List<String>? _prefixOf(Group group) {
  final declared = group.prefix;
  final shared = _commonPrefix(group);
  if (declared == null) return shared;
  final segments = ThorRoute(declared, const _NoPage())._serverSegments;
  final ok =
      shared != null &&
      segments.length <= shared.length &&
      [
        for (var i = 0; i < segments.length; i++) segments[i] == shared[i],
      ].every((b) => b);
  if (!ok) {
    throw ArgumentError(
      thorError(
        'THOR-P014',
        "Group(prefix: '$declared'): not a prefix of every route below it",
      ),
    );
  }
  return segments;
}

/// What `ThorRoute.resource` holds in place of a page.
class _ResourcePage<T> extends ThorPage<T> {
  const _ResourcePage(this.respond);

  final FutureOr<ThorResponse> Function(PageRequest request) respond;

  @override
  Widget build(BuildContext context, PageState<T> state) =>
      throw StateError('a resource route has no page');
}

class _NoPage extends ThorPage<void> {
  const _NoPage();

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      throw UnimplementedError();
}

/// The URL segments every route under [node] starts with; null without
/// routes. A rest segment (`*x`) is never shared: it stays with its route.
List<String>? _commonPrefix(RouteTableNode node) {
  switch (node) {
    case ThorRoute():
      final segments = node._serverSegments;
      return segments.isNotEmpty && segments.last.startsWith('[...')
          ? segments.sublist(0, segments.length - 1)
          : segments;
    case Group():
      List<String>? common;
      for (final c in node.children) {
        final p = _commonPrefix(c);
        if (p == null) continue;
        if (common == null) {
          common = p;
          continue;
        }
        var i = 0;
        while (i < common.length && i < p.length && common[i] == p[i]) {
          i++;
        }
        common = common.sublist(0, i);
      }
      return common;
    case SitemapRoute() || RobotsRoute():
      return null;
  }
}

enum _Kind { static, string, integer, rest }

final class _Segment {
  const _Segment(this.name, this.kind);
  final String name;
  final _Kind kind;
}

String _decode(String part) {
  try {
    return Uri.decodeComponent(part);
  } on ArgumentError {
    return part;
  } on FormatException {
    return part; // invalid UTF-8: matched as written, like the server
  }
}

/// An `int` segment as the server's router reads it: an optional `-` and
/// digits only (`int.tryParse` alone also takes `+5` and `0x1F`).
bool _isInt(String s) {
  final digits = s.startsWith('-') ? s.substring(1) : s;
  if (digits.isEmpty) return false;
  for (final c in digits.codeUnits) {
    if (c < 0x30 || c > 0x39) return false;
  }
  return int.tryParse(s) != null;
}

// Whether a route type carries data: `ThorPage<void>` (and a raw `ThorPage`) has
// no `load`.
bool _hasData<T>() => T != _typeOf<void>() && T != dynamic && T != Null;

Type _typeOf<X>() => X;
