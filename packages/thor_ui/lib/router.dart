/// Routes, server data and form actions for widget pages: the widget side of
/// `package:thor_server`.
///
/// The routes are a table in code (`ThorRouter`, `ThorRoute`, `Group`; pages
/// are `ThorPage<T>` classes, layouts `ThorLayout<T>`), with nothing generated.
/// The server:
///
/// ```dart
/// import 'package:thor_ui/router.dart';
/// import 'router.dart'; // the app's table: `final ThorRouter router = …`
///
/// Future<void> main() => ThorServer.serve(
///   () => ThorServer(
///     handler: RouteHandler(routes: router.routes, renderer: WidgetRenderer()),
///     publicDir: 'build/web',
///   ),
/// );
/// ```
library;

import 'dart:async';
import 'dart:convert';

import 'package:thor_engine/thor_engine.dart'
    show
        ServerCommandBase,
        ServerErrorKind,
        ServerQuery,
        SignalScope,
        ThorState;
import 'package:thor_server/thor_server.dart';

import 'html.dart' as html;
import 'server.dart' show initializeThor;
import 'src/core/markup.dart' show nonceTokenZoneKey;
import 'src/core/render.dart' as core;
import 'src/foundation/builder_errors.dart';
import 'src/foundation/css_rules.dart' show StyleRule, renderStyleRules;
import 'src/foundation/deferred.dart'
    show DeferHolder, DeferRun, DeferScope, lazyFragment, lazyPieceParameter;
import 'src/foundation/errors.dart';
import 'src/foundation/image_manifest_scope.dart';
import 'src/foundation/image_preload.dart';
import 'src/foundation/inspect.dart';
import 'src/foundation/localizations.dart' show Locale, PreferredLocales;
import 'src/foundation/material_localizations.dart' show ThorLocalizations;
import 'src/foundation/page_navigation.dart'
    show
        PageNavigation,
        RoutedPageScope,
        SpeculationDelivery,
        noPrefetchZoneKey;
import 'src/foundation/request_scope.dart' show RequestScope;
import 'src/foundation/style_registry.dart'
    show
        LinkedStyleSheet,
        ModuleSheet,
        ModuleStyles,
        SharedStylesScope,
        prefetchFallbackPath,
        ThorStyleRegistry,
        thorLayerOrder,
        noteAppStylesheet;
import 'src/router/late_pieces.dart';
import 'src/widgets/feedback.dart' show FlashScope;
import 'thor_ui.dart'
    show
        BuildContext,
        Center,
        FontFace,
        StatelessWidget,
        Text,
        ThemeMode,
        ThorApp,
        Widget;

// What an app writes. Dev, export and test plumbing (`ThorDev`, `DevHosts`,
// `exportSite`, `ThorHttpTransport`, `ResponseDraft`, the router index…) is
// not re-exported: import `package:thor_server/thor_server.dart` for it.
export 'package:thor_server/thor_server.dart'
    show
        ActionMessage,
        ActionOutcome,
        ActionResult,
        ChangeFrequency,
        CommandAnswer,
        ContextKey,
        DeferredRender,
        DiscoveredLinks,
        EarlyHints,
        EnvBool,
        EnvError,
        EnvInt,
        EnvOptional,
        EnvSchema,
        EnvSecret,
        EnvString,
        EnvUrl,
        EnvValues,
        EnvVar,
        ErrorState,
        FlashKind,
        FlashMessage,
        FormAction,
        FormData,
        Guard,
        HttpError,
        ImageEntry,
        ImageManifest,
        ImageVariant,
        LayoutRoute,
        LinkHint,
        ListQuery,
        ListQueryRequest,
        Loader,
        LocaleRouting,
        LocaleStrategy,
        MemoryRateLimitStore,
        Middleware,
        MiddlewareError,
        Next,
        NotFound,
        OpenGraph,
        PageMeta,
        PageRenderer,
        PageRequest,
        PageRoute,
        PageState,
        RateLimit,
        RateLimitCount,
        RateLimitResult,
        RateLimitStore,
        Redirect,
        RenderContext,
        RequestContext,
        ResourceRoute,
        Robots,
        RobotsMeta,
        RobotsRule,
        RouteHandler,
        RouteIndex,
        RouteNode,
        Secret,
        ServerEvent,
        ServerMessages,
        SetCookie,
        SignedCookies,
        Sitemap,
        SitemapUrl,
        StaticFiles,
        HttpHeader,
        RouteUrl,
        HttpMethod,
        StatusCode,
        ThorHttpClient,
        ThorHttpResponse,
        ThorResponse,
        ThorServer,
        TooManyRequests,
        UploadedFile,
        UpstreamError,
        ContentSecurityPolicy,
        contentSecurityPolicy,
        CspHashAlgorithm,
        CspSource,
        FrameOptions,
        OpenerPolicy,
        ReferrerPolicy,
        SecurityHeaders,
        cors,
        isRtlLanguageTag,
        matchLocale,
        parseAcceptLanguage,
        parseCookies,
        parseIsoDateTime,
        revalidateTag,
        safeNext,
        securityHeaders,
        signInOn401;

