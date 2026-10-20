/// What a hot reload can't apply: variables whose initializer or declared
/// type changed, typedefs whose shape changed, and classes whose header
/// type arguments changed.
///
/// The VM swaps the code of functions and methods on a reload, but a
/// variable that already has a value keeps it: a top-level `final`, a
/// `static` field, or a field of an object that already exists (a global
/// `ThorState`, the route table). `thor dev` compares these before and after
/// a save and restarts the server when one changed.
library;

/// The variables of [source] that have an initializer, by name, with the
/// initializer's text (comments dropped, spaces collapsed): top-level ones
/// (`name`) and fields of classes, mixins, enums and extensions
/// (`Class.name`).
///
/// A light scan, not a parser: strings, comments and brackets are tracked,
/// declarations are told apart by their shape. Code it doesn't understand
/// only makes it report a change it can't rule out.
Map<String, String> variableInitializers(String source) {
  final out = <String, String>{};
  final chunks = _Scanner(source).chunks();
  for (final chunk in chunks) {
    // `class OrderPage extends ThorPage<Order>`: the instance the route
    // table holds keeps the type arguments of the old header (a page
    // changes its data type and every visit fails the `as T` cast).
    final header = chunk.header;
    if (header != null) {
      out['class ${header.$1}'] = header.$2;
      continue;
    }
    // A typedef is not a variable, but a reload keeps what was built with
    // its old shape (a closure typed `Future<({int a})>`, a `Page<T>` in
    // the route table): it is tracked as `typedef Name`.
    final alias = chunk.owner == null ? _typedef(chunk.text) : null;
    if (alias != null) {
      out['typedef ${alias.$1}'] = alias.$2;
      continue;
    }
    final variable = _variable(chunk.text);
    if (variable == null) continue;
    final name = chunk.owner == null
        ? variable.$1
        : '${chunk.owner}.${variable.$1}';
    out[name] = variable.$2;
    // A generic or record type (`Map<String, ({int a})> cache = {}`): the
    // value it already holds keeps the old type arguments.
    final type = variable.$3;
    if (type != null) out['type $name'] = type;
  }
  return out;
}

/// The names of [before]'s variables that [after] initializes differently.
/// A variable that is new or gone doesn't count: a new one gets its value
/// the first time it's read, and a removed one is no longer read.
List<String> changedInitializers(
  Map<String, String> before,
  Map<String, String> after,
) => [
  for (final MapEntry(:key, :value) in after.entries)
    if (before.containsKey(key) && before[key] != value) key,
];

/// The typedefs and class headers (`typedef X`, `class X` keys) that, in
/// one save, left a file of [before] and are in a different file of [after]
/// with another value, by key to the file they are in now.
///
/// [changedInitializers] compares file by file; a typedef moved to a new
/// file has no earlier version there, and the file it left no longer has
/// it. A file missing from [before] is new; one missing from [after] is gone.
Map<String, String> changedAcrossFiles(
  Map<String, Map<String, String>> before,
  Map<String, Map<String, String>> after,
) {
  bool tracked(String key) =>
      key.startsWith('typedef ') || key.startsWith('class ');
  final old = <String, String>{
    for (final file in before.values)
      for (final MapEntry(:key, :value) in file.entries)
        if (tracked(key)) key: value,
  };
  return {
    for (final MapEntry(key: file, value: declarations) in after.entries)
      for (final MapEntry(:key, :value) in declarations.entries)
        if (tracked(key) && old.containsKey(key) && old[key] != value)
          key: file,
  };
}

/// A declaration ending in `;`, with the type it's in (`null` at the top);
/// or, with `header` (`(name, text)`), the head of a type's body.
typedef _Chunk = ({String text, String? owner, (String, String)? header});

/// The message `thor dev` prints for a [key] of [changedInitializers] in
/// [file].
String restartReason(String key, String file) {
  if (key.startsWith('typedef ')) {
    return 'the shape of $key (in $file) changed';
  }
  if (key.startsWith('class ')) {
    return 'the type arguments of $key (in $file) changed';
  }
  if (key.startsWith('type ')) {
    return 'the type of ${key.substring(5)} (in $file) changed';
  }
  return '$key (in $file) has a new initializer';
}

const _notVariables = {
  'import',
  'export',
  'part',
  'library',
  'typedef',
  'return',
};

