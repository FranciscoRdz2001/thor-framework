/// A source-preserving view of an HTML page, for the build steps (optimizer,
/// fingerprints, shared styles).
///
/// Those steps used to parse with `package:html` and serialize the tree back.
/// That is not safe for thor's markup: `package:html` predates `<template>`
/// in the table insertion modes, so a `<template>` inside a `<tbody>` (the
/// row template of a `Watch.list`) is foster-parented out of the table, and
/// a `<tr>` without `<tbody>` gains one: the page that comes out is another
/// page. Here nothing is ever re-serialized: the page is scanned into a tree
/// that remembers where every tag, attribute value and text sits in the
/// source, edits are recorded against those places, and [MarkupDoc.render]
/// splices them into the original text. What was not edited stays byte for
/// byte.
///
/// The scanner is tolerant, not a conforming parser: it knows void elements,
/// raw-text elements (`script`, `style`, `textarea`, `title`), comments and
/// the usual optional end tags, which is all thor's output (and the markup
/// of other servers the optimizer takes) needs. `<template>` content is just
/// children, wherever the template is.
library;

/// An attribute of a [MElement] as written in the source.
class MAttr {
  MAttr._(this.name, this.value, this.start, this.end);

  /// Lower-cased name.
  final String name;

  /// The value with character references decoded; empty without one.
  final String value;

  /// Source range of the whole attribute (`name="value"`).
  final int start, end;
}

/// A text node.
class MText {
  MText._(this.data);

  /// The text, character references decoded.
  final String data;
}

/// An element with its places in the source.
class MElement {
  MElement._(this.name, this.start, this.startEnd, this.attrs, this.selfClosed);

  /// Lower-cased tag name.
  final String name;

  /// Where the start tag begins (`<`) and ends (after `>`).
  final int start, startEnd;

  /// Attributes in source order (a repeated name keeps its first).
  final List<MAttr> attrs;

  /// Ended with `/>`.
  final bool selfClosed;

  /// The parent; the document root for top-level elements.
  MElement? parent;

  /// Children, elements and text in source order.
  final List<Object> nodes = [];

  /// The end tag's range, or null when it was omitted (void or implied).
  int? endStart, endEnd;

  int _closeEnd = 0;

  /// The element's child elements.
  List<MElement> get children => [
    for (final n in nodes)
      if (n is MElement) n,
  ];

  /// First attribute called [name] (lower-case), or null.
  MAttr? attrNode(String name) {
    for (final a in attrs) {
      if (a.name == name) return a;
    }
    return null;
  }

  /// The decoded value of [name], or null when absent.
  String? attr(String name) => attrNode(name)?.value;

  /// Whether the start tag has [name].
  bool has(String name) => attrNode(name) != null;

  /// Where the element ends in the source.
  int get outerEnd => endEnd ?? _closeEnd;

  /// The source range between the tags.
  int get contentStart => startEnd;

  /// See [contentStart].
  int get contentEnd => endStart ?? _closeEnd;

  /// Concatenated text of the element and its descendants.
  String get text {
    final b = StringBuffer();
    void walk(MElement e) {
      for (final n in e.nodes) {
        if (n is MText) {
          b.write(n.data);
        } else if (n is MElement) {
          walk(n);
        }
      }
    }

    walk(this);
    return b.toString();
  }

  /// The element right before this one under the same parent, or null.
  MElement? get previousElement {
    final p = parent;
    if (p == null) return null;
    MElement? prev;
    for (final n in p.nodes) {
      if (identical(n, this)) return prev;
      if (n is MElement) prev = n;
    }
    return null;
  }
}

const _voids = {
  'area',
  'base',
  'br',
  'col',
  'embed',
  'hr',
  'img',
  'input',
  'link',
  'meta',
  'param',
  'source',
  'track',
  'wbr',
};

const _rawText = {'script', 'style', 'textarea', 'title'};

