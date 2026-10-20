/// The app, declared once: its routes, theme and stylesheet.
library;

import 'package:thor_ui/thor_ui.dart';

import 'router.dart';
import 'styles.dart';

/// What the server draws every page in.
final gridApp = ThorApp.router(
  routerConfig: router,
  theme: ThemeData(),
  styles: gridStyles,
);
