import 'adaptive.dart';
import 'css.dart';
import 'css_variable.dart';
import 'errors.dart';

/// A color in `0xAARRGGBB` form, exactly like Flutter's `Color`.
///
/// ```dart
/// const Color(0xFF4361EE)
/// Color.fromRGBO(0, 0, 0, 0.2)
/// Color.css('var(--brand)') // escape hatch for tokens / CSS color functions
/// ```
class Color with Adaptable<Color> {
  /// Creates a color from a 32-bit `0xAARRGGBB` [value].
  const Color(int value)
    : _value = value,
      _raw = null,
      _variable = null,
      _fallback = null;

  /// Creates a color from alpha, red, green and blue channel values (0-255).
  const Color.fromARGB(int a, int r, int g, int b)
    : _value =
          (((a & 0xff) << 24) |
              ((r & 0xff) << 16) |
              ((g & 0xff) << 8) |
              (b & 0xff)) &
          0xFFFFFFFF,
      _raw = null,
      _variable = null,
      _fallback = null;

  /// Creates a color from red, green, blue (0-255) and a fractional
  /// [opacity] (0.0-1.0).
  Color.fromRGBO(int r, int g, int b, double opacity)
    : this.fromARGB((opacity * 255).round(), r, g, b);

  /// Any valid CSS color expression. Its channels are not known on the
  /// server: reading them throws (THOR-R023, see [hasChannels]).
  const Color.css(String raw)
    : _value = 0,
      _raw = raw,
      _variable = null,
      _fallback = null;

  /// The variants travel inside a CSS color expression.
  @override
  Color withVariants(Adaptive<Color> variants) =>
      Color.css(variants.css((c) => c.css));

  /// References a CSS custom property, e.g.
  /// `Color.variable(CssVariable('--primary'))`.
  const Color.variable(CssVariable<Color> variable, {Color? fallback})
    : _value = 0,
      _raw = null,
      _variable = variable,
      _fallback = fallback;

  /// The theme variable `--t-<name>` (a role or a token), the way
  /// `ColorToken` names itself.
  const Color.token(String name, {Color? fallback})
    : _value = 0,
      _raw = null,
      _variable = '--t-$name',
      _fallback = fallback;

  final int _value;

  /// The color as a packed `0xAARRGGBB` integer.
  ///
  /// `// web:` a theme variable (`ThemeColor.primary`,
  /// `Theme.of(context).colorScheme.primary`) has no channels on the server:
  /// light or dark is decided in the browser. Reading them (`value`,
  /// [alpha], [red], [green], [blue], [opacity]) throws (THOR-R023) instead
  /// of answering a wrong color; `withValues(alpha:)` and [withOpacity] mix
  /// it in the browser and keep following the theme. The color the server
  /// knows, when you need its channels anyway (a contrast check made for
  /// the light theme), is [fallback].
  int get value {
    final name = _variable;
    final raw = _raw;
    if (name != null || raw != null) {
      final what = name != null ? '`var($name)`' : '`$raw`';
      throw UnsupportedError(
        thorError(
          'THOR-R023',
          'the channels of $what are not known on the server: a theme '
              'color, a CSS color expression or a color with `.when()` '
              'variants is resolved in the browser (light or dark, a '
              'breakpoint, a state), so reading '
              '`value`/`alpha`/`red`/`green`/`blue`/`opacity` would answer '
              'the wrong color in some of those cases. Use '
              '`withValues(alpha:)` (the browser mixes it and it keeps '
              'following the theme), choose between two colors with '
              '`.when(dark: …)`, or read the channels of a plain '
              '`Color(0x…)`; the color the server knows (the theme\'s '
              'light one, the dark one with `themeMode: dark`) is '
              '`.fallback`',
        ),
      );
    }
    return _value;
  }

  /// Whether the server knows this color's channels: a plain `Color(0x…)`.
  /// False for [Color.css], [Color.variable], [Color.token] and a color with
  /// `.when()` variants, whose channels throw (THOR-R023). Check it before
  /// reading [value] and the channels when the color may come from the theme.
  bool get hasChannels => _raw == null && _variable == null;