// Opening tag → the open elements it implicitly ends.
const _blocks = {
  'address',
  'article',
  'aside',
  'blockquote',
  'div',
  'dl',
  'fieldset',
  'footer',
  'form',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'header',
  'hr',
  'main',
  'nav',
  'ol',
  'p',
  'pre',
  'section',
  'table',
  'ul',
};
const _implied = <String, Set<String>>{
  'li': {'li'},
  'dt': {'dt', 'dd'},
  'dd': {'dt', 'dd'},
  'option': {'option'},
  'optgroup': {'option', 'optgroup'},
  'tr': {'td', 'th', 'tr'},
  'td': {'td', 'th'},
  'th': {'td', 'th'},
  'thead': {'thead', 'tbody', 'tfoot', 'tr', 'td', 'th'},
  'tbody': {'thead', 'tbody', 'tfoot', 'tr', 'td', 'th'},
  'tfoot': {'thead', 'tbody', 'tfoot', 'tr', 'td', 'th'},
};

bool _ws(int c) =>
    c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0c || c == 0x0d;

bool _letter(int c) => (c >= 0x41 && c <= 0x5a) || (c >= 0x61 && c <= 0x7a);

final _reference = RegExp(r'&(#[xX][0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);');

/// Decodes the character references of [s] (the common named ones and
/// numeric ones; others stay as written).
String decodeEntities(String s) {
  if (!s.contains('&')) return s;
  return s.replaceAllMapped(_reference, (m) {
    final r = m[1]!;
    if (r.startsWith('#')) {
      final hex = r.startsWith('#x') || r.startsWith('#X');
      final code = int.tryParse(r.substring(hex ? 2 : 1), radix: hex ? 16 : 10);
      return code == null || code > 0x10ffff
          ? m[0]!
          : String.fromCharCode(code);
    }
    return switch (r) {
      'amp' => '&',
      'lt' => '<',
      'gt' => '>',
      'quot' => '"',
      'apos' => "'",
      'nbsp' => ' ',
      _ => m[0]!,
    };
  });
}

/// [v] as the inside of a double-quoted attribute.
String escapeAttribute(String v) =>
    v.replaceAll('&', '&amp;').replaceAll('"', '&quot;');

class _Edit {
  _Edit(this.start, this.end, this.text, this.seq);
  final int start, end;
  final String text;
  final int seq;
}

/// A scanned page plus the edits recorded against it.
class MarkupDoc {
  /// Scans [source].
  MarkupDoc(this.source) {
    _scan();
  }

  /// The original text.
  final String source;

  /// Every element in document order.
  final List<MElement> all = [];

  late final MElement _root;

  final _attrEdits = <MElement, Map<String, String?>>{};
  final _content = <MElement, String>{};
  final _removed = <MElement>{};
  final _inserts = <(MElement, String)>[];
  final _voidSlash = <MElement>[];

  /// The first element with the given `id`, or null.
  MElement? byId(String id) {
    for (final e in all) {
      if (e.attr('id') == id) return e;
    }
    return null;
  }

  /// The first element called [name], or null.
  MElement? byName(String name) {
    for (final e in all) {
      if (e.name == name) return e;
    }
    return null;
  }

  /// Whether [e] was removed, or sits inside something that was.
  bool isGone(MElement e) {
    for (MElement? x = e; x != null; x = x.parent) {
      if (_removed.contains(x)) return true;
    }
    return false;
  }

  /// Sets (or, with null, removes) the attribute [name] of [e].
  void setAttr(MElement e, String name, String? value) =>
      (_attrEdits[e] ??= {})[name.toLowerCase()] = value;

  /// Replaces what is between the tags of [e] (raw, as for `<style>`).
  void setContent(MElement e, String raw) => _content[e] = raw;

  /// Deletes [e] with its content.
  void remove(MElement e) => _removed.add(e);

  /// Writes [markup] right before the start tag of [e].
  void insertBefore(MElement e, String markup) => _inserts.add((e, markup));

