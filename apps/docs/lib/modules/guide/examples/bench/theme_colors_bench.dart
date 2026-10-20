/// `:::bench bench-theme-colors`: a `ColorScheme` you change. A Switch picks
/// light or dark, another the accent; the card, the chip and the button read
/// `Theme.of(context)` and follow.
///
/// Both choices are finite, so each combination is a `ThemeData` the server
/// compiled; the browser only swaps one for another.
library;

import 'package:thor_ui/thor_ui.dart';

import 'bench_example.dart';

/// Light or dark.
enum ThemeLook {
  /// `ColorScheme.light`.
  light,

  /// `ColorScheme.dark`.
  dark,
}

/// The accents the second Switch offers. Colors are held as numbers: the
/// state runs in the browser, which has no Flutter `Color`.
enum Accent {
  /// The Material 3 default.
  violet(0xFF6750A4, 0xFFD0BCFF, 0xFF381E72, '0xFF6750A4', '0xFFD0BCFF'),

  /// A green-blue.
  teal(0xFF0F766E, 0xFF5EEAD4, 0xFF042F2E, '0xFF0F766E', '0xFF5EEAD4'),

  /// An orange.
  orange(0xFFC2410C, 0xFFFDBA74, 0xFF431407, '0xFFC2410C', '0xFFFDBA74');

  const Accent(
    this.lightValue,
    this.darkValue,
    this.onDarkValue,
    this.lightHex,
    this.darkHex,
  );

  /// The primary color in the light scheme.
  final int lightValue;

  /// The primary color in the dark scheme.
  final int darkValue;

  /// The text on the primary color in the dark scheme.
  final int onDarkValue;

  /// The light primary as the Code view writes it.
  final String lightHex;

  /// The dark primary as the Code view writes it.
  final String darkHex;

  /// The hex the Code view shows for [look].
  String hex(ThemeLook look) => look == ThemeLook.dark ? darkHex : lightHex;
}

/// The scheme of [look] with [accent].
ColorScheme accentScheme(Accent accent, ThemeLook look) =>
    look == ThemeLook.dark
    ? ColorScheme.dark(
        primary: Color(accent.darkValue),
        onPrimary: Color(accent.onDarkValue),
      )
    : ColorScheme.light(primary: Color(accent.lightValue));

/// What the panel controls and the stage reads.
class ThemeColorsViewModel extends ThorState {
  /// Light or dark.
  final look = state(ThemeLook.light);

  /// The accent.
  final accent = state(Accent.violet);

  /// The `colorScheme` line of the Code view.
  String schemeCode() =>
      'colorScheme: ColorScheme.${look.value.name}(primary: Color(${accent.value.hex(look.value)})),';

  /// What the look Switch calls.
  void setLook(Set<ThemeLook> value) => look.value = value.first;

  /// What the accent Switch calls.
  void setAccent(Set<Accent> value) => accent.value = value.first;
}

/// One instance, at the top level: the browser boots with it.
final themeColors = ThemeColorsViewModel();

/// The example: two Switches, the stage and its code.
final themeColorsBench = BenchExample(
  title: (t) => t.exThemeColorsTitle,
  description: (t) => t.exThemeColorsDescription,
  stage: const ThemeColorsStage(),
  code: BenchCode([
    const BenchCodeLine('final theme = ThemeData('),
    BenchCodeLine.live(themeColors.schemeCode, indent: 1),
    const BenchCodeLine(');'),
    const BenchCodeLine(' '),
    const BenchCodeLine('// in any widget:'),
    const BenchCodeLine('final scheme = Theme.of(context).colorScheme;'),
    const BenchCodeLine('Container(color: scheme.surfaceContainer)'),
  ]),
  controls: [
    BenchSwitch<ThemeLook>(
      label: (t) => t.exThemeLook,
      value: themeColors.look.value,
      onChanged: themeColors.setLook,
      segments: [
        BenchSegment(ThemeLook.light, label: (t) => t.exThemeLookLight),
        BenchSegment(ThemeLook.dark, label: (t) => t.exThemeLookDark),
      ],
    ),
    BenchSwitch<Accent>(
      label: (t) => t.exThemeAccent,
      value: themeColors.accent.value,
      onChanged: themeColors.setAccent,
      segments: [
        BenchSegment(Accent.violet, label: (t) => t.exThemeAccentViolet),
        BenchSegment(Accent.teal, label: (t) => t.exThemeAccentTeal),
        BenchSegment(Accent.orange, label: (t) => t.exThemeAccentOrange),
      ],
    ),
  ],
);

/// The stage: a card under the chosen theme.
class ThemeColorsStage extends StatelessWidget {
  /// The stage of the example.
  const ThemeColorsStage({super.key});

  @override
  Widget build(BuildContext context) => Watch.field(
    themeColors.look,
    builder: (look) => Watch.field(
      themeColors.accent,
      builder: (accent) => Theme(
        data: ThemeData(colorScheme: accentScheme(accent, look)),
        child: const _ThemedCard(),
      ),
    ),
  );
}

class _ThemedCard extends StatelessWidget {
  const _ThemedCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'New',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
          ),
          Text(
            'Weekly summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          Text(
            'What changed in your app this week.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'View details',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
