import 'package:thor_ui/thor_ui.dart';

import '../../theme/component_themes/studio_chip_theme.dart';
import '../../tokens/color/studio_tone.dart';

/// A small pill that labels something: "New", a version, a status.
///
/// ```dart
/// StudioStatusLabel(label: Text('New'))
/// StudioStatusLabel(label: Text('Deprecated'), tone: StudioTone.warn)
/// ```
///
/// It is a label, not a control: no focus, no events. Colors and size come
/// from the nearest [StudioChipThemeData] (the neutral gray, or its `info`,
/// `ok`, `warn`, `danger` and `flutter` tones); [theme] overrides it.
///
/// `// web:` it does not decorate another widget the way Flutter's `Badge`
/// (an indicator over its child) does, so it is not called `Badge`: it is
/// the pill of a docs page ("New", a version) and stands alone in a row.
class StudioStatusLabel extends StatelessWidget implements ThorElementWidget {
  /// A pill showing [label] in [tone].
  const StudioStatusLabel({
    super.key,
    required this.label,
    this.tone = StudioTone.neutral,
    this.theme,
  });

  /// The content, usually a `Text`.
  final Widget label;

  /// Neutral gray, or one of the status tones.
  final StudioTone tone;

  /// Overrides the chip theme.
  final StudioChipThemeData? theme;

  @override
  Widget build(BuildContext context) {
    final t = StudioChipThemeData.of(context, theme);
    final (background, foreground) = switch (tone) {
      StudioTone.neutral => (t.color, t.labelColor),
      StudioTone.info => (t.info.background, t.info.foreground),
      StudioTone.ok => (t.ok.background, t.ok.foreground),
      StudioTone.warn => (t.warn.background, t.warn.foreground),
      StudioTone.danger => (t.danger.background, t.danger.foreground),
      StudioTone.flutter => (t.flutter.background, t.flutter.foreground),
    };
    return Container(
      padding: t.badgePadding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(t.radius),
      ),
      child: DefaultTextStyle(
        style: t.badgeLabelStyle.copyWith(
          // The line box is the label's height: the text centers itself.
          height: t.badgeHeight / (t.badgeLabelStyle.fontSize ?? 12),
          color: foreground,
        ),
        child: label,
      ),
    );
  }
}
