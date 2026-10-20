/// The app, declared once: its routes, theme, navigation and stylesheet.
library;

import 'package:thor_ui/thor_ui.dart';

import 'router.dart';
import 'styles.dart';
import 'ui.dart' show conduitTheme;

/// What the server draws every page in.
final realworldApp = ThorApp.router(
  routerConfig: router,
  theme: conduitTheme,
  // Prefetch on hover (the default) and a cross-fade between pages; an
  // article's title travels from the list (Hero).
  navigation: const PageNavigation(
    transition: PageTransition.fade(duration: Duration(milliseconds: 250)),
  ),
  styles: conduitStyles,
);
