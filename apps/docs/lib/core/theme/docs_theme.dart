/// The site's themes.
library;

import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/thor_ui.dart';

/// Where the app serves the studio's fonts (`web/fonts/`, copied there by
/// the `thor` CLI).
const docsFontsPath = '/fonts';

/// The site's window sizes: the sidebar is a column from 1024 px
/// (`expanded`) and the table of contents a column from 1280 px (`large`);
/// below 1024 the sidebar is the drawer.
const docsBreakpoints = Breakpoints(expanded: 1024, large: 1280);

/// The light theme: one instance for every page.
final docsTheme = StudioTheme.light(
  fontsPath: docsFontsPath,
).copyWith(breakpoints: docsBreakpoints);

/// The dark theme. It follows the system until the reader picks one with the
/// top bar's `StudioThemeToggle` (the choice is remembered).
final docsDarkTheme = StudioTheme.dark(
  fontsPath: docsFontsPath,
).copyWith(breakpoints: docsBreakpoints);
