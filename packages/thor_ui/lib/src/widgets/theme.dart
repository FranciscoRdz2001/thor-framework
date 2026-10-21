import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/errors.dart';
import '../foundation/parent_data.dart';
import '../foundation/responsive.dart' show ResponsiveVisibility;
import '../foundation/style_registry.dart';
import '../foundation/stylesheet.dart' show Breakpoints;
import '../foundation/widget_state.dart' show WidgetState, WidgetStateProperty;
import 'component_themes.dart';
import 'date_picker.dart' show DatePickerThemeData;
import 'navigation_rail.dart' show NavigationRailThemeData;
import 'text_field.dart' show InputDecorationTheme;

/// Flutter's `ThemeMode`.
enum ThemeMode {
  /// Follows the OS/browser color-scheme preference.
  system,

  /// Always light.
  light,

  /// Always dark.
  dark,
}

/// Flutter's `Brightness`.
enum Brightness {
  /// A light background, dark foreground.
  light,

  /// A dark background, light foreground.
  dark,
}

/// Flutter's (Material 3) `ColorScheme`, subset.
///
/// Every role is also published as a CSS custom property (`--t-primary`,
/// `--t-on-surface`, …) so static stylesheets can use the theme without any
/// Dart lookup: `Color.variable(CssVariable('--t-primary'))`.
///
/// `// web:` `Theme.of(context).colorScheme` hands out these same variables
/// (`var(--t-primary, <its color>)`), not the colors: the server can't know
/// whether the page is light or dark, the browser does. What you build with
/// them follows the switch; what reads their channels (`value`, `red`…)
/// fails with the way out (THOR-R023). The scheme you construct keeps its
/// real colors.
class ColorScheme {
  /// Creates a color scheme from every role.
  const ColorScheme({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.error,
    required this.onError,
    required this.surface,
    required this.onSurface,
    required this.surfaceContainer,
    required this.outline,
    required this.outlineVariant,
    this.onSurfaceVariant,
    this.surfaceContainerHighest,
    this.primaryContainer,
    this.onPrimaryContainer,
    this.secondaryContainer,
    this.onSecondaryContainer,
    this.surfaceContainerLow,
    this.surfaceContainerHigh,
    this.inverseSurface,
    this.onInverseSurface,
    this.inversePrimary,
    this.tertiary,
    this.onTertiary,
    this.tertiaryContainer,
    this.onTertiaryContainer,
    this.errorContainer,
    this.onErrorContainer,
    this.surfaceContainerLowest,
  });

  /// Material 3 baseline (light).
  const ColorScheme.light({
    this.primary = const Color(0xFF6750A4),
    this.onPrimary = const Color(0xFFFFFFFF),
    this.secondary = const Color(0xFF625B71),
    this.onSecondary = const Color(0xFFFFFFFF),
    this.error = const Color(0xFFB3261E),
    this.onError = const Color(0xFFFFFFFF),
    this.surface = const Color(0xFFFEF7FF),
    this.onSurface = const Color(0xFF1D1B20),
    this.surfaceContainer = const Color(0xFFF3EDF7),
    this.outline = const Color(0xFF79747E),
    this.outlineVariant = const Color(0xFFCAC4D0),
    this.onSurfaceVariant = const Color(0xFF49454F),
    this.surfaceContainerHighest = const Color(0xFFE6E0E9),
    this.primaryContainer = const Color(0xFFEADDFF),
    this.onPrimaryContainer = const Color(0xFF21005D),
    this.secondaryContainer = const Color(0xFFE8DEF8),
    this.onSecondaryContainer = const Color(0xFF4A4458),
    this.surfaceContainerLow = const Color(0xFFF7F2FA),
    // null: the widgets' own fallback, the same light value.
    this.surfaceContainerHigh,
    this.inverseSurface = const Color(0xFF322F35),
    this.onInverseSurface = const Color(0xFFF5EFF7),
    this.inversePrimary = const Color(0xFFD0BCFF),
    this.tertiary,
    this.onTertiary,
    this.tertiaryContainer,
    this.onTertiaryContainer,
    this.errorContainer,
    this.onErrorContainer,
    this.surfaceContainerLowest,
  }) : brightness = Brightness.light;

  /// Material 3 baseline (dark).
  const ColorScheme.dark({
    this.primary = const Color(0xFFD0BCFF),
    this.onPrimary = const Color(0xFF381E72),
    this.secondary = const Color(0xFFCCC2DC),
    this.onSecondary = const Color(0xFF332D41),
    this.error = const Color(0xFFF2B8B5),
    this.onError = const Color(0xFF601410),
    this.surface = const Color(0xFF141218),
    this.onSurface = const Color(0xFFE6E0E9),
    this.surfaceContainer = const Color(0xFF211F26),
    this.outline = const Color(0xFF938F99),
    this.outlineVariant = const Color(0xFF49454F),
    this.onSurfaceVariant = const Color(0xFFCAC4D0),
    this.surfaceContainerHighest = const Color(0xFF36343B),
    this.primaryContainer = const Color(0xFF4F378B),
    this.onPrimaryContainer = const Color(0xFFEADDFF),
    this.secondaryContainer = const Color(0xFF4A4458),
    this.onSecondaryContainer = const Color(0xFFE8DEF8),
    this.surfaceContainerLow = const Color(0xFF1D1B20),
    this.surfaceContainerHigh = const Color(0xFF2B2930),
    this.inverseSurface = const Color(0xFFE6E0E9),
    this.onInverseSurface = const Color(0xFF322F35),
    this.inversePrimary = const Color(0xFF6750A4),
    this.tertiary,
    this.onTertiary,
    this.tertiaryContainer,
    this.onTertiaryContainer,
    this.errorContainer,
    this.onErrorContainer,
    this.surfaceContainerLowest,
  }) : brightness = Brightness.dark;

  /// Material 3 baseline with high contrast (light), like Flutter's
  /// `ColorScheme.highContrastLight`: the roles of [ColorScheme.light] with
  /// text, borders and brand colors dark enough for 7:1 (WCAG AAA) against
  /// their backgrounds. What a `ThorApp(highContrastTheme:)` is made of.
  /// `// web:` the defaults are derived from the Material 3 baseline like
  /// [ColorScheme.light], not Flutter's M2 high-contrast values (primary
  /// `0xff0000ba`, secondary `0xff66fff9`).
  const ColorScheme.highContrastLight({
    this.primary = const Color(0xFF2C0B6B),
    this.onPrimary = const Color(0xFFFFFFFF),
    this.secondary = const Color(0xFF2B2538),
    this.onSecondary = const Color(0xFFFFFFFF),
    this.error = const Color(0xFF740006),
    this.onError = const Color(0xFFFFFFFF),
    this.surface = const Color(0xFFFFFFFF),
    this.onSurface = const Color(0xFF000000),
    this.surfaceContainer = const Color(0xFFF5F0FA),
    this.outline = const Color(0xFF1D1B20),
    this.outlineVariant = const Color(0xFF49454F),
    this.onSurfaceVariant = const Color(0xFF1D1B20),
    this.surfaceContainerHighest = const Color(0xFFE6E0E9),
    this.primaryContainer = const Color(0xFFD9C7FF),
    this.onPrimaryContainer = const Color(0xFF000000),
    this.secondaryContainer = const Color(0xFFDDD3EC),
    this.onSecondaryContainer = const Color(0xFF000000),
    this.surfaceContainerLow = const Color(0xFFF7F2FA),
    this.surfaceContainerHigh = const Color(0xFFEDE7F2),
    this.inverseSurface = const Color(0xFF000000),
    this.onInverseSurface = const Color(0xFFFFFFFF),
    this.inversePrimary = const Color(0xFFE6DAFF),
    this.tertiary,
    this.onTertiary,
    this.tertiaryContainer,
    this.onTertiaryContainer,
    this.errorContainer,
    this.onErrorContainer,
    this.surfaceContainerLowest,
  }) : brightness = Brightness.light;

  /// Material 3 baseline with high contrast (dark), like Flutter's
  /// `ColorScheme.highContrastDark` (see [ColorScheme.highContrastLight]).
  const ColorScheme.highContrastDark({
    this.primary = const Color(0xFFEADDFF),
    this.onPrimary = const Color(0xFF000000),
    this.secondary = const Color(0xFFE8DEF8),
    this.onSecondary = const Color(0xFF000000),
    this.error = const Color(0xFFFFD9D6),
    this.onError = const Color(0xFF000000),
    this.surface = const Color(0xFF000000),
    this.onSurface = const Color(0xFFFFFFFF),
    this.surfaceContainer = const Color(0xFF141218),
    this.outline = const Color(0xFFE6E0E9),
    this.outlineVariant = const Color(0xFFCAC4D0),
    this.onSurfaceVariant = const Color(0xFFF2ECF9),
    this.surfaceContainerHighest = const Color(0xFF2B2930),
    this.primaryContainer = const Color(0xFFD0BCFF),
    this.onPrimaryContainer = const Color(0xFF000000),
    this.secondaryContainer = const Color(0xFFCCC2DC),
    this.onSecondaryContainer = const Color(0xFF000000),
    this.surfaceContainerLow = const Color(0xFF0E0C11),
    this.surfaceContainerHigh = const Color(0xFF211F26),
    this.inverseSurface = const Color(0xFFFFFFFF),
    this.onInverseSurface = const Color(0xFF000000),
    this.inversePrimary = const Color(0xFF4F378B),
    this.tertiary,
    this.onTertiary,
    this.tertiaryContainer,
    this.onTertiaryContainer,
    this.errorContainer,
    this.onErrorContainer,
    this.surfaceContainerLowest,
  }) : brightness = Brightness.dark;

