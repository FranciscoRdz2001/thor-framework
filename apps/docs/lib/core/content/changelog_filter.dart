/// What an app developer reads of a package's `CHANGELOG.md`: a
/// deterministic filter (the changelogs also record how Thor is built) and
/// a classification of each entry (new, changed, deprecated, breaking).
///
/// The changelogs stay as the maintainers write them; the site never shows
/// engine talk or repository paths.
library;

/// The terms that belong to how Thor is built, not to using it: the
/// browser runtime and its two builds, repository tools and paths, the
/// render protocol and the internals of the widgets.
final internalTerms = RegExp(
  r'\b[Ll]ites?\b|dart2js|\bmotor\b|\b[Ee]ngines?\b|tool/|\bapps/|packages/'
  r'|\.dart_tool|data-t[a-z-]*|[Tt]horElement|ChildRules|WrapData|render core'
  r'|docs/\d|thor_builder:\w+|state_misuses',
);

/// How an entry reads to an app developer.
enum ChangeKind {
  /// Something that stops compiling or behaving: an app must change.
  breaking,

  /// A name that goes away: the entry says what to use instead.
  deprecated,

  /// Something an app can now do.
  added,

  /// Something that works differently or was wrong before.
  changed,
}

/// One cleaned entry of a changelog.
class Change {
  /// An entry.
  const Change(this.kind, this.markdown);

  /// What the entry is about.
  final ChangeKind kind;

  /// Its text, as a Markdown list item (continuation lines indented).
  final String markdown;
}

/// A version's heading and its entries.
class Release {
  /// A version.
  const Release(this.heading, this.changes);

  /// `Unreleased` or `0.1.0 (not published)`.
  final String heading;

  /// Its entries that matter to an app, in the order they were written.
  final List<Change> changes;

  /// Whether it is the section of what is not in a version yet.
  bool get isUnreleased => heading == 'Unreleased';
}

/// Words of an entry that only an app developer meets: what the app
/// writes or sees. The packages that are not the app's API (the browser
/// runtime, the code generator, the analyzer rules) show an entry only
/// when it is a break, a deprecation or about one of these.
final appFacing = RegExp(
  r'\bThorState\b|\bstate\(|\bderived\b|\bquery\(|\bcommand\(|\bWatch\b'
  r'|THOR-[A-Z]\d{3}',
);

/// The label some entries start with (`Fix:`, `Add:`, `Change (behavior):`):
/// the section already says it.
final _label = RegExp(
  r'^(?:\*\*)?(Fix|Fixed|Add|Added|New|Change|Security)(?: \(behavior\))?:(?:\*\*)?\s*',
);

final _breaking = RegExp(r'\bBreaking\b');
final _deprecated = RegExp(
  r'@Deprecated|\b(?:is|are|was|were|now|been|gets?|marks?|as) deprecated\b'
  r'|\bdeprecates\b|\bDeprecated:',
);
final _fixed = RegExp(
  r'^\W*(?:fix(?:es|ed)?\b|a\b[^.]*\b(?:now|no longer)\b)'
  r'|\b(?:now|no longer|instead of|used to|stops?|renamed|is gone)\b',
  caseSensitive: false,
);

/// The releases of [changelog] (the text of a `CHANGELOG.md`): only the
/// entries that matter to an app, cleaned. [strict] is for the packages
/// that are not the app's API.
List<Release> releasesOf(String changelog, {bool strict = false}) {
  final releases = <Release>[];
  String? heading;
  var buffer = <String>[];
  final entries = <String>[];
  var fenced = false;

  void flushEntry() {
    if (buffer.isNotEmpty) entries.add(buffer.join('\n').trimRight());
    buffer = [];
  }

  void flushRelease() {
    flushEntry();
    if (heading != null) {
      final changes = <Change>[];
      for (final entry in entries) {
        final change = cleanEntry(entry, strict: strict);
        if (change != null) changes.add(change);
      }
      if (changes.isNotEmpty) releases.add(Release(heading, changes));
    }
    entries.clear();
  }

  for (final line in changelog.split('\n')) {
    if (line.trimLeft().startsWith('```')) fenced = !fenced;
    if (!fenced && line.startsWith('## ')) {
      flushRelease();
      heading = line.substring(3).trim();
    } else if (heading == null) {
      continue;
    } else if (!fenced && line.startsWith('- ')) {
      flushEntry();
      buffer.add(line);
    } else if (buffer.isNotEmpty) {
      buffer.add(line);
    }
  }
  flushRelease();
  return releases;
}

