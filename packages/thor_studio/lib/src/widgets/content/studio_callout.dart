import 'package:thor_ui/thor_ui.dart';

import '../../attributes.dart';
import '../../icons.dart';
import '../../theme/component_themes/studio_callout_theme.dart';
import '../../tokens/color/studio_tone.dart';
import '../../tokens/color/studio_tone_colors.dart';
import 'studio_content_icons.dart';

/// A note in the reading flow: a tone's icon and color, a [title] and a body,
/// on the tone's tint with its color as a bar down the left edge.
///
/// ```dart
/// StudioCallout(
///   tone: StudioTone.warn,
///   title: l10n.warning, // the tone's name, in the page's language
///   body: 'A state method cannot await a Future that the server created.',
/// )
///
/// // Rich content (rendered markdown, code, a list):
/// StudioCallout(title: 'Tip', tone: StudioTone.ok, child: StudioProse(html))
/// ```
///
/// `// web:` Flutter has no callout. The element is `role="note"` and its [title] is its accessible name, so a
/// screen reader announces "Warning, note" before the text. The tone is never
/// the only signal: each has its own icon and its title. Colors come from
/// `StudioCalloutThemeData` (each tone is a `StudioToneColors`), 4.5:1 in both
/// themes.
class StudioCallout extends StatelessWidget implements ThorElementWidget {
  /// A callout of [tone]: give it a [body] (text) or a [child] (widgets).
  const StudioCallout({
    super.key,
    this.tone = StudioTone.info,
    required this.title,
    this.body,
    this.child,
  }) : assert(
         (body == null) != (child == null),
         'StudioCallout takes a body or a child, not both',
       );

  /// Its tone.
  final StudioTone tone;

  /// The bold first line and the note's accessible name.
  final String title;

  /// The text.
  final String? body;

  /// The content, when text is not enough.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = StudioCalloutThemeData.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final StudioToneColors colors = switch (tone) {
      StudioTone.info || StudioTone.neutral => theme.info,
      StudioTone.ok => theme.ok,
      StudioTone.warn => theme.warn,
      StudioTone.danger => theme.danger,
      StudioTone.flutter => theme.flutter,
    };
    final icon = switch (tone) {
      StudioTone.info || StudioTone.neutral => StudioIcons.info,
      StudioTone.ok => StudioContentIcons.lightbulb,
      StudioTone.warn => StudioIcons.triangleAlert,
      StudioTone.danger => StudioContentIcons.octagonAlert,
      StudioTone.flutter => StudioContentIcons.arrowLeftRight,
    };
    return StudioAttributes(
      {'role': 'note', 'aria-label': title},
      child: Container(
        padding: theme.padding,
        decoration: BoxDecoration(
          color: colors.background,
          // The tone's bar down the left edge, a hairline round the rest.
          border: Border(
            left: BorderSide(color: colors.foreground, width: 3),
            top: BorderSide(color: colors.border),
            right: BorderSide(color: colors.border),
            bottom: BorderSide(color: colors.border),
          ),
          borderRadius: BorderRadius.circular(theme.radius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: theme.gap,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Semantics(
                hidden: true,
                child: Icon(
                  icon,
                  size: theme.iconSize,
                  color: colors.foreground,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 4,
                children: [
                  Text(
                    title,
                    style: text.titleSmall.copyWith(
                      fontSize: 13,
                      color: colors.foreground,
                    ),
                  ),
                  DefaultTextStyle(
                    style: text.bodyLarge.copyWith(
                      fontSize: 15,
                      color: scheme.onSurface,
                      height: 1.6,
                    ),
                    child: body != null ? Text(body!) : child!,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