/// `(name, initializer, type)` when [text] (a whole declaration, comments already
/// gone) declares variables with an initializer; the first variable names
/// the declaration (`final a = 1, b = 2;` is one entry, `a`).
(String, String, String?)? _variable(String text) {
  var rest = text.trim();
  // Annotations: `@override`, `@Foo(...)`.
  while (rest.startsWith('@')) {
    final match = RegExp(r'^@[\w.$]+').firstMatch(rest);
    if (match == null) return null;
    rest = rest.substring(match.end).trimLeft();
    if (rest.startsWith('(')) {
      final end = _closing(rest, 0);
      if (end < 0) return null;
      rest = rest.substring(end + 1).trimLeft();
    }
  }
  final first = RegExp(r'^[A-Za-z_$][\w$]*').firstMatch(rest)?[0];
  if (first == null || _notVariables.contains(first)) return null;
  // The first `=` at the declaration's own level that isn't part of `==`,
  // `=>`, `<=`, `>=`, `!=`, `+=`…
  var depth = 0;
  var angles = 0;
  for (var i = 0; i < rest.length; i++) {
    final c = rest[i];
    if (c == '<') angles++;
    if (c == '>' && angles > 0 && rest[i - 1] != '=') angles--;
    if (c == '(' || c == '[' || c == '{') {
      // A parameter list before any `=`: a function or a getter, not a
      // variable (`int f(x) => …`, `get x => …`). Not a record or a
      // function type (`Map<String, (int,)> m`, `void Function(int) f`).
      if (depth == 0 &&
          c == '(' &&
          angles == 0 &&
          !rest.substring(0, i).trimRight().endsWith('Function')) {
        return null;
      }
      depth++;
    } else if (c == ')' || c == ']' || c == '}') {
      depth--;
    } else if (c == '=' && depth == 0) {
      final next = i + 1 < rest.length ? rest[i + 1] : '';
      final prev = i > 0 ? rest[i - 1] : '';
      if (next == '=' || next == '>') return null;
      if ('=!<>+-*/%~&|^?'.contains(prev) && prev.isNotEmpty) return null;
      final head = rest.substring(0, i).trim();
      if (RegExp(r'\b(get|set|operator)\b').hasMatch(head)) return null;
      final name = RegExp(r'([A-Za-z_$][\w$]*)$').firstMatch(head)?[1];
      if (name == null) return null;
      var type = head
          .substring(0, head.length - name.length)
          .replaceAll(
            RegExp(r'\b(static|late|final|const|var|covariant|external)\b'),
            '',
          );
      type = _normalize(type);
      return (
        name,
        _normalize(rest.substring(i + 1)),
        type.contains('<') || type.contains('(') ? type : null,
      );
    }
  }
  return null;
}

/// `(name, type)` when [text] is `typedef Name<T> = type;`; the old
/// function-type form (`typedef R F(int x);`) has no `=` and isn't one.
(String, String)? _typedef(String text) {
  final match = RegExp(
    r'^typedef\s+([A-Za-z_$][\w$]*)\s*(?:<[^=]*>)?\s*=([\s\S]*)$',
  ).firstMatch(text.trim());
  if (match == null) return null;
  return (match[1]!, _normalize(match[2]!));
}

/// Collapses spaces and drops what a formatter moves (trailing commas,
/// spaces inside brackets), outside string literals, which stay as written.
String _normalize(String text) {
  final out = StringBuffer();
  var last = 0;
  for (final m in _stringLiteral.allMatches(text)) {
    out
      ..write(_squeeze(text.substring(last, m.start)))
      ..write(m[0]);
    last = m.end;
  }
  out.write(_squeeze(text.substring(last)));
  return out.toString().replaceAll(RegExp(r';$'), '').trim();
}

final _stringLiteral = RegExp(
  r"""r?(?:\"\"\"[\s\S]*?\"\"\"|'''[\s\S]*?'''|"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*')""",
);

String _squeeze(String code) => code
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp(r'\s*,\s*'), ', ')
    .replaceAll(RegExp(r',\s*(?=[)\]}])'), '')
    .replaceAllMapped(RegExp(r'([(\[{])\s+'), (m) => m[1]!)
    .replaceAllMapped(RegExp(r'\s+([)\]}])'), (m) => m[1]!);

