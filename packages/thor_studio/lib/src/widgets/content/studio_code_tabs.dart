import 'package:thor_ui/thor_ui.dart';

import '../../theme/component_themes/studio_code_theme.dart';
import '../../theme/studio_extra_colors.dart';
import '../../theme/studio_extra_text_styles.dart';
import 'support/studio_code_language.dart';
import 'support/studio_code_pane.dart';
import 'support/studio_line_range.dart';

/// One tab of a [StudioCodeTabs]: a [label] and the [code] behind it.
class StudioCodeTab {
  /// A tab labeled [label] (often a file name or a package manager).
  const StudioCodeTab({
    required this.label,
    required this.code,
    this.language = StudioCodeLanguage.dart,
    this.highlight = const [],
    this.changed = const [],
  });

  /// The tab's text.
  final String label;

  /// The source.
  final String code;

  /// Its language.
  final StudioCodeLanguage language;

  /// Lines to draw the eye to.
  final List<StudioLineRange> highlight;

  /// Lines that changed.
  final List<StudioLineRange> changed;
}

/// Several code blocks behind tabs, in one frame.
///
/// ```dart
/// StudioCodeTabs(
///   tabs: [
///     StudioCodeTab(label: 'main.dart', code: mainSource),
///     StudioCodeTab(label: 'pubspec.yaml', code: pubspecSource, language: StudioCodeLanguage.yaml),
///   ],
///   copyLabel: l10n.copy,
///   copiedLabel: l10n.copied,
/// )
/// ```
///
/// `// web:` the tabs are native radios (thor_ui's `DefaultTabController`,
/// `TabBar` and `TabBarView`): no JavaScript, arrow keys move between the
/// tabs, the browser restores the choice on back and forward, and the
/// selection is exposed as a radio group. Flutter's `TabBar` is the same API.
/// Give each set an [id] when a page has several and you want stable ids.
class StudioCodeTabs extends StatelessWidget implements ThorElementWidget {
  /// Tabs over [tabs]; the first one is open.
  const StudioCodeTabs({
    super.key,
    required this.tabs,
    this.id,
    this.initialIndex = 0,
    this.copyButton = true,
    this.copyLabel,
    this.copiedLabel,
  });

  /// The tabs (at least one).
  final List<StudioCodeTab> tabs;

  /// Names the radio group and the panels' ids (default: its place in the
  /// page).
  final String? id;

  /// The tab open when the page loads.
  final int initialIndex;

  /// Whether the copy buttons show (it needs `scripts/studio-code.js`).
  final bool copyButton;

  /// The copy buttons' text (null: no buttons).
  final String? copyLabel;

  /// The text after copying (default: [copyLabel]).
  final String? copiedLabel;

  @override
  Widget build(BuildContext context) {
    assert(tabs.isNotEmpty, 'StudioCodeTabs needs a tab');
    final theme = StudioCodeThemeData.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: theme.color,
        border: Border.all(color: theme.borderColor),
        borderRadius: BorderRadius.circular(theme.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: DefaultTabController(
        id: id,
        length: tabs.length,
        initialIndex: initialIndex,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabBar(
              isScrollable: true,
              indicatorColor: scheme.accent,
              labelColor: scheme.onSurface,
              unselectedLabelColor: theme.headerTextColor,
              dividerColor: theme.borderColor,
              tabs: [
                for (final tab in tabs)
                  Tab(
                    height: 44,
                    child: Text(
                      tab.label,
                      style: StudioExtraTextStyles.of(
                        context,
                      ).codeSmall.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
            TabBarView(
              children: [
                for (final tab in tabs)
                  StudioCodePane(
                    code: tab.code,
                    language: tab.language,
                    highlight: tab.highlight,
                    changed: tab.changed,
                    copyButton: copyButton,
                    copyLabel: copyLabel,
                    copiedLabel: copiedLabel,
                    semanticLabel: tab.label,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