  /// The custom property of a `Color.variable` (`--t-accent`), else null.
  String? get variableName => _variable;

  /// The value a `Color.variable` falls back to, else null.
  Color? get fallback => _fallback;
  final String? _raw;
  final String? _variable;
  final Color? _fallback;

  /// Alpha channel, 0-255.
  int get alpha => (value >> 24) & 0xFF;

  /// Red channel, 0-255.
  int get red => (value >> 16) & 0xFF;

  /// Green channel, 0-255.
  int get green => (value >> 8) & 0xFF;

  /// Blue channel, 0-255.
  int get blue => value & 0xFF;

  /// Fractional opacity (0.0-1.0) derived from [alpha].
  double get opacity => alpha / 0xFF;

  /// [foreground] painted over [background], like Flutter's
  /// `Color.alphaBlend` (the same integer math, so the same channels).
  /// Both must be plain colors: a theme variable's channels aren't known in
  /// Dart ([ArgumentError]).
  static Color alphaBlend(Color foreground, Color background) {
    if (!foreground.hasChannels || !background.hasChannels) {
      throw ArgumentError(
        thorError(
          'THOR-R023',
          'alphaBlend needs plain colors: the channels of a CSS color or of a '
              'theme variable are not known on the server (light or dark is '
              'decided in the browser). Put the translucent color over the '
              'background with `withValues(alpha:)` instead: the browser '
              'mixes it',
        ),
      );
    }
    final alpha = foreground.alpha;
    if (alpha == 0) return background;
    final invAlpha = 0xff - alpha;
    var backAlpha = background.alpha;
    if (backAlpha == 0xff) {
      return Color.fromARGB(
        0xff,
        (alpha * foreground.red + invAlpha * background.red) ~/ 0xff,
        (alpha * foreground.green + invAlpha * background.green) ~/ 0xff,
        (alpha * foreground.blue + invAlpha * background.blue) ~/ 0xff,
      );
    }
    backAlpha = (backAlpha * invAlpha) ~/ 0xff;
    final outAlpha = alpha + backAlpha;
    return Color.fromARGB(
      outAlpha,
      (foreground.red * alpha + background.red * backAlpha) ~/ outAlpha,
      (foreground.green * alpha + background.green * backAlpha) ~/ outAlpha,
      (foreground.blue * alpha + background.blue * backAlpha) ~/ outAlpha,
    );
  }

  /// Returns a copy with the alpha channel replaced by [a] (0-255).
  ///
  /// On a variable or CSS color the browser mixes it, like [withOpacity].
  Color withAlpha(int a) =>
      hasChannels ? Color.fromARGB(a, red, green, blue) : withOpacity(a / 255);

  /// Returns a copy with the fractional [opacity] (0.0-1.0) applied.
  ///
  /// On a variable or CSS color (a theme role) the channels aren't known in
  /// Dart, so the browser mixes it: `color-mix(in srgb, var(--x) 50%,
  /// transparent)`, which still follows the theme.
  ///
  /// `// web:` `color-mix` scales the color's own alpha, while Flutter
  /// replaces it: on a translucent token (`0x66000000`) `withValues(alpha:
  /// 1.0)` stays 40% black here and is opaque in Flutter. Opaque tokens, the
  /// usual case, match.
  Color withOpacity(double opacity) => hasChannels
      ? withAlpha((opacity * 255).round())
      : Color.css('color-mix(in srgb, $css ${_percent(opacity)}, transparent)');

  static String _percent(double f) {
    final p = (f * 100).toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
    return '$p%';
  }

  /// Returns a copy with [alpha] replaced, matching Flutter's
  /// `Color.withValues`.
  Color withValues({double? alpha}) =>
      alpha == null ? this : withOpacity(alpha);

