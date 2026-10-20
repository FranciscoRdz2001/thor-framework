import 'package:thor_ui/thor_ui.dart';

import '../../../attributes.dart';
import '../../../highlight.dart';
import '../../../l10n/studio_localizations.dart';
import '../../../theme/component_themes/studio_code_theme.dart';
import '../../../tokens/color/studio_syntax_colors.dart';
import 'studio_code_language.dart';
import 'studio_copy_button.dart';
import 'studio_line_range.dart';

/// The code of a block: highlighted at render time, scrolling inside itself,
/// with marked lines and a copy button.
///
/// What every code widget (`StudioCodeBlock`, `StudioCodeTabs`,
/// `StudioFlutterCompare`) puts inside its frame. Not exported: use those.
///
/// How the lines are made: consecutive lines with the same mark are one run,
/// so a 40-line block with one highlighted line is three elements, not forty.
/// Every run keeps its own newline, so the `<pre>`'s text is the exact source
/// (what the copy script reads).
class StudioCodePane extends StatelessWidget implements ThorElementWidget {
  /// A pane showing [code].
  const StudioCodePane({
    super.key,
    required this.code,
    this.language = StudioCodeLanguage.dart,
    this.highlight = const [],
    this.changed = const [],
    this.copyButton = true,
    this.copyLabel,
    this.copiedLabel,
    this.semanticLabel,
  });

  /// The source.
  final String code;

  /// Its language.
  final StudioCodeLanguage language;

  /// Lines to draw the eye to.
  final List<StudioLineRange> highlight;

  /// Lines that changed (what a diff adds).
  final List<StudioLineRange> changed;

  /// Whether the copy button shows (it needs `scripts/studio-code.js`).
  final bool copyButton;

  /// The copy button's text (default: `StudioLocalizations.copy`).
  final String? copyLabel;

  /// The text after copying (default: [copyLabel] when given, else
  /// `StudioLocalizations.copied`).
  final String? copiedLabel;

  /// The accessible name of the scrolling code (default: the language).
  final String? semanticLabel;

  // The copy button (28px) and its 8px offset, less the pane's own padding.
  static const _copyStrip = 28.0;

  // The block's own width from which the copy button floats in the corner.
  // web: a container query on the block, so a code block in a narrow column
  // of a wide page keeps its strip.
  static const _floatFrom = 480.0;

