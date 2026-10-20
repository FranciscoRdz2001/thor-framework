import 'package:thor_ui/thor_ui.dart';

/// The surfaces things sit on, from the page down to a hovered row.
///
/// Neutrals with a cool, indigo-leaning cast so the brand accent belongs:
/// dark is an ink-blue stack (`#0B0D17` page, `#12141F` cards, `#1A1D2B`
/// raised); light is a cool off-white page (`#F6F7FB`) under white cards.
/// The names are the CSS variables (`--t-app`, `--t-panel`...).
abstract final class StudioSurfaceColors {
  /// Behind everything: the page.
  static const app = ColorToken(
    'app',
    light: Color(0xFFF6F7FB),
    dark: Color(0xFF0B0D17),
  );

  /// The ground the cards float on (a hair off the page).
  static const canvas = ColorToken(
    'canvas',
    light: Color(0xFFEFF1F6),
    dark: Color(0xFF0E101A),
  );

  /// Cards, panels and fields.
  static const panel = ColorToken(
    'panel',
    light: Color(0xFFFFFFFF),
    dark: Color(0xFF12141F),
  );

  /// Tiles, rows and tracks inside a card.
  static const raised = ColorToken(
    'raised',
    light: Color(0xFFF1F2F7),
    dark: Color(0xFF1A1D2B),
  );

  /// The neutral hover of a row or a pill.
  static const hover = ColorToken(
    'hover',
    light: Color(0xFFE7E9F1),
    dark: Color(0xFF242838),
  );

  /// Every surface token.
  static const values = [app, canvas, panel, raised, hover];
}
