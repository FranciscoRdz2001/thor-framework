/// The ```dart blocks of the guide (docs/guia/es/*.md): extracting them and
/// making each one a Dart library the analyzer can check (tool/docs_check.dart,
/// tool/tutorial_check.dart).
///
/// Convention:
///  * ```dart            a block that must compile.
///  * ```dart no-check   a genuinely partial snippet (`...`, pseudocode, a
///                       block that needs a file the page does not show):
///                       skipped, and counted in the report.
///  * A first line `// lib/foo.dart` (a path comment) makes the block that
///    file of the page's project: other blocks of the page import it.
library;

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/diagnostic/diagnostic.dart' show Diagnostic;

/// One fenced code block of a Markdown page.
class DocBlock {
  const DocBlock({
    required this.file,
    required this.line,
    required this.lang,
    required this.info,
    required this.code,
  });

  /// The page, as the path it was read from.
  final String file;

  /// The line (1-based) of the block's first code line.
  final int line;

  /// The language of the fence (`dart`, `bash`...).
  final String lang;

  /// The words after the language (`no-check`).
  final List<String> info;

  /// The code, without the fences or their indentation.
  final String code;

  /// Whether the page says this snippet is partial.
  bool get skip => info.contains('no-check');

  /// The file a first-line path comment (`// lib/catalog.dart`) names.
  String? get path {
    final first = code.split('\n').first.trim();
    final m = RegExp(
      r'^//\s+((?:lib|bin|test|web)/[\w/.-]+\.dart)\s*$',
    ).firstMatch(first);
    return m?.group(1);
  }

  @override
  String toString() => '$file:$line';
}

final _open = RegExp(r'^(\s*)(```+|~~~+)\s*([\w+-]*)\s*(.*)$');

/// Every fenced block of [markdown] (of any language).
List<DocBlock> extractBlocks(String markdown, {String file = 'doc.md'}) {
  final lines = markdown.split('\n');
  final blocks = <DocBlock>[];
  for (var i = 0; i < lines.length; i++) {
    final m = _open.firstMatch(lines[i]);
    if (m == null) continue;
    final indent = m.group(1)!;
    final fence = m.group(2)!;
    final body = <String>[];
    var j = i + 1;
    while (j < lines.length) {
      final t = lines[j].trimLeft();
      if (t.startsWith(fence) && t.substring(fence.length).trim().isEmpty) {
        break;
      }
      body.add(
        lines[j].startsWith(indent)
            ? lines[j].substring(indent.length)
            : lines[j],
      );
      j++;
    }
    blocks.add(
      DocBlock(
        file: file,
        line: i + 2,
        lang: m.group(3)!,
        info: m
            .group(4)!
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .toList(),
        code: body.join('\n'),
      ),
    );
    i = j;
  }
  return blocks;
}

final _marker = RegExp(r'^\s*//\s*(WRONG|RIGHT|MAL|BIEN)\b');

/// [block] cut at its `// WRONG` / `// RIGHT` comment lines: each section is
/// a block of its own (a line below the first section's), and `wrong` says
/// the section shows what not to write, which is not checked.
List<({DocBlock block, bool wrong})> sections(DocBlock block) {
  final lines = block.code.split('\n');
  final cuts = [
    for (var i = 0; i < lines.length; i++)
      if (_marker.hasMatch(lines[i])) i,
  ];
  if (cuts.isEmpty) return [(block: block, wrong: false)];
  final out = <({DocBlock block, bool wrong})>[];
  final bounds = [if (cuts.first > 0) 0, ...cuts, lines.length];
  for (var k = 0; k < bounds.length - 1; k++) {
    final part = lines.sublist(bounds[k], bounds[k + 1]);
    if (part.every((l) => l.trim().isEmpty)) continue;
    final m = _marker.firstMatch(part.first);
    out.add((
      block: DocBlock(
        file: block.file,
        line: block.line + bounds[k],
        lang: block.lang,
        info: block.info,
        code: part.join('\n').trimRight(),
      ),
      wrong: m != null && (m.group(1) == 'WRONG' || m.group(1) == 'MAL'),
    ));
  }
  return out;
}

/// How a block was made a library.
enum WrapKind {
  /// It parses as a library: declarations (and imports).
  library,