export 'src/foundation/request_scope.dart' show RequestScope;
export 'src/router/form_schema.dart';
export 'src/router/locale_switcher.dart';
export 'src/router/page_actions.dart'
    show
        FormValues,
        formActionUrl,
        PageActionWithArg,
        PageActionWithArgs2,
        PageActionWithArgs3,
        PageActionMethod,
        PagePost,
        PageValidPost,
        registerPageActions;
export 'src/router/route_table.dart';
// Moved to thor_ui.dart (it is a form widget); still here for old imports.
export 'src/widgets/form.dart' show HiddenField;
// A schema field's rules: a schema file needs this import alone (the
// same declaration as thor_ui.dart's, so both together don't clash).
export 'src/widgets/form.dart' show Validator;

/// Draws widget pages as HTML documents: the only place routes meet the
/// render engine.
class WidgetRenderer
    implements
        PageRenderer<Widget>,
        RequestScopedRenderer,
        RendererAssets,
        EarlyHints,
        DeferredRender,
        DiscoveredLinks,
        ServerCommands,
        ServerCallIds {
  /// A renderer. [app] wraps every page (a `ThorApp` with the theme);
  /// [head] goes in every `<head>` (icons, fonts, stylesheets); [styles] is
  /// the app's own stylesheet (the page basics no widget covers).
  ///
  /// With [shareStyles] every page links one cached stylesheet
  /// (`/_thor/base.<hash>.css`: the app stylesheet, the theme and the
  /// classes of [specimens]) and the files of its route modules
  /// (`Group(styles:)`), and keeps inline only its own classes.
  WidgetRenderer({
    this.app,
    this.locale = const Locale('en'),
    this.head = const [],
    this.styles = const [],
    this.errorBuilder,
    this.shareStyles = false,
    this.specimens = const [],
    this.preload = const [],
    this.fonts = const [],
    this.navigation,
    ImageManifest? images,
  }) : _imagesGiven = images {
    if (!_initialized) {
      initializeThor();
      _initialized = true;
    }
  }

  /// The renderer of a [ThorApp.router]: each page drawn in [app] (its
  /// theme, locale, navigation) with its `styles`. The rest are the
  /// renderer's own options, as in the default constructor.
  WidgetRenderer.router(
    ThorApp app, {
    Locale locale = const Locale('en'),
    List<Widget> head = const [],
    Widget Function(ErrorState state)? errorBuilder,
    bool shareStyles = false,
    List<Widget> specimens = const [],
    List<LinkHint> preload = const [],
    ImageManifest? images,
  }) : this(
         app: app.page,
         styles: app.styles,
         locale: locale,
         head: head,
         errorBuilder: errorBuilder,
         shareStyles: shareStyles,
         specimens: specimens,
         preload: preload,
         fonts: _themeFonts(app),
         navigation: app.navigation,
         images: images,
       );

  static bool _initialized = false;

  /// The faces the theme [app] shows (the dark one when the app is always
  /// dark, like the page's own preloads) that ask for a `preload`.
  static List<FontFace> _themeFonts(ThorApp app) {
    final dark = app.darkTheme;
    final base = app.themeMode == ThemeMode.dark && dark != null
        ? dark
        : app.theme;
    return [
      for (final f in base?.fonts ?? const <FontFace>[])
        if (f.preload) f,
    ];
  }

  /// Wraps each page: `(page) => ThorApp(theme: lightTheme, child: page)`.
  final Widget Function(Widget page)? app;

  /// The `<html lang>` of an app in one language. With
  /// `<html lang>` of an app in one language. With
  /// `RouteHandler(locales:)` each page carries its own locale (and its
  /// `dir`, and `hreflang` alternates for the other locales).
  final Locale locale;

  /// Extra `<head>` elements for every page.
  final List<Widget> head;

  /// App stylesheet rules (`css('body').styles(...)`), in every page.
  final List<StyleRule> styles;

  // The app stylesheet never changes: serialized once, not per request.
  late final String _stylesCss = _noted(renderStyleRules(styles));

  // The theme keeps the text role variables the app stylesheet reads.
  static String _noted(String css) {
    noteAppStylesheet(css);
    return css;
  }

  /// Plain error page when no group's `error` page handles an error.
  final Widget Function(ErrorState state)? errorBuilder;

  /// Whether pages link the shared stylesheet files instead of repeating
  /// the app stylesheet, the theme and the module rules inline.
  ///
  /// `// web:` a second visit (or the next page) downloads only what is
  /// new; the first one fetches one more file, in parallel with the page.
  final bool shareStyles;

  /// Widgets drawn once, when the server starts sharing, whose classes go
  /// into the shared stylesheet: the app's components as every page uses
  /// them (`ShadButton` in each variant, the shell's sidebar). A page's
  /// element with the same style names the same class and leaves its
  /// rules out. They render in [app] with an empty request: no data.
  final List<Widget> specimens;

  /// Files every page uses and the browser should fetch before it reads
  /// the document (the fonts): in each page's `Link` header, with the
  /// shared stylesheets ([shareStyles]). See [EarlyHints].
  final List<LinkHint> preload;

  /// Font faces to preload with every page: in its `Link` header (and the
  /// early answer), next to the `<link rel=preload>` the page itself has.
  /// `WidgetRenderer.router` takes the `preload: true` faces of the app's
  /// theme; give them here when the app is built with [app].
  final List<FontFace> fonts;

  /// The app's `ThorApp(navigation:)`, for the rules a header carries
  /// ([SpeculationDelivery.header]); `WidgetRenderer.router` takes it from
  /// the app. `null`: the default [PageNavigation].
  final PageNavigation? navigation;

  PageNavigation get _navigation => navigation ?? const PageNavigation();

  // The rules file of a header delivery: named by its content.
  late final (String, List<int>)? _rulesFile = () {
    final nav = _navigation;
    final json = nav.speculationRulesJson;
    if (nav.delivery != SpeculationDelivery.header || json == null) {
      return null;
    }
    return (
      '/_thor/speculation.${ThorStyleRegistry.stableHash(json)}.json',
      utf8.encode(json),
    );
  }();

  final ImageManifest? _imagesGiven;

  /// The build's image manifest: what `Image.asset` reads for its
  /// sizes and `srcset`. Default: `THOR_IMAGES`, else `build/images.json`
  /// when the app was built, else none; under `thor dev`, read again after
  /// a hot reload (a new image in `web/images/`).
  ImageManifest get images => _imagesGiven ?? currentImageManifest();

  Future<LinkedStyleSheet?>? _sheet;

  /// The shared stylesheet, made from the code on first use (the same text
  /// on every isolate): [specimens] rendered in [app].
  // Its own scope: the first request that asks for it doesn't lend it
  // its page states.
  Future<LinkedStyleSheet?> _sharedSheet() =>
      _sheet ??= SignalScope.run<Future<LinkedStyleSheet?>>(_makeSheet);

  Future<LinkedStyleSheet?> _makeSheet() async {
    ThorStyleRegistry? captured;
    final request = PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://localhost/'),
    );
    final specimen = Widget.fragment(specimens);
    try {
      await core.renderPage(
        core.Document(
          base: null,
          body: RequestScope(
            request: request,
            child: SharedStylesScope(
              capture: (registry) => captured = registry,
              child: RoutedPageScope(child: app?.call(specimen) ?? specimen),
            ),
          ),
        ),
      );
    } on Object catch (e) {
      print(
        thorError(
          'THOR-R012',
          'WidgetRenderer(shareStyles: true): the specimens did not render '
              '($e); pages keep their styles inline',
        ),
      );
      return null;
    }
    final registry = captured;
    // No ThorApp in `app`: nothing collects classes, nothing to share.
    if (registry == null) return null;
    return LinkedStyleSheet.of(registry, _stylesCss);
  }

  @override
  Future<RendererAsset?> asset(String path) async {
    if (_rulesFile case (final href, final body) when href == path) {
      return RendererAsset('application/speculationrules+json', body);
    }
    if (path == prefetchFallbackPath(_navigation)) {
      return RendererAsset(
        'text/javascript; charset=utf-8',
        utf8.encode(_navigation.prefetchFallbackScript!),
      );
    }
    if (!shareStyles) return null;
    final sheet = await _sharedSheet();
    if (sheet != null && sheet.href == path) {
      return RendererAsset.css(sheet.css);
    }
    if (ModuleSheet.at(path) case final module?) {
      return RendererAsset.css(module.css);
    }
    return null;
  }

  /// The shared stylesheet and those of the route modules above the page
  /// (when [shareStyles]), then [preload].
  @override
  Future<List<LinkHint>> linksFor(
    PageRequest request,
    List<LayoutRoute<Object?, Object?>> layouts,
  ) async {
    final sheet = shareStyles ? await _sharedSheet() : null;
    return [
      if (sheet != null) LinkHint.style(sheet.href),
      if (shareStyles)
        for (final layout in layouts)
          if (_moduleSheets[layout] case final module?)
            LinkHint.style(module.href),
      for (final f in fonts)
        if (f.preload && !preload.any((l) => l.href == f.url))
          LinkHint.font(f.url, type: f.mimeType),
      ...preload,
      if (_rulesFile case (final href, _)) LinkHint.speculationRules(href),
    ];
  }

  @override
  Future<Iterable<String>> assetPaths() async {
    // A static export has no headers: nothing names the rules file.
    final fallback = prefetchFallbackPath(_navigation);
    if (!shareStyles) return [?fallback];
    final sheet = await _sharedSheet();
    return [?sheet?.href, for (final m in ModuleSheet.all) m.href, ?fallback];
  }

  @override
  Future<List<int>> render(Widget page, RenderContext context) {
    final values = {
      // A page that opted out of prefetch draws without its inline rules.
      if (!context.request.prefetch) noPrefetchZoneKey: true,
      // Under a Content-Security-Policy: the scripts and styles Thor writes
      // carry the placeholder the middleware turns into the request's nonce.
      nonceTokenZoneKey: ?context.cspNonceToken,
    };
    return values.isEmpty
        ? _render(page, context)
        : runZoned(() => _render(page, context), zoneValues: values);
  }

  Future<List<int>> _render(Widget page, RenderContext context) async {
    final meta = context.meta;
    final request = context.request;
    final sheet = shareStyles ? await _sharedSheet() : null;
    final requestLocale = request.locale;
    Widget content = RoutedPageScope(child: app?.call(page) ?? page);
    // The `FutureBuilder`s of the page: their futures, as this render
    // handles them (in pieces, or awaited before the page is drawn).
    final defer = DeferHolder();
    // A fragment request (`?thor-piece=id`, see `LazyPiece`): the page is drawn
    // as always, with nothing awaited (only the piece is answered).
    final lazyId = context.status == 200 ? _lazyPieceOf(request) : null;
    final deferRun = DeferRun(
      stream: context.stream || lazyId != null,
      timeout: context.deferTimeout,
      describe: (e) => _describe(e, request),
      report: context.reportDeferred,
      warn: context.devWarning,
    );
    deferRun.lazyId = lazyId;
    defer.run = deferRun;
    content = DeferScope(holder: defer, child: content);
    // What a `QueryBuilder`'s builder threw (not a read of the data) while it
    // was drawn with no data: it reaches the server's `onError` with the
    // errors of the queries.
    final builderErrors = <(Object, StackTrace)>[];
    content = BuilderErrorScope(errors: builderErrors, child: content);
    if (!images.isEmpty) {
      content = ImageManifestScope(manifest: images, child: content);
    }
    if (requestLocale != null) {
      // web: the request's locale plays the platform's preferred locales.
      content = PreferredLocales(locales: [requestLocale], child: content);
    }
    ThorStyleRegistry? registry;
    // A flash the last redirect left: this page shows it, once. A page that
    // never draws (a redirect, a prefetch the server declined) leaves it.
    final flash = FlashMessage.parse(request.frameworkCookies[flashCookie]);
    // A HEAD (a link checker, a probe) is not the visit: it leaves it too.
    if (request.method != HttpMethod.head &&
        request.frameworkCookies.containsKey(flashCookie)) {
      request.response.deleteCookie(flashCookie);
    }
    final body = RequestScope(
      request: request,
      // One document of a multi-page app: `ThorApp` fetches linked pages
      // ahead unless its `navigation` says otherwise.
      child: SharedStylesScope(
        sheet: sheet,
        files: shareStyles,
        capture: (r) => registry = r,
        // Only the answer of a failed action moves the focus to an error.
        errorFocus:
            context.status >= 400 &&
            request.method != HttpMethod.get &&
            request.method != HttpMethod.head,
        child: FlashScope(flash: flash, child: content),
      ),
    );
    // An error page is not the translation of anything: no `hreflang`
    // unless its `PageMeta.alternates` says so.
    final alternates = (meta.alternates ?? context.status < 400)
        ? request.localeRouting?.alternates(request.routePath) ?? const {}
        : const <String, String>{};
    final document = core.Document(
      // No `<base>`: relative URLs (a form's `action="?/save"`) must resolve
      // against the page's own URL.
      base: null,
      title: meta.title,
      lang: requestLocale ?? locale,
      dir: requestLocale?.textDirection.name,
      meta: {
        'description': ?meta.description,
        'robots': ?meta.robotsContent,
        'twitter:card': ?meta.openGraph?.twitterCard,
        ...meta.meta,
      },
      head: [
        // web: the app's unlayered rules (`css.states`) must find the layers
        // already ordered, or `thor.overrides` ends below `thor.props`; the
        // first appearance of a layer fixes its place, so the order is
        // stated before any app rule. The shared sheet opens with it.
        if (sheet == null && (styles.isNotEmpty || ModuleSheet.all.isNotEmpty))
          const Widget.element(
            tag: 'style',
            children: [html.RawText(thorLayerOrder)],
          ),
        ...head,
        // In the shared sheet when there is one.
        if (styles.isNotEmpty && sheet == null)
          Widget.element(tag: 'style', children: [html.RawText(_stylesCss)]),
        for (final MapEntry(:key, :value) in {
          ...?meta.openGraph?.properties,
          ...meta.properties,
        }.entries)
          html.meta(
            attributes: {
              'property': key,
              'content': _absoluteOg(key, value, request),
            },
          ),
        for (final data in meta.jsonLd)
          Widget.element(
            tag: 'script',
            attributes: const {'type': 'application/ld+json'},
            // `<` escaped: no `</script>` or `<!--` can end the block.
            children: [
              html.RawText(jsonEncode(data).replaceAll('<', r'\u003c')),
            ],
          ),
        if (meta.canonical case final href?)
          html.link(rel: 'canonical', href: href),
        for (final MapEntry(:key, :value) in alternates.entries)
          html.link(
            rel: 'alternate',
            href: value,
            attributes: {'hreflang': key},
          ),
      ],
      body: body,
    );
    // The page states the browser persisted (`state(…, cookie:)`): the
    // page draws with them, so a reload shows them without a flash.
    Future<List<int>> drawOnce() async =>
        (await (request.carriesPersistedState
                ? SignalScope.withCookies(
                    request.frameworkCookies,
                    _readPersisted,
                    () => core.renderPage(document),
                  )
                : core.renderPage(document)))
            .body;
    Future<List<int>> draw() async {
      deferRun.reset();
      var bytes = await drawOnce();
      // Not in pieces: wait for what the page defers and draw it again with
      // the values (a deferred value may hold another one).
      for (var pass = 1; !deferRun.stream && deferRun.unresolved.isNotEmpty;) {
        if (++pass > _maxDeferPasses) {
          throw StateError(
            thorError(
              'THOR-R031',
              'a FutureBuilder got a new future on every draw: create the '
                  'future in `load` (and read it in `build`), not in `build`',
            ),
          );
        }
        await deferRun.settle();
        deferRun.reset();
        bytes = await drawOnce();
      }
      return bytes;
    }

    var rendered = await draw();
    // Queries of the states the page used (`query(fn)`): run the ones this
    // request hasn't, together, then draw again with their values, so the
    // HTML and `#thor-state` carry the data. Only such pages draw twice.
    final used = registry?.usedStates ?? const {};
    final queries = ServerQuery.of(used);
    // The commands too: the handler answers one only on a route whose
    // pages use it. Drawing never runs a command.
    final commands = ServerCommandBase.of(used);
    if (queries.isNotEmpty || commands.isNotEmpty) {
      _queries[context] = {...queries.keys, ...commands.keys};
    }
    if (queries.isNotEmpty) {
      final pending = [
        for (final q in queries.values)
          // `ssr: false`: the page goes out waiting, the browser asks.
          if (!q.ran && q.ssr) q,
      ];
      if (pending.isNotEmpty) {
        final errors = <(Object, StackTrace)>[];
        await runQueryFor(
          request,
          () => Future.wait([
            for (final q in pending)
              q.prefetch((e) => _describe(e, request)).catchError((
                Object e,
                StackTrace st,
              ) {
                errors.add((e, st));
              }),
          ]),
        );
        if (errors.isNotEmpty) _queryErrors[context] = errors;
        rendered = await draw();
      }
    }
    if (builderErrors.isNotEmpty) {
      _queryErrors[context] = [...?_queryErrors[context], ...builderErrors];
    }
    if (lazyId != null) {
      final draw = deferRun.lazy;
      // What the piece holds that the page's draw didn't wait for: the
      // queries of the states it uses, run like the page's own.
      deferRun.afterLazyDraw = () async {
        final used = registry?.usedStates ?? const {};
        final queries = ServerQuery.of(used);
        final calls = {...queries.keys, ...ServerCommandBase.of(used).keys};
        if (calls.isNotEmpty) {
          _queries[context] = {...?_queries[context], ...calls};
        }
        final pending = [
          for (final q in queries.values)
            if (!q.ran && q.ssr) q,
        ];
        if (pending.isEmpty) return false;
        final errors = <(Object, StackTrace)>[];
        await runQueryFor(
          request,
          () => Future.wait([
            for (final q in pending)
              q.prefetch((e) => _describe(e, request)).catchError((
                Object e,
                StackTrace st,
              ) {
                errors.add((e, st));
              }),
          ]),
        );
        if (errors.isNotEmpty) {
          _queryErrors[context] = [...?_queryErrors[context], ...errors];
        }
        return true;
      };
      // No piece of that name on this page: nothing to answer.
      if (draw == null) throw const NotFound();
      // A fragment is no page: robots keep out of it.
      request.response.headers[const HttpHeader('x-robots-tag')] = 'noindex';
      return lazyFragment(await draw(request), nonce: context.cspNonceToken);
    }
    // The page goes out in pieces when it waits for values: the document
    // up to where they go, then each as it arrives.
    if (context.stream && deferRun.slots.isNotEmpty) {
      rendered = openShell(rendered, nonce: context.cspNonceToken);
      _late[context] = latePieces(deferRun, nonce: context.cspNonceToken);
    }
    final main = registry?.imagePreloads ?? const <ImagePreload>[];
    if (main.isNotEmpty) {
      _found[context] = [
        for (final i in main)
          LinkHint.image(
            i.href,
            srcset: i.srcset,
            sizes: i.sizes,
            type: i.type,
            media: i.media,
          ),
      ];
    }
    return rendered;
  }

  // The piece a `GET` asks for (`?thor-piece=id`), or null. A query that
  // does not decode asks for none (the page answers it as it always did).
  static String? _lazyPieceOf(PageRequest request) {
    if (request.method != HttpMethod.get) return null;
    try {
      return request.uri.queryParameters[lazyPieceParameter];
    } on FormatException {
      return null;
    }
  }

  // What each render found (its main images), by its context.
  final _found = Expando<List<LinkHint>>();

  // What follows the document of a render that waits for values, by its
  // context (taken once: see [lateOf]).
  final _late = Expando<Stream<List<int>>>();

  static const _maxDeferPasses = 8;

  @override
  Stream<List<int>>? lateOf(RenderContext context) {
    final late = _late[context];
    _late[context] = null;
    return late;
  }

  // The queries each render used, and what they threw, by its context.
  final _queries = Expando<Set<String>>();
  final _queryErrors = Expando<List<(Object, StackTrace)>>();

  /// The texts of the errors of a call: `ThorApp(serverMessages:)`, of the
  /// app this renderer draws its pages in.
  @override
  late final ServerMessages serverMessages = switch (app?.call(
    const Text(''),
  )) {
    final ThorApp a => a.serverMessages,
    _ => const ServerMessages(),
  };

  // The visitor's message and kind for a query's error: an HttpError's own
  // message, a generic one for anything else (the details go to onError and
  // the `thor dev` overlay).
  (String, ServerErrorKind) _describe(Object error, PageRequest request) {
    final messages = serverMessages.forLocale(request.locale);
    return switch (error) {
      TimeoutException() => (messages.timeout, ServerErrorKind.timeout),
      HttpError(:final message?, :final status) when error is! UpstreamError =>
        (message, ServerErrorKind.ofStatus(status)),
      HttpError(:final status) when error is! UpstreamError => (
        messages.forStatus(status),
        ServerErrorKind.ofStatus(status),
      ),
      _ => (messages.generic, ServerErrorKind.server),
    };
  }

  @override
  Set<String> queriesFound(RenderContext context) =>
      _queries[context] ?? const {};

  @override
  List<(Object, StackTrace)> queryErrorsFound(RenderContext context) =>
      _queryErrors[context] ?? const [];

  /// The generated registry's query and command fields.
  @override
  bool declaresCall(String id) => ThorState.declaresCall(id);

  @override
  Future<Object?> runQuery(PageRequest request, String id, Object? arg) {
    final query = ServerQuery.find(id);
    if (query == null) throw const NotFound();
    final Future<Object?> Function() call;
    try {
      call = query.callWith(arg);
    } on ArgumentError {
      throw HttpError(400, serverMessages.forLocale(request.locale).badRequest);
    }
    return runQueryFor(request, call);
  }

  @override
  Future<CommandAnswer> runCommand(
    PageRequest request,
    String id,
    Object? arg, {
    required Set<String> refresh,
    required Map<String, Object?> queryArgs,
  }) {
    final command = ServerCommandBase.find(id);
    if (command == null) throw const NotFound();
    // Every argument is checked before anything runs.
    final Future<Object?> Function() call;
    final queries = <String, Future<Object?> Function()>{};
    // `invalidates:` narrows them to the queries the command names.
    final only = ServerCommandBase.invalidatedBy(id);
    try {
      call = command.callWith(arg);
      for (final q in only == null ? refresh : refresh.intersection(only)) {
        final query = ServerQuery.find(q);
        if (query == null) continue;
        queries[q] = queryArgs.containsKey(q)
            ? query.callWith(queryArgs[q])
            : query.run;
      }
    } on ArgumentError {
      throw HttpError(400, serverMessages.forLocale(request.locale).badRequest);
    }
    return runQueryFor(request, () async {
      final result = await call();
      // The page's queries after the change, together; one that fails
      // gets its message and the others their values.
      final data = <String, Object?>{};
      final errors = <String, String>{};
      final kinds = <String, String>{};
      final thrown = <(Object, StackTrace)>[];
      await Future.wait([
        for (final MapEntry(key: q, value: run) in queries.entries)
          run().then(
            (v) => data[q] = v,
            onError: (Object e, StackTrace st) {
              final (message, kind) = _describe(e, request);
              errors[q] = message;
              kinds[q] = kind.name;
              thrown.add((e, st));
            },
          ),
      ]);
      return CommandAnswer(
        result: result,
        queries: data,
        errors: errors,
        kinds: kinds,
        thrown: thrown,
        writes: command.writes,
      );
    });
  }

  /// The page's main images (`Image(priority: true)`): the handler puts
  /// them in the `Link` header and learns them for the path.
  @override
  List<LinkHint> linksFound(RenderContext context) =>
      _found[context] ?? const [];

  /// Each request in its own `SignalScope`: page states written by its
  /// middleware and loads stay in it, and its render reads them.
  @override
  Future<T> inRequestScope<T>(Future<T> Function() body) =>
      SignalScope.run(body);

  @override
  Widget errorPage(ErrorState state) =>
      errorBuilder?.call(state) ??
      Center(child: _DefaultErrorTitle(state.status));
}

