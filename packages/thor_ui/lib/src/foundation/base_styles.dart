import 'css_rules.dart';
import 'style_registry.dart' show thorResetLayer;

/// Opinionated page reset (body margin, box sizing, bare buttons). Opt in by adding it to
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
    // A `<button>` no Material widget styles (a raw `html.button`) draws
    // like the text around it, not the browser's gray Arial box. It is in
    // the lowest layer: every widget's own class, and the app's, win.
    css('button').styles(
      raw: {
        'font': 'inherit',
        'color': 'inherit',
        'background': 'none',
        'border': '0',
        'padding': '0',
      },
    ),
  ]),
];
