/// Short names for the lite engine's own variables: the runtime's and its
/// parts' `const`/`let`/`class` bindings (and `function`/`var` ones at a
/// function body's top level) get the shortest names free in the bundle,
/// the most used first. It is the part of a JS minifier's renaming that is
/// safe without a full parser, on code thor writes itself.
///
/// Why it is safe: a binding declared directly in a `{…}` is visible only
/// inside it, and there every mention of its name is that binding or one
/// that shadows it. Renaming every mention of the name inside the braces the
/// same way keeps each reference pointing where it pointed, as long as the
/// new name appears nowhere in the source (no capture) and the mentions
/// that are not references are left alone:
///
/// - property names after `.` or `?.`, and object keys (`{name: …}`,
///   `, name: …`), are skipped;
/// - a name that ever appears where it would be both a key and a variable
///   (shorthand `{name}`, a method `{name() {}}`, `get name`, a class
///   member, `break name`) is never renamed.
///
/// Strings, regular expressions and the text of template literals are never
/// touched; the code inside `${…}` is.
library;

/// [source] with its locals renamed (see the library comment).
String renameLocals(String source) {
  final tokens = _Lexer(source).run();
  final declared = <int>{};
  final scopes = _scopes(tokens, declared);
  if (scopes.isEmpty) return source;
  final byStart = <int, List<_Scope>>{};
  for (final s in scopes) {
    (byStart[s.start] ??= []).add(s);
  }
  final shorthand = <int>{};
  final blocked = _blocked(tokens, shorthand, declared);
  // Every word in the source (a new name must be none of them).
  final taken = {
    for (final t in tokens)
      if (t.kind == _word) t.text,
  };
  // (scope, name) → how many tokens it would rename.
  final uses = <_Binding, int>{};
  final owner = List<_Binding?>.filled(tokens.length, null);
  final open = <_Scope>[];
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    if (byStart[i] case final s?) open.addAll(s);
    while (open.isNotEmpty && open.last.close < i) {
      open.removeLast();
    }
    if (t.kind != _word || blocked.contains(t.text)) continue;
    if (!_isReference(tokens, i)) continue;
    // The innermost scope around i that declares the name.
    for (var k = open.length - 1; k >= 0; k--) {
      if (open[k].names.contains(t.text)) {
        final b = owner[i] = _Binding(open[k], t.text);
        uses[b] = (uses[b] ?? 0) + 1;
        break;
      }
    }
  }
  // Names by scope, outermost first: a scope's bindings take the shortest
  // names that no enclosing scope's binding took (the most used first), so
  // sibling scopes reuse the same few names (gzip likes that) and a nested
  // binding never captures an outer one.
  final byScope = <_Scope, List<_Binding>>{};
  for (final b in uses.keys) {
    (byScope[b.scope] ??= []).add(b);
  }
  final sorted = scopes.toList()..sort((a, b) => a.start.compareTo(b.start));
  final renamed = <_Binding, String>{};
  final chain = <(_Scope, Set<String>)>[]; // enclosing scopes and their names
  for (final s in sorted) {
    while (chain.isNotEmpty && chain.last.$1.close < s.start) {
      chain.removeLast();
    }
    final outer = {for (final (_, n) in chain) ...n};
    final mine = <String>{};
    final list = (byScope[s] ?? [])
      ..sort((a, b) {
        final save = (uses[b]! * b.name.length).compareTo(
          uses[a]! * a.name.length,
        );
        return save != 0 ? save : a.name.compareTo(b.name);
      });
    final names = _NameSource(taken, outer);
    for (final b in list) {
      final next = names.peek();
      // Only when it is shorter.
      if (next.length >= b.name.length) continue;
      mine.add(renamed[b] = names.take());
    }
    chain.add((s, mine));
  }
  final out = StringBuffer();
  var at = 0;
  for (var i = 0; i < tokens.length; i++) {
    final b = owner[i];
    final to = b == null ? null : renamed[b];
    if (to == null) continue;
    out
      ..write(source.substring(at, tokens[i].start))
      // `{name}` → `{name: a}`: the key stays.
      ..write(shorthand.contains(i) ? '${tokens[i].text}: $to' : to);
    at = tokens[i].end;
  }
  out.write(source.substring(at));
  return '$out';
}