  @override
  Widget build(BuildContext context) {
    final theme = StudioCodeThemeData.of(context);
    final scheme = Theme.of(context).colorScheme;
    final style = theme.textStyle.copyWith(color: scheme.onSurface);
    final side = theme.padding.left;
    final runs = _runs(_lines(code.trimRight(), language.name));
    final l10n = StudioLocalizations.of(context);
    final copy = copyLabel ?? l10n.copy;
    return StudioAttributes(
      const {'data-studio-code': ''},
      child: LayoutScope(
        child: Stack(
          children: [
            // A long line scrolls inside the block, not the page. The region
            // is focusable so the keyboard can scroll it.
            StudioAttributes(
              {
                'tabindex': '0',
                'role': 'group',
                'aria-label': semanticLabel ?? language.name,
              },
              child: Styled(
                style: const StyleProps(overflowX: Overflow.auto),
                child: Padding(
                  // In a narrow block the copy button gets a strip of its own
                  // above the code, so it never covers a line; once the block
                  // itself (not the window) is wide enough it floats in the
                  // corner.
                  padding: !copyButton
                      ? EdgeInsets.symmetric(vertical: theme.padding.top)
                      : EdgeInsets.only(
                          top: theme.padding.top + _copyStrip,
                          bottom: theme.padding.top,
                        ).when(
                          // The end of a line can scroll out from under the
                          // floating button.
                          container: {
                            _floatFrom: EdgeInsets.only(
                              top: theme.padding.top,
                              bottom: theme.padding.top,
                              right: _copyStrip + 8 - side,
                            ),
                          },
                        ),
                  child: Styled(
                    // The lines are as wide as the longest one (and at least the
                    // pane), so a marked line's band reaches the end of the
                    // scroll, not just the end of the window.
                    style: StyleProps(
                      widthLength: Length.maxContent,
                      minWidth: 100.percent,
                    ),
                    child: Semantics(
                      role: SemanticsRole.preformatted,
                      // The `<pre>` comes with the browser's 1em margins.
                      child: Container(
                        margin: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final (i, run) in runs.indexed)
                              _Run(
                                run,
                                style: style,
                                side: side,
                                theme: theme,
                                endsLine: i < runs.length - 1,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (copyButton)
              Positioned(
                top: 8,
                right: 8,
                child: StudioCopyButton(
                  iconOnly: true,
                  label: copy,
                  copiedLabel:
                      copiedLabel ?? (copyLabel == null ? l10n.copied : copy),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // The tokens of each line (a token that spans lines is cut at them).
  static List<List<(CodeToken, String)>> _lines(String code, String language) {
    final lines = <List<(CodeToken, String)>>[[]];
    for (final (kind, text) in highlightSource(code, language: language)) {
      final parts = text.split('\n');
      for (final (i, part) in parts.indexed) {
        if (i > 0) lines.add([]);
        if (part.isNotEmpty) lines.last.add((kind, part));
      }
    }
    return lines;
  }

  // Consecutive lines with the same mark, as one run.
  List<_RunData> _runs(List<List<(CodeToken, String)>> lines) {
    final runs = <_RunData>[];
    for (final (i, tokens) in lines.indexed) {
      final line = i + 1;
      final mark = changed.any((r) => r.contains(line))
          ? _Mark.changed
          : highlight.any((r) => r.contains(line))
          ? _Mark.highlight
          : null;
      if (runs.isEmpty || runs.last.mark != mark) {
        runs.add(_RunData(mark));
      }
      runs.last.lines.add(tokens);
    }
    return runs;
  }
}

enum _Mark { highlight, changed }

class _RunData {
  _RunData(this.mark);

  final _Mark? mark;
  final List<List<(CodeToken, String)>> lines = [];
}

class _Run extends StatelessWidget implements ThorElementWidget {
  const _Run(
    this.run, {
    required this.style,
    required this.side,
    required this.theme,
    required this.endsLine,
  });

  final _RunData run;
  final bool endsLine;
  final TextStyle style;
  final double side;
  final StudioCodeThemeResolved theme;

  @override
  Widget build(BuildContext context) {
    // Every line ends with its newline; the pane's last one does not.
    final spans = <TextSpan>[
      for (final (i, tokens) in run.lines.indexed) ...[
        for (final (kind, text) in tokens)
          TextSpan(text: text, style: _tokenStyle(kind)),
        if (i < run.lines.length - 1 || endsLine) const TextSpan(text: '\n'),
      ],
    ];
    final mark = run.mark;
    // web: a line never wraps (the pane scrolls).
    final text = Text.rich(
      TextSpan(children: spans),
      style: style,
      softWrap: false,
    );
    if (mark == null) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: side),
        child: text,
      );
    }
    final (background, bar) = switch (mark) {
      _Mark.highlight => (theme.highlightColor, theme.highlightBarColor),
      _Mark.changed => (theme.changedColor, theme.changedBarColor),
    };
    return Container(
      padding: EdgeInsets.only(left: side - 2, right: side),
      decoration: BoxDecoration(
        color: background,
        border: Border(left: BorderSide(color: bar, width: 2)),
      ),
      child: text,
    );
  }

  static TextStyle? _tokenStyle(CodeToken kind) => switch (kind) {
    CodeToken.keyword => const TextStyle(color: StudioSyntaxColors.keyword),
    CodeToken.string => const TextStyle(color: StudioSyntaxColors.string),
    CodeToken.number => const TextStyle(color: StudioSyntaxColors.number),
    CodeToken.type => const TextStyle(color: StudioSyntaxColors.type),
    CodeToken.comment => const TextStyle(color: StudioSyntaxColors.comment),
    CodeToken.plain => null,
  };
}
