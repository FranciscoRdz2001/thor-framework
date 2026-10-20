/// Code on the site: how a markdown fence becomes a [CodeBlockData] (its
/// file name from a first comment line, its `{2-4}` marks), and the two
/// widgets the home page uses, [DocsCode] and [DocsPreview]. The look is
/// `thor_studio`'s (`StudioCodeBlock`); nothing here writes CSS.
library;

import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/thor_ui.dart';

import '../i18n/docs_locale.dart';
import 'blocks.dart';

/// Whether [language] is a shell (shown as a terminal).
bool isShell(String language) =>
    language == 'bash' || language == 'sh' || language == 'shell';

/// A first line that names the file: `// lib/x.dart`, `# apps/a/pubspec.yaml`,
/// `<!-- index.html -->`, `# .env`, with an optional ` — note` after it.
final _fileComment = RegExp(
  r'^\s*(?://|#|<!--)\s*([\w./\[\]()-]+\.[a-z]+|\.[a-z][\w-]*|[\w.-]+/[\w./\[\]()-]*)'
  r'(?:\s+[—-]+\s*(.*?))?\s*(?:-->)?\s*$',
);

/// `{2-4,7}` in a fence's info string: the lines to draw the eye to.
final _highlightMeta = RegExp(r'(?<!\+)\{([\d,\s-]+)\}');

/// `+{4-5}`: the lines a step adds.
final _changedMeta = RegExp(r'\+\{([\d,\s-]+)\}');

/// The block of a fence: [source] in [language] (the info string's first
/// word, or null), with [meta] (the rest: `{2-4}`, `+{4-5}`).
///
/// A first line that is a comment naming a file (`// lib/main.dart`, with an
/// optional ` — note`) becomes the block's title and leaves the code. The
/// numbers of `{…}` count the lines of the fence as the author wrote it, so
/// they keep their meaning when that first line goes.
CodeBlockData codeBlockOf(String source, String? language, [String? meta]) {
  var code = source.replaceAll(RegExp(r'\n+$'), '');
  final lang = language == null || language.isEmpty ? 'text' : language;
  String? title;
  var skipped = 0;
  if (!isShell(lang)) {
    final first = code.split('\n').first;
    final match = _fileComment.firstMatch(first);
    if (match != null && code.contains('\n')) {
      final note = match[2];
      title = note == null || note.isEmpty ? match[1] : '${match[1]} — $note';
      code = code.substring(first.length + 1);
      skipped = 1;
    }
  }
  List<StudioLineRange> ranges(RegExp pattern) => [
    for (final m in pattern.allMatches(meta ?? ''))
      for (final r in StudioLineRange.parse(m[1]!))
        if (r.end > skipped)
          StudioLineRange((r.start - skipped).clamp(1, r.end), r.end - skipped),
  ];
  return CodeBlockData(
    code,
    language: lang,
    title: title,
    highlight: ranges(_highlightMeta),
    changed: ranges(_changedMeta),
  );
}

/// A code block as a widget: [code] in [language], with an optional [title]
/// (a file name) and the copy button.
class DocsCode extends StatelessWidget {
  /// [code] in [language], with an optional [title].
  const DocsCode(this.code, {super.key, this.language = 'dart', this.title});

  /// The source.
  final String code;

  /// Its language.
  final String language;

  /// The header (a file name).
  final String? title;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return StudioCodeBlock(
      code,
      language: StudioCodeLanguage.fromName(language),
      title: title ?? (isShell(language) ? t.codeTerminal : null),
    );
  }
}

/// A live preview of widgets: a card with a label and the widgets on its
/// stage.
class DocsPreview extends StatelessWidget {
  /// [child] on the stage, under [label] (the ARB's "Preview" by default).
  const DocsPreview({super.key, this.label, required this.child});

  /// The label in the corner.
  final String? label;

  /// What is shown.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final card = StudioCardThemeData.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: card.color,
        border: Border.all(color: card.borderColor),
        borderRadius: BorderRadius.circular(card.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: card.borderColor)),
            ),
            child: Text(
              label ?? context.l10n.previewLabel,
              style: text.labelMedium.copyWith(color: scheme.onSurfaceVariant!),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(28),
            color: scheme.surfaceContainerLowest!,
            child: child,
          ),
        ],
      ),
    );
  }
}