  /// Statements: the body of an async function.
  statements,

  /// Widgets or expressions one after another, a `;` after each.
  sequence,

  /// One expression.
  expression,

  /// The elements of a list (`for (...) Widget()`, commas between them).
  elements,

  /// The arguments of a call (`padding: x, child: y`).
  arguments,

  /// The members of a class (a method, a getter, an `@override`).
  members,

  /// Declarations and statements side by side: a class and the widget that
  /// uses it, split at the blank lines.
  mixed,

  /// None of them parses.
  unparseable,
}

/// A block as the source the analyzer reads.
class Wrapped {
  const Wrapped(
    this.kind,
    this.source,
    this.firstLine, [
    this.errors = const [],
    this.lineMap,
  ]);

  final WrapKind kind;

  /// The generated Dart source.
  final String source;

  /// The line (1-based) of the block's first line inside [source].
  final int firstLine;

  /// For [WrapKind.unparseable]: the syntax errors of the closest form,
  /// as `line: message` with lines of the block.
  final List<String> errors;

  /// For [WrapKind.mixed]: the block's line (1-based) of each line of
  /// [source] (index 0 is line 1; 0 where the line is not the block's).
  final List<int>? lineMap;

  /// The line of the block (1-based) of [generated], a line of [source].
  int blockLine(int generated) =>
      lineMap == null ? generated - firstLine + 1 : lineMap![generated - 1];
}

List<Diagnostic> _syntax(String source) {
  final r = parseString(
    content: source,
    throwIfDiagnostics: false,
    featureSet: FeatureSet.latestLanguageVersion(),
  );
  return r.errors;
}

/// [code] with [mark] (`;` or `,`) at the end of each top-level piece, where
/// the author wrote several one after another with nothing between them: a
/// line that closes everything it opened and is followed by a line that
/// starts a new piece at the same or a smaller indentation.
String separate(String code, String mark) {
  final lines = code.split('\n');
  var depth = 0;
  String? inString; // the quote of an open multi-line string
  final out = <String>[];
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    final (:depthAfter, :open, :trimmed) = _scan(line, depth, inString);
    depth = depthAfter;
    inString = open;
    if (depth == 0 && inString == null && trimmed.isNotEmpty) {
      var j = i + 1;
      while (j < lines.length &&
          (lines[j].trim().isEmpty || lines[j].trim().startsWith('//'))) {
        j++;
      }
      final last = trimmed[trimmed.length - 1];
      final startsPiece = j < lines.length && _startsPiece(lines[j]);
      final indent = line.length - line.trimLeft().length;
      final nextIndent = j < lines.length
          ? lines[j].length - lines[j].trimLeft().length
          : 0;
      final ends =
          RegExp(
            r'[)\]}\w'
            "'"
            r'"]$',
          ).hasMatch(trimmed) &&
          last != ';' &&
          last != ',';
      if (ends &&
          startsPiece &&
          nextIndent <= indent &&
          !trimmed.startsWith('//')) {
        line = _insertAtCodeEnd(line, mark);
      }
    }
    out.add(line);
  }
  // The last piece.
  for (var k = out.length - 1; k >= 0; k--) {
    final t = _scan(out[k], 0, null).trimmed;
    if (t.isEmpty) continue;
    if (RegExp(
      r'[)\]\w'
      "'"
      r'"]$',
    ).hasMatch(t)) {
      out[k] = _insertAtCodeEnd(out[k], mark);
    }
    break;
  }
  return out.join('\n');
}

bool _startsPiece(String line) {
  final t = line.trim();
  if (t.isEmpty || t.startsWith('//')) return false;
  return !RegExp(
    r'^([.?:)\]}]|=>|&&|\|\||\+|-|\*|/|\?\?|else\b|catch\b|on\b)',
  ).hasMatch(t);
}

String _insertAtCodeEnd(String line, String mark) {
  final code = _scan(line, 0, null).trimmed;
  final at = line.indexOf(code) + code.length;
  return line.substring(0, at) + mark + line.substring(at);
}

