/// The app around every page: theme and base styles, in one place for the
/// server and the tests.
library;

import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import 'l10n/app_localizations.thor.dart';
import 'router.dart';
import 'ui/tokens.dart';

/// The accent as primary; system font (`ThemeData`'s default).
final recipesTheme = ThemeData(
  colorScheme: const ColorScheme.light(primary: accent, error: danger),
  // The same tokens by name, for the web layer (`tw('text-muted')`).
  colorTokens: const {
    'ink': ink,
    'muted': muted,
    'line': line,
    'canvas': canvas,
    'danger': danger,
  },
);

/// The app: its routes, [recipesTheme], the page reset (no body margin,
/// border-box) and its languages (Spanish without a prefix, English under
/// `/en`), declared once.
final recipesApp = ThorApp.router(
  routerConfig: router,
  theme: recipesTheme,
  styles: thorResetStyles,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  localeStrategy: LocaleStrategy.prefixExceptDefault,
);

/// Each page drawn in [recipesApp].
WidgetRenderer recipesRenderer() => WidgetRenderer.router(recipesApp);

/// The app's handler: its routes, [recipesRenderer] and its languages.
RouteHandler<Widget> recipesHandler() => RouteHandler(
  routes: recipesApp.routes,
  locales: recipesApp.localeRouting,
  renderer: recipesRenderer(),
);
