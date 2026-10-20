import 'dart:math' as math;

import 'package:matcher/expect.dart' show fail;
import 'package:thor_ui/thor_ui.dart'
    show Brightness, Color, ColorScheme, ColorToken, ThemeData;

/// The WCAG 2 contrast ratio between [a] and [b] (1 to 21), for two plain
/// colors (the alpha is ignored: blend a translucent one first).
///
/// ```dart
/// contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)); // 21
/// ```
double contrastRatio(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

// The relative luminance of WCAG 2.x.
double _luminance(Color c) {
  double channel(int v) {
    final s = v / 255;
    return s <= 0.03928
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(c.red) +
      0.7152 * channel(c.green) +
      0.0722 * channel(c.blue);
}

/// One foreground / background pair of a theme and how it fares.
class ContrastPair {
  /// Creates a measured pair.
  const ContrastPair({
    required this.foreground,
    required this.background,
    required this.ratio,
    required this.minimum,
  });

  /// The role drawn on [background] (`onPrimary`).
  final String foreground;

  /// The role it is drawn on (`primary`).
  final String background;

  /// The measured WCAG contrast ratio.
  final double ratio;

  /// The ratio the pair needs: 4.5 for text, 3 for the edges of a control.
  final double minimum;

  /// Whether [ratio] reaches [minimum].
  bool get passes => ratio >= minimum;

  @override
  String toString() =>
      '$foreground on $background: ${ratio.toStringAsFixed(2)}:1 '
      '(needs $minimum:1)';
}

/// [fg] drawn over the opaque [bg]: the color the eye gets.
Color _over(Color fg, Color bg) {
  final a = fg.alpha / 255;
  int mix(int f, int b) => (f * a + b * (1 - a)).round();
  return Color.fromARGB(
    255,
    mix(fg.red, bg.red),
    mix(fg.green, bg.green),
    mix(fg.blue, bg.blue),
  );
}

/// The plain `Color(0x…)` a role stands for in a theme of the given
/// brightness: a `ColorToken` is its light or its dark value, any other
/// theme variable (`Color.variable`) its fallback; a color that is a CSS
/// expression (`Color.css`) cannot be measured and gives null.
Color? _plain(Color? c, {required bool dark}) {
  var color = c;
  while (color != null && color.variableName != null) {
    color = color is ColorToken
        ? (dark ? color.dark : color.light)
        : color.fallback;
  }
  if (color == null) return null;
  // `Color.css('color-mix(…)')` has no channels to measure.
  final css = color.css;
  return css.startsWith('#') || css.startsWith('rgb') ? color : null;
}

/// The measured pairs of [scheme]: every `onX` role on its `X`, the text
/// roles on the surfaces they are used on, and `outline` against `surface`.
///
/// Text pairs need [text] (WCAG AA, 4.5:1 by default); the edges of controls
/// (`outline`, WCAG 1.4.11) need [nonText] (3:1). A role the scheme leaves
/// null is skipped; so is a pair with a color that is not a plain value.
/// [extra] adds the pairs of an app's own tokens: `(label, foreground,
/// background)`, measured against [text].
List<ContrastPair> schemeContrast(
  ColorScheme scheme, {
  double text = 4.5,
  double nonText = 3,
  List<(String, Color, Color)> extra = const [],
}) {
  final s = scheme;
  final surface = s.surface;
  final pairs = <(String, Color?, String, Color?, double)>[
    ('onPrimary', s.onPrimary, 'primary', s.primary, text),
    ('onSecondary', s.onSecondary, 'secondary', s.secondary, text),
    ('onError', s.onError, 'error', s.error, text),
    ('onTertiary', s.onTertiary, 'tertiary', s.tertiary, text),
    (
      'onPrimaryContainer',
      s.onPrimaryContainer,
      'primaryContainer',
      s.primaryContainer,
      text,
    ),
    (
      'onSecondaryContainer',
      s.onSecondaryContainer,
      'secondaryContainer',
      s.secondaryContainer,
      text,
    ),
    (
      'onTertiaryContainer',
      s.onTertiaryContainer,
      'tertiaryContainer',
      s.tertiaryContainer,
      text,
    ),
    (
      'onErrorContainer',
      s.onErrorContainer,
      'errorContainer',
      s.errorContainer,
      text,
    ),
    (
      'onInverseSurface',
      s.onInverseSurface,
      'inverseSurface',
      s.inverseSurface,
      text,
    ),
    (
      'inversePrimary',
      s.inversePrimary,
      'inverseSurface',
      s.inverseSurface,
      text,
    ),
    ('onSurface', s.onSurface, 'surface', surface, text),
    ('onSurfaceVariant', s.onSurfaceVariant, 'surface', surface, text),
    ('primary', s.primary, 'surface', surface, text),
    ('error', s.error, 'surface', surface, text),
    ('onSurface', s.onSurface, 'surfaceContainer', s.surfaceContainer, text),
    (
      'onSurfaceVariant',
      s.onSurfaceVariant,
      'surfaceContainer',
      s.surfaceContainer,
      text,
    ),
    (
      'onSurface',
      s.onSurface,
      'surfaceContainerLow',
      s.surfaceContainerLow,
      text,
    ),
    (
      'onSurface',
      s.onSurface,
      'surfaceContainerHigh',
      s.surfaceContainerHigh,
      text,
    ),
    (
      'onSurface',
      s.onSurface,
      'surfaceContainerHighest',
      s.surfaceContainerHighest,
      text,
    ),
    ('outline', s.outline, 'surface', surface, nonText),
    for (final (label, fg, bg) in extra) (label, fg, 'background', bg, text),
  ];
  final dark = s.brightness == Brightness.dark;
  return [
    for (final (fgName, fg, bgName, bg, minimum) in pairs)
      if (_plain(fg, dark: dark) case final f?)
        // A translucent background has no color of its own to measure.
        if (_plain(bg, dark: dark) case final b? when b.alpha == 255)
          ContrastPair(
            foreground: fgName,
            background: bgName,
            // A translucent foreground is what shows over the background.
            ratio: contrastRatio(_over(f, b), b),
            minimum: minimum,
          ),
  ];
}

/// The measured pairs of [theme]'s color scheme (see [schemeContrast]).
List<ContrastPair> themeContrast(
  ThemeData theme, {
  double text = 4.5,
  double nonText = 3,
  List<(String, Color, Color)> extra = const [],
}) => schemeContrast(
  theme.colorScheme,
  text: text,
  nonText: nonText,
  extra: extra,
);

/// Fails the test, naming every pair, when [theme] has text on a background
/// under WCAG AA (4.5:1) or an `outline` under 3:1.
///
/// ```dart
/// test('the app theme is readable', () {
///   expectThemeContrast(appTheme);
///   expectThemeContrast(appDarkTheme);
/// });
/// ```
///
/// A pair with a role the scheme leaves null is skipped. [skip] names pairs
/// you accept as they are (`'outline on surface'`), [reason] says which theme
/// is checked, and [extra] adds the pairs of the app's own tokens.
void expectThemeContrast(
  ThemeData theme, {
  String? reason,
  Set<String> skip = const {},
  double text = 4.5,
  double nonText = 3,
  List<(String, Color, Color)> extra = const [],
}) {
  final failing = [
    for (final p in themeContrast(
      theme,
      text: text,
      nonText: nonText,
      extra: extra,
    ))
      if (!p.passes && !skip.contains('${p.foreground} on ${p.background}')) p,
  ];
  if (failing.isEmpty) return;
  fail(
    '${reason ?? 'The theme'} has ${failing.length} pair(s) under WCAG AA '
    'contrast:\n${failing.map((p) => '  $p').join('\n')}',
  );
}
