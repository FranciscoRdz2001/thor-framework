import 'package:thor_ui/thor_ui.dart';

import '../../theme/component_themes/studio_code_theme.dart';
import '../../theme/studio_extra_colors.dart';
import '../../theme/studio_extra_text_styles.dart';
import '../../tokens/shape/studio_radii.dart';

/// A keyboard key, drawn as a key cap.
///
/// ```dart
/// Row(spacing: 4, children: [StudioKbd('Ctrl'), StudioKbd('K')])
/// ```
///
/// It is announced as a keyboard key (`<kbd>`-like role) and the text stays
/// selectable. Pass a symbol (`⌘`) with the word a screen reader should say as
/// [semanticLabel] (`Command`).
///
/// `// web:` Flutter has no key cap; this is the `<kbd>` element, named by
/// [semanticLabel] when the glyphs (`⌘K`) read badly aloud.
class StudioKbd extends StatelessWidget implements ThorElementWidget {
  /// A key cap showing [keys].
  const StudioKbd(this.keys, {super.key, this.semanticLabel});

  /// The key or combination (`K`, `Ctrl`, `⌘`).
  final String keys;

  /// What a screen reader says when [keys] is a symbol.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final extra = StudioExtraColors.of(context);
    final code = StudioCodeThemeData.of(context);
    return Semantics(
      role: SemanticsRole.keyboardKey,
      label: semanticLabel,
      child: Container(
        constraints: const BoxConstraints(minWidth: 24),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: code.color,
          // The thicker bottom edge is the key's side.
          border: Border(
            left: BorderSide(color: code.borderColor),
            top: BorderSide(color: code.borderColor),
            right: BorderSide(color: code.borderColor),
            bottom: BorderSide(color: extra.lineStrong, width: 2),
          ),
          borderRadius: BorderRadius.circular(StudioRadii.small),
        ),
        child: Text(
          keys,
          style: StudioExtraTextStyles.of(context).codeSmall.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
