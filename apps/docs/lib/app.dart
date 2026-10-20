/// The site's request handler, shared by the dev server and the static
/// export (both render exactly the same pages).
library;

import 'package:thor_studio/thor_studio.dart' show StudioLocalizations;
import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import 'core/content/changelog.dart';
import 'core/content/library.dart';
import 'core/content/widget_docs.dart';
import 'core/i18n/docs_locale.dart';
import 'core/theme/docs_theme.dart';
import 'core/theme/motion.dart';
import 'modules/errors/errors_routes.dart';
import 'modules/search/search_routes.dart';
import 'router.dart';
import 'shell/docs_locale_routing.dart';

/// The site's own page rules: its motion (fonts, selection and focus come
/// with [docsTheme]; the content and the frame are `thor_studio` widgets with
/// their own styles).
final docsStyles = [...motionStyles];

/// The site, declared once: its routes, themes, languages, navigation and
/// stylesheet. The languages are the ARB files of `lib/l10n/`: adding one
/// is a file there and a folder `docs/guia/<locale>/`. The dark theme
/// follows the system until the reader picks one (`StudioThemeToggle`).
final docsApp = ThorApp.router(
  routerConfig: router,
  theme: docsTheme,
  darkTheme: docsDarkTheme,
  supportedLocales: AppLocalizations.supportedLocales,
  // The studio's own strings ("Skip to content", "Copy", the bench's tabs…)
  // come from its delegate; the app's ARB keeps what is docs-specific.
  localizationsDelegates: [
    StudioLocalizations.delegate,
    ...AppLocalizations.localizationsDelegates,
  ],
  defaultLocale: const Locale(defaultLocale),
  // A quick cross-fade between pages; the frame (top bar and sidebar) keeps
  // its own transition name in `motion.dart` so it stays put.
  navigation: const PageNavigation(
    transition: PageTransition.fade(duration: docsPageFade),
  ),
  styles: docsStyles,
);

/// How the site's URLs carry the language (see [DocsLocaleRouting]).
/// [baseUrl] makes the `hreflang` links absolute.
LocaleRouting docsLocaleRouting({String? baseUrl}) =>
    DocsLocaleRouting(baseUrl: baseUrl);

/// The handler; [baseUrl] (`https://docs.example.com`) makes the `hreflang`
/// alternates absolute, as search engines ask.
RouteHandler<Widget> docsHandler({String? baseUrl}) => RouteHandler(
  routes: docsApp.routes,
  locales: docsLocaleRouting(baseUrl: baseUrl),
  renderer: WidgetRenderer.router(
    docsApp,
    locale: const Locale(defaultLocale),
    // The fonts are preloaded by the theme (`StudioTheme`).
    head: const [html.link(rel: 'icon', href: '/favicon.png')],
  ),
);

/// Every page of the site, without its language: the static export writes
/// each one in every language (and `/` as the page that picks one).
List<String> sitePaths() => [
  '/',
  for (final guide in allGuides) guide.path,
  for (final page in apiPages()) page.path,
  for (final widget in widgetDocs()) widget.path,
  ...changesPaths(),
  searchRoute.link(),
  errorsRoute.link(),
  for (final code in errorCodes()) errorCodeRoute.link({'code': code}),
];