const _word = 0, _punct = 1, _opaque = 2;

class _Tok {
  _Tok(this.kind, this.text, this.start, this.end, {this.nl = false});
  final int kind;
  final String text;
  final int start;
  final int end;

  /// Whether a line break comes before it.
  final bool nl;

  /// Whether a statement may end with it (automatic semicolons).
  bool get ends =>
      kind != _punct || const {')', ']', '}', '++', '--'}.contains(text);

  /// Whether a statement may start with it.
  bool get starts =>
      kind == _word && !_binaryWords.contains(text) ||
      kind == _opaque ||
      const {'{', '!', '~', '++', '--'}.contains(text);
}

/// What comes right before a `{` that opens an object literal or a
/// destructuring pattern (not a block). Not `:`: a `case x: {` block
/// looks the same as a key's object value.
const _beforeObject = {
  '=', '(', ',', '?', '[', 'return', '||', '&&', '??', '...', 'const', //
  'let', 'var', '|', '&',
};

/// Words that continue an expression (`a\n in b`).
const _binaryWords = {'in', 'of', 'instanceof'};

class _Scope {
  _Scope(this.open, this.close) : start = open;
  final int open; // index of `{`
  final int close; // index of its `}`

  /// Where the names are visible from: the `{`, or a function's parameters.
  int start;
  final Set<String> names = {};
}

final class _Binding {
  _Binding(this.scope, this.name);
  final _Scope scope;
  final String name;
  @override
  bool operator ==(Object other) =>
      other is _Binding && other.scope == scope && other.name == name;
  @override
  int get hashCode => Object.hash(scope, name);
}

/// Whether the word at [i] is a variable, not a property name or a key.
bool _isReference(List<_Tok> t, int i) {
  final prev = i > 0 ? t[i - 1] : null;
  final next = i + 1 < t.length ? t[i + 1] : null;
  if (prev != null && prev.kind == _punct) {
    if (prev.text == '.' || prev.text == '?.' || prev.text == '#') {
      return false;
    }
  }
  // `{name: …}` / `, name: …`: a key (a label too; labels are blocked).
  if (next != null && next.text == ':' && prev != null) {
    if (prev.text == '{' || prev.text == ',') return false;
  }
  return !_keywords.contains(t[i].text);
}

/// Names never renamed: class members, methods and accessors of object
/// literals, labels, and a shorthand `{name}` in a brace that may be a
/// block. The shorthands of object literals and patterns go to
/// [shorthand] (their index): renamed, they become `name: new`.
Set<String> _blocked(List<_Tok> t, Set<int> shorthand, Set<int> declared) {
  final out = <String>{};
  // '{' a block, 'o' an object literal or pattern, '(' '[', 'c' a class.
  final stack = <String>[];
  var classAt = -1; // stack depth where a `class` header waits for its `{`
  for (var i = 0; i < t.length; i++) {
    final x = t[i];
    if (x.kind == _punct) {
      switch (x.text) {
        case '{':
          final before = i > 0 ? t[i - 1].text : '';
          stack.add(
            classAt == stack.length
                ? 'c'
                : _beforeObject.contains(before)
                ? 'o'
                : '{',
          );
          if (classAt == stack.length - 1) classAt = -1;
        case '(' || '[':
          stack.add(x.text);
        case '}' || ')' || ']':
          if (stack.isNotEmpty) stack.removeLast();
      }
      continue;
    }
    if (x.kind != _word) continue;
    if (x.text == 'class') classAt = stack.length;
    final prev = i > 0 ? t[i - 1].text : '';
    final next = i + 1 < t.length ? t[i + 1].text : '';
    final inside = stack.isEmpty ? '' : stack.last;
    if (inside == 'c') out.add(x.text);
    // `const a = 1, b = 2`: `, b =` is a declaration, not a shorthand.
    if (!declared.contains(i) &&
        (inside == '{' || inside == 'o') &&
        (prev == '{' || prev == ',') &&
        (next == ',' || next == '}' || next == '=' || next == '(')) {
      if (inside == 'o' && next != '(') {
        shorthand.add(i);
      } else {
        out.add(x.text);
      }
    }
    if (const {
      'get',
      'set',
      'async',
      'static',
      'break',
      'continue',
    }.contains(prev)) {
      out.add(x.text);
    }
  }
  return out;
}

