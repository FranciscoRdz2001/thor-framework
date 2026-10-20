import 'package:thor_ui/html.dart' show css;
import 'package:thor_ui/thor_ui.dart';

import '../color/studio_palette.dart';
import 'studio_durations.dart';

/// Page rules of the studio's motion that no widget can carry: they belong to
/// the whole document, so the app lists them in `ThorApp(styles:)`.
abstract final class StudioMotionStyles {
  /// The theme change as a short cross-fade instead of a flash.
  ///
  /// ```dart
  /// ThorApp(
  ///   theme: StudioTheme.light(),
  ///   darkTheme: StudioTheme.dark(),
  ///   styles: [...StudioMotionStyles.themeFade],
  ///   child: …,
  /// )
  /// ```
  ///
  /// Every color token (`--t-app`, `--t-ink`...) is registered as a `<color>`
  /// and transitioned on `:root` for [StudioDurations.base] (160 ms, short
  /// enough that the page never passes through a grey). The tokens are
  /// `light-dark()` values, so flipping the page's `color-scheme` (the
  /// `ThemeToggle`, or the system) changes their computed value, which is
  /// what starts the transition; everything that reads a token follows it
  /// with no transition of its own, and nothing is animated on load (the
  /// first style has nothing to come from). With `prefers-reduced-motion`
  /// the theme changes at once.
  ///
  /// `// web:` the registered `initial-value` is only what the browsers
  /// without `light-dark()` would show.
  static final List<StyleRule> themeFade = themeFadeWith(const []);

  /// [themeFade] plus the color tokens the app publishes of its own
  /// (`ThemeData(tokens:)` next to the studio's palette), so they ease with
  /// the rest instead of lagging a visible 160 ms behind it.
  ///
  /// ```dart
  /// // The app's own tokens (issue kinds, brand hues...):
  /// const kindError = ColorToken('kind-error', light: …, dark: …);
  /// ThorApp(
  ///   theme: StudioTheme.light().copyWith(tokens: [kindError]),
  ///   styles: [...StudioMotionStyles.themeFadeWith([kindError])],
  ///   child: …,
  /// )
  /// ```
  ///
  /// A token of [extra] whose name is already in [StudioPalette] (or listed
  /// twice) is registered once. The rules are the same as [themeFade]'s: the
  /// `@property` registrations everywhere, the transitions only where motion
  /// is welcome.
  static List<StyleRule> themeFadeWith(Iterable<ColorToken> extra) {
    final seen = <String>{};
    final tokens = [
      for (final token in [...StudioPalette.values, ...extra])
        if (seen.add(token.name)) token,
    ];
    return [
      for (final token in tokens)
        css.colorProperty('--t-${token.name}', initialValue: token.light),
      css.media('(prefers-reduced-motion: no-preference)', [
        css(':root').props(
          StyleProps(
            transition: [
              for (final token in tokens)
                Transition(
                  CssProperty.custom('--t-${token.name}'),
                  StudioDurations.base,
                ),
            ],
          ),
        ),
      ]),
    ];
  }
}
