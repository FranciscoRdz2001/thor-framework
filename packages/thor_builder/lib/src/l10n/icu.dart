/// A parser for the ICU MessageFormat subset of ARB files: text,
/// `{placeholder}`, `{n, plural, =0{…} one{…} other{…}}` with `#`, and
/// `{g, select, a{…} other{…}}`, nested.
library;

/// A piece of a message.
sealed class IcuNode {
  const IcuNode();
}

/// Literal text.
final class IcuText extends IcuNode {
  /// [text], unescaped.
  const IcuText(this.text);

  /// The text.
  final String text;
}

/// `{name}`: a placeholder's value.
final class IcuArgument extends IcuNode {
  /// The placeholder [name].
  const IcuArgument(this.name);

  /// Placeholder name.
  final String name;
}

/// `#` in a plural: the number of the nearest enclosing plural.
final class IcuPound extends IcuNode {
  /// For the plural of [name].
  const IcuPound(this.name);

  /// The plural's placeholder.
  final String name;
}

/// `{name, plural, …}` or `{name, select, …}`.
final class IcuChoice extends IcuNode {
  /// A choice on [name].
  const IcuChoice(this.name, {required this.plural, required this.cases});

  /// The placeholder chosen on.
  final String name;

  /// Plural (numbers, `=N` and CLDR categories) or select (strings).
  final bool plural;

  /// Case key (`=0`, `one`, `other`, `male`) → its message, in source order.
  final Map<String, List<IcuNode>> cases;
}

/// A message that isn't valid ICU: [message] at [offset].
class IcuSyntaxError implements Exception {
  /// An error at [offset] of the message.
  const IcuSyntaxError(this.message, this.offset);

  /// What is wrong.
  final String message;

  /// Where, in characters from the start.
  final int offset;

  @override
  String toString() => '$message (at character $offset)';
}

/// CLDR plural categories.
const pluralCategories = {'zero', 'one', 'two', 'few', 'many', 'other'};

/// Parses [message].
///
/// Apostrophes follow ICU's default (`DOUBLE_OPTIONAL`): `''` is one
/// apostrophe; a `'` before `{`, `}` (or `#` in a plural) quotes up to the
/// next `'`; any other `'` is literal, so `don't` needs no escaping.
List<IcuNode> parseIcu(String message) {
  final parser = _Parser(message);
  final nodes = parser.message(null);
  if (parser.i < message.length) {
    throw IcuSyntaxError('unbalanced "}"', parser.i);
  }
  return nodes;
}

final _identifier = RegExp(r'[A-Za-z_][A-Za-z0-9_]*');

class _Parser {
  _Parser(this.s);
  final String s;
  var i = 0;

  /// Nodes until an unmatched `}` (left unread) or the end. [pound] is
  /// the nearest plural's placeholder.
  List<IcuNode> message(String? pound) {
    final nodes = <IcuNode>[];
    final text = StringBuffer();
    void flush() {
      if (text.isEmpty) return;
      nodes.add(IcuText(text.toString()));
      text.clear();
    }

    while (i < s.length) {
      final c = s[i];
      if (c == "'") {
        final next = i + 1 < s.length ? s[i + 1] : null;
        if (next == "'") {
          text.write("'");
          i += 2;
        } else if (next == '{' ||
            next == '}' ||
            (next == '#' && pound != null)) {
          final start = i;
          i++;
          while (true) {
            if (i >= s.length) {
              throw IcuSyntaxError('unterminated quote', start);
            }
            if (s[i] == "'") {
              if (i + 1 < s.length && s[i + 1] == "'") {
                text.write("'");
                i += 2;
                continue;
              }
              i++;
              break;
            }
            text.write(s[i++]);
          }
        } else {
          text.write("'");
          i++;
        }
      } else if (c == '{') {
        flush();
        nodes.add(_argument(pound));
      } else if (c == '}') {
        break;
      } else if (c == '#' && pound != null) {
        flush();
        nodes.add(IcuPound(pound));
        i++;
      } else {
        text.write(c);
        i++;
      }
    }
    flush();
    return nodes;
  }

  void _spaces() {
    while (i < s.length && s[i].trim().isEmpty) {
      i++;
    }
  }

  String _name(String what) {
    _spaces();
    final m = _identifier.matchAsPrefix(s, i);
    if (m == null) throw IcuSyntaxError('expected $what', i);
    i = m.end;
    return m[0]!;
  }

  void _expect(String c) {
    _spaces();
    if (i >= s.length || s[i] != c) {
      throw IcuSyntaxError('expected "$c"', i);
    }
    i++;
  }

  IcuNode _argument(String? pound) {
    final open = i;
    i++; // {
    final name = _name('a placeholder name');
    _spaces();
    if (i >= s.length) throw IcuSyntaxError('unclosed "{"', open);
    if (s[i] == '}') {
      i++;
      return IcuArgument(name);
    }
    _expect(',');
    final typeAt = i;
    final type = _name('plural or select');
    if (type != 'plural' && type != 'select') {
      throw IcuSyntaxError(
        '"$type" is not supported (plural or select; numbers and dates '
        'are formatted with the placeholder\'s "format")',
        typeAt,
      );
    }
    final plural = type == 'plural';
    _expect(',');
    final cases = <String, List<IcuNode>>{};
    while (true) {
      _spaces();
      if (i >= s.length) throw IcuSyntaxError('unclosed "{"', open);
      if (s[i] == '}') {
        i++;
        break;
      }
      final keyAt = i;
      final String key;
      if (plural && s[i] == '=') {
        final m = RegExp(r'=\d+').matchAsPrefix(s, i);
        if (m == null) throw IcuSyntaxError('expected a number after "="', i);
        key = '=${int.parse(m[0]!.substring(1))}';
        i = m.end;
      } else {
        final m = RegExp(r'[^\s{}]+').matchAsPrefix(s, i);
        if (m == null) throw IcuSyntaxError('expected a case', i);
        key = m[0]!;
        i = m.end;
        if (key.startsWith('offset:')) {
          throw IcuSyntaxError('plural offsets are not supported', keyAt);
        }
        if (plural && !pluralCategories.contains(key)) {
          throw IcuSyntaxError(
            '"$key" is not a plural category '
            '(zero, one, two, few, many, other or =N)',
            keyAt,
          );
        }
      }
      if (cases.containsKey(key)) {
        throw IcuSyntaxError('case "$key" appears twice', keyAt);
      }
      _expect('{');
      cases[key] = message(plural ? name : pound);
      if (i >= s.length) throw IcuSyntaxError('unclosed "{"', open);
      i++; // }
    }
    if (!cases.containsKey('other')) {
      throw IcuSyntaxError('a $type needs an "other" case', open);
    }
    return IcuChoice(name, plural: plural, cases: cases);
  }
}

/// Every placeholder [nodes] use, with whether it is a plural's or a
/// select's (`plural`, `select`) or plain (`text`), in order of first use.
Map<String, Set<String>> placeholderUses(List<IcuNode> nodes) {
  final uses = <String, Set<String>>{};
  void visit(List<IcuNode> nodes) {
    for (final n in nodes) {
      switch (n) {
        case IcuText():
          break;
        case IcuArgument(:final name):
          (uses[name] ??= {}).add('text');
        case IcuPound(:final name):
          (uses[name] ??= {}).add('plural');
        case IcuChoice(:final name, :final plural, :final cases):
          (uses[name] ??= {}).add(plural ? 'plural' : 'select');
          cases.values.forEach(visit);
      }
    }
  }

  visit(nodes);
  return uses;
}