/// The braces that declare names directly inside them.
List<_Scope> _scopes(List<_Tok> t, Set<int> declared) {
  final open = <int>[]; // indices of the open brackets
  final byOpen = <int, _Scope>{};
  final bodies = <int>{}; // `{` that are function bodies
  final scopes = <_Scope>[];
  // First pass: match brackets.
  final match = <int, int>{};
  for (var i = 0; i < t.length; i++) {
    final x = t[i];
    if (x.kind != _punct) continue;
    if (x.text == '{' || x.text == '(' || x.text == '[') {
      open.add(i);
    } else if (x.text == '}' || x.text == ')' || x.text == ']') {
      if (open.isNotEmpty) match[open.removeLast()] = i;
    }
  }
  final closeToOpen = {for (final e in match.entries) e.value: e.key};
  for (final MapEntry(key: o, value: c) in match.entries) {
    if (t[o].text != '{') continue;
    final s = byOpen[o] = _Scope(o, c);
    scopes.add(s);
    // A function body: `=> {`, or `) {` whose `(` follows `function` or
    // `function name`.
    // Its parameters are its names too.
    final before = o > 0 ? t[o - 1] : null;
    if (before?.text == '=>') {
      bodies.add(o);
      final p = o > 1 ? t[o - 2] : null;
      if (p?.text == ')') {
        final q = closeToOpen[o - 2];
        if (q != null) _params(t, q, o - 2, s);
      } else if (p != null && p.kind == _word && !_keywords.contains(p.text)) {
        s
          ..start = o - 2
          ..names.add(p.text);
      }
    }
    if (before?.text == ')') {
      final p = closeToOpen[o - 1];
      if (p != null && p > 0) {
        final a = t[p - 1];
        if (a.text == 'function' ||
            a.kind == _word && p > 1 && t[p - 2].text == 'function') {
          bodies.add(o);
          _params(t, p, o - 1, s);
        }
      }
    }
  }
  // Declarations directly in each brace (not in a nested bracket).
  final stack = <int>[];
  for (var i = 0; i < t.length; i++) {
    final x = t[i];
    if (x.kind == _punct) {
      if (x.text == '{' || x.text == '(' || x.text == '[') stack.add(i);
      if ((x.text == '}' || x.text == ')' || x.text == ']') &&
          stack.isNotEmpty) {
        stack.removeLast();
      }
      continue;
    }
    if (x.kind != _word || stack.isEmpty || t[stack.last].text != '{') continue;
    final scope = byOpen[stack.last]!;
    final body = bodies.contains(stack.last);
    final kw = x.text;
    final hoisted = kw == 'function' || kw == 'var';
    if (!(kw == 'const' || kw == 'let' || kw == 'class' || hoisted)) continue;
    if (hoisted && !body) continue;
    // `x.const`, `{const: 1}`: not a declaration.
    if (i > 0 && (t[i - 1].text == '.' || t[i - 1].text == '?.')) continue;
    if (i + 1 < t.length && t[i + 1].text == ':') continue;
    if (kw == 'function' || kw == 'class') {
      if (i + 1 < t.length && t[i + 1].kind == _word) {
        scope.names.add(t[i + 1].text);
      }
      continue;
    }
    // const/let/var: `a = …, b = …;` until `;` or the end of the brace.
    var depth = 0;
    var expectName = true;
    for (var j = i + 1; j < t.length; j++) {
      final y = t[j];
      // A new statement without a semicolon.
      if (depth == 0 && y.nl && t[j - 1].ends && y.starts && j > i + 1) break;
      if (y.kind == _punct) {
        if (y.text == '{' || y.text == '(' || y.text == '[') {
          if (expectName && depth == 0) {
            // `const {a, b: c} = …` / `const [a, b] = …`: one level.
            if (y.text == '(') break;
            _pattern(t, j, scope.names);
            expectName = false;
          }
          depth++;
        } else if (y.text == '}' || y.text == ')' || y.text == ']') {
          if (depth == 0) break;
          depth--;
        } else if (depth == 0 && y.text == ';') {
          break;
        } else if (depth == 0 && y.text == ',') {
          expectName = true;
        }
        continue;
      }
      if (y.kind == _word && depth == 0) {
        if (expectName) {
          if (_keywords.contains(y.text)) break;
          scope.names.add(y.text);
          declared.add(j);
          expectName = false;
        } else if (_statementKeywords.contains(y.text)) {
          break; // a new statement (no semicolon)
        }
      }
    }
  }
  return scopes;
}