/// [entry] (a `- ` bullet and its continuation lines) as an [Change], or
/// null when it is only about how Thor is built (its first sentence is
/// internal, nothing is left after the cleaning, or [strict] and the app
/// does not meet it).
Change? cleanEntry(String entry, {bool strict = false}) {
  if (entry.startsWith('- Nothing yet')) return null;
  var raw = _unindent(entry);
  final label = _label.firstMatch(raw);
  if (label != null) raw = raw.substring(label.end);
  final blocks = _blocks(_dropReferences(raw));
  final kept = <String>[];
  var first = true;
  for (final block in blocks) {
    if (block.code) {
      // A code sample with internals goes with its entry.
      if (internalTerms.hasMatch(block.text)) {
        if (first) return null;
        continue;
      }
      kept.add('\n${block.text}\n');
      first = false;
      continue;
    }
    final text = _sentences(block.text, headline: first);
    if (text == null) {
      if (first) return null;
      continue;
    }
    if (text.isNotEmpty) {
      kept.add(text.startsWith('- ') || first ? text : '\n$text');
    }
    first = false;
  }
  if (kept.isEmpty) return null;
  var text = kept.join('\n');
  var kind = _kindOf(text);
  if (kind == ChangeKind.added || kind == ChangeKind.changed) {
    if (label != null &&
        label[1] != 'Add' &&
        label[1] != 'Added' &&
        label[1] != 'New') {
      kind = ChangeKind.changed;
    }
    // Two sentences say what it is; the rest is the maintainers' notes.
    kept[0] = kept[0].startsWith('- ')
        ? kept[0]
        : kept[0].split(_sentenceEnd).take(2).join(' ');
    text = [
      for (final part in kept)
        if (!part.startsWith('\n') ||
            part.startsWith('\n```') ||
            part.startsWith('\n- '))
          part,
    ].join('\n');
  }
  if (strict &&
      kind != ChangeKind.breaking &&
      kind != ChangeKind.deprecated &&
      !appFacing.hasMatch(text)) {
    return null;
  }
  return Change(kind, _asItem(text));
}

ChangeKind _kindOf(String text) {
  if (_breaking.hasMatch(text)) return ChangeKind.breaking;
  if (_deprecated.hasMatch(text)) return ChangeKind.deprecated;
  final head = text.split(_sentenceEnd).first;
  return _fixed.hasMatch(head) ? ChangeKind.changed : ChangeKind.added;
}

/// The entry without its `- ` and the indentation of its lines.
String _unindent(String entry) => [
  for (final (i, line) in entry.split('\n').indexed)
    i == 0
        ? line.substring(2)
        : line.startsWith('  ')
        ? line.substring(2)
        : line,
].join('\n');

/// Drops what points into the repository: notes that cite a file and links
/// to files (their text stays).
String _dropReferences(String text) => text
    // `(see docs/x.md)`, `(docs/x.md; Chrome 123)`.
    .replaceAll(RegExp(r'\s*\([^()]*docs/[^()]*\)'), '')
    // `, in both engines`.
    .replaceAll(RegExp(r',? in both engines\b'), '')
    // `[text](docs/x.md)`, `[text](../x.md)`: the text only.
    .replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\((?!https?:|/|#)[^)\s]*\)'),
      (m) => m[1]!,
    );

class _Block {
  const _Block(this.text, {required this.code});
  final String text;
  final bool code;
}

/// Fenced code and paragraphs (a blank line, or a nested list item, ends
/// one).
List<_Block> _blocks(String text) {
  final out = <_Block>[];
  var paragraph = <String>[];
  var code = <String>[];
  var fenced = false;
  void flush() {
    if (paragraph.isNotEmpty) {
      out.add(_Block(paragraph.join('\n'), code: false));
    }
    paragraph = [];
  }

  for (final line in text.split('\n')) {
    if (line.trimLeft().startsWith('```')) {
      if (fenced) {
        code.add(line);
        out.add(_Block(code.join('\n'), code: true));
        code = [];
      } else {
        flush();
        code.add(line);
      }
      fenced = !fenced;
    } else if (fenced) {
      code.add(line);
    } else if (line.trim().isEmpty) {
      flush();
    } else if (RegExp(r'^\s*(?:[-*]|\d+\.) ').hasMatch(line)) {
      flush();
      paragraph.add(line);
    } else {
      paragraph.add(line);
    }
  }
  flush();
  return out;
}

final _sentenceEnd = RegExp(r'(?<=[.!?])\s+(?=[A-Z`*(])');

/// [text] without the sentences about internals: null when [headline] (the
/// entry's first sentence) is one of them, the entry is about nothing an
/// app sees.
String? _sentences(String text, {required bool headline}) {
  final lines = text.split('\n');
  final out = <String>[];
  final flat = lines.map((l) => l.trim()).join(' ');
  final isItem = RegExp(r'^[-*] ').hasMatch(flat);
  final body = isItem ? flat.substring(2) : flat;
  final sentences = body.split(_sentenceEnd);
  for (final (i, sentence) in sentences.indexed) {
    if (internalTerms.hasMatch(sentence)) {
      if (i == 0 && headline) return null;
      continue;
    }
    out.add(sentence);
  }
  if (out.isEmpty) return isItem || !headline ? '' : null;
  final joined = out.join(' ');
  return isItem ? '- $joined' : joined;
}

/// [text] as a list item: the first line after `- `, the rest indented.
String _asItem(String text) {
  final lines = text.split('\n');
  return [
    '- ${lines.first}',
    for (final line in lines.skip(1)) line.isEmpty ? '' : '  $line',
  ].join('\n');
}
