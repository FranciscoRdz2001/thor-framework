/// The guide's own markdown components, as container directives (the
/// syntax of Docusaurus and VitePress). Each directive becomes a
/// [DocBlock]; `blocks_view.dart` draws it with the `thor_studio` widget of
/// the same name.
///
/// ```markdown
/// > **Heads up:** Text in **markdown**.   a callout: its label is the
///                                          ARB's (Note, Tip, Heads up,
///                                          Caution, Difference from
///                                          Flutter, Important)
///
/// :::note Optional title             note, tip, warning, danger, flutter
/// …
/// :::
///
/// :::steps                           each ### is a numbered step
/// :::steps diff                      …and each step's code marks what it adds
/// :::tabs                            each @tab is a tab (no JavaScript)
/// :::cards                           - [Title](link) — description
/// :::files                           a tree: 2 spaces per level, a note after
///
/// :::flutter                         @flutter and @thor, each with a code
/// @flutter                           block: the same code both ways, behind
/// …                                  a selector, with the changes marked
/// :::
/// :::flutter Flutter: X · Thor: Y    one line, no closing `:::`
/// :::compare                         like `:::flutter` (two code blocks: the
///                                    first is Flutter's, the second Thor's)
///
/// :::example accordion               a live widget of the guide, with its code
/// :::bench row-align                 an example with its controls
/// :::layers orders                   an architecture diagram you open by layer
/// ```
library;

import 'package:markdown/markdown.dart' as md;
import 'package:thor_studio/thor_studio.dart' show StudioTone;

import '../i18n/docs_locale.dart';
import 'blocks.dart';
import 'style_directives.dart';

/// A directive: `:::name arg` … `:::`.
class Directive {
  /// A directive.
  const Directive(this.name, this.arg, this.body);

  /// Its name (`note`, `steps`…).
  final String name;

  /// The rest of the opening line (a title, an id).
  final String arg;

  /// The markdown inside.
  final String body;
}

final _open = RegExp(r'^:::([a-z][\w-]*)\s*(.*)$');

/// `:::flutter Flutter: X · Thor: Y`: a directive of one line (it has no
/// closing `:::`).
final _summaryLine = RegExp(
  r'^:::flutter\s+Flutter:\s*(.+?)\s*·\s*Thor:\s*(.+?)\s*$',
);

/// The tone each label of a callout quote stands for, from the ARB of every
/// language the site has (`> **Ojo:**`, `> **Warning:**`): a new language
/// brings its labels with its ARB.
final Map<String, StudioTone> _toneOfLabel = {
  for (final locale in docsLocales)
    ...() {
      final t = messagesFor(locale);
      return {
        t.calloutNote: StudioTone.note,
        t.calloutTip: StudioTone.tip,
        t.calloutWarning: StudioTone.warning,
        t.calloutWarningAlias: StudioTone.warning,
        t.calloutDanger: StudioTone.danger,
        t.calloutFlutter: StudioTone.flutter,
      };
    }(),
};

/// Each alias label (`Heads up`) mapped to the label the page shows for it
/// (`Important`), in the same locale.
final Map<String, String> _shownLabel = {
  for (final locale in docsLocales)
    messagesFor(locale).calloutWarningAlias: messagesFor(locale).calloutWarning,
};

/// The directive name of each tone.
const _nameOfTone = {
  StudioTone.note: 'note',
  StudioTone.tip: 'tip',
  StudioTone.warning: 'warning',
  StudioTone.danger: 'danger',
  StudioTone.flutter: 'flutter',
};

/// `> **Ojo:** text`: the first line of a callout written as a quote.
final RegExp _calloutQuote = RegExp(
  '^>\\s?\\*\\*(${(_toneOfLabel.keys.toList()..sort((a, b) => b.length - a.length)).map(RegExp.escape).join('|')}):\\*\\*\\s*(.*)\$',
);

