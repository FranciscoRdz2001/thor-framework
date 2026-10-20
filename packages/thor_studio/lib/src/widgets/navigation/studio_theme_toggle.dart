import 'package:thor_ui/thor_ui.dart';

import '../../icons.dart';
import '../../theme/component_themes/studio_nav_theme.dart';
import '../inputs/state_styles.dart';

/// The light/dark switch of the top bar: thor's `ThemeToggle` (a label of the
/// page's hidden checkbox, so it works with no JavaScript) wearing the
/// studio's sun and moon.
///
/// ```dart
/// // The accessible name comes from the app:
/// // ThorApp(darkTheme: …, themeToggleLabel: l10n.switchTheme)
/// const StudioThemeToggle()
/// ```
///
/// It needs a `ThorApp` with a `darkTheme` (the studio's `StudioTheme.dark`).
/// The choice is remembered by thor's own inline script and applied before
/// the first paint.
///
/// Motion: the icon that shows turns a quarter turn and grows from 60 % while
/// it fades in (200 ms, the studio's enter curve), and the whole switch
/// squeezes to `scale(.97)` while pressed. `// web:` the turn is an
/// `@starting-style`: the theme's icons are shown and hidden with `display`,
/// and a box that starts to be shown plays it, with no script. Under
/// `prefers-reduced-motion` the icons just swap.
class StudioThemeToggle extends StatelessWidget implements ThorElementWidget {
  /// A theme switch; [size] is its square target (default: the search pill's
  /// height, so the bar's controls line up).
  const StudioThemeToggle({super.key, this.size});

  /// The side of the square target.
  final double? size;

  @override
  Widget build(BuildContext context) {
    final nav = StudioNavThemeData.of(context);
    return Styled(
      duration: nav.duration,
      curve: nav.curve,
      style: const StyleProps(
        scale: 1,
      ).when(pressed: StyleProps(scale: nav.pressScale)),
      child: ThemeToggle(
        size: size ?? nav.searchHeight,
        // The sun comes in turning clockwise, the moon the other way.
        light: const _ToggleIcon(StudioIcons.sun, -0.25),
        dark: const _ToggleIcon(StudioIcons.moon, 0.25),
      ),
    );
  }
}

/// One of the toggle's icons: it turns in (a quarter turn, from 60 %, 200 ms)
/// when its theme starts to show.
class _ToggleIcon extends StatelessWidget implements ThorElementWidget {
  const _ToggleIcon(this.icon, this.turns);

  final IconData icon;
  final double turns;

  @override
  Widget build(BuildContext context) {
    final nav = StudioNavThemeData.of(context);
    return StateStyles(
      duration: nav.toggleDuration,
      curve: nav.curve,
      states: [
        StateStyle(
          const CssCondition.startingStyle(),
          StyleProps(opacity: 0, turns: turns, scale: nav.toggleEnterScale),
        ),
      ],
      child: Icon(icon, size: nav.iconSize, color: nav.hintColor),
    );
  }
}