  /// Overall brightness of the scheme.
  final Brightness brightness;

  /// Main brand color, e.g. for filled buttons.
  final Color primary;

  /// Color of content drawn on `primary`.
  final Color onPrimary;

  /// Less prominent accent color.
  final Color secondary;

  /// Color of content drawn on `secondary`.
  final Color onSecondary;

  /// Color indicating errors.
  final Color error;

  /// Color of content drawn on `error`.
  final Color onError;

  /// Default background color.
  final Color surface;

  /// Color of content drawn on `surface`.
  final Color onSurface;

  /// Background color of containers, e.g. cards.
  final Color surfaceContainer;

  /// Color of borders and dividers.
  final Color outline;

  /// A subtler `outline`, for decorative dividers.
  final Color outlineVariant;

  /// Secondary text and icons on `surface` (default: `onSurface`).
  final Color? onSurfaceVariant;

  /// The most prominent container, e.g. a muted panel (default:
  /// `surfaceContainer`).
  final Color? surfaceContainerHighest;

  /// The brand's container, e.g. a `FloatingActionButton` (default:
  /// `primary`).
  final Color? primaryContainer;

  /// Content on `primaryContainer` (default: `onPrimary`).
  final Color? onPrimaryContainer;

  /// A tonal container, e.g. a secondary button (default: `secondary`).
  final Color? secondaryContainer;

  /// Content on `secondaryContainer` (default: `onSecondary`).
  final Color? onSecondaryContainer;

  /// A low-emphasis container, e.g. a `Card` or a `Drawer` (null: the
  /// widgets' Material fallback).
  final Color? surfaceContainerLow;

  /// A high-emphasis container, e.g. a `Dialog` or an `AlertDialog` (null:
  /// the widgets' Material fallback, a light value: a dark scheme sets it).
  final Color? surfaceContainerHigh;

  /// A surface that stands out against `surface`, e.g. a `SnackBar` or a
  /// `Tooltip` (null: the widgets' Material fallback).
  final Color? inverseSurface;

  /// Content on `inverseSurface` (null: the widgets' Material fallback).
  final Color? onInverseSurface;

  /// A primary color readable on `inverseSurface`, e.g. a `SnackBar`
  /// action.
  final Color? inversePrimary;

  /// A contrasting accent next to `primary` (Material 3's third color). Null
  /// (the default): not published, widgets that want it fall back to
  /// `primary`.
  final Color? tertiary;

  /// Content on `tertiary`.
  final Color? onTertiary;

  /// A container tinted with the `tertiary` accent.
  final Color? tertiaryContainer;

  /// Content on `tertiaryContainer`.
  final Color? onTertiaryContainer;

  /// A container for error messages (null: not published).
  final Color? errorContainer;

  /// Content on `errorContainer`.
  final Color? onErrorContainer;

  /// The lowest container, the closest to `surface` (null: not published).
  final Color? surfaceContainerLowest;

  /// A copy of this scheme with the given roles replaced (Flutter's
  /// `ColorScheme.copyWith`). On the scheme of `Theme.of` the roles you
  /// leave out stay the theme's variables.
  ColorScheme copyWith({
    Brightness? brightness,
    Color? primary,
    Color? onPrimary,
    Color? secondary,
    Color? onSecondary,
    Color? error,
    Color? onError,
    Color? surface,
    Color? onSurface,
    Color? surfaceContainer,
    Color? outline,
    Color? outlineVariant,
    Color? onSurfaceVariant,
    Color? surfaceContainerHighest,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? secondaryContainer,
    Color? onSecondaryContainer,
    Color? surfaceContainerLow,
    Color? surfaceContainerHigh,
    Color? inverseSurface,
    Color? onInverseSurface,
    Color? inversePrimary,
    Color? tertiary,
    Color? onTertiary,
    Color? tertiaryContainer,
    Color? onTertiaryContainer,
    Color? errorContainer,
    Color? onErrorContainer,
    Color? surfaceContainerLowest,
  }) => ColorScheme(
    brightness: brightness ?? this.brightness,
    primary: primary ?? this.primary,
    onPrimary: onPrimary ?? this.onPrimary,
    secondary: secondary ?? this.secondary,
    onSecondary: onSecondary ?? this.onSecondary,
    error: error ?? this.error,
    onError: onError ?? this.onError,
    surface: surface ?? this.surface,
    onSurface: onSurface ?? this.onSurface,
    surfaceContainer: surfaceContainer ?? this.surfaceContainer,
    outline: outline ?? this.outline,
    outlineVariant: outlineVariant ?? this.outlineVariant,
    onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
    surfaceContainerHighest:
        surfaceContainerHighest ?? this.surfaceContainerHighest,
    primaryContainer: primaryContainer ?? this.primaryContainer,
    onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
    secondaryContainer: secondaryContainer ?? this.secondaryContainer,
    onSecondaryContainer: onSecondaryContainer ?? this.onSecondaryContainer,
    surfaceContainerLow: surfaceContainerLow ?? this.surfaceContainerLow,
    surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
    inverseSurface: inverseSurface ?? this.inverseSurface,
    onInverseSurface: onInverseSurface ?? this.onInverseSurface,
    inversePrimary: inversePrimary ?? this.inversePrimary,
    tertiary: tertiary ?? this.tertiary,
    onTertiary: onTertiary ?? this.onTertiary,
    tertiaryContainer: tertiaryContainer ?? this.tertiaryContainer,
    onTertiaryContainer: onTertiaryContainer ?? this.onTertiaryContainer,
    errorContainer: errorContainer ?? this.errorContainer,
    onErrorContainer: onErrorContainer ?? this.onErrorContainer,
    surfaceContainerLowest:
        surfaceContainerLowest ?? this.surfaceContainerLowest,
  );

  /// This scheme as `Theme.of` hands it out: every role is the theme's
  /// variable, with the role's color as its fallback (a page without the
  /// variables, a test, still shows the right one). A role that already is a
  /// variable follows the theme as it is; a null one stays null.
  ColorScheme _followed() {
    Color? follow(String name, Color? color) => color == null
        ? null
        : color.variableName != null
        ? color
        : Color.variable(CssVariable(name), fallback: color);
    return ColorScheme(
      brightness: brightness,
      primary: follow('--t-primary', primary)!,
      onPrimary: follow('--t-on-primary', onPrimary)!,
      secondary: follow('--t-secondary', secondary)!,
      onSecondary: follow('--t-on-secondary', onSecondary)!,
      error: follow('--t-error', error)!,
      onError: follow('--t-on-error', onError)!,
      surface: follow('--t-surface', surface)!,
      onSurface: follow('--t-on-surface', onSurface)!,
      surfaceContainer: follow('--t-surface-container', surfaceContainer)!,
      outline: follow('--t-outline', outline)!,
      outlineVariant: follow('--t-outline-variant', outlineVariant)!,
      // The three that default to another role publish that default.
      onSurfaceVariant: follow(
        '--t-on-surface-variant',
        onSurfaceVariant ?? onSurface,
      ),
      surfaceContainerHighest: follow(
        '--t-surface-container-highest',
        surfaceContainerHighest ?? surfaceContainer,
      ),
      primaryContainer: follow(
        '--t-primary-container',
        primaryContainer ?? primary,
      ),
      onPrimaryContainer: follow(
        '--t-on-primary-container',
        onPrimaryContainer ?? onPrimary,
      ),
      secondaryContainer: follow(
        '--t-secondary-container',
        secondaryContainer ?? secondary,
      ),
      onSecondaryContainer: follow(
        '--t-on-secondary-container',
        onSecondaryContainer ?? onSecondary,
      ),
      surfaceContainerLow: follow(
        '--t-surface-container-low',
        surfaceContainerLow,
      ),
      surfaceContainerHigh: follow(
        '--t-surface-container-high',
        surfaceContainerHigh,
      ),
      inverseSurface: follow('--t-inverse-surface', inverseSurface),
      onInverseSurface: follow('--t-inverse-on-surface', onInverseSurface),
      inversePrimary: follow('--t-inverse-primary', inversePrimary),
      tertiary: follow('--t-tertiary', tertiary),
      onTertiary: follow('--t-on-tertiary', onTertiary),
      tertiaryContainer: follow('--t-tertiary-container', tertiaryContainer),
      onTertiaryContainer: follow(
        '--t-on-tertiary-container',
        onTertiaryContainer,
      ),
      errorContainer: follow('--t-error-container', errorContainer),
      onErrorContainer: follow('--t-on-error-container', onErrorContainer),
      surfaceContainerLowest: follow(
        '--t-surface-container-lowest',
        surfaceContainerLowest,
      ),
    );
  }

