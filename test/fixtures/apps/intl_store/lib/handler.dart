import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import 'catalog.dart';
import 'l10n/app_localizations.thor.dart';
import 'router.dart';

/// The shop: its routes, its languages (every page under `/en` and `/es`;
/// `/` redirects to the visitor's language, by cookie `locale` then
/// `Accept-Language`) and its messages, declared once.
final storeApp = ThorApp.router(
  routerConfig: router,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  defaultLocale: const Locale('en'),
);

/// The shop's route handler; [baseUrl] makes the `hreflang` links absolute.
RouteHandler<Widget> storeHandler({String? baseUrl}) => RouteHandler(
  routes: storeApp.routes,
  locales: storeApp.localeRouting!.copyWith(baseUrl: baseUrl),
  renderer: WidgetRenderer.router(storeApp),
);

/// Every page, without its locale (the export writes each in both).
List<String> sitePaths() => ['/', for (final p in catalog) '/product/${p.id}'];