/// [markdown] with each `> **Ojo:** …` quote written as the `:::warning`
/// directive it stands for: the same callout, and the file reads on GitHub
/// as a quote. The quote ends at the first line that doesn't start with `>`;
/// code fences are left alone.
String calloutQuotes(String markdown) {
  if (!markdown.contains('**')) return markdown;
  final lines = markdown.split('\n');
  final out = <String>[];
  var fenced = false;
  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    if (_fence.hasMatch(line)) fenced = !fenced;
    final open = fenced ? null : _calloutQuote.firstMatch(line);
    if (open == null) {
      out.add(line);
      i++;
      continue;
    }
    final label = _shownLabel[open[1]!] ?? open[1]!;
    final tone = _nameOfTone[_toneOfLabel[label]!]!;
    final body = [open[2]!];
    i++;
    while (i < lines.length && lines[i].startsWith('>')) {
      body.add(lines[i].replaceFirst(RegExp(r'^>\s?'), ''));
      i++;
    }
    // The label is the callout's title, in the language it is written in;
    // an alias shows as its tone's own label.
    out
      ..add(':::$tone $label')
      ..addAll(body)
      ..add(':::');
  }
  return out.join('\n');
}

final _close = RegExp(r'^:::\s*$');
final _fence = RegExp(r'^\s*(```|~~~)');

/// [markdown] split into plain markdown (`String`) and directives, in
/// order. Code fences are left alone; directives nest.
List<Object> splitDirectives(String markdown) {
  final out = <Object>[];
  final text = <String>[];
  final lines = calloutQuotes(markdown).split('\n');
  var fenced = false;
  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    if (_fence.hasMatch(line)) fenced = !fenced;
    final open = fenced ? null : _open.firstMatch(line);
    if (open == null) {
      text.add(line);
      i++;
      continue;
    }
    if (text.isNotEmpty) out.add(text.join('\n'));
    text.clear();
    // The one-line `:::flutter Flutter: X · Thor: Y` ends where it begins.
    if (_summaryLine.hasMatch(line)) {
      out.add(Directive(open[1]!, open[2]!.trim(), ''));
      i++;
      continue;
    }
    // Find the matching `:::`, counting nested directives (outside code).
    var depth = 1, j = i + 1, innerFenced = false;
    for (; j < lines.length; j++) {
      if (_fence.hasMatch(lines[j])) innerFenced = !innerFenced;
      if (innerFenced) continue;
      if (_open.hasMatch(lines[j]) && !_summaryLine.hasMatch(lines[j])) depth++;
      if (_close.hasMatch(lines[j]) && --depth == 0) break;
    }
    out.add(
      Directive(
        open[1]!,
        open[2]!.trim(),
        lines.sublist(i + 1, j.clamp(i + 1, lines.length)).join('\n'),
      ),
    );
    i = j + 1;
  }
  if (text.isNotEmpty) out.add(text.join('\n'));
  return out;
}

/// What a directive needs from the page's renderer.
abstract interface class DirectiveContext {
  /// The messages in the language the page is written in.
  AppLocalizations get l10n;

  /// Renders [markdown] to blocks (headings keep their ids and join the
  /// page's table of contents).
  List<DocBlock> blocks(String markdown);

  /// A link as the site serves it.
  String link(String href);

  /// Notes that the page shows example [id] (`:::example`, `:::bench`).
  void useExample(String id, {bool bench = false});

  /// Notes that the page shows the layer set [id].
  void useLayers(String id);

  /// A heading [text] drawn by a directive (a step's title): its unique id,
  /// listed in the page's table of contents.
  String heading(String text);
}