  /// Publishes every role as a `--t-*` CSS custom property.
  ///
  /// With [nested] (a `Theme` inside the page's theme), a role that is its
  /// own variable (the scheme came from `Theme.of`, which follows the page's
  /// light/dark switch) is left out, and so is `color-scheme`: the subtree
  /// inherits the ancestor's live values instead of the light hex fallbacks.
  CssDeclarations toCssVariables({bool nested = false}) {
    String? pub(String name, Color color) =>
        nested && color.variableName == name ? null : _publish(name, color);
    String? pubNull(String name, Color? color) =>
        color == null ? null : pub(name, color);
    return {
      '--t-primary': ?pub('--t-primary', primary),
      '--t-on-primary': ?pub('--t-on-primary', onPrimary),
      '--t-secondary': ?pub('--t-secondary', secondary),
      '--t-on-secondary': ?pub('--t-on-secondary', onSecondary),
      '--t-error': ?pub('--t-error', error),
      '--t-on-error': ?pub('--t-on-error', onError),
      '--t-surface': ?pub('--t-surface', surface),
      '--t-on-surface': ?pub('--t-on-surface', onSurface),
      '--t-surface-container': ?pub('--t-surface-container', surfaceContainer),
      '--t-outline': ?pub('--t-outline', outline),
      '--t-outline-variant': ?pub('--t-outline-variant', outlineVariant),
      '--t-on-surface-variant': ?pub(
        '--t-on-surface-variant',
        onSurfaceVariant ?? onSurface,
      ),
      '--t-surface-container-highest': ?pub(
        '--t-surface-container-highest',
        surfaceContainerHighest ?? surfaceContainer,
      ),
      '--t-primary-container': ?pub(
        '--t-primary-container',
        primaryContainer ?? primary,
      ),
      '--t-on-primary-container': ?pub(
        '--t-on-primary-container',
        onPrimaryContainer ?? onPrimary,
      ),
      '--t-secondary-container': ?pub(
        '--t-secondary-container',
        secondaryContainer ?? secondary,
      ),
      '--t-on-secondary-container': ?pub(
        '--t-on-secondary-container',
        onSecondaryContainer ?? onSecondary,
      ),
      '--t-surface-container-low': ?pubNull(
        '--t-surface-container-low',
        surfaceContainerLow,
      ),
      '--t-surface-container-high': ?pubNull(
        '--t-surface-container-high',
        surfaceContainerHigh,
      ),
      '--t-inverse-surface': ?pubNull('--t-inverse-surface', inverseSurface),
      '--t-inverse-on-surface': ?pubNull(
        '--t-inverse-on-surface',
        onInverseSurface,
      ),
      '--t-inverse-primary': ?pubNull('--t-inverse-primary', inversePrimary),
      '--t-tertiary': ?pubNull('--t-tertiary', tertiary),
      '--t-on-tertiary': ?pubNull('--t-on-tertiary', onTertiary),
      '--t-tertiary-container': ?pubNull(
        '--t-tertiary-container',
        tertiaryContainer,
      ),
      '--t-on-tertiary-container': ?pubNull(
        '--t-on-tertiary-container',
        onTertiaryContainer,
      ),
      '--t-error-container': ?pubNull('--t-error-container', errorContainer),
      '--t-on-error-container': ?pubNull(
        '--t-on-error-container',
        onErrorContainer,
      ),
      '--t-surface-container-lowest': ?pubNull(
        '--t-surface-container-lowest',
        surfaceContainerLowest,
      ),
      // A scheme from `Theme.of` with only an accent replaced
      // (`copyWith(primary: …)`) still follows the page's light/dark: its
      // surface decides, not the replaced role.
      if (!(nested && surface.variableName == '--t-surface'))
        'color-scheme': brightness.name,
    };
  }
}

/// What variable [name] is set to: [color], unless [color] is a theme
/// variable that came out of `Theme.of` (`--t-…` with the color it falls
/// back to): the same variable can't be its own value, and another role's
/// would be read from this element (the nested theme's own, or a cycle in
/// a swap: `primary: s.secondary, secondary: s.primary`), not from the
/// parent theme it was taken from. It publishes the color it falls back to.
/// A variable of the app's own (`--brand`) stays an alias, and so does a
/// [ColorToken] (`light-dark()` in the page, its `fallback` is only the
/// deprecated `.light`): a role published as its light hex stays light in
/// the dark theme.
String _publish(String name, Color color) {
  final variable = color.variableName;
  return color is! ColorToken &&
          variable != null &&
          color.fallback != null &&
          (variable == name || variable.startsWith('--t-'))
      ? color.fallback!.css
      : color.css;
}

/// [_publish] for an optional color: null leaves the variable out.
String? _publishOrNull(String name, Color? color) =>
    color == null ? null : _publish(name, color);

TextStyle _m3(
  double size,
  double lineHeight,
  FontWeight weight,
  double tracking,
) => TextStyle(
  fontSize: size,
  height: double.parse((lineHeight / size).toStringAsFixed(4)),
  fontWeight: weight,
  letterSpacing: tracking,
);

/// Flutter's (Material 3) `TextTheme`.
///
/// Every style carries its role (`TextStyle.themeRole`): widgets render it as
/// the theme's CSS variables with the values as fallbacks, so
/// `ThorApp(theme:)` can change a role per breakpoint
/// (`textTheme.when(medium: textTheme.copyWith(...))`) without touching the
/// widgets.
class TextTheme with Adaptable<TextTheme> {
  /// Creates a text theme, filling gaps with the Material 3 defaults.
  TextTheme({
    TextStyle? displayLarge,
    TextStyle? displayMedium,
    TextStyle? displaySmall,
    TextStyle? headlineLarge,
    TextStyle? headlineMedium,
    TextStyle? headlineSmall,
    TextStyle? titleLarge,
    TextStyle? titleMedium,
    TextStyle? titleSmall,
    TextStyle? bodyLarge,
    TextStyle? bodyMedium,
    TextStyle? bodySmall,
    TextStyle? labelLarge,
    TextStyle? labelMedium,
    TextStyle? labelSmall,
  }) : displayLarge = (displayLarge ?? _m3(57, 64, FontWeight.w400, -0.25))
           .withRole(TextThemeRole.displayLarge),
       displayMedium = (displayMedium ?? _m3(45, 52, FontWeight.w400, 0))
           .withRole(TextThemeRole.displayMedium),
       displaySmall = (displaySmall ?? _m3(36, 44, FontWeight.w400, 0))
           .withRole(TextThemeRole.displaySmall),
       headlineLarge = (headlineLarge ?? _m3(32, 40, FontWeight.w400, 0))
           .withRole(TextThemeRole.headlineLarge),
       headlineMedium = (headlineMedium ?? _m3(28, 36, FontWeight.w400, 0))
           .withRole(TextThemeRole.headlineMedium),
       headlineSmall = (headlineSmall ?? _m3(24, 32, FontWeight.w400, 0))
           .withRole(TextThemeRole.headlineSmall),
       titleLarge = (titleLarge ?? _m3(22, 28, FontWeight.w400, 0)).withRole(
         TextThemeRole.titleLarge,
       ),
       titleMedium = (titleMedium ?? _m3(16, 24, FontWeight.w500, 0.15))
           .withRole(TextThemeRole.titleMedium),
       titleSmall = (titleSmall ?? _m3(14, 20, FontWeight.w500, 0.1)).withRole(
         TextThemeRole.titleSmall,
       ),
       bodyLarge = (bodyLarge ?? _m3(16, 24, FontWeight.w400, 0.5)).withRole(
         TextThemeRole.bodyLarge,
       ),
       bodyMedium = (bodyMedium ?? _m3(14, 20, FontWeight.w400, 0.25)).withRole(
         TextThemeRole.bodyMedium,
       ),
       bodySmall = (bodySmall ?? _m3(12, 16, FontWeight.w400, 0.4)).withRole(
         TextThemeRole.bodySmall,
       ),
       labelLarge = (labelLarge ?? _m3(14, 20, FontWeight.w500, 0.1)).withRole(
         TextThemeRole.labelLarge,
       ),
       labelMedium = (labelMedium ?? _m3(12, 16, FontWeight.w500, 0.5))
           .withRole(TextThemeRole.labelMedium),
       labelSmall = (labelSmall ?? _m3(11, 16, FontWeight.w500, 0.5)).withRole(
         TextThemeRole.labelSmall,
       );

  /// Largest text, reserved for short important text.
  final TextStyle displayLarge;

  /// Second-largest display text.
  final TextStyle displayMedium;

  /// Smallest display text.
  final TextStyle displaySmall;

  /// Largest headline text, for high-emphasis short text.
  final TextStyle headlineLarge;

  /// Second-largest headline text.
  final TextStyle headlineMedium;

  /// Smallest headline text.
  final TextStyle headlineSmall;

  /// Largest title text, for medium-emphasis text.
  final TextStyle titleLarge;

  /// Second-largest title text.
  final TextStyle titleMedium;

  /// Smallest title text.
  final TextStyle titleSmall;

  /// Largest body text.
  final TextStyle bodyLarge;

  /// Default body text (the page text of `ThorApp(theme:)`).
  final TextStyle bodyMedium;

  /// Smallest body text.
  final TextStyle bodySmall;

  /// Largest label text, e.g. button labels.
  final TextStyle labelLarge;

  /// Second-largest label text.
  final TextStyle labelMedium;

  /// Smallest label text.
  final TextStyle labelSmall;