  /// The source with every recorded edit applied.
  String render({bool compactVoids = true}) {
    final edits = <_Edit>[];
    var seq = 0;
    void add(int s, int e, String t) => edits.add(_Edit(s, e, t, seq++));
    for (final MapEntry(key: el, value: changes) in _attrEdits.entries) {
      final added = StringBuffer();
      for (final MapEntry(key: name, value: value) in changes.entries) {
        final old = el.attrNode(name);
        if (old != null) {
          if (value == null) {
            var s = old.start;
            while (s > el.start && _ws(source.codeUnitAt(s - 1))) {
              s--;
            }
            add(s, old.end, '');
          } else {
            add(old.start, old.end, '$name="${escapeAttribute(value)}"');
          }
        } else if (value != null) {
          added.write(' $name="${escapeAttribute(value)}"');
        }
      }
      if (added.isNotEmpty) {
        final closed = source.codeUnitAt(el.startEnd - 1) == 0x3e;
        final at = !closed
            ? el.startEnd
            : compactVoids && _voidSlash.contains(el)
            ? _slashStart(el)
            : el.selfClosed
            ? el.startEnd - 2
            : el.startEnd - 1;
        add(at, at, added.toString());
      }
    }
    for (final MapEntry(key: el, value: text) in _content.entries) {
      add(el.contentStart, el.contentEnd, text);
    }
    for (final (el, markup) in _inserts) {
      add(el.start, el.start, markup);
    }
    for (final el in _removed) {
      add(el.start, el.outerEnd, '');
    }
    // The renderer writes void elements XHTML-style (`<br/>`); HTML wants
    // `<br>`, and the build has always shipped that (a byte less each).
    if (compactVoids) {
      for (final el in _voidSlash) {
        add(_slashStart(el), el.startEnd - 1, '');
      }
    }
    edits.sort((a, b) {
      if (a.start != b.start) return a.start.compareTo(b.start);
      final ai = a.start == a.end, bi = b.start == b.end;
      if (ai != bi) return ai ? -1 : 1;
      if (!ai && a.end != b.end) return b.end.compareTo(a.end);
      return a.seq.compareTo(b.seq);
    });
    final out = StringBuffer();
    var cursor = 0;
    for (final e in edits) {
      if (e.start < cursor) continue; // inside something already replaced
      out
        ..write(source.substring(cursor, e.start))
        ..write(e.text);
      cursor = e.end;
    }
    out.write(source.substring(cursor));
    return out.toString();
  }

  /// Where the `/` of a self-closed void tag starts (with its spaces).
  int _slashStart(MElement el) {
    var s = el.startEnd - 2;
    while (s > el.start && _ws(source.codeUnitAt(s - 1))) {
      s--;
    }
    return s;
  }

