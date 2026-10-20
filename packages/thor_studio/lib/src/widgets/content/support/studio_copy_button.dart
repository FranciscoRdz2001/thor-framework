import 'package:thor_ui/thor_ui.dart';

import '../../../attributes.dart';
import '../../../icons.dart';
import '../../../theme/component_themes/studio_code_theme.dart';
import '../../../theme/studio_extra_colors.dart';
import '../../../tokens/shape/studio_radii.dart';
import 'studio_when.dart';

/// The copy button of a code pane.
///
/// A progressive enhancement: the button is a plain `<button>` with
/// `data-studio-copy`, and `scripts/studio-code.js` (published into the app's
/// `web/scripts/` by the `thor` command, loaded with
/// `html.script(src: 'scripts/studio-code.js', defer: true)`) copies the
/// pane's text on click and shows [copiedLabel] for a moment. Without the
/// script the button is hidden (`:root:not([data-studio-js])`, which the
/// script sets) and the code stays selectable.
///
/// `// web:` Flutter's `Clipboard.setData` needs an engine state method. A
/// code block must work on a page that has no `ThorState`, so the copy is
/// this 20-line script instead.
class StudioCopyButton extends StatelessWidget implements ThorElementWidget {
  /// A copy button labeled [label] that shows [copiedLabel] after copying.
  const StudioCopyButton({
    super.key,
    required this.label,
    required this.copiedLabel,
    this.iconOnly = false,
  });

  /// Whether the button is the 28 px icon alone ([label] is its accessible
  /// name and tooltip): the button that floats over a code pane's corner.
  final bool iconOnly;

  /// The button's text and accessible name ("Copy").
  final String label;

  /// The text shown for a moment after the copy ("Copied").
  final String copiedLabel;

  @override
  Widget build(BuildContext context) {
    final extra = StudioExtraColors.of(context);
    final code = StudioCodeThemeData.of(context);
    // The copy icon, swapped for a check while the button says it copied
    // (the script sets `data-copied` for a moment).
    const icon = Stack(
      children: [
        StudioWhen(
          CssCondition.within('[data-copied]'),
          StyleProps(opacity: 0),
          child: Icon(StudioIcons.copy, size: 14),
        ),
        Positioned.fill(
          child: StudioWhen(
            CssCondition.within('[data-copied]'),
            StyleProps(opacity: 1),
            child: Opacity(
              opacity: 0,
              child: Icon(StudioIcons.circleCheck, size: 14),
            ),
          ),
        ),
      ],
    );
    final style = TextButton.styleFrom(
      foregroundColor: code.headerTextColor,
      backgroundColor: Colors.transparent,
      overlayColor: extra.hover,
      minimumSize: const Size(28, 28),
      padding: iconOnly
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StudioRadii.control),
      ),
      textStyle: Theme.of(context).textTheme.labelMedium,
    );
    return StudioWhen(
      const CssCondition.within(':root:not([data-studio-js])'),
      const StyleProps(offstage: true),
      child: StudioAttributes(
        {'data-studio-copy': copiedLabel},
        child: Styled(
          style: const StyleProps(
            scale: 1,
          ).when(pressed: StyleProps(scale: code.pressScale)),
          duration: code.duration,
          curve: code.curve,
          // web: the script handles the click; the callback only makes the
          // control a live (not disabled) <button>.
          child: iconOnly
              ? StudioAttributes(
                  // The script swaps the name for [copiedLabel] for a moment.
                  {'aria-label': label, 'title': label},
                  child: TextButton(
                    onPressed: _live,
                    style: style,
                    child: icon,
                  ),
                )
              : TextButton.icon(
                  onPressed: _live,
                  icon: icon,
                  label: Text(label),
                  style: style,
                ),
        ),
      ),
    );
  }
}

void _live() {}