  /// The breakpoint variants (`textTheme.when(medium: …)`), or null. Only
  /// breakpoints apply to a theme; give each one a full theme
  /// (`copyWith`), only the roles that differ are published.
  Adaptive<TextTheme>? get variants => null;

  @override
  TextTheme withVariants(Adaptive<TextTheme> variants) =>
      _AdaptiveTextTheme(variants);

  /// A copy with the given roles replaced (Flutter's `copyWith`).
  TextTheme copyWith({
    TextStyle? displayLarge,
    TextStyle? displayMedium,
    TextStyle? displaySmall,
    TextStyle? headlineLarge,
    TextStyle? headlineMedium,
    TextStyle? headlineSmall,
    TextStyle? titleLarge,
    TextStyle? titleMedium,
    TextStyle? titleSmall,
    TextStyle? bodyLarge,
    TextStyle? bodyMedium,
    TextStyle? bodySmall,
    TextStyle? labelLarge,
    TextStyle? labelMedium,
    TextStyle? labelSmall,
  }) => _each(
    (t) => TextTheme(
      displayLarge: displayLarge ?? t.displayLarge,
      displayMedium: displayMedium ?? t.displayMedium,
      displaySmall: displaySmall ?? t.displaySmall,
      headlineLarge: headlineLarge ?? t.headlineLarge,
      headlineMedium: headlineMedium ?? t.headlineMedium,
      headlineSmall: headlineSmall ?? t.headlineSmall,
      titleLarge: titleLarge ?? t.titleLarge,
      titleMedium: titleMedium ?? t.titleMedium,
      titleSmall: titleSmall ?? t.titleSmall,
      bodyLarge: bodyLarge ?? t.bodyLarge,
      bodyMedium: bodyMedium ?? t.bodyMedium,
      bodySmall: bodySmall ?? t.bodySmall,
      labelLarge: labelLarge ?? t.labelLarge,
      labelMedium: labelMedium ?? t.labelMedium,
      labelSmall: labelSmall ?? t.labelSmall,
    ),
  );

  // Maps over the variants when built with `.when()`, so a copy keeps them.
  TextTheme _each(TextTheme Function(TextTheme plain) f) => f(this);

  /// Role name (`headline-large`) → style.
  Map<String, TextStyle> get roles => {
    'display-large': displayLarge,
    'display-medium': displayMedium,
    'display-small': displaySmall,
    'headline-large': headlineLarge,
    'headline-medium': headlineMedium,
    'headline-small': headlineSmall,
    'title-large': titleLarge,
    'title-medium': titleMedium,
    'title-small': titleSmall,
    'body-large': bodyLarge,
    'body-medium': bodyMedium,
    'body-small': bodySmall,
    'label-large': labelLarge,
    'label-medium': labelMedium,
    'label-small': labelSmall,
  };

  /// The CSS variables of every role: `--t-<role>-size`, `-line`,
  /// `-weight`, `-tracking`.
  CssDeclarations toCssVariables() => {
    for (final e in roles.entries) ..._roleVariables(e.key, e.value),
  };

  /// Only the variables that differ from [base] (a breakpoint override).
  CssDeclarations diffCssVariables(TextTheme base) {
    final mine = toCssVariables(), theirs = base.toCssVariables();
    return {
      for (final e in mine.entries)
        if (theirs[e.key] != e.value) e.key: e.value,
    };
  }

  static CssDeclarations _roleVariables(String role, TextStyle s) => {
    '--t-$role-size': ?s.cssFontSize,
    if (s.height case final v?) '--t-$role-line': cssNum(v),
    if (s.fontWeight case final v?) '--t-$role-weight': '${v.value}',
    '--t-$role-tracking': ?s.cssLetterSpacing,
  };
}

class _AdaptiveTextTheme extends TextTheme {
  _AdaptiveTextTheme(this.adaptive)
    : super(
        displayLarge: adaptive.base.displayLarge,
        displayMedium: adaptive.base.displayMedium,
        displaySmall: adaptive.base.displaySmall,
        headlineLarge: adaptive.base.headlineLarge,
        headlineMedium: adaptive.base.headlineMedium,
        headlineSmall: adaptive.base.headlineSmall,
        titleLarge: adaptive.base.titleLarge,
        titleMedium: adaptive.base.titleMedium,
        titleSmall: adaptive.base.titleSmall,
        bodyLarge: adaptive.base.bodyLarge,
        bodyMedium: adaptive.base.bodyMedium,
        bodySmall: adaptive.base.bodySmall,
        labelLarge: adaptive.base.labelLarge,
        labelMedium: adaptive.base.labelMedium,
        labelSmall: adaptive.base.labelSmall,
      );

  final Adaptive<TextTheme> adaptive;

  @override
  TextTheme _each(TextTheme Function(TextTheme plain) f) =>
      _AdaptiveTextTheme(adaptive.map((t) => t._each(f)));

  @override
  Adaptive<TextTheme> get variants => adaptive;
}

/// The theme's text roles for building widgets without a `BuildContext`
/// (`Text('x', style: ThemeText.headlineLarge)`); like `ThemeColor`, they
/// follow the theme's CSS variables. `Theme.of(context).textTheme` gives the
/// same roles with the values as fallbacks.
abstract final class ThemeText {
  /// The `display-large` role.
  static const displayLarge = TextStyle(role: TextThemeRole.displayLarge);

  /// The `display-medium` role.
  static const displayMedium = TextStyle(role: TextThemeRole.displayMedium);

  /// The `display-small` role.
  static const displaySmall = TextStyle(role: TextThemeRole.displaySmall);

  /// The `headline-large` role.
  static const headlineLarge = TextStyle(role: TextThemeRole.headlineLarge);

  /// The `headline-medium` role.
  static const headlineMedium = TextStyle(role: TextThemeRole.headlineMedium);

  /// The `headline-small` role.
  static const headlineSmall = TextStyle(role: TextThemeRole.headlineSmall);

  /// The `title-large` role.
  static const titleLarge = TextStyle(role: TextThemeRole.titleLarge);

  /// The `title-medium` role.
  static const titleMedium = TextStyle(role: TextThemeRole.titleMedium);

  /// The `title-small` role.
  static const titleSmall = TextStyle(role: TextThemeRole.titleSmall);

  /// The `body-large` role.
  static const bodyLarge = TextStyle(role: TextThemeRole.bodyLarge);

  /// The `body-medium` role.
  static const bodyMedium = TextStyle(role: TextThemeRole.bodyMedium);

  /// The `body-small` role.
  static const bodySmall = TextStyle(role: TextThemeRole.bodySmall);

  /// The `label-large` role.
  static const labelLarge = TextStyle(role: TextThemeRole.labelLarge);

  /// The `label-medium` role.
  static const labelMedium = TextStyle(role: TextThemeRole.labelMedium);

  /// The `label-small` role.
  static const labelSmall = TextStyle(role: TextThemeRole.labelSmall);
}

/// Flutter's `ThemeData`, subset.
class ThemeData {
  /// Creates a theme, defaulting to the Material 3 light scheme.
  ThemeData({
    ColorScheme? colorScheme,
    TextTheme? textTheme,
    this.breakpoints = const Breakpoints(),
    Map<String, Color> colorTokens = const {},
    this.tokens = const [],
    this.extensions = const [],
    this.fontFamily =
        'system-ui, -apple-system, "Segoe UI", Roboto, sans-serif',
    this.fontFamilyFallback,
    this.fonts = const [],
    this.textSelectionTheme,
    this.focusColor,
    this.scaffoldBackgroundColor,
    this.scrollbarTheme,
    this.datePickerTheme,
    this.inputDecorationTheme,
    this.navigationRailTheme,
    this.cardTheme,
    this.chipTheme,
    this.expansionTileTheme,
    this.filledButtonTheme,
    this.elevatedButtonTheme,
    this.outlinedButtonTheme,
    this.textButtonTheme,
    this.iconButtonTheme,
    this.dividerTheme,
    this.dialogTheme,
    this.appBarTheme,
    this.listTileTheme,
    this.tooltipTheme,
    this.snackBarTheme,
    this.progressIndicatorTheme,
    this.bottomSheetTheme,
    this.drawerTheme,
    this.checkboxTheme,
    this.switchTheme,
    this.radioTheme,
    this.sliderTheme,
    this.tabBarTheme,
    this.popupMenuTheme,
    this.navigationBarTheme,
  }) : colorScheme = colorScheme ?? const ColorScheme.light(),
       textTheme = textTheme ?? TextTheme(),
       _ownColorTokens = colorTokens,
       colorTokens = _withTokens(
         colorTokens,
         tokens,
         dark: (colorScheme?.brightness ?? Brightness.light) == Brightness.dark,
       );