  /// CSS representation: a raw expression, a `var()` reference, a hex
  /// string, `transparent`, or an `rgba()` function.
  String get css {
    if (_raw != null) return _raw;
    // Interned: the same color gives the same string, built once (the
    // render's style memo then hashes it once and compares by identity).
    final known = _cssStrings[this];
    if (known != null) return known;
    if (_cssStrings.length >= 4096) _cssStrings.clear();
    return _cssStrings[this] = _computeCss();
  }

  static final _cssStrings = <Color, String>{};

  String _computeCss() {
    if (_variable != null) {
      return _fallback == null
          ? 'var($_variable)'
          : 'var($_variable, ${_fallback.css})';
    }
    String hex(int v) => v.toRadixString(16).padLeft(2, '0');
    if (alpha == 0xFF) return '#${hex(red)}${hex(green)}${hex(blue)}';
    if (_value == 0) return 'transparent';
    return 'rgba($red, $green, $blue, ${cssNum(double.parse(opacity.toStringAsFixed(3)))})';
  }

  @override
  bool operator ==(Object other) =>
      other is Color &&
      other._value == _value &&
      other._raw == _raw &&
      other._variable == _variable &&
      other._fallback == _fallback;

  @override
  int get hashCode => Object.hash(_value, _raw, _variable, _fallback);

  @override
  String toString() => css;
}

/// Flutter's material base palette (500 shades) plus common tones.
abstract final class Colors {
  /// Fully transparent black.
  static const transparent = Color(0x00000000);

  /// Opaque black.
  static const black = Color(0xFF000000);

  /// Black at 87% opacity.
  static const black87 = Color(0xDD000000);

  /// Black at 54% opacity.
  static const black54 = Color(0x8A000000);

  /// Black at 38% opacity.
  static const black38 = Color(0x61000000);

  /// Black at 26% opacity.
  static const black26 = Color(0x42000000);

  /// Black at 12% opacity.
  static const black12 = Color(0x1F000000);

  /// Opaque white.
  static const white = Color(0xFFFFFFFF);

  /// White at 70% opacity.
  static const white70 = Color(0xB3FFFFFF);

  /// White at 54% opacity.
  static const white54 = Color(0x8AFFFFFF);

  /// White at 38% opacity.
  static const white38 = Color(0x62FFFFFF);

  /// White at 24% opacity.
  static const white24 = Color(0x3DFFFFFF);

  /// White at 12% opacity.
  static const white12 = Color(0x1FFFFFFF);

  /// Material red 500.
  static const red = Color(0xFFF44336);

  /// Material pink 500.
  static const pink = Color(0xFFE91E63);

  /// Material purple 500.
  static const purple = Color(0xFF9C27B0);

  /// Material deep purple 500.
  static const deepPurple = Color(0xFF673AB7);

  /// Material indigo 500.
  static const indigo = Color(0xFF3F51B5);

  /// Material blue 500.
  static const blue = Color(0xFF2196F3);

  /// Material light blue 500.
  static const lightBlue = Color(0xFF03A9F4);

  /// Material cyan 500.
  static const cyan = Color(0xFF00BCD4);

  /// Material teal 500.
  static const teal = Color(0xFF009688);

  /// Material green 500.
  static const green = Color(0xFF4CAF50);

  /// Material light green 500.
  static const lightGreen = Color(0xFF8BC34A);

  /// Material lime 500.
  static const lime = Color(0xFFCDDC39);

  /// Material yellow 500.
  static const yellow = Color(0xFFFFEB3B);

  /// Material amber 500.
  static const amber = Color(0xFFFFC107);

  /// Material orange 500.
  static const orange = Color(0xFFFF9800);

  /// Material deep orange 500.
  static const deepOrange = Color(0xFFFF5722);

  /// Material brown 500.
  static const brown = Color(0xFF795548);

  /// Material grey 500.
  static const grey = Color(0xFF9E9E9E);

  /// Material blue grey 500.
  static const blueGrey = Color(0xFF607D8B);
}
