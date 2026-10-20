// ignore_for_file: thor_lints/avoid_raw_css
// (a fixture that checks raw CSS next to typed values)
// The page's look as a thor theme: its tokens are Material roles of a
// light and a dark `ThemeData` (ThorApp publishes them as `--t-*` CSS
// variables and flips them with the theme switch), plus the few rules that
// only this page has (keyframes, gradient text, the sticky header…).
import 'package:thor_ui/html.dart' show css;
import 'package:thor_ui/thor_ui.dart';

// Short names for the theme roles, so the sections read like a design
// spec. They are CSS variables: they follow the light/dark switch.
const background = ThemeColor.surface;
const foreground = ThemeColor.onSurface;
const card = ThemeColor.surfaceContainer;
const primary = ThemeColor.primary;
const primaryForeground = ThemeColor.onPrimary;
const secondary = ThemeColor.secondaryContainer;
const secondaryForeground = ThemeColor.onSecondaryContainer;
const muted = ThemeColor.surfaceContainerHighest;
const mutedForeground = ThemeColor.onSurfaceVariant;
const border = ThemeColor.outlineVariant;

/// `bg-muted/50 dark:bg-card` and `bg-muted/60 dark:bg-card`: the tinted
/// surface of most cards (theme tokens, since light and dark differ).
const surface = Color.variable(CssVariable('--t-surface-soft'));
const surfaceStrong = Color.variable(CssVariable('--t-surface-soft-strong'));

/// The header's inset glow (dark in light mode, light in dark mode).
const headerGlow = Color.variable(CssVariable('--t-header-glow'));

/// Tailwind's default sans stack (the page loads no web font).
const sans =
    'ui-sans-serif, system-ui, sans-serif, "Apple Color Emoji", '
    '"Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji"';

Color _hsl(num h, num s, num l, [num a = 1]) {
  final hsl = '${cssNum(h)} ${cssNum(s)}% ${cssNum(l)}%';
  return Color.css(a == 1 ? 'hsl($hsl)' : 'hsl($hsl / ${cssNum(a)})');
}

/// Tailwind's type scale as Material roles (sizes/line heights of
/// `text-xs` … `text-6xl`, no tracking).
TextStyle _type(double size, double line, [FontWeight? weight, double? ls]) =>
    TextStyle(
      fontSize: size,
      height: line / size,
      fontWeight: weight ?? FontWeight.w400,
      letterSpacing: ls ?? 0,
    );

final textTheme = TextTheme(
  displayLarge: _type(48, 48, FontWeight.w700), // hero headline
  displayMedium: _type(36, 40, FontWeight.w700, -0.9), // community title
  headlineLarge: _type(30, 36, FontWeight.w700), // section titles
  headlineSmall: _type(24, 24, FontWeight.w600, -0.6), // card titles
  titleLarge: _type(20, 28), // section subtitles
  titleMedium: _type(18, 28), // eyebrows, small headings
  bodyLarge: _type(16, 24),
  bodyMedium: _type(16, 24), // page text (Tailwind's base)
  bodySmall: _type(14, 20), // descriptions, fields
  labelLarge: _type(14, 20, FontWeight.w500), // buttons, labels
  labelSmall: _type(12, 16, FontWeight.w600), // badges
);

/// From `md` up the big titles grow (`md:text-6xl`, `md:text-5xl`,
/// `md:text-4xl`): one place instead of a wrapper per title.
final _textFromMd = textTheme.copyWith(
  displayLarge: _type(60, 60, FontWeight.w700),
  displayMedium: _type(48, 48, FontWeight.w700, -1.2),
  headlineLarge: _type(36, 40, FontWeight.w700),
);

// Tailwind's widths (the design was drawn on them): 640 / 1024 / 1280.
const _breakpoints = Breakpoints(medium: 640, expanded: 1024, large: 1280);

final lightTheme = ThemeData(
  fontFamily: sans,
  textTheme: textTheme.when(medium: _textFromMd),
  breakpoints: _breakpoints,
  colorScheme: ColorScheme(
    brightness: Brightness.light,
    primary: _hsl(15, 100, 50),
    onPrimary: _hsl(0, 0, 98),
    secondary: _hsl(0, 0, 96.1),
    onSecondary: _hsl(0, 0, 9),
    secondaryContainer: _hsl(0, 0, 96.1),
    onSecondaryContainer: _hsl(0, 0, 9),
    error: _hsl(0, 84.2, 60.2),
    onError: _hsl(0, 0, 98),
    surface: _hsl(0, 0, 100),
    onSurface: _hsl(0, 0, 3.9),
    onSurfaceVariant: _hsl(0, 0, 45.1),
    surfaceContainer: _hsl(0, 0, 100),
    surfaceContainerHighest: _hsl(0, 0, 96.1),
    outline: _hsl(0, 0, 89.8),
    outlineVariant: _hsl(0, 0, 89.8),
  ),
  colorTokens: {
    'surface-soft': _hsl(0, 0, 96.1, 0.5),
    'surface-soft-strong': _hsl(0, 0, 96.1, 0.6),
    'header-glow': const Color(0x16000000),
  },
);

