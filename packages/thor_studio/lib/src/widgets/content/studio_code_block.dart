import 'package:thor_ui/thor_ui.dart';

import '../../attributes.dart';
import '../../l10n/studio_localizations.dart';
import '../../theme/component_themes/studio_code_theme.dart';
import '../../theme/studio_extra_colors.dart';
import '../../theme/studio_extra_text_styles.dart';
import 'support/studio_code_language.dart';
import 'support/studio_code_pane.dart';
import 'support/studio_copy_button.dart';
import 'support/studio_line_range.dart';

/// A code block: an optional file-name title bar (`file.dart — note`, the
/// note in the faint ink) holding the copy button, the code highlighted at
/// render time, and lines you can highlight or mark as changed. Without a
/// title the copy button floats in the top corner.
///
/// ```dart
/// StudioCodeBlock(
///   counterSource,
///   title: 'counter_state.dart',
///   highlight: [StudioLineRange(2)],      // draw the eye to the `state(0)` line
///   changed: StudioLineRange.parse('4-5'), // what this step added
///   copyLabel: 'Copy',                     // optional: the locale's "Copy"
///   copiedLabel: 'Copied',
/// )
/// ```
///
/// A long line scrolls inside the block, never the page. The look comes from
/// `StudioCodeThemeData` (surface, hairline, mono type, line marks) and the colors
/// from `StudioSyntaxColors`, so both themes work with no extra CSS.
///
/// `// web:` the copy button is a progressive enhancement: it needs
/// `scripts/studio-code.js` (see `StudioCopyButton`) and is hidden without it.
/// With no JavaScript the code is plain, selectable text.
class StudioCodeBlock extends StatelessWidget implements ThorElementWidget {
  /// A block showing [code].
  const StudioCodeBlock(
    this.code, {
    super.key,
    this.language = StudioCodeLanguage.dart,
    this.title,
    this.highlight = const [],
    this.changed = const [],
    this.copyButton = true,
    this.copyLabel,
    this.copiedLabel,
  });

  /// The source.
  final String code;

  /// Its language: a [StudioCodeLanguage] (`dart`, `bash`, `yaml` and `json`
  /// are colored, the rest is plain).
  final StudioCodeLanguage language;

  /// A file name or caption for the header (null: no header).
  final String? title;

  /// Lines to draw the eye to.
  final List<StudioLineRange> highlight;

  /// Lines that changed, marked as added.
  final List<StudioLineRange> changed;

  /// Whether the copy button shows (it needs `scripts/studio-code.js`).
  final bool copyButton;

  /// The copy button's text (default: `StudioLocalizations.copy`).
  final String? copyLabel;

  /// The text after copying (default: [copyLabel], or
  /// `StudioLocalizations.copied` without one).
  final String? copiedLabel;

  @override
  Widget build(BuildContext context) {
    final theme = StudioCodeThemeData.of(context);
    final codeStyles = StudioExtraTextStyles.of(context);
    final extra = StudioExtraColors.of(context);
    final l10n = StudioLocalizations.of(context);
    final copy = copyLabel ?? l10n.copy;
    // `file.dart — note`: the name, then the note in the faint ink.
    final cut = title?.indexOf(' — ') ?? -1;
    final name = cut < 0 ? title : title!.substring(0, cut);
    final note = cut < 0 ? null : title!.substring(cut + 3);
    final small = codeStyles.codeSmall.copyWith(fontSizeLength: null);
    return StudioAttributes(
      // The copy button in the title bar finds the code through this.
      const {'data-studio-code': ''},
      child: Container(
        decoration: BoxDecoration(
          color: theme.color,
          border: Border.all(color: theme.borderColor),
          borderRadius: BorderRadius.circular(theme.radius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (name != null)
              Container(
                height: 36,
                padding: EdgeInsets.only(left: theme.padding.left, right: 4),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: theme.borderColor)),
                ),
                child: Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: name),
                            if (note != null)
                              TextSpan(
                                text: ' — $note',
                                style: TextStyle(color: extra.onSurfaceFaint),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: small.copyWith(color: theme.headerTextColor),
                      ),
                    ),
                    if (copyButton)
                      StudioCopyButton(
                        label: copy,
                        copiedLabel:
                            copiedLabel ??
                            (copyLabel == null ? l10n.copied : copy),
                      ),
                  ],
                ),
              ),
            StudioCodePane(
              code: code,
              language: language,
              highlight: highlight,
              changed: changed,
              // With a title bar the button sits in it.
              copyButton: copyButton && name == null,
              copyLabel: copyLabel,
              copiedLabel: copiedLabel,
              semanticLabel: title,
            ),
          ],
        ),
      ),
    );
  }
}
