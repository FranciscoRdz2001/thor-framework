import 'package:thor_ui/html.dart' show css;
import 'package:thor_ui/thor_ui.dart';

import '../../l10n/studio_localizations.dart';
import '../inputs/studio_segmented_control.dart';

/// The group name of [StudioThemeChoice]'s radios (`name=` of the inputs).
const studioThemeChoiceName = 'studio-theme';

/// The three-way theme choice: System (follow the operating system), Light
/// or Dark, as a segmented control of native radios.
///
/// ```dart
/// ThorApp(
///   theme: StudioTheme.light(),
///   darkTheme: StudioTheme.dark(),
///   styles: [...StudioThemeChoice.styles],
///   child: StudioScaffold(
///     appBar: StudioTopBar(brand: …, actions: [StudioThemeChoice()]),
///     …
///   ),
/// )
/// ```
///
/// `StudioThemeToggle` stays the two-state switch (light/dark, a sun and a
/// moon); this is for the page that wants "System" as an explicit option, a
/// settings page or the phone drawer. Both can live on a page.
///
/// It works with no JavaScript: the radios are the state and
/// [StudioThemeChoice.styles] (put in `ThorApp(styles:)`) read it with
/// `:root:has(input[name="studio-theme"][value="dark"]:checked)` to set the
/// page's `color-scheme`. System is checked when the page loads and sets
/// `color-scheme: light dark`, so the studio's `light-dark()` tokens follow
/// the system and ignore thor's own switch.
///
/// `// web:` limits, on purpose. The choice lasts for the page view (thor's
/// inline theme script remembers only `StudioThemeToggle`'s checkbox, and
/// a new script would need a new CSP hash). An app that wants it remembered
/// stores the value itself. The rules set `color-scheme`, which is what the
/// studio's tokens read; widgets that switch by brightness (`CssCondition.dark`,
/// `ResponsiveVisibility`, themed images) follow thor's checkbox instead, so
/// they follow the system or the toggle, not this choice.
class StudioThemeChoice extends StatelessWidget implements ThorElementWidget {
  /// A System / Light / Dark choice; [initial] is checked when the page
  /// loads (default: System). Its labels come from [StudioLocalizations].
  const StudioThemeChoice({
    super.key,
    this.initial = StudioThemeMode.system,
    this.semanticLabel,
  });

  /// The choice that is checked when the page loads.
  final StudioThemeMode initial;

  /// The group's accessible name (default: `StudioLocalizations.themeChoice`).
  final String? semanticLabel;

  /// The page rules that make the radios change the theme: list them in
  /// `ThorApp(styles:)`.
  static final List<StyleRule> styles = [
    for (final mode in StudioThemeMode.values)
      css(
        ':root:root:has(input[name="$studioThemeChoiceName"]'
        '[value="${mode.name}"]:checked)',
      ).props(
        StyleProps(colorScheme: mode.colorScheme),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = StudioLocalizations.of(context);
    String label(StudioThemeMode mode) => switch (mode) {
      StudioThemeMode.system => l10n.themeSystem,
      StudioThemeMode.light => l10n.themeLight,
      StudioThemeMode.dark => l10n.themeDark,
    };
    return StudioSegmentedControl<String>(
      name: studioThemeChoiceName,
      semanticLabel: semanticLabel ?? l10n.themeChoice,
      selected: {initial.name},
      segments: [
        for (final mode in StudioThemeMode.values)
          StudioButtonSegment(value: mode.name, label: Text(label(mode))),
      ],
    );
  }
}

/// What [StudioThemeChoice] picks.
enum StudioThemeMode {
  /// Follow the operating system (`color-scheme: light dark`).
  system(CssColorScheme.lightDark),

  /// Always the light theme.
  light(CssColorScheme.light),

  /// Always the dark theme.
  dark(CssColorScheme.dark);

  const StudioThemeMode(this.colorScheme);

  /// The `color-scheme` the page takes under this choice.
  final CssColorScheme colorScheme;
}