  // The theme as `Theme.of` hands it out: same everything, but the scheme's
  // roles and the color tokens are the theme's variables (see
  // `ColorScheme._followed`), so what a page builds from them follows the
  // light/dark switch.
  ThemeData._followed(ThemeData t)
    : colorScheme = t.colorScheme._followed(),
      textTheme = t.textTheme,
      breakpoints = t.breakpoints,
      colorTokens = {
        for (final e in t.colorTokens.entries)
          e.key: e.value.variableName != null
              ? e.value
              : Color.variable(CssVariable('--t-${e.key}'), fallback: e.value),
      },
      _ownColorTokens = t._ownColorTokens,
      tokens = t.tokens,
      extensions = t.extensions,
      fontFamily = t.fontFamily,
      fontFamilyFallback = t.fontFamilyFallback,
      fonts = t.fonts,
      textSelectionTheme = t.textSelectionTheme,
      focusColor = t.focusColor,
      scaffoldBackgroundColor = t.scaffoldBackgroundColor,
      scrollbarTheme = t.scrollbarTheme,
      datePickerTheme = t.datePickerTheme,
      inputDecorationTheme = t.inputDecorationTheme,
      navigationRailTheme = t.navigationRailTheme,
      cardTheme = t.cardTheme,
      chipTheme = t.chipTheme,
      expansionTileTheme = t.expansionTileTheme,
      filledButtonTheme = t.filledButtonTheme,
      elevatedButtonTheme = t.elevatedButtonTheme,
      outlinedButtonTheme = t.outlinedButtonTheme,
      textButtonTheme = t.textButtonTheme,
      iconButtonTheme = t.iconButtonTheme,
      dividerTheme = t.dividerTheme,
      dialogTheme = t.dialogTheme,
      appBarTheme = t.appBarTheme,
      listTileTheme = t.listTileTheme,
      tooltipTheme = t.tooltipTheme,
      snackBarTheme = t.snackBarTheme,
      progressIndicatorTheme = t.progressIndicatorTheme,
      bottomSheetTheme = t.bottomSheetTheme,
      drawerTheme = t.drawerTheme,
      checkboxTheme = t.checkboxTheme,
      switchTheme = t.switchTheme,
      radioTheme = t.radioTheme,
      sliderTheme = t.sliderTheme,
      tabBarTheme = t.tabBarTheme,
      popupMenuTheme = t.popupMenuTheme,
      navigationBarTheme = t.navigationBarTheme;

  /// The `colorTokens` as given, without the typed [tokens] that joined
  /// them (what [copyWith] hands back to the constructor).
  final Map<String, Color> _ownColorTokens;

  /// A copy with the given fields replaced (Flutter's `copyWith`). A null
  /// one keeps this theme's value (it cannot clear it, as in Flutter).
  ///
  /// `// web:` the typed [tokens] resolve to the side of the brightness of
  /// the copy's `colorScheme`, so `copyWith(colorScheme: dark)` swaps them.
  ThemeData copyWith({
    ColorScheme? colorScheme,
    TextTheme? textTheme,
    Breakpoints? breakpoints,
    Map<String, Color>? colorTokens,
    List<ColorToken>? tokens,
    List<ThemeExtension<dynamic>>? extensions,
    String? fontFamily,
    List<String>? fontFamilyFallback,
    List<FontFace>? fonts,
    TextSelectionThemeData? textSelectionTheme,
    Color? focusColor,
    Color? scaffoldBackgroundColor,
    ScrollbarThemeData? scrollbarTheme,
    DatePickerThemeData? datePickerTheme,
    InputDecorationTheme? inputDecorationTheme,
    CardThemeData? cardTheme,
    ChipThemeData? chipTheme,
    ExpansionTileThemeData? expansionTileTheme,
    FilledButtonThemeData? filledButtonTheme,
    ElevatedButtonThemeData? elevatedButtonTheme,
    OutlinedButtonThemeData? outlinedButtonTheme,
    TextButtonThemeData? textButtonTheme,
    IconButtonThemeData? iconButtonTheme,
    NavigationRailThemeData? navigationRailTheme,
    DividerThemeData? dividerTheme,
    DialogThemeData? dialogTheme,
    AppBarThemeData? appBarTheme,
    ListTileThemeData? listTileTheme,
    TooltipThemeData? tooltipTheme,
    SnackBarThemeData? snackBarTheme,
    ProgressIndicatorThemeData? progressIndicatorTheme,
    BottomSheetThemeData? bottomSheetTheme,
    DrawerThemeData? drawerTheme,
    CheckboxThemeData? checkboxTheme,
    SwitchThemeData? switchTheme,
    RadioThemeData? radioTheme,
    SliderThemeData? sliderTheme,
    TabBarThemeData? tabBarTheme,
    PopupMenuThemeData? popupMenuTheme,
    NavigationBarThemeData? navigationBarTheme,
  }) => ThemeData(
    colorScheme: colorScheme ?? this.colorScheme,
    textTheme: textTheme ?? this.textTheme,
    breakpoints: breakpoints ?? this.breakpoints,
    colorTokens: colorTokens ?? _ownColorTokens,
    tokens: tokens ?? this.tokens,
    extensions: extensions ?? this.extensions,
    fontFamily: fontFamily ?? this.fontFamily,
    fontFamilyFallback: fontFamilyFallback ?? this.fontFamilyFallback,
    fonts: fonts ?? this.fonts,
    textSelectionTheme: textSelectionTheme ?? this.textSelectionTheme,
    focusColor: focusColor ?? this.focusColor,
    scaffoldBackgroundColor:
        scaffoldBackgroundColor ?? this.scaffoldBackgroundColor,
    scrollbarTheme: scrollbarTheme ?? this.scrollbarTheme,
    datePickerTheme: datePickerTheme ?? this.datePickerTheme,
    inputDecorationTheme: inputDecorationTheme ?? this.inputDecorationTheme,
    cardTheme: cardTheme ?? this.cardTheme,
    chipTheme: chipTheme ?? this.chipTheme,
    expansionTileTheme: expansionTileTheme ?? this.expansionTileTheme,
    filledButtonTheme: filledButtonTheme ?? this.filledButtonTheme,
    elevatedButtonTheme: elevatedButtonTheme ?? this.elevatedButtonTheme,
    outlinedButtonTheme: outlinedButtonTheme ?? this.outlinedButtonTheme,
    textButtonTheme: textButtonTheme ?? this.textButtonTheme,
    iconButtonTheme: iconButtonTheme ?? this.iconButtonTheme,
    navigationRailTheme: navigationRailTheme ?? this.navigationRailTheme,
    dividerTheme: dividerTheme ?? this.dividerTheme,
    dialogTheme: dialogTheme ?? this.dialogTheme,
    appBarTheme: appBarTheme ?? this.appBarTheme,
    listTileTheme: listTileTheme ?? this.listTileTheme,
    tooltipTheme: tooltipTheme ?? this.tooltipTheme,
    snackBarTheme: snackBarTheme ?? this.snackBarTheme,
    progressIndicatorTheme:
        progressIndicatorTheme ?? this.progressIndicatorTheme,
    bottomSheetTheme: bottomSheetTheme ?? this.bottomSheetTheme,
    drawerTheme: drawerTheme ?? this.drawerTheme,
    checkboxTheme: checkboxTheme ?? this.checkboxTheme,
    switchTheme: switchTheme ?? this.switchTheme,
    radioTheme: radioTheme ?? this.radioTheme,
    sliderTheme: sliderTheme ?? this.sliderTheme,
    tabBarTheme: tabBarTheme ?? this.tabBarTheme,
    popupMenuTheme: popupMenuTheme ?? this.popupMenuTheme,
    navigationBarTheme: navigationBarTheme ?? this.navigationBarTheme,
  );

  /// The theme that follows the page's light/dark: what [Theme.of] returns.
  late final ThemeData _view = ThemeData._followed(this);

  // The typed [tokens] join the map, on this theme's side: from here on
  // (the page's variables, the dark theme's `light-dark()`, `tw()`'s check)
  // both are the same thing.
  static Map<String, Color> _withTokens(
    Map<String, Color> colorTokens,
    List<ColorToken> tokens, {
    required bool dark,
  }) {
    if (tokens.isEmpty) return colorTokens;
    final out = {...colorTokens};
    for (final token in tokens) {
      if (out.containsKey(token.name)) {
        throw ArgumentError.value(
          token.name,
          'tokens',
          thorError(
            'THOR-R021',
            'the color `${token.name}` is declared twice in the theme (in '
                '`colorTokens` or twice in `tokens`); each name has one '
                'value per theme',
          ),
        );
      }
      out[token.name] = dark ? token.dark : token.light;
    }
    return out;
  }

  /// A theme using the Material 3 light color scheme.
  factory ThemeData.light() => ThemeData();

  /// A theme using the Material 3 dark color scheme.
  factory ThemeData.dark() => ThemeData(colorScheme: const ColorScheme.dark());

  /// Colors used across the theme.
  ///
  /// `// web:` from `Theme.of(context)` these are the theme's variables (see
  /// [ColorScheme]); on a theme you construct, the colors you gave.
  final ColorScheme colorScheme;

  /// Text styles used across the theme.
  final TextTheme textTheme;

  /// The widths of the `WindowSizeClass`es (`Breakpoints(medium: 640)`).
  final Breakpoints breakpoints;

  /// Typed values of the app's own (Flutter's `ThemeExtension`), read with
  /// `Theme.of(context).extension<T>()`. They may publish CSS variables too.
  final List<ThemeExtension<dynamic>> extensions;

  /// The extension of type [T], or null.
  T? extension<T extends ThemeExtension<T>>() {
    for (final e in extensions) {
      if (e is T) return e;
    }
    return null;
  }

  /// The app's own colors beyond the scheme's roles, published as
  /// `--t-<name>` (read them with `ThemeColor.token('<name>')`). Give the
  /// dark theme the same names. `// web:` the web counterpart of Flutter's
  /// `ThemeExtension`: a CSS variable follows the light/dark switch, a Dart
  /// value could not.
  final Map<String, Color> colorTokens;