/// The blocks of [d], or null for an unknown directive.
List<DocBlock>? parseDirective(Directive d, DirectiveContext cx) =>
    switch (d.name) {
      'note' || 'tip' || 'warning' || 'danger' => [_callout(d, cx)],
      'flutter' => _flutter(d, cx),
      'compare' => _compare(d, cx),
      'steps' => _steps(d, cx),
      'tabs' => [_tabs(d, cx)],
      'cards' => [_cards(d, cx)],
      'files' => [_tree(d)],
      'example' => _example(d, cx, bench: false),
      'bench' => _example(d, cx, bench: true),
      'layers' => _layers(d, cx),
      // The styles guide's own components (style_directives.dart).
      _ => parseStyleDirective(d, cx),
    };

const _tones = {
  'note': StudioTone.note,
  'tip': StudioTone.tip,
  'warning': StudioTone.warning,
  'danger': StudioTone.danger,
  'flutter': StudioTone.flutter,
};

/// The default title of the callout directive [name], in the page's language.
String _calloutTitle(String name, AppLocalizations t) => switch (name) {
  'note' => t.calloutNote,
  'tip' => t.calloutTip,
  'warning' => t.calloutWarning,
  'danger' => t.calloutDanger,
  _ => t.calloutFlutter,
};

DocBlock _callout(Directive d, DirectiveContext cx) => CalloutBlock(
  _tones[d.name]!,
  d.arg.isEmpty ? _calloutTitle(d.name, cx.l10n) : d.arg,
  cx.blocks(d.body),
);

/// The code blocks of [blocks], in order.
List<CodeBlockData> _codeOf(List<DocBlock> blocks) => [
  for (final b in blocks)
    if (b is CodeBlockData) b,
];

/// `:::flutter`: a one-line summary, a Flutter / Thor pair, or (with only
/// text) a note about what differs from Flutter.
List<DocBlock> _flutter(Directive d, DirectiveContext cx) {
  final summary = _summaryLine.firstMatch(':::flutter ${d.arg}');
  if (summary != null) {
    return [
      // The backticks stay: the summary draws them as code spans.
      CompareSummaryBlock(summary[1]!.trim(), summary[2]!.trim()),
    ];
  }
  if (_markers.hasMatch(d.body)) return _compare(d, cx);
  return [_callout(d, cx)];
}

/// `@flutter` or `@thor` alone on a line.
final _markers = RegExp(r'^@(flutter|thor)\s*$', multiLine: true);

/// A Flutter / Thor pair: `@flutter` and `@thor` each over a code block (text
/// before the first marker stays as it is), or two code blocks, the first of
/// them Flutter's.
List<DocBlock> _compare(Directive d, DirectiveContext cx) {
  final sections = <String, List<String>>{'intro': []};
  var at = 'intro';
  for (final line in d.body.split('\n')) {
    final m = _markers.firstMatch(line);
    if (m != null) {
      at = m[1]!;
      sections.putIfAbsent(at, () => []);
    } else {
      sections[at]!.add(line);
    }
  }
  final marked =
      sections.containsKey('flutter') && sections.containsKey('thor');
  final intro = cx.blocks(sections['intro']!.join('\n'));
  final CodeBlockData? flutter, thor;
  if (marked) {
    flutter = _codeOf(cx.blocks(sections['flutter']!.join('\n'))).firstOrNull;
    thor = _codeOf(cx.blocks(sections['thor']!.join('\n'))).firstOrNull;
  } else {
    final both = _codeOf(intro);
    flutter = both.firstOrNull;
    thor = both.length > 1 ? both[1] : null;
  }
  // A pair needs both sides; without them the body stays as written.
  if (flutter == null || thor == null) return cx.blocks(d.body);
  return [CompareBlock(flutter, thor, intro: marked ? intro : const [])];
}

