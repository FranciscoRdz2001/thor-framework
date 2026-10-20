import 'package:thor_ui/thor_ui.dart';

import '../../l10n/studio_localizations.dart';
import '../../theme/component_themes/studio_code_theme.dart';
import '../../theme/studio_extra_colors.dart';
import 'support/studio_code_diff.dart';
import 'support/studio_code_language.dart';
import 'support/studio_code_pane.dart';

/// The "In Flutter / In Thor" pair: the same example written both ways behind
/// a Flutter / Thor selector, with the lines that differ marked on each side.
///
/// ```dart
/// StudioFlutterCompare(
///   flutterCode: "Text('Hello', style: TextStyle(fontSize: 20))",
///   thorCode: "Text('Hello', style: TextStyle(fontSize: 20))",
///   flutterLabel: l10n.inFlutter, // 'In Flutter'
///   thorLabel: l10n.inThor,       // 'In Thor'
///   copyLabel: l10n.copy,
///   copiedLabel: l10n.copied,
/// )
/// ```
///
/// A line is marked when the other version has no line with the same text
/// (indentation and blank lines do not count): the reader's eye lands on what
/// changes when moving from one to the other. Turn it off with
/// [markChanges].
///
/// `// web:` the selector is a native radio group (`DefaultTabController`,
/// `TabBar`, `TabBarView`): no JavaScript, arrow keys switch sides, and both
/// codes are in the page, so search and print find them.
class StudioFlutterCompare extends StatelessWidget
    implements ThorElementWidget {
  /// The same example, [flutterCode] and [thorCode].
  const StudioFlutterCompare({
    super.key,
    required this.flutterCode,
    required this.thorCode,
    this.flutterLabel,
    this.thorLabel,
    this.language = StudioCodeLanguage.dart,
    this.initialIndex = 1,
    this.markChanges = true,
    this.id,
    this.copyButton = true,
    this.copyLabel,
    this.copiedLabel,
  });

  /// The Flutter source.
  final String flutterCode;

  /// The Thor source.
  final String thorCode;

  /// The Flutter tab's text (default: `StudioLocalizations.flutterLabel`).
  final String? flutterLabel;

  /// The Thor tab's text (default: `StudioLocalizations.thorLabel`).
  final String? thorLabel;

  /// The language of both.
  final StudioCodeLanguage language;

  /// The tab open when the page loads: 0 Flutter, 1 Thor (the default).
  final int initialIndex;

  /// Whether to mark the lines that differ.
  final bool markChanges;

  /// Names the radio group (default: its place in the page).
  final String? id;

  /// Whether the copy buttons show (it needs `scripts/studio-code.js`).
  final bool copyButton;

  /// The copy buttons' text (default: `StudioLocalizations.copy`).
  final String? copyLabel;

  /// The text after copying (default: [copyLabel]).
  final String? copiedLabel;

  @override
  Widget build(BuildContext context) {
    final theme = StudioCodeThemeData.of(context);
    final scheme = Theme.of(context).colorScheme;
    final l10n = StudioLocalizations.of(context);
    final flutter = flutterLabel ?? l10n.flutterLabel;
    final thor = thorLabel ?? l10n.thorLabel;
    return Container(
      decoration: BoxDecoration(
        color: theme.color,
        border: Border.all(color: theme.borderColor),
        borderRadius: BorderRadius.circular(theme.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: DefaultTabController(
        id: id,
        length: 2,
        initialIndex: initialIndex,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabBar(
              indicatorColor: scheme.accent,
              labelColor: scheme.onSurface,
              unselectedLabelColor: theme.headerTextColor,
              dividerColor: theme.borderColor,
              tabs: [
                Tab(height: 44, text: flutter),
                Tab(height: 44, text: thor),
              ],
            ),
            TabBarView(
              children: [
                StudioCodePane(
                  code: flutterCode,
                  language: language,
                  highlight: markChanges
                      ? StudioCodeDiff.added(thorCode, flutterCode)
                      : const [],
                  copyButton: copyButton,
                  copyLabel: copyLabel,
                  copiedLabel: copiedLabel,
                  semanticLabel: flutter,
                ),
                StudioCodePane(
                  code: thorCode,
                  language: language,
                  highlight: markChanges
                      ? StudioCodeDiff.added(flutterCode, thorCode)
                      : const [],
                  copyButton: copyButton,
                  copyLabel: copyLabel,
                  copiedLabel: copiedLabel,
                  semanticLabel: thor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
