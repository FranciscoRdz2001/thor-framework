import 'package:thor_ui/thor_ui.dart';

import '../../l10n/studio_localizations.dart';
import '../../theme/component_themes/studio_code_theme.dart';
import '../../theme/studio_extra_text_styles.dart';
import '../../tokens/color/studio_surface_colors.dart';

/// The two-line version of `StudioFlutterCompare`, for the top of a page:
/// what you would use in Flutter, and what you use in Thor.
///
/// ```dart
/// StudioCompareSummary(
///   flutter: 'setState(() => count++)',
///   thor: 'count.value++',
///   flutterLabel: l10n.inFlutter,
///   thorLabel: l10n.inThor,
/// )
/// ```
///
/// Each line is reading text (15 px) where a span between backticks is code
/// (`` `setState` ``, in mono). Long lines wrap inside the box.
class StudioCompareSummary extends StatelessWidget
    implements ThorElementWidget {
  /// A summary of [flutter] against [thor].
  const StudioCompareSummary({
    super.key,
    required this.flutter,
    required this.thor,
    this.flutterLabel,
    this.thorLabel,
  });

  /// What you use in Flutter.
  final String flutter;

  /// What you use in Thor.
  final String thor;

  /// The label of the Flutter line (default:
  /// `StudioLocalizations.flutterLabel`).
  final String? flutterLabel;

  /// The label of the Thor line (default: `StudioLocalizations.thorLabel`).
  final String? thorLabel;

  @override
  Widget build(BuildContext context) {
    final theme = StudioCodeThemeData.of(context);
    final scheme = Theme.of(context).colorScheme;
    final l10n = StudioLocalizations.of(context);
    return Semantics(
      role: SemanticsRole.list,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: StudioSurfaceColors.canvas,
          border: Border.all(color: theme.borderColor),
          borderRadius: BorderRadius.circular(theme.radius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            _Line(
              label: flutterLabel ?? l10n.flutterLabel,
              code: flutter,
              color: scheme.onSurface,
            ),
            _Line(
              label: thorLabel ?? l10n.thorLabel,
              code: thor,
              color: scheme.onSurface,
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget implements ThorElementWidget {
  const _Line({required this.label, required this.code, required this.color});

  final String label;
  final String code;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final codeStyles = StudioExtraTextStyles.of(context);
    final theme = StudioCodeThemeData.of(context);
    return Semantics(
      role: SemanticsRole.listItem,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        spacing: 12,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: text.labelMedium.copyWith(color: theme.headerTextColor),
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  // Odd pieces between backticks are code.
                  for (final (i, piece) in code.split('`').indexed)
                    if (piece.isNotEmpty)
                      TextSpan(
                        text: piece,
                        style: i.isOdd
                            ? codeStyles.codeMedium.copyWith(
                                fontSizeLength: const Length.em(0.875),
                              )
                            : null,
                      ),
                ],
              ),
              style: text.bodyLarge.copyWith(
                fontSize: 15,
                height: 1.5,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