/// The names a one-level destructuring pattern at [open] binds: `{a}`,
/// `{a = 1}`, `{k: a}`, `[a, b]`, `[a = 1]`.
void _pattern(List<_Tok> t, int open, Set<String> names) {
  final obj = t[open].text == '{';
  var depth = 0;
  for (var i = open + 1; i < t.length; i++) {
    final x = t[i];
    if (x.kind == _punct) {
      if (x.text == '{' || x.text == '(' || x.text == '[') depth++;
      if (x.text == '}' || x.text == ')' || x.text == ']') {
        if (depth == 0) return;
        depth--;
      }
      continue;
    }
    if (depth != 0 || x.kind != _word) continue;
    final prev = t[i - 1].text, next = t[i + 1].text;
    final end = next == ',' || next == (obj ? '}' : ']') || next == '=';
    if (end &&
        (prev == t[open].text || prev == ',' || prev == ':' || prev == '...')) {
      names.add(x.text);
    }
  }
}

/// The simple parameters between `(` at [from] and `)` at [to] (`a`,
/// `a = 1`, `...a`): names of [s], visible from the `(`. A destructured
/// parameter keeps its names.
void _params(List<_Tok> t, int from, int to, _Scope s) {
  s.start = from;
  var depth = 0;
  for (var i = from + 1; i < to; i++) {
    final x = t[i];
    if (x.kind == _punct) {
      if (x.text == '{' || x.text == '(' || x.text == '[') depth++;
      if (x.text == '}' || x.text == ')' || x.text == ']') depth--;
      continue;
    }
    if (depth != 0 || x.kind != _word) continue;
    final prev = t[i - 1].text, next = t[i + 1].text;
    if ((prev == '(' || prev == ',' || prev == '...') &&
        (next == ',' || next == ')' || next == '=')) {
      s.names.add(x.text);
    }
  }
}

class _NameSource {
  _NameSource(this.taken, this.outer);

  /// Every word of the source.
  final Set<String> taken;

  /// The new names of the enclosing scopes.
  final Set<String> outer;
  final Set<String> _mine = {};
  int _n = 0;
  String? _next;

  String peek() => _next ??= _find();
  String take() {
    final n = peek();
    _next = null;
    _mine.add(n);
    return n;
  }

  String _find() {
    for (;;) {
      var n = _n++;
      const first = r'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_$';
      const rest =
          r'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_$0123456789';
      final b = StringBuffer(first[n % first.length]);
      n ~/= first.length;
      while (n > 0) {
        n--;
        b.write(rest[n % rest.length]);
        n ~/= rest.length;
      }
      final name = '$b';
      if (!taken.contains(name) &&
          !outer.contains(name) &&
          !_mine.contains(name) &&
          !_keywords.contains(name)) {
        return name;
      }
    }
  }
}

const _statementKeywords = {
  'const', 'let', 'var', 'function', 'class', 'return', 'if', 'for', //
  'while', 'do', 'switch', 'try', 'throw', 'break', 'continue',
};

const _keywords = {
  'break', 'case', 'catch', 'class', 'const', 'continue', 'debugger', //
  'default', 'delete', 'do', 'else', 'export', 'extends', 'false',
  'finally', 'for', 'function', 'if', 'import', 'in', 'instanceof', 'new',
  'null', 'return', 'super', 'switch', 'this', 'throw', 'true', 'try',
  'typeof', 'var', 'void', 'while', 'with', 'yield', 'let', 'static',
  'enum', 'await', 'implements', 'package', 'protected', 'interface',
  'private', 'public', 'of', 'get', 'set', 'async', 'undefined', 'NaN',
  'Infinity', 'arguments', 'eval',
};

/// Tokens of JS source: words, punctuation (`...` and `?.` as one), and
/// opaque pieces (strings, regular expressions, template text).
class _Lexer {
  _Lexer(this.s);
  final String s;
  final List<_Tok> out = [];
  int i = 0;
  bool regexAllowed = true;
  final List<int> templates = [];
  int depth = 0;
  bool nl = false;