  /// The app's own colors, typed ([ColorToken]): each one carries its light
  /// and dark value, and this theme publishes the side of its brightness.
  /// Give the light and the dark theme the same list. They are also in
  /// [colorTokens].
  final List<ColorToken> tokens;

  /// Every CSS custom property of this theme (scheme roles, tokens, font).
  ///
  /// With [nested] the roles that are their own variable (a scheme taken
  /// from `Theme.of`) are left to the ancestor theme; see
  /// [ColorScheme.toCssVariables].
  CssDeclarations toCssVariables({bool nested = false}) => {
    ...colorScheme.toCssVariables(nested: nested),
    for (final e in colorTokens.entries)
      '--t-${e.key}': _publish('--t-${e.key}', e.value),
    for (final e in extensions) ...e.toCssVariables(),
    '--t-scaffold': ?_publishOrNull('--t-scaffold', scaffoldBackgroundColor),
    ...?scrollbarTheme?._variables(),
    'font-family': ?_stackWithFallbacks(),
  };

  /// [fontFamily] with each [fonts] fallback face right after its family:
  /// the resized local font covers the page until the file arrives.
  String? _stackWithFallbacks() {
    // Flutter's list of names: the server writes the CSS stack (a name with
    // spaces is quoted; a generic family or an already quoted name is not).
    final family = fontFamily;
    final stack = [
      // One name with a space (`Exo 2`) is quoted; a CSS stack (with a comma)
      // is the author's own.
      if (family != null)
        family.contains(' ') &&
                !family.contains(',') &&
                !family.startsWith('"') &&
                !family.startsWith("'")
            ? '"$family"'
            : family,
      for (final f in fontFamilyFallback ?? const <String>[])
        f.contains(' ') && !f.startsWith('"') && !f.startsWith("'")
            ? '"$f"'
            : f,
    ].join(', ');
    if (stack.isEmpty) return null;
    final fallbacks = {
      for (final f in fonts)
        if (f.fallback != null) f._family.toLowerCase(): f.fallbackFamily,
    };
    if (fallbacks.isEmpty) return stack;
    final out = <String>[];
    for (final part in stack.split(',')) {
      final name = part.trim();
      out.add(name);
      final key = name.replaceAll(RegExp('^["\']|["\']\$'), '').toLowerCase();
      final fallback = fallbacks.remove(key);
      if (fallback != null) out.add('"$fallback"');
    }
    return out.join(', ');
  }

  /// Font family applied to all text (Flutter's default: a system font
  /// stack). A CSS stack string (`'Inter, sans-serif'`) still works; in
  /// Flutter's shape, one name here and the rest in [fontFamilyFallback].
  final String? fontFamily;

  /// Families tried, in order, when [fontFamily] is unavailable (Flutter's
  /// `fontFamilyFallback`). `// web:` the server writes them after
  /// [fontFamily] in the one CSS `font-family` stack.
  final List<String>? fontFamilyFallback;

  /// The app's own font files (the web counterpart of the `fonts:` of a
  /// Flutter `pubspec.yaml`): each becomes an `@font-face`, and the ones
  /// with `preload` are fetched with the page.
  final List<FontFace> fonts;

  /// Selection and caret colors (Flutter's `TextSelectionThemeData`).
  final TextSelectionThemeData? textSelectionTheme;

  /// The focus ring of whatever the keyboard reaches (`:focus-visible`).
  /// Flutter paints focus per widget; the web draws one ring for every
  /// link, button and control.
  final Color? focusColor;

  /// The color behind the page (Flutter's `scaffoldBackgroundColor`): the
  /// `body`, so the gaps between panels and the overscroll. Null uses
  /// `colorScheme.surface`.
  ///
  /// `// web:` published as `--t-scaffold`, so a dark theme with its own
  /// value switches with the rest.
  final Color? scaffoldBackgroundColor;

  /// The scrollbars of the page and of every scrollable (Flutter's
  /// `ScrollbarThemeData`), as `scrollbar-width` and `scrollbar-color`.
  final ScrollbarThemeData? scrollbarTheme;

  /// How the date pickers look (`CalendarDatePicker`,
  /// `DatePickerDialog`); `DatePickerTheme` overrides it for a subtree.
  final DatePickerThemeData? datePickerTheme;

  /// The default look of `TextField`, `TextFormField` and
  /// `DropdownButtonFormField`, under each field's own `InputDecoration`.
  /// Its values are resolved on the server: give colors as `ThemeColor`
  /// variables so they follow the dark theme.
  final InputDecorationTheme? inputDecorationTheme;

  /// Defaults of every `NavigationRail` (Flutter's
  /// `ThemeData.navigationRailTheme`); `NavigationRailTheme` overrides it
  /// for a subtree.
  final NavigationRailThemeData? navigationRailTheme;
  // The component themes (Flutter's `ThemeData.cardTheme` and the like):
  // each widget reads its own when it builds; its own parameters win over
  // the theme, and the theme over the widget's defaults. Colors are resolved
  // on the server: give them as `ThemeColor` variables to follow dark.

  /// The default look of `Card`.
  final CardThemeData? cardTheme;

  /// The default look of the chips (`Chip`, `InputChip`, `FilterChip`,
  /// `ChoiceChip`, `ActionChip`).
  final ChipThemeData? chipTheme;

  /// The default look of `ExpansionTile`.
  final ExpansionTileThemeData? expansionTileTheme;

  /// The default `ButtonStyle` of `FilledButton`.
  final FilledButtonThemeData? filledButtonTheme;

  /// The default `ButtonStyle` of `ElevatedButton`.
  final ElevatedButtonThemeData? elevatedButtonTheme;

  /// The default `ButtonStyle` of `OutlinedButton`.
  final OutlinedButtonThemeData? outlinedButtonTheme;

  /// The default `ButtonStyle` of `TextButton`.
  final TextButtonThemeData? textButtonTheme;

  /// The default `ButtonStyle` of every `IconButton`.
  final IconButtonThemeData? iconButtonTheme;

  /// The default look of `Divider` and `VerticalDivider`.
  final DividerThemeData? dividerTheme;

  /// The default look of `AlertDialog` and `Dialog`.
  final DialogThemeData? dialogTheme;

  /// The default look of `AppBar`.
  final AppBarThemeData? appBarTheme;

  /// The default look of `ListTile`.
  final ListTileThemeData? listTileTheme;

  /// The default look and timing of `Tooltip`.
  final TooltipThemeData? tooltipTheme;

  /// The default look of `SnackBar`.
  final SnackBarThemeData? snackBarTheme;

  /// The default look of `LinearProgressIndicator` and `CircularProgressIndicator`.
  final ProgressIndicatorThemeData? progressIndicatorTheme;

  /// The default look of `ModalBottomSheet`.
  final BottomSheetThemeData? bottomSheetTheme;

  /// The default look of `Drawer`.
  final DrawerThemeData? drawerTheme;

  /// The default look of `Checkbox` and `CheckboxListTile`.
  final CheckboxThemeData? checkboxTheme;

  /// The default look of `Switch` and `SwitchListTile`.
  final SwitchThemeData? switchTheme;

  /// The default look of `Radio` and `RadioListTile`.
  final RadioThemeData? radioTheme;

  /// The default look of `Slider`.
  final SliderThemeData? sliderTheme;

  /// The default look of `TabBar`.
  final TabBarThemeData? tabBarTheme;

  /// The default look of the menu of `PopupMenuButton`.
  final PopupMenuThemeData? popupMenuTheme;

  /// The default look of `NavigationBar`.
  final NavigationBarThemeData? navigationBarTheme;

  /// Brightness of `colorScheme`.
  Brightness get brightness => colorScheme.brightness;
}

/// When text in a font that hasn't loaded yet shows (`font-display`).
enum FontDisplay {
  /// The fallback font at once, swapped when the file arrives: no
  /// invisible text (the default).
  swap('swap'),

  /// Invisible for a moment, then the fallback, swapped only if the file
  /// arrives soon.
  fallback('fallback'),

  /// Used only if already cached or very quick; else the fallback stays.
  optional('optional'),

  /// Invisible text until the file arrives.
  block('block');

  const FontDisplay(this.css);

  /// The CSS keyword.
  final String css;
}

/// A font file of the app (`@font-face`): [family] as `TextStyle` and
/// `ThemeData.fontFamily` name it, served at [url].
///
/// ```dart
/// FontFace('Figtree', url: '/fonts/figtree.woff2',
///     weight: FontWeight.w300, maxWeight: FontWeight.w900, preload: true)
/// ```
class FontFace {
  /// A face of [family].
  const FontFace(
    this.family, {
    required this.url,
    this.weight = FontWeight.normal,
    this.maxWeight,
    this.style = FontStyle.normal,
    this.display = FontDisplay.swap,
    this.preload = false,
    this.unicodeRange,
    this.fallback,
  });

  /// The family name.
  final String family;

  /// Where the file is served (`.woff2`).
  final String url;

  /// Its weight, or the lightest one of a variable font (with
  /// [maxWeight]).
  final FontWeight weight;

  /// A variable font: the heaviest weight the file covers.
  final FontWeight? maxWeight;