/// `:::steps` and `:::steps diff`: each `###` is a step. Text before the
/// first one is plain text.
List<DocBlock> _steps(Directive d, DirectiveContext cx) {
  final diff = d.arg == 'diff';
  final intro = <String>[];
  final raw = <(String, List<String>)>[];
  for (final line in d.body.split('\n')) {
    if (line.startsWith('### ')) {
      raw.add((plainText(line.substring(4)), []));
    } else if (raw.isEmpty) {
      intro.add(line);
    } else {
      raw.last.$2.add(line);
    }
  }
  final steps = <StepData>[];
  for (final (title, lines) in raw) {
    final id = cx.heading(title);
    var children = cx.blocks(lines.join('\n'));
    CodeBlockData? code;
    // A step of a diff compares its code with the previous step's: the code
    // is the step's last block.
    if (diff && children.isNotEmpty && children.last is CodeBlockData) {
      code = children.last as CodeBlockData;
      children = children.sublist(0, children.length - 1);
    }
    steps.add(StepData(title, children, code: code, id: id));
  }
  return [...cx.blocks(intro.join('\n')), StepsBlock(steps, diff: diff)];
}

DocBlock _tabs(Directive d, DirectiveContext cx) {
  final tabs = <TabData>[];
  String? label;
  final buffer = <String>[];
  void flush() {
    if (label != null) tabs.add(TabData(label, cx.blocks(buffer.join('\n'))));
    buffer.clear();
  }

  for (final line in d.body.split('\n')) {
    final tab = RegExp(r'^@tab\s+(.+)$').firstMatch(line);
    if (tab != null) {
      flush();
      label = plainText(tab[1]!);
    } else {
      buffer.add(line);
    }
  }
  flush();
  return TabsBlock(tabs);
}

final _card = RegExp(
  r'^\s*[-*]\s*\[([^\]]+)\]\(([^)]+)\)\s*(?:[—:–-]+\s*(.*))?$',
);

DocBlock _cards(Directive d, DirectiveContext cx) => CardsBlock([
  for (final line in d.body.split('\n'))
    if (_card.firstMatch(line) case final m?)
      CardData(
        plainText(m[1]!),
        cx.link(m[2]!),
        (m[3] ?? '').isEmpty ? null : plainText(m[3]!),
      ),
]);

/// A file tree: two spaces per level, a trailing `/` for folders, and an
/// optional note after the name (two spaces, `#` or `←`).
DocBlock _tree(Directive d) {
  final lines = d.body
      .split('\n')
      .where((l) => l.trim().isNotEmpty && !l.trim().startsWith('```'));
  final root = <FileData>[];
  // The folders open, from the top level down.
  final path = <FileData>[];
  for (final line in lines) {
    final level = (line.length - line.trimLeft().length) ~/ 2;
    final m = RegExp(
      r'^(\S+)(?:\s{2,}|\s*#\s*|\s*←\s*)?(.*)$',
    ).firstMatch(line.trim());
    final note = m?[2]?.trim();
    final entry = FileData(
      m?[1] ?? line.trim(),
      note == null || note.isEmpty ? null : plainText(note),
    );
    while (path.length > level) {
      path.removeLast();
    }
    (path.isEmpty ? root : path.last.children).add(entry);
    path.add(entry);
  }
  return FilesBlock(root);
}

List<DocBlock> _example(
  Directive d,
  DirectiveContext cx, {
  required bool bench,
}) {
  // `:::example id` or `:::example id open` (its code shown from the start).
  final [id, ...flags] = d.arg.split(RegExp(r'\s+'));
  cx.useExample(id, bench: bench);
  return [
    ExampleBlock(id, open: flags.contains('open'), bench: bench),
    ...cx.blocks(d.body),
  ];
}

List<DocBlock> _layers(Directive d, DirectiveContext cx) {
  final id = d.arg.split(RegExp(r'\s+')).first;
  cx.useLayers(id);
  return [LayersBlock(id), ...cx.blocks(d.body)];
}

/// [markdown] (inline) as plain text: no marks, no tags, no escapes.
String plainText(String markdown) => md
    .markdownToHtml(markdown.trim(), inlineOnly: true)
    .replaceAll(RegExp('<[^>]+>'), '')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&');