final darkTheme = ThemeData(
  fontFamily: sans,
  textTheme: textTheme.when(medium: _textFromMd),
  breakpoints: _breakpoints,
  colorScheme: ColorScheme(
    brightness: Brightness.dark,
    primary: _hsl(15, 100, 50),
    onPrimary: _hsl(0, 0, 98),
    secondary: _hsl(0, 0, 14.9),
    onSecondary: _hsl(0, 0, 98),
    secondaryContainer: _hsl(0, 0, 14.9),
    onSecondaryContainer: _hsl(0, 0, 98),
    error: _hsl(0, 62.8, 30.6),
    onError: _hsl(0, 0, 98),
    surface: _hsl(0, 0, 3.9),
    onSurface: _hsl(0, 0, 98),
    onSurfaceVariant: _hsl(0, 0, 63.9),
    surfaceContainer: _hsl(0, 0, 7.8),
    surfaceContainerHighest: _hsl(0, 0, 14.9),
    outline: _hsl(0, 0, 14.9),
    outlineVariant: _hsl(0, 0, 14.9),
  ),
  colorTokens: {
    'surface-soft': _hsl(0, 0, 7.8),
    'surface-soft-strong': _hsl(0, 0, 7.8),
    'header-glow': const Color(0x24FFFFFF),
  },
);

/// A one-off Tailwind size (`text-5xl` digit, sponsor names…) that is no
/// theme role: (font-size, line-height).
TextStyle text(
  double size, {
  FontWeight? weight,
  Color? color,
  double? letterSpacing,
}) {
  final lineHeight = switch (size) {
    12 => 16.0,
    14 => 20.0,
    16 => 24.0,
    18 || 20 => 28.0,
    24 => 32.0,
    30 => 36.0,
    36 => 40.0,
    _ => size,
  };
  return TextStyle(
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
  );
}

/// What only this page has: page basics, keyframes, the gradient headline
/// and the few effects no widget covers. Everything else (hover, theme,
/// breakpoints, visibility) is widget props.
final List<StyleRule> landingStyles = [
  ...thorResetStyles,
  // No `scroll-behavior: smooth`: with LazyLayout sections a smooth jump to
  // an anchor lands wrong on the first visit (sections change height while
  // scrolling past); an instant jump is exact.
  css('body').styles(raw: {'-webkit-font-smoothing': 'antialiased'}),
  // Tailwind's `container`: centered, full width up to its max.
  css('.container').styles(raw: {'width': '100%', 'margin-inline': 'auto'}),
  css('.site-header').styles(
    raw: {
      'position': 'sticky',
      'top': '20px',
      'z-index': '40',
      'margin-inline': 'auto',
    },
  ),
  css('.gradient-text').styles(
    raw: {
      'background-image':
          'linear-gradient(to right, #D247BF, var(--t-primary))',
      '-webkit-background-clip': 'text',
      'background-clip': 'text',
      'color': 'transparent',
    },
  ),
  // Sponsors marquee (paused on hover), hero glow and image border pulse.
  css.keyframes('marquee', {
    'from': const StyleProps(raw: {'transform': 'translateX(0)'}),
    'to': const StyleProps(raw: {'transform': 'translateX(-50%)'}),
  }),
  css('.marquee').styles(raw: {'animation': 'marquee 25s linear infinite'}),
  css('.marquee:hover').styles(raw: {'animation-play-state': 'paused'}),
  css.keyframes('glow', {
    'from': const StyleProps(
      raw: {'opacity': '0.5', 'transform': 'translateY(30px)'},
    ),
    'to': const StyleProps(raw: {'opacity': '1', 'transform': 'translateY(0)'}),
  }),
  css('.glow').styles(
    raw: {
      'animation': 'glow 2s linear infinite alternate',
      'filter': 'blur(64px)',
    },
  ),
  css.keyframes('border-pulse', {
    'from': const StyleProps(
      raw: {
        'border-top-color':
            'color-mix(in srgb, var(--t-primary) 10%, transparent)',
      },
    ),
    'to': const StyleProps(
      raw: {
        'border-top-color':
            'color-mix(in srgb, var(--t-primary) 60%, transparent)',
      },
    ),
  }),
  css('.hero-image').styles(
    raw: {
      // Painted above the glow (`relative`).
      'position': 'relative',
      'border-top': '2px solid transparent',
      'animation': 'border-pulse 2s linear infinite alternate',
    },
  ),
  css('.blob').styles(raw: {'filter': 'blur(64px)', 'z-index': '-1'}),
  // Contact form select (the input look on the native <select>).
  css('.select').styles(
    raw: {
      'height': '40px',
      'min-height': '0',
      'padding': '0 12px',
      'border': '1px solid var(--t-outline-variant)',
      'border-radius': '6px',
      'background-color': 'var(--t-surface)',
      'color': 'var(--t-on-surface)',
      'font-size': '14px',
    },
  ),
  // FAQ: an accordion look on the native <details> group.
  css(
    '.accordion',
  ).styles(raw: {'border': '0', 'border-radius': '0', 'overflow': 'visible'}),
  css(
    '.accordion details',
  ).styles(raw: {'border-bottom': '1px solid var(--t-outline-variant)'}),
  css('.accordion summary').styles(
    raw: {
      'padding': '16px 0',
      'min-height': '0',
      'font-weight': '500',
      'color': 'inherit',
    },
  ),
  css('.accordion summary:hover').styles(raw: {'text-decoration': 'underline'}),
  // Footer: the brand spans the whole first row, then two of six columns.
  css('.footer-brand').styles(raw: {'grid-column': '1 / -1'}),
  css.media('(min-width: 1200px)', [
    css('.footer-brand').styles(raw: {'grid-column': 'span 2'}),
  ]),
];