  List<_Tok> run() {
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (c == 0x0A || c == 0x0D) {
        nl = true;
        i++;
      } else if (c == 0x20 || c == 0x09 || c == 0x0C || c == 0x0B) {
        i++;
      } else if (c == 0x2F && _at(i + 1) == 0x2F) {
        while (i < s.length && s.codeUnitAt(i) != 0x0A) {
          i++;
        }
      } else if (c == 0x2F && _at(i + 1) == 0x2A) {
        final end = s.indexOf('*/', i + 2);
        if (end < 0) throw FormatException('unterminated comment', s, i);
        if (s.substring(i, end).contains('\n')) nl = true;
        i = end + 2;
      } else if (c == 0x27 || c == 0x22) {
        final start = i++;
        while (i < s.length) {
          final d = s.codeUnitAt(i++);
          if (d == 0x5C) {
            i++;
          } else if (d == c) {
            break;
          }
        }
        _add(_opaque, start, regexAfter: false);
      } else if (c == 0x60) {
        _template();
      } else if (c == 0x7D && templates.isNotEmpty && templates.last == depth) {
        templates.removeLast();
        _template();
      } else if (c == 0x2F && regexAllowed) {
        final start = i++;
        var inClass = false;
        while (i < s.length) {
          final d = s.codeUnitAt(i++);
          if (d == 0x5C) {
            i++;
          } else if (d == 0x5B) {
            inClass = true;
          } else if (d == 0x5D) {
            inClass = false;
          } else if (d == 0x2F && !inClass) {
            while (i < s.length && _isWord(s.codeUnitAt(i))) {
              i++;
            }
            break;
          }
        }
        _add(_opaque, start, regexAfter: false);
      } else if (_isWord(c)) {
        final start = i;
        while (i < s.length && _isWord(s.codeUnitAt(i))) {
          i++;
        }
        final w = s.substring(start, i);
        _push(_Tok(_word, w, start, i, nl: nl));
        regexAllowed = _keywordsBeforeRegex.contains(w);
      } else {
        final start = i;
        if (c == 0x2E && _at(i + 1) == 0x2E && _at(i + 2) == 0x2E) {
          i += 3;
        } else if (c == 0x3F &&
            _at(i + 1) == 0x2E &&
            !(_at(i + 2) >= 0x30 && _at(i + 2) <= 0x39)) {
          i += 2;
        } else if (c == 0x3D && _at(i + 1) == 0x3E ||
            (c == 0x2B || c == 0x2D) && _at(i + 1) == c) {
          i += 2;
        } else {
          i++;
        }
        if (c == 0x7B) depth++;
        if (c == 0x7D) depth--;
        _push(_Tok(_punct, s.substring(start, i), start, i, nl: nl));
        regexAllowed = !(c == 0x29 || c == 0x5D || c == 0x7D);
      }
    }
    return out;
  }

  int _at(int j) => j < s.length ? s.codeUnitAt(j) : 0;

  void _push(_Tok t) {
    out.add(t);
    nl = false;
  }

  void _add(int kind, int start, {required bool regexAfter}) {
    _push(_Tok(kind, s.substring(start, i), start, i, nl: nl));
    regexAllowed = regexAfter;
  }

  void _template() {
    final from = i++;
    while (i < s.length) {
      final c = s.codeUnitAt(i++);
      if (c == 0x5C) {
        i++;
      } else if (c == 0x60) {
        _add(_opaque, from, regexAfter: false);
        return;
      } else if (c == 0x24 && _at(i) == 0x7B) {
        i++;
        _add(_opaque, from, regexAfter: true);
        templates.add(depth);
        return;
      }
    }
    throw FormatException('unterminated template literal', s, from);
  }

  static bool _isWord(int c) =>
      (c >= 0x61 && c <= 0x7A) ||
      (c >= 0x41 && c <= 0x5A) ||
      (c >= 0x30 && c <= 0x39) ||
      c == 0x5F ||
      c == 0x24 ||
      c > 0x7F;

  static const _keywordsBeforeRegex = {
    'return', 'typeof', 'instanceof', 'in', 'of', 'new', 'delete', 'void', //
    'throw', 'case', 'do', 'else', 'yield', 'await',
  };
}