/// Index of the bracket that closes the one at [open] in [text], or -1.
int _closing(String text, int open) {
  var depth = 0;
  for (var i = open; i < text.length; i++) {
    final c = text[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

/// Splits Dart source into declarations: the top level's, and the members
/// of every type body, each ending in `;`. Strings keep their text,
/// comments are dropped, function bodies are skipped.
class _Scanner {
  _Scanner(this.source);

  final String source;
  var _i = 0;

  List<_Chunk> chunks() {
    final out = <_Chunk>[];
    _level(out, owner: null, typeBody: false);
    return out;
  }

  /// Reads declarations until the `}` that closes this level (or the end).
  /// In a type body ([typeBody]) or at the top, declarations are kept;
  /// anywhere else (a function body) they are skipped.
  void _level(
    List<_Chunk> out, {
    required String? owner,
    required bool typeBody,
  }) {
    final buffer = StringBuffer();
    while (_i < source.length) {
      final c = source[_i];
      if (_comment()) continue;
      if (_string(buffer)) continue;
      if (c == '}') {
        _i++;
        return;
      }
      if (c == '{') {
        final head = buffer.toString();
        _i++;
        final type = RegExp(
          r'\b(class|mixin|enum|extension)\s+(type\s+)?([A-Za-z_$][\w$]*)',
        ).firstMatch(head);
        // `class P extends ThorPage<({int a})> {`: the first `{` is the
        // record's, inside the header.
        final isTypeBody =
            type != null &&
            _parens(head) == 0 &&
            !head.contains('=>') &&
            !RegExp(r'\)\s*(async\*?|sync\*)?\s*$').hasMatch(head.trim());
        if (isTypeBody) {
          if (owner == null && head.substring(type.start).contains('<')) {
            out.add((
              text: '',
              owner: null,
              header: (type[3]!, _normalize(head.substring(type.start))),
            ));
          }
          _level(out, owner: type[3], typeBody: true);
          buffer.clear();
          continue;
        }
        // A function body, a block, or a literal inside an initializer
        // (`final m = {…};`): keep the literal's text, skip a body.
        final inInitializer = _inInitializer(head);
        final start = _i;
        _skipBlock();
        if (inInitializer) {
          buffer
            ..write('{')
            ..write(_stripComments(source.substring(start, _i)));
        } else {
          buffer.clear();
        }
        continue;
      }
      if (c == ';') {
        _i++;
        final text = buffer.toString().trim();
        buffer.clear();
        if (text.isNotEmpty) {
          out.add((text: '$text;', owner: owner, header: null));
        }
        continue;
      }
      buffer.write(c);
      _i++;
    }
  }

  static int _parens(String head) {
    var depth = 0;
    for (var i = 0; i < head.length; i++) {
      if (head[i] == '(') depth++;
      if (head[i] == ')') depth--;
    }
    return depth;
  }

  /// Whether a `{` after [head] opens a literal of an initializer (a map,
  /// a set, a closure passed to one) rather than a body.
  static bool _inInitializer(String head) {
    var depth = 0;
    for (var i = 0; i < head.length; i++) {
      final c = head[i];
      if (c == '(' || c == '[') depth++;
      if (c == ')' || c == ']') depth--;
      if (c == '=' &&
          depth == 0 &&
          (i + 1 >= head.length || head[i + 1] != '>') &&
          (i == 0 || !'=!<>'.contains(head[i - 1]))) {
        return true;
      }
    }
    return depth > 0;
  }

  /// Skips to after the `}` that closes the block whose `{` was just read.
  void _skipBlock() {
    var depth = 1;
    final sink = StringBuffer();
    while (_i < source.length && depth > 0) {
      if (_comment()) continue;
      if (_string(sink)) continue;
      final c = source[_i++];
      if (c == '{') depth++;
      if (c == '}') depth--;
    }
  }

  /// Skips a comment at [_i]; whether there was one.
  bool _comment() {
    if (source.startsWith('//', _i)) {
      final end = source.indexOf('\n', _i);
      _i = end < 0 ? source.length : end;
      return true;
    }
    if (source.startsWith('/*', _i)) {
      var depth = 0;
      while (_i < source.length) {
        if (source.startsWith('/*', _i)) {
          depth++;
          _i += 2;
        } else if (source.startsWith('*/', _i)) {
          depth--;
          _i += 2;
          if (depth == 0) break;
        } else {
          _i++;
        }
      }
      return true;
    }
    return false;
  }

  /// Copies a string literal at [_i] into [buffer] (interpolations with
  /// braces included); whether there was one.
  bool _string(StringBuffer buffer) {
    var raw = false;
    var start = _i;
    if (source[_i] == 'r' &&
        _i + 1 < source.length &&
        (source[_i + 1] == '"' || source[_i + 1] == "'") &&
        (_i == 0 || !RegExp(r'[\w$]').hasMatch(source[_i - 1]))) {
      raw = true;
      start = _i + 1;
    }
    final quote = source[start];
    if (quote != '"' && quote != "'") return false;
    final triple = source.startsWith(quote * 3, start);
    final delimiter = triple ? quote * 3 : quote;
    var j = start + delimiter.length;
    while (j < source.length) {
      if (!raw && source[j] == r'\') {
        j += 2;
        continue;
      }
      if (!raw && source.startsWith(r'${', j)) {
        // Interpolation: to its closing brace.
        var depth = 0;
        while (j < source.length) {
          if (source[j] == '{') depth++;
          if (source[j] == '}') {
            depth--;
            if (depth == 0) break;
          }
          j++;
        }
        j++;
        continue;
      }
      if (source.startsWith(delimiter, j)) {
        j += delimiter.length;
        break;
      }
      if (!triple && source[j] == '\n') break;
      j++;
    }
    buffer.write(source.substring(_i, j));
    _i = j;
    return true;
  }

  static String _stripComments(String text) => text
      .replaceAll(RegExp(r'//[^\n]*'), '')
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
}