  void _scan() {
    final s = source;
    final n = s.length;
    _root = MElement._('#root', 0, 0, const [], false);
    final stack = <MElement>[_root];
    var i = 0;
    var textStart = 0;

    void flush(int end) {
      if (end > textStart) {
        stack.last.nodes.add(
          MText._(decodeEntities(s.substring(textStart, end))),
        );
      }
    }

    bool foreign() => stack.any((e) => e.name == 'svg' || e.name == 'math');

    while (i < n) {
      i = s.indexOf('<', i);
      if (i < 0) break;
      if (s.startsWith('<!--', i)) {
        final end = s.indexOf('-->', i + 4);
        flush(i);
        i = textStart = end < 0 ? n : end + 3;
        continue;
      }
      final next = i + 1 < n ? s.codeUnitAt(i + 1) : 0;
      if (next == 0x21 || next == 0x3f) {
        final end = s.indexOf('>', i);
        flush(i);
        i = textStart = end < 0 ? n : end + 1;
        continue;
      }
      if (next == 0x2f && i + 2 < n && _letter(s.codeUnitAt(i + 2))) {
        var j = i + 2;
        while (j < n && !_ws(s.codeUnitAt(j)) && s[j] != '/' && s[j] != '>') {
          j++;
        }
        final name = s.substring(i + 2, j).toLowerCase();
        final gt = s.indexOf('>', j);
        final end = gt < 0 ? n : gt + 1;
        flush(i);
        for (var k = stack.length - 1; k > 0; k--) {
          if (stack[k].name != name) continue;
          for (var m = stack.length - 1; m > k; m--) {
            stack[m]._closeEnd = i;
          }
          stack[k]
            ..endStart = i
            ..endEnd = end;
          stack.length = k;
          break;
        }
        i = textStart = end;
        continue;
      }
      if (!_letter(next)) {
        i++;
        continue;
      }
      // A start tag.
      flush(i);
      var j = i + 1;
      while (j < n && !_ws(s.codeUnitAt(j)) && s[j] != '/' && s[j] != '>') {
        j++;
      }
      final name = s.substring(i + 1, j).toLowerCase();
      final attrs = <MAttr>[];
      var selfClosed = false;
      while (true) {
        while (j < n && _ws(s.codeUnitAt(j))) {
          j++;
        }
        if (j >= n) break;
        final c = s[j];
        if (c == '>') {
          j++;
          break;
        }
        if (c == '/') {
          if (j + 1 < n && s[j + 1] == '>') {
            selfClosed = true;
            j += 2;
            break;
          }
          j++;
          continue;
        }
        final aStart = j++;
        while (j < n &&
            !_ws(s.codeUnitAt(j)) &&
            s[j] != '=' &&
            s[j] != '>' &&
            s[j] != '/') {
          j++;
        }
        final aName = s.substring(aStart, j).toLowerCase();
        var value = '';
        var aEnd = j;
        var k = j;
        while (k < n && _ws(s.codeUnitAt(k))) {
          k++;
        }
        if (k < n && s[k] == '=') {
          k++;
          while (k < n && _ws(s.codeUnitAt(k))) {
            k++;
          }
          if (k < n && (s[k] == '"' || s[k] == "'")) {
            final close = s.indexOf(s[k], k + 1);
            final ve = close < 0 ? n : close;
            value = s.substring(k + 1, ve);
            aEnd = close < 0 ? n : close + 1;
          } else {
            final vs = k;
            while (k < n && !_ws(s.codeUnitAt(k)) && s[k] != '>') {
              k++;
            }
            value = s.substring(vs, k);
            aEnd = k;
          }
          j = aEnd;
        }
        if (attrs.every((a) => a.name != aName)) {
          attrs.add(MAttr._(aName, decodeEntities(value), aStart, aEnd));
        }
      }
      final startEnd = j;

      // Optional end tags the new tag implies.
      final closes = _implied[name];
      while (stack.length > 1) {
        final top = stack.last.name;
        final ends =
            (closes != null && closes.contains(top)) ||
            (top == 'p' && _blocks.contains(name));
        if (!ends) break;
        stack.removeLast()._closeEnd = i;
      }

      final el = MElement._(name, i, startEnd, attrs, selfClosed)
        ..parent = stack.last;
      stack.last.nodes.add(el);
      all.add(el);
      if (selfClosed && _voids.contains(name) && !foreign()) _voidSlash.add(el);
      if (_voids.contains(name) ||
          (selfClosed && (foreign() || name == 'svg'))) {
        el._closeEnd = startEnd;
        i = textStart = startEnd;
        continue;
      }
      if (_rawText.contains(name) && !selfClosed) {
        final close = RegExp(
          '</$name(?=[\\s/>])',
          caseSensitive: false,
        ).allMatches(s, startEnd).firstOrNull;
        final cs = close == null ? n : close.start;
        if (cs > startEnd) {
          final raw = s.substring(startEnd, cs);
          el.nodes.add(
            MText._(
              name == 'script' || name == 'style' ? raw : decodeEntities(raw),
            ),
          );
        }
        if (close == null) {
          el._closeEnd = n;
          i = textStart = n;
        } else {
          final gt = s.indexOf('>', cs);
          final end = gt < 0 ? n : gt + 1;
          el
            ..endStart = cs
            ..endEnd = end;
          i = textStart = end;
        }
        continue;
      }
      stack.add(el);
      i = textStart = startEnd;
    }
    flush(n);
    for (var k = 1; k < stack.length; k++) {
      stack[k]._closeEnd = n;
    }
  }
}