/// The title of the default error page, in the page's language
/// (`ThorLocalizations.notFoundTitle`, `errorPageTitle`).
class _DefaultErrorTitle extends StatelessWidget {
  const _DefaultErrorTitle(this.status);

  final int status;

  @override
  Widget build(BuildContext context) {
    final l10n = ThorLocalizations.of(context);
    return Text(
      status == 404 ? l10n.notFoundTitle : l10n.errorPageTitle(status),
    );
  }
}

/// A page route whose `build` gets a `BuildContext`, like a Flutter
/// widget's: what `ThorRouter` builds for each `ThorRoute`.
PageRoute<Widget, T> routePage<T>({
  String path = '',
  Loader<T>? load,
  required Widget Function(BuildContext context, PageState<T> state) build,
  Map<String, FormAction> actions = const {},
  Guard? redirect,
  PageMeta Function(PageState<T> state)? meta,
  Duration? cache,
  bool? personalized,
  bool? prerender,
  bool? earlyHints,
  int? maxBodyBytes,
  List<String> tags = const [],
  bool invalidateOnWrite = true,
  bool? prefetch,
}) => PageRoute<Widget, T>(
  path: path,
  load: load,
  build: (state) =>
      _WithContext((context) => build(context, state), source: build),
  actions: actions,
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

/// A layout route whose `build` gets a `BuildContext`, with the error and
/// 404 pages, the middleware and the stylesheet of its group: what
/// `ThorRouter` builds for each `Group`.
///
/// [styles] go to every page under the group, after those of the groups
/// above: a linked, cached file with `WidgetRenderer(shareStyles: true)`,
/// else a `<style>` in the page.
LayoutRoute<Widget, T> routeLayout<T>({
  String path = '',
  Loader<T>? load,
  Widget Function(BuildContext context, PageState<T> state, Widget child)?
  build,
  Guard? redirect,
  PageMeta Function(PageState<T> state)? meta,
  Widget Function(BuildContext context, ErrorState state)? error,
  Widget Function(BuildContext context, ErrorState state)? notFound,
  PageMeta Function(ErrorState state)? errorMeta,
  PageMeta Function(ErrorState state)? notFoundMeta,
  Middleware? middleware,
  List<StyleRule>? styles,
  Duration? cache,
  bool? personalized,
  bool? prerender,
  bool? earlyHints,
  bool? prefetch,
  required List<RouteNode<Widget>> children,
}) {
  // Made with the route tree (at startup): every isolate names it the same.
  final sheet = styles == null || styles.isEmpty
      ? null
      : ModuleSheet.of(styles);
  Widget styled(Widget page) =>
      sheet == null ? page : ModuleStyles(sheet: sheet, child: page);
  final route = LayoutRoute<Widget, T>(
    path: path,
    load: load,
    // A group with only an `error` page gets a layout that adds nothing.
    build: build == null
        ? (state, child) => styled(child)
        : (state, child) => styled(
            _WithContext(
              (context) => build(context, state, child),
              source: build,
            ),
          ),
    redirect: redirect,
    meta: meta,
    error: error == null
        ? null
        : (state) => styled(
            _WithContext((context) => error(context, state), source: error),
          ),
    notFound: notFound == null
        ? null
        : (state) => styled(
            _WithContext(
              (context) => notFound(context, state),
              source: notFound,
            ),
          ),
    errorMeta: errorMeta,
    notFoundMeta: notFoundMeta,
    middleware: middleware,
    cache: cache,
    personalized: personalized,
    prerender: prerender,
    earlyHints: earlyHints,
    prefetch: prefetch,
    children: children,
  );
  // What `WidgetRenderer.linksFor` hints for the pages below.
  if (sheet != null) _moduleSheets[route] = sheet;
  return route;
}

/// The stylesheet (`Group(styles:)`) of each layout route that has one.
final _moduleSheets = Expando<ModuleSheet>('thor route module sheet');

class _WithContext extends StatelessWidget implements InspectSourceOwner {
  const _WithContext(this.builder, {required this.source});

  final Widget Function(BuildContext context) builder;

  /// The app's `build` (page, layout, error, 404): what the inspector
  /// points at.
  final Function source;

  @override
  Function get inspectSource => source;

  @override
  Widget build(BuildContext context) => builder(context);
}

/// A persisted page state's cookie as JSON data (the engine writes
/// `encodeURIComponent(JSON.stringify(value))`; the request's cookies already
/// hold it decoded once).
Object? _readPersisted(String raw) => jsonDecode(raw);

/// `og:url` and `og:image` must be absolute: a path (`/og.png`) is made
/// one against the request's origin and the path the site is published
/// under (the site's base URL in an export).
String _absoluteOg(String property, String value, PageRequest request) =>
    (property == 'og:url' || property == 'og:image') &&
        value.startsWith('/') &&
        !value.startsWith('//') &&
        request.uri.hasAuthority
    ? '${request.uri.origin}${request.publicPathPrefix}$value'
    : value;