  /// Normal or italic.
  final FontStyle style;

  /// What shows while it loads.
  final FontDisplay display;

  /// Fetched with the page (`<link rel="preload">` and the `Link` header):
  /// the face of the first screen's text, so it doesn't swap in late.
  ///
  /// Only when the page uses it: its CSS names the [family] in a
  /// `font-family` (in any variant: hover, a breakpoint, a dialog or popover
  /// drawn in the page) and, when the theme has several faces of the family,
  /// a `font-weight` this face covers (400 always counts) and, for an
  /// italic face, a `font-style: italic`. A page that doesn't use it
  /// doesn't preload it: the browser warns about a preload nothing reads.
  /// `// web:` a weight only the browser's own styles set (`<strong>`) is
  /// not seen; that face loads when first used, not with the page.
  final bool preload;

  /// The characters this file covers (`U+0000-00FF, U+2013`): a subset
  /// file (`thor fonts subset`) is only fetched when the page uses one of
  /// them. `null`: all.
  final String? unicodeRange;

  /// A local font resized to this face's metrics, shown while the file
  /// loads: the text doesn't jump when it swaps in. `ThemeData.fontFamily`
  /// gets `"<family> Fallback"` right after [family]; a `TextStyle` with its
  /// own `fontFamily` names [fallbackFamily] in `fontFamilyFallback`.
  final FontFallback? fallback;

  /// The name of the [fallback] face: `"<family> Fallback"`.
  String get fallbackFamily => '$_family Fallback';

  String get _family => family.replaceAll('"', '');

  static final _range = RegExp(
    r'^U\+[0-9A-Fa-f?]{1,6}(-[0-9A-Fa-f]{1,6})?'
    r'(\s*,\s*U\+[0-9A-Fa-f?]{1,6}(-[0-9A-Fa-f]{1,6})?)*$',
  );

  /// The `@font-face` rule (and the [fallback]'s).
  String get css {
    final weights = maxWeight == null
        ? '${weight.value}'
        : '${weight.value} ${maxWeight!.value}';
    final range = unicodeRange?.trim();
    if (range != null && !_range.hasMatch(range)) {
      throw ArgumentError.value(
        unicodeRange,
        'unicodeRange',
        thorError('THOR-R016', 'not a unicode-range (`U+0000-00FF, U+2013`)'),
      );
    }
    final face =
        '@font-face{${cssInline({'font-family': '"$_family"', 'src': '${cssUrl(url)} format("$format")', 'font-weight': weights, 'font-style': style.name, 'font-display': display.css, 'unicode-range': ?range})}}';
    final f = fallback;
    if (f == null) return face;
    return '$face@font-face{${cssInline({'font-family': '"$fallbackFamily"', 'src': f.local.map((l) => 'local("${l.replaceAll('"', '')}")').join(','), 'font-weight': weights, 'font-style': style.name, 'size-adjust': ?_pct(f.sizeAdjust), 'ascent-override': ?_pct(f.ascentOverride), 'descent-override': ?_pct(f.descentOverride), 'line-gap-override': ?_pct(f.lineGapOverride)})}}';
  }

  static String? _pct(double? v) => v == null ? null : '${cssNum(v * 100)}%';

  /// The file's format, from its extension (`woff2`, `woff`, `opentype`,
  /// `truetype`).
  String get format {
    final path = url.split(RegExp('[?#]')).first.toLowerCase();
    if (path.endsWith('.woff2')) return 'woff2';
    if (path.endsWith('.woff')) return 'woff';
    if (path.endsWith('.otf')) return 'opentype';
    return 'truetype';
  }

  /// Its media type, for the preload (`font/woff2`, `font/ttf`…): a
  /// preload with the wrong type is dropped by the browser.
  String get mimeType => switch (format) {
    'woff2' => 'font/woff2',
    'woff' => 'font/woff',
    'opentype' => 'font/otf',
    _ => 'font/ttf',
  };
}

/// A local font resized to a [FontFace]'s metrics (the numbers
/// `size-adjust` and the overrides take, as fractions: `1.07` = 107 %).
/// Get them from the font's own tables (`thor fonts metrics`, or tools
/// like fontaine/capsize) against the [local] font.
///
/// ```dart
/// FontFace('Figtree', url: '/fonts/figtree.woff2',
///     fallback: FontFallback(sizeAdjust: 1.012, ascentOverride: 0.94,
///         descentOverride: 0.25, lineGapOverride: 0))
/// ```
class FontFallback {
  /// The first of [local] the system has, with these overrides.
  const FontFallback({
    this.local = const ['Arial', 'Helvetica Neue', 'Helvetica'],
    this.sizeAdjust,
    this.ascentOverride,
    this.descentOverride,
    this.lineGapOverride,
  });

  /// System fonts to try, in order (`local("Arial")`).
  final List<String> local;

  /// `size-adjust`.
  final double? sizeAdjust;

  /// `ascent-override`.
  final double? ascentOverride;

  /// `descent-override`.
  final double? descentOverride;

  /// `line-gap-override`.
  final double? lineGapOverride;
}

/// Flutter's `TextSelectionThemeData`: the colors of selected text and of
/// the caret.
class TextSelectionThemeData {
  /// Selection and caret colors; null ones keep the browser's.
  const TextSelectionThemeData({
    this.selectionColor,
    this.selectionTextColor,
    this.cursorColor,
  });

  /// Background of selected text (`::selection`).
  final Color? selectionColor;

  /// `// web:` text color of the selection (Flutter keeps the text's).
  final Color? selectionTextColor;

  /// The caret in text fields (`caret-color`).
  final Color? cursorColor;
}

/// Flutter's `ScrollbarThemeData`: the look of the scrollbars.
///
/// ```dart
/// ThemeData(
///   scrollbarTheme: ScrollbarThemeData(
///     thickness: WidgetStatePropertyAll(6),
///     thumbColor: WidgetStatePropertyAll(line),
///   ),
/// )
/// ```
///
/// `// web:` the browser draws the bar; CSS only picks `scrollbar-width`
/// and `scrollbar-color`, and the properties are resolved once (no hover or
/// drag states). [thickness] 0 hides the bar, up to 10 is `thin`, more is
/// the browser's classic one. [trackColor] needs [thumbColor] (CSS takes
/// both or none). Radius, `thumbVisibility` and `interactive` have no CSS.
class ScrollbarThemeData {
  /// Scrollbar values; null ones keep the browser's.
  const ScrollbarThemeData({this.thickness, this.thumbColor, this.trackColor});

  /// How thick the bar is.
  final WidgetStateProperty<double?>? thickness;

  /// The thumb.
  final WidgetStateProperty<Color?>? thumbColor;

  /// The track.
  final WidgetStateProperty<Color?>? trackColor;

  // The enabled, idle value of each property.
  Color? get _thumb => thumbColor?.resolve(const <WidgetState>{});
  Color? get _track => trackColor?.resolve(const <WidgetState>{});

  Map<String, String> _variables() => {
    // `scrollbar-color` takes both colors or none: a track alone is dropped.
    if (_thumb case final thumb?)
      '--t-scrollbar-thumb': _publish('--t-scrollbar-thumb', thumb),
    if (_thumb != null)
      '--t-scrollbar-track': ?_publishOrNull('--t-scrollbar-track', _track),
  };

  /// The rule for every scrollable, or null when the theme sets nothing.
  String? get rule {
    final width = thickness?.resolve(const <WidgetState>{});
    final size = width == null
        ? null
        : width <= 0
        ? ScrollbarWidth.none
        : width <= 10
        ? ScrollbarWidth.thin
        : ScrollbarWidth.auto;
    final track = _track != null ? 'var(--t-scrollbar-track)' : 'transparent';
    final decls = [
      if (size != null) 'scrollbar-width:${size.css}',
      if (_thumb != null) 'scrollbar-color:var(--t-scrollbar-thumb) $track',
    ];
    return decls.isEmpty ? null : '*{${decls.join(';')}}';
  }
}

/// Flutter's `ThemeExtension<T>`: the app's own theme values, typed
/// (`ThemeData(extensions: [BrandShape(radius: 8)])`, read with
/// `Theme.of(context).extension<BrandShape>()`).
///
/// ```dart
/// class BrandShape extends ThemeExtension<BrandShape> {
///   const BrandShape({this.radius = 8});
///   final double radius;
/// }
/// ```
///
/// `// web:` a value that must follow the light/dark switch has to reach
/// the page as a CSS variable: return it from [toCssVariables]
/// (`{'--t-brand-radius': '8px'}`). A theme change is CSS (the page swaps
/// `light-dark()` values in the browser), so nothing interpolates between two
/// themes in Dart: [lerp] defaults to Flutter's step (this one before half,
/// the other one after) and a subclass overrides it only to animate something
/// itself. Flutter's abstract `copyWith` is not required here: a subclass
/// declares its own, with its own named parameters.
abstract class ThemeExtension<T extends ThemeExtension<T>> {
  /// Const constructor for subclasses.
  const ThemeExtension();

  /// This extension moved [t] of the way to [other] (Flutter's `lerp`).
  /// Default: [other] from `t >= 0.5`, this one before, and this one when
  /// [other] is null.
  T lerp(covariant T? other, double t) =>
      (other == null || t < 0.5 ? this : other) as T;