/// The nesting after [line], whether a multi-line string stays open, and the
/// line without its `//` comment and trailing blanks.
({int depthAfter, String? open, String trimmed}) _scan(
  String line,
  int depth,
  String? inString,
) {
  var i = 0;
  var d = depth;
  var open = inString;
  while (i < line.length) {
    final c = line[i];
    if (open != null) {
      if (line.startsWith(open, i)) {
        i += open.length;
        open = null;
        continue;
      }
      if (c == r'\') i++;
      i++;
      continue;
    }
    if (c == '/' && line.startsWith('//', i)) {
      return (
        depthAfter: d,
        open: open,
        trimmed: line.substring(0, i).trimRight(),
      );
    }
    if (c == "'" || c == '"') {
      final triple = c * 3;
      if (line.startsWith(triple, i)) {
        open = triple;
        i += 3;
        continue;
      }
      // A single-line string.
      var j = i + 1;
      while (j < line.length && line[j] != c) {
        if (line[j] == r'\') j++;
        j++;
      }
      i = j + 1;
      continue;
    }
    if ('([{'.contains(c)) d++;
    if (')]}'.contains(c)) d--;
    i++;
  }
  return (depthAfter: d, open: open, trimmed: line.trimRight());
}

/// [block] as a Dart library: as written when it parses as one, else the
/// first of the other forms ([WrapKind]) that parses. A block with no
/// `import` gets [prelude] (the imports a page of the guide takes for granted).
Wrapped wrapBlock(DocBlock block, {String prelude = '', String always = ''}) {
  final code = block.code;
  final hasImport = RegExp(r'^\s*import\s', multiLine: true).hasMatch(code);
  final head = (hasImport ? '' : prelude) + always;
  final headLines = head.isEmpty ? 0 : head.split('\n').length - 1;
  // Every form puts the block's first line [shift] lines below the head.
  const ignore = '// ignore_for_file: unused_local_variable, unused_element\n';
  String? lastSource;
  var lastShift = 0;
  List<Diagnostic>? lastErrors;

  Wrapped? tryForm(
    WrapKind kind,
    String open,
    String body,
    String close,
    int shift,
  ) {
    final source = '$head$open$body$close';
    final errors = _syntax(source);
    if (errors.isEmpty) return Wrapped(kind, source, headLines + shift + 1);
    return null;
  }

  // `@override` at the start of a line: members of a class, not a library.
  final memberLike = RegExp(r'^@override', multiLine: true).hasMatch(code);
  final library = memberLike
      ? null
      : tryForm(WrapKind.library, '', code, '\n', 0);
  if (library != null) return library;
  // Imports followed by statements: the imports go to the top of the library.
  final importLines = RegExp(r'^import\s.*;\s*$', multiLine: true);
  if (hasImport && importLines.hasMatch(code)) {
    final imports = importLines
        .allMatches(code)
        .map((m) => '${m.group(0)!.trim()}\n')
        .join();
    final rest = code.replaceAll(importLines, '');
    if (rest.trim().isNotEmpty) {
      return wrapBlock(
        DocBlock(
          file: block.file,
          line: block.line,
          lang: block.lang,
          info: block.info,
          code: rest,
        ),
        prelude: imports,
        always: always,
      );
    }
  }
  final bare = code.trim().replaceFirst(RegExp(r'[,;]\s*$'), '');
  // `state.form`, `state.data`: the page's `PageState`, not the `state(...)`
  // function that declares a field.
  final shadow =
      RegExp(r'\bstate\.\w').hasMatch(code) &&
          !RegExp(r'\bstate\(').hasMatch(code)
      ? 'dynamic state'
      : '';
  final forms = <Wrapped? Function()>[
    if (!memberLike) ...[
      () => tryForm(
        WrapKind.statements,
        '${ignore}Future<void> _docs($shadow) async {\n',
        code,
        '\n}\n',
        2,
      ),
      () => tryForm(
        WrapKind.sequence,
        '${ignore}Future<void> _docs($shadow) async {\n',
        separate(code, ';'),
        '\n}\n',
        2,
      ),
      () => tryForm(
        WrapKind.expression,
        'Object? _docs($shadow) => (\n',
        bare,
        '\n);\n',
        1,
      ),
      () => tryForm(
        WrapKind.elements,
        'Object? _docs($shadow) => [\n',
        separate(code, ','),
        '\n];\n',
        1,
      ),
      () => tryForm(
        WrapKind.arguments,
        'void _docs(dynamic _${shadow.isEmpty ? '' : ', $shadow'}) {\n_(\n',
        code,
        '\n);\n}\n',
        2,
      ),
    ],
    () => _mixed(code, head, headLines, shadow),
    () =>
        tryForm(WrapKind.members, 'abstract class _Docs {\n', code, '\n}\n', 1),
  ];
  for (final form in forms) {
    final w = form();
    if (w != null) return w;
  }

  // None parses: the library's errors when the block looks like one, the
  // statements' otherwise, in the block's own lines.
  final looksLikeLibrary = RegExp(
    r'^\s*(import|class|abstract|final|const|void|sealed|enum|mixin|typedef|extension|@)\b',
  ).hasMatch(code.split('\n').first);
  lastShift = looksLikeLibrary ? 0 : 2;
  lastSource = looksLikeLibrary
      ? '$head$code\n'
      : '$head${ignore}Future<void> _docs() async {\n$code\n}\n';
  lastErrors = _syntax(lastSource);
  final lineInfo = parseString(
    content: lastSource,
    throwIfDiagnostics: false,
  ).lineInfo;
  final offset = headLines + lastShift;
  return Wrapped(WrapKind.unparseable, lastSource, offset + 1, [
    for (final e in lastErrors.take(3))
      '${lineInfo.getLocation(e.offset).lineNumber - offset}: ${e.message}',
  ]);
}

/// The chunks of [code] (split at the blank lines outside any brackets) as
/// declarations at the top and statements inside one function.
Wrapped? _mixed(String code, String head, int headLines, String shadow) {
  final lines = code.split('\n');
  final chunks = <(int, List<String>)>[]; // (first line index, lines)
  var depth = 0;
  String? open;
  var current = <String>[];
  var start = 0;
  for (var i = 0; i < lines.length; i++) {
    final scan = _scan(lines[i], depth, open);
    depth = scan.depthAfter;
    open = scan.open;
    if (lines[i].trim().isEmpty && depth == 0 && open == null) {
      if (current.isNotEmpty) chunks.add((start, current));
      current = [];
      start = i + 1;
    } else {
      if (current.isEmpty) start = i;
      current.add(lines[i]);
    }
  }
  if (current.isNotEmpty) chunks.add((start, current));
  if (chunks.length < 2) return null;

  final top = StringBuffer(head);
  final topMap = <int>[...List.filled(headLines, 0)];
  final body = StringBuffer();
  final bodyMap = <int>[];
  final members = StringBuffer();
  final membersMap = <int>[];
  var memberClasses = 0;
  for (final (first, chunk) in chunks) {
    final text = chunk.join('\n');
    final asMember = _syntax('abstract class _M {\n$text\n}\n').isEmpty;
    final memberLike = RegExp(r'^@override', multiLine: true).hasMatch(text);
    if (!(memberLike && asMember) && _syntax('$text\n').isEmpty) {
      top.writeln(text);
      topMap.addAll([for (var k = 0; k < chunk.length; k++) first + k + 1]);
      continue;
    }
    final asBody = memberLike && asMember
        ? ''
        : [text, separate(text, ';')].firstWhere(
            (t) => _syntax('Future<void> _docs() async {\n$t\n}\n').isEmpty,
            orElse: () => '',
          );
    final lineNumbers = [for (var k = 0; k < chunk.length; k++) first + k + 1];
    if (asBody.isEmpty) {
      if (!asMember) return null;
      members
        ..writeln('abstract class _DocsMembers${memberClasses++} {')
        ..writeln(text)
        ..writeln('}');
      membersMap.addAll([0, ...lineNumbers, 0]);
      continue;
    }
    body.writeln(asBody);
    bodyMap.addAll(lineNumbers);
  }
  top
    ..writeln('// ignore_for_file: unused_local_variable, unused_element')
    ..writeln('Future<void> _docs($shadow) async {')
    ..write(body)
    ..writeln('}');
  var map = [...topMap, 0, 0, ...bodyMap, 0];
  if (members.isNotEmpty) {
    top.write(members);
    map = [...map, ...membersMap];
  }
  return Wrapped(WrapKind.mixed, top.toString(), 1, const [], map);
}
