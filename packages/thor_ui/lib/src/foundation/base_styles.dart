import 'css_rules.dart';
import 'style_registry.dart' show thorResetLayer;

/// Opinionated page reset (body margin, box sizing). Opt in by adding it to
/// the app's styles: `initializeThor(styles: [...thorResetStyles, ...])` or
/// `WidgetRenderer(styles: [...thorResetStyles, ...])`.
///
/// thor ships no other base stylesheet: widgets compile everything they need
/// (including what their parent grants them, see `ChildRules`) into one
/// class per element.
final List<StyleRule> thorResetStyles = [
  css.layer(name: thorResetLayer, [
    css('html, body').styles(raw: {'margin': '0', 'padding': '0'}),
    css('*, *::before, *::after').styles(raw: {'box-sizing': 'border-box'}),
  ]),
];