  /// CSS custom properties this extension publishes (default: none).
  CssDeclarations toCssVariables() => const {};
}

/// Flutter's `Theme`.
///
/// Two channels, on purpose:
/// - **Dart**: `Theme.of(context)` for values you need while building.
/// - **CSS**: color roles as custom properties on the child element, so
///   static stylesheets (hover, focus, media queries) follow the theme and a
///   theme switch never has to rebuild them.
class Theme extends StatelessWidget {
  /// Creates a theme scope around `child`.
  const Theme({
    super.key,
    required this.data,
    this.darkData,
    this.themeMode = ThemeMode.system,
    required this.child,
  });

  /// Theme applied to `child`.
  final ThemeData data;

  /// With [ThemeMode.system], applied through `prefers-color-scheme: dark`:
  /// the CSS switches instantly and even on the server-rendered page, with no
  /// JavaScript. `Theme.of` still returns [data] (the server can't know the
  /// user's scheme), so prefer CSS variables for colors that must follow it.
  final ThemeData? darkData;

  /// Which of `data`/`darkData` is active (Flutter's default:
  /// `ThemeMode.system`).
  final ThemeMode themeMode;

  /// Subtree the theme applies to.
  final Widget child;

  /// Makes [data] what `Theme.of` returns below, without publishing CSS
  /// (`ThorApp(theme:)` publishes it on `:root`).
  static Widget provide({required ThemeData data, required Widget child}) =>
      _InheritedTheme(data: data, child: child);

  /// Returns the nearest enclosing `ThemeData`, or the default theme.
  ///
  /// `// web:` the colors of its `colorScheme` and `colorTokens` are the
  /// theme's CSS variables (`var(--t-primary, #6750a4)`), not the light
  /// values the server would otherwise write: the page's dark mode switches
  /// them in the browser, without a reload. Reading their channels
  /// (`.value`, `.red`…) throws (THOR-R023); `withValues(alpha:)` works.
  static ThemeData of(BuildContext context) =>
      (context.dependOnInheritedWidgetOfExactType<_InheritedTheme>()?.data ??
              _fallback)
          ._view;

  static final _fallback = ThemeData();

  @override
  Widget build(BuildContext context) {
    final dark = darkData;
    final active = themeMode == ThemeMode.dark && dark != null ? dark : data;
    CssDeclarations vars(ThemeData t) => t.toCssVariables(nested: true);
    return _InheritedTheme(
      data: active,
      child: WrapWith(
        WrapData(
          // A class (not inline) so the dark media query can override it.
          classCss: {...vars(active), 'color': 'var(--t-on-surface)'},
          conditions: [
            if (themeMode == ThemeMode.system && dark != null)
              ConditionalCss(CssCondition.dark, vars(dark)),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// The theme's colors as CSS variables, for building widgets: they follow
/// the light/dark switch, which `Theme.of(context)` (resolved on the server)
/// can't.
///
/// ```dart
/// Container(color: ThemeColor.surfaceContainer, child: Text('x',
///   style: TextStyle(color: ThemeColor.onSurfaceVariant)))
/// ```
abstract final class ThemeColor {
  /// The `--t-primary` role.
  static const primary = Color.variable(CssVariable('--t-primary'));

  /// The `--t-on-primary` role.
  static const onPrimary = Color.variable(CssVariable('--t-on-primary'));

  /// The `--t-secondary` role.
  static const secondary = Color.variable(CssVariable('--t-secondary'));

  /// The `--t-on-secondary` role.
  static const onSecondary = Color.variable(CssVariable('--t-on-secondary'));

  /// The `--t-primary-container` role.
  static const primaryContainer = Color.variable(
    CssVariable('--t-primary-container'),
  );

  /// The `--t-on-primary-container` role.
  static const onPrimaryContainer = Color.variable(
    CssVariable('--t-on-primary-container'),
  );

  /// The `--t-secondary-container` role.
  static const secondaryContainer = Color.variable(
    CssVariable('--t-secondary-container'),
  );

  /// The `--t-on-secondary-container` role.
  static const onSecondaryContainer = Color.variable(
    CssVariable('--t-on-secondary-container'),
  );

  /// The `--t-error` role.
  static const error = Color.variable(CssVariable('--t-error'));

  /// The `--t-on-error` role.
  static const onError = Color.variable(CssVariable('--t-on-error'));

  /// The `--t-surface` role.
  static const surface = Color.variable(CssVariable('--t-surface'));

  /// The `--t-on-surface` role.
  static const onSurface = Color.variable(CssVariable('--t-on-surface'));

  /// The `--t-on-surface-variant` role.
  static const onSurfaceVariant = Color.variable(
    CssVariable('--t-on-surface-variant'),
  );

  /// The `--t-surface-container` role.
  static const surfaceContainer = Color.variable(
    CssVariable('--t-surface-container'),
  );

  /// The `--t-surface-container-highest` role.
  static const surfaceContainerHighest = Color.variable(
    CssVariable('--t-surface-container-highest'),
  );

  /// The `--t-surface-container-low` role.
  static const surfaceContainerLow = Color.variable(
    CssVariable('--t-surface-container-low'),
  );

  /// The `--t-surface-container-high` role.
  static const surfaceContainerHigh = Color.variable(
    CssVariable('--t-surface-container-high'),
  );

  /// The `--t-inverse-surface` role.
  static const inverseSurface = Color.variable(
    CssVariable('--t-inverse-surface'),
  );

  /// The `--t-inverse-on-surface` role (Flutter's `onInverseSurface`).
  static const onInverseSurface = Color.variable(
    CssVariable('--t-inverse-on-surface'),
  );

  /// The `--t-inverse-primary` role.
  static const inversePrimary = Color.variable(
    CssVariable('--t-inverse-primary'),
  );

  /// The `--t-tertiary` role (only when the scheme sets it).
  static const tertiary = Color.variable(CssVariable('--t-tertiary'));

  /// The `--t-on-tertiary` role.
  static const onTertiary = Color.variable(CssVariable('--t-on-tertiary'));

  /// The `--t-tertiary-container` role.
  static const tertiaryContainer = Color.variable(
    CssVariable('--t-tertiary-container'),
  );

  /// The `--t-on-tertiary-container` role.
  static const onTertiaryContainer = Color.variable(
    CssVariable('--t-on-tertiary-container'),
  );

  /// The `--t-error-container` role.
  static const errorContainer = Color.variable(
    CssVariable('--t-error-container'),
  );

  /// The `--t-on-error-container` role.
  static const onErrorContainer = Color.variable(
    CssVariable('--t-on-error-container'),
  );

  /// The `--t-surface-container-lowest` role.
  static const surfaceContainerLowest = Color.variable(
    CssVariable('--t-surface-container-lowest'),
  );

  /// The `--t-outline` role.
  static const outline = Color.variable(CssVariable('--t-outline'));

  /// The `--t-outline-variant` role.
  static const outlineVariant = Color.variable(
    CssVariable('--t-outline-variant'),
  );

  /// One of `ThemeData.colorTokens`.
  static Color token(String name) => Color.variable(CssVariable('--t-$name'));
}

/// The theme switch: a label of the page's hidden checkbox (rendered by
/// `ThorApp` when it has a `darkTheme`), showing [light] in the light theme
/// and [dark] in the dark one. Works with no JavaScript; the checkbox is the
/// focusable control (Tab + Space), its focus ring shows on the label.
///
/// `// web:` not in Flutter (an app would switch `themeMode` with state).
/// The choice is kept in `localStorage` by a tiny inline `<head>` script (no
/// engine) and applied before the first paint; with no JavaScript, or with
/// storage blocked, it lasts for the page view.
class ThemeToggle extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Creates a theme switch.
  const ThemeToggle({
    super.key,
    required this.light,
    required this.dark,
    this.size = 40,
  });

  /// Shown while the light theme is on (e.g. a sun).
  final Widget light;

  /// Shown while the dark theme is on (e.g. a moon).
  final Widget dark;

  /// Side of the square target.
  final double size;

  @override
  Widget build(BuildContext context) => thorElement(
    'label',
    debugName: 'ThemeToggle',
    css: {
      'display': 'inline-grid',
      'place-items': 'center',
      'width': cssPx(size),
      'height': cssPx(size),
      'border-radius': '6px',
      'cursor': 'pointer',
      'flex': 'none',
    },
    conditions: [
      const ConditionalCss(CssCondition.hoverEnabled, {
        'background-color': 'color-mix(in srgb, currentColor 8%, transparent)',
      }),
      const ConditionalCss(
        CssCondition.within(':root:has(#$themeToggleId:focus-visible)'),
        {'outline': '2px solid var(--t-primary)', 'outline-offset': '2px'},
      ),
    ],
    attributes: const {'for': themeToggleId},
    children: [
      ResponsiveVisibility(brightness: Brightness.light, child: light),
      ResponsiveVisibility(brightness: Brightness.dark, child: dark),
    ],
  );
}

class _InheritedTheme extends InheritedWidget implements InheritedMemoKey {
  const _InheritedTheme({required this.data, required super.child});

  final ThemeData data;

  @override
  bool updateShouldNotify(covariant _InheritedTheme oldComponent) =>
      !identical(oldComponent.data, data);

  /// Readers see only the theme data.
  @override
  Object? get memoKey => data;
}
