/// A small JS minifier for the lite engine's bundle: it drops comments and
/// collapses whitespace, and never renames or rewrites code. The bundle is
/// thor's own runtime plus code thor_builder generates, so the build needs
/// no JS toolchain (node, esbuild) to ship it.
///
/// It reads the source as tokens only as far as needed to know what is
/// code: strings, template literals (with `${…}` nested to any depth) and
/// regular expression literals are copied as they are. A line break is kept
/// where automatic semicolon insertion could depend on it; every other run
/// of whitespace becomes one space, or nothing between punctuation.
library;

/// [source] without comments and with whitespace collapsed.
String minifyJs(String source) => _Minifier(source).run();

class _Minifier {
  _Minifier(this.s);

  final String s;
  final StringBuffer out = StringBuffer();
  int i = 0;

  /// The last character written (0 at the start).
  int last = 0;

  /// Whether a `/` after what was written starts a regular expression.
  bool regexAllowed = true;

  /// Whitespace seen since the last token: 0 none, 1 spaces, 2 a line break.
  int gap = 0;

  /// Open `${` of template literals, by brace depth at which each opened.
  final List<int> templates = [];
  int depth = 0;

  String run() {
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (c == 0x0A || c == 0x0D) {
        gap = 2;
        i++;
      } else if (c == 0x20 || c == 0x09 || c == 0x0C || c == 0x0B) {
        if (gap == 0) gap = 1;
        i++;
      } else if (c == 0x2F && _at(i + 1) == 0x2F) {
        // Line comment: it ends in a line break.
        while (i < s.length && s.codeUnitAt(i) != 0x0A) {
          i++;
        }
      } else if (c == 0x2F && _at(i + 1) == 0x2A) {
        final end = s.indexOf('*/', i + 2);
        if (end < 0) throw FormatException('unterminated comment', s, i);
        if (s.substring(i, end).contains('\n')) {
          gap = 2;
        } else if (gap == 0) {
          gap = 1;
        }
        i = end + 2;
      } else if (c == 0x27 || c == 0x22) {
        _token(_string(c), word: false, regexAfter: false);
      } else if (c == 0x60) {
        _template(start: true);
      } else if (c == 0x7D && templates.isNotEmpty && templates.last == depth) {
        // The `}` that closes a `${` goes back into its template literal.
        templates.removeLast();
        _template(start: false);
      } else if (c == 0x2F && regexAllowed) {
        _token(_regex(), word: false, regexAfter: false);
      } else if (_isWord(c)) {
        final start = i;
        while (i < s.length && _isWord(s.codeUnitAt(i))) {
          i++;
        }
        final word = s.substring(start, i);
        _token(
          word,
          word: true,
          regexAfter: _keywordsBeforeRegex.contains(word),
        );
      } else {
        final ch = String.fromCharCode(c);
        i++;
        if (c == 0x7B) depth++;
        if (c == 0x7D) depth--;
        // After `)` `]` `}` a `/` divides (`(a) / b`); `}` of a block may
        // start a regex, which the runtime never writes.
        _token(
          ch,
          word: false,
          regexAfter: !(c == 0x29 || c == 0x5D || c == 0x7D),
        );
      }
    }
    return out.toString();
  }

  int _at(int j) => j < s.length ? s.codeUnitAt(j) : 0;

  /// Writes [token] after the pending whitespace, if it still matters.
  void _token(String token, {required bool word, required bool regexAfter}) {
    final first = token.codeUnitAt(0);
    if (last != 0 && gap != 0) {
      if (gap == 2 && _endsStatement(last) && _startsStatement(first)) {
        out.writeCharCode(0x0A);
      } else if (_isWord(last) && _isWord(first) ||
          // `a + +b`, `a - -b`, `a / /re/`: never glue them.
          (last == first && (first == 0x2B || first == 0x2D)) ||
          (last == 0x2F && first == 0x2F)) {
        out.writeCharCode(0x20);
      }
    }
    out.write(token);
    last = token.codeUnitAt(token.length - 1);
    gap = 0;
    regexAllowed = regexAfter;
  }

  String _string(int quote) {
    final start = i++;
    while (i < s.length) {
      final c = s.codeUnitAt(i++);
      if (c == 0x5C) {
        i++;
      } else if (c == quote) {
        return s.substring(start, i);
      } else if (c == 0x0A) {
        break;
      }
    }
    throw FormatException('unterminated string', s, start);
  }

  /// Copies a template literal from its backtick (or from the `}` of a
  /// `${…}` when not [start]) to its end or to its next `${`.
  void _template({required bool start}) {
    final from = i++;
    while (i < s.length) {
      final c = s.codeUnitAt(i++);
      if (c == 0x5C) {
        i++;
      } else if (c == 0x60) {
        _raw(s.substring(from, i), start: start, regexAfter: false);
        return;
      } else if (c == 0x24 && _at(i) == 0x7B) {
        i++;
        _raw(s.substring(from, i), start: start, regexAfter: true);
        templates.add(depth);
        return;
      }
    }
    throw FormatException('unterminated template literal', s, from);
  }

  void _raw(String part, {required bool start, required bool regexAfter}) {
    if (start) {
      _token(part, word: false, regexAfter: regexAfter);
    } else {
      // Inside a template: no whitespace between `}` and the text.
      out.write(part);
      last = part.codeUnitAt(part.length - 1);
      gap = 0;
      regexAllowed = regexAfter;
    }
  }

  String _regex() {
    final start = i++;
    var inClass = false;
    while (i < s.length) {
      final c = s.codeUnitAt(i++);
      if (c == 0x5C) {
        i++;
      } else if (c == 0x5B) {
        inClass = true;
      } else if (c == 0x5D) {
        inClass = false;
      } else if (c == 0x2F && !inClass) {
        while (i < s.length && _isWord(s.codeUnitAt(i))) {
          i++;
        }
        return s.substring(start, i);
      } else if (c == 0x0A) {
        break;
      }
    }
    throw FormatException('unterminated regular expression', s, start);
  }

  static bool _isWord(int c) =>
      (c >= 0x61 && c <= 0x7A) ||
      (c >= 0x41 && c <= 0x5A) ||
      (c >= 0x30 && c <= 0x39) ||
      c == 0x5F ||
      c == 0x24 ||
      c > 0x7F;

  /// A line break after this may end a statement (ASI).
  static bool _endsStatement(int c) =>
      _isWord(c) ||
      c == 0x29 || // )
      c == 0x5D || // ]
      c == 0x7D || // }
      c == 0x27 ||
      c == 0x22 ||
      c == 0x60 ||
      c == 0x2F || // end of a regex
      c == 0x2B || // x++
      c == 0x2D; // x--

  /// A line break before this may start a statement (ASI).
  static bool _startsStatement(int c) =>
      _isWord(c) ||
      c == 0x28 || // (
      c == 0x5B || // [
      c == 0x7B || // {
      c == 0x27 ||
      c == 0x22 ||
      c == 0x60 ||
      c == 0x2F ||
      c == 0x2B ||
      c == 0x2D ||
      c == 0x21 || // !
      c == 0x7E; // ~

  static const _keywordsBeforeRegex = {
    'return',
    'typeof',
    'instanceof',
    'in',
    'of',
    'new',
    'delete',
    'void',
    'throw',
    'case',
    'do',
    'else',
    'yield',
    'await',
  };
}
