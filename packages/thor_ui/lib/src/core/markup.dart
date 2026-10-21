/// The HTML a page is built into, and how it is written: compact in
/// release (one buffer, nothing added) or indented in debug.
library;

import 'dart:convert';
import 'dart:typed_data';

/// A node of the page.
sealed class Node {}

/// A node with children: an element, a fragment or the page root.
sealed class ParentNode extends Node {
  /// The children, in order.
  final List<Node> children = [];

  /// Appends [node].
  void add(Node node) => children.add(node);

  /// The last child.
  Node get last => children.last;
}

/// An HTML element.
final class ElementNode extends ParentNode {
  /// An element [tag] with its attributes.
  ElementNode(this.tag, {this.id, this.classes, this.styles, this.attributes});

  /// The tag, as given (written in lowercase).
  final String tag;

  /// The `id` attribute.
  String? id;

  /// The `class` attribute.
  String? classes;

  /// The `style` declarations, in order.
  Map<String, String>? styles;

  /// The other attributes, in order.
  Map<String, String>? attributes;
}

/// Text: escaped, or [raw] HTML written as is.
final class TextNode extends Node {
  /// Text: [raw] HTML, or escaped.
  TextNode(this.text, {this.raw = false});

  /// The text.
  final String text;

  /// Whether [text] is HTML written as is.
  final bool raw;
}

/// Children with no element around them.
final class FragmentNode extends ParentNode {
  /// Whether this fragment is kept and added as it is to later pages
  /// (`Cached`): its children never change, so its compact HTML is written
  /// once.
  bool kept = false;

  String? _compact;

  Uint8List? _utf8;
}

/// The page: each child ends with a line break.
final class RootNode extends ParentNode {}

/// The first element [test] accepts among [parent]'s children, looking
/// inside fragments, with the list that holds it.
({ElementNode node, List<Node> list})? findElement(
  ParentNode parent,
  bool Function(ElementNode node) test,
) {
  for (final child in parent.children) {
    if (child is ElementNode && test(child)) {
      return (node: child, list: parent.children);
    }
    if (child is FragmentNode) {
      final found = findElement(child, test);
      if (found != null) return found;
    }
  }
  return null;
}

/// The zone value that holds the nonce placeholder (see [stampingNonce]).
const nonceTokenZoneKey = #thorNonceToken;

String? _nonceToken;

/// Runs [body] (a synchronous write of a page) with every `<script>` and
/// `<style>` element that has no `nonce` of its own written with
/// `nonce="[token]"`: a placeholder the server's `contentSecurityPolicy`
/// replaces with the request's nonce. Only element nodes get it: text that
/// holds `<script>` (an escaping failure, a markdown renderer) is not an
/// element and never does.
///
/// With a [token], kept fragments are written again instead of from their
/// cache: their bytes are shared by every render, the placeholder is not.
T stampingNonce<T>(String? token, T Function() body) {
  final before = _nonceToken;
  _nonceToken = token;
  try {
    return body();
  } finally {
    _nonceToken = before;
  }
}

bool _takesNonce(String tag, ElementNode node) =>
    _nonceToken != null &&
    (tag == 'script' || tag == 'style') &&
    !(node.attributes?.containsKey('nonce') ?? false);

/// The page as HTML: [compact] (release) or indented.
String writePage(RootNode root, {required bool compact}) {
  final out = StringBuffer();
  if (compact) {
    for (final child in root.children) {
      _writeCompact(child, out);
      out.writeln();
    }
  } else {
    final before = _preservingClasses;
    _preservingClasses = _classesThatPreserveWhitespace(root);
    try {
      for (final child in root.children) {
        out.writeln(_Pretty.node(child, false, false, '').html);
      }
    } finally {
      _preservingClasses = before;
    }
  }
  return out.toString();
}

void _writeCompact(Node node, StringBuffer out) {
  switch (node) {
    case ElementNode():
      final tag = _openTag(node, out);
      if (_voidElements.contains(tag)) {
        out.write('/>');
        return;
      }
      out.write('>');
      for (final child in node.children) {
        _writeCompact(child, out);
      }
      out
        ..write('</')
        ..write(tag)
        ..write('>');
    case TextNode(:final text, :final raw):
      if (text.isNotEmpty) out.write(raw ? text : _textEscape.convert(text));
    case FragmentNode(kept: true) when _nonceToken == null:
      out.write(
        node._compact ??= () {
          final own = StringBuffer();
          for (final child in node.children) {
            _writeCompact(child, own);
          }
          return own.toString();
        }(),
      );
    case FragmentNode() || RootNode():
      for (final child in (node as ParentNode).children) {
        _writeCompact(child, out);
      }
  }
}

/// The page as UTF-8, compact: the bytes of
/// `utf8.encode(writePage(root, compact: true))`, written straight from
/// the nodes (no page-sized string, no second pass to encode it; ASCII,
/// most of a page, is copied a code unit at a time).
Uint8List writePageUtf8(RootNode root) {
  final out = _Utf8Out();
  for (final child in root.children) {
    _writeUtf8(child, out);
    out.byte(0x0a);
  }
  return out.bytes;
}

/// The children of [parent] as UTF-8, compact, with nothing between them:
/// the HTML of a part of a page (what a `PageBuild.late` built).
Uint8List writeChildrenUtf8(ParentNode parent) {
  final out = _Utf8Out();
  for (final child in parent.children) {
    _writeUtf8(child, out);
  }
  return out.bytes;
}

void _writeUtf8(Node node, _Utf8Out out) {
  switch (node) {
    case ElementNode():
      final tag = _openTagUtf8(node, out);
      if (_voidElements.contains(tag)) {
        out.ascii('/>');
        return;
      }
      out.byte(0x3e); // >
      for (final child in node.children) {
        _writeUtf8(child, out);
      }
      out
        ..ascii('</')
        ..text(tag)
        ..byte(0x3e);
    case TextNode(:final text, :final raw):
      if (text.isEmpty) return;
      if (!raw) {
        out.escaped(text, attribute: false);
      } else if (_rawBytes(text) case final bytes?) {
        out.add(bytes);
      } else {
        out.text(text);
      }
    case FragmentNode(kept: true) when _nonceToken == null:
      out.add(
        node._utf8 ??= () {
          final own = _Utf8Out();
          for (final child in node.children) {
            _writeUtf8(child, own);
          }
          return own.bytes;
        }(),
      );
    case FragmentNode() || RootNode():
      for (final child in (node as ParentNode).children) {
        _writeUtf8(child, out);
      }
  }
}

/// The UTF-8 of a long raw text written before as this same instance (a
/// page's stylesheet, a constant script: the caches above hand out one
/// string page after page), or null: the caller encodes it. A text is
/// encoded and kept only the second time it is seen, so a per-request
/// string (JSON-LD, a page's data) costs one map entry, never a copy.
Uint8List? _rawBytes(String text) {
  if (text.length < _rawBytesMinLength) return null;
  final seen = _rawBytesSeen;
  if (seen.containsKey(text)) {
    return seen[text] ??= (_Utf8Out()..text(text)).bytes;
  }
  // Bounded: per-request strings come and go.
  if (seen.length >= _rawBytesLimit) seen.clear();
  seen[text] = null;
  return null;
}

// Identity: hashing a long string per lookup would cost what encoding it
// does (the VM caches a string's identity hash in the object).
final _rawBytesSeen = Map<String, Uint8List?>.identity();
const _rawBytesMinLength = 512;
const _rawBytesLimit = 256;

/// [_openTag] for [writePageUtf8]: the same bytes.
String _openTagUtf8(ElementNode node, _Utf8Out out) {
  final tag = node.tag.toLowerCase();
  _checkName(tag, 'element');
  out
    ..byte(0x3c) // <
    ..text(tag);
  if (_takesNonce(tag, node)) out.text(' nonce="$_nonceToken"');
  if (node.id case final id?) {
    out
      ..ascii(' id="')
      ..escaped(id, attribute: true)
      ..byte(0x22);
  }
  if (node.classes case final classes? when classes.isNotEmpty) {
    out
      ..ascii(' class="')
      ..escaped(classes, attribute: true)
      ..byte(0x22);
  }
  if (node.styles case final styles? when styles.isNotEmpty) {
    out
      ..ascii(' style="')
      ..escaped(
        [
          for (final MapEntry(:key, :value) in styles.entries) '$key: $value',
        ].join('; '),
        attribute: true,
      )
      ..byte(0x22);
  }
  if (node.attributes case final attributes? when attributes.isNotEmpty) {
    for (final MapEntry(:key, :value) in attributes.entries) {
      if (key == scrollFocusAttr) {
        out.ascii(_scrollFocus(node));
        continue;
      }
      _checkName(key, 'attribute');
      if (runsCode(key, value)) continue;
      out
        ..byte(0x20)
        ..text(key);
      if (value.isNotEmpty) {
        out
          ..ascii('="')
          ..escaped(value, attribute: true)
          ..byte(0x22);
      }
    }
  }
  return tag;
}

/// A growing UTF-8 buffer: what `utf8.encode` and `HtmlEscape` give, byte
/// for byte (an unpaired surrogate is U+FFFD, like `utf8.encode`).
final class _Utf8Out {
  Uint8List _b = Uint8List(1 << 14);
  int _n = 0;

  /// The bytes written (a view of the buffer).
  Uint8List get bytes => Uint8List.sublistView(_b, 0, _n);

  void _room(int more) {
    if (_n + more <= _b.length) return;
    var size = _b.length * 2;
    while (size < _n + more) {
      size *= 2;
    }
    _b = Uint8List(size)..setRange(0, _n, _b);
  }

  void byte(int b) {
    _room(1);
    _b[_n++] = b;
  }

  /// [s], known to be ASCII (the writer's own punctuation).
  void ascii(String s) {
    _room(s.length);
    for (var i = 0; i < s.length; i++) {
      _b[_n++] = s.codeUnitAt(i);
    }
  }

  void add(Uint8List bytes) {
    _room(bytes.length);
    _b.setRange(_n, _n + bytes.length, bytes);
    _n += bytes.length;
  }

  /// [s] as it is (raw HTML, names).
  void text(String s) {
    final length = s.length;
    // A UTF-16 unit is at most 3 bytes (a surrogate pair, 2 units, is 4).
    _room(length * 3);
    final b = _b;
    var n = _n;
    for (var i = 0; i < length; i++) {
      final c = s.codeUnitAt(i);
      if (c < 0x80) {
        b[n++] = c;
      } else {
        n = _encode(s, i, c, n);
        if (_pairAt == i) i++;
      }
    }
    _n = n;
  }

  /// [s] escaped as `HtmlEscape` does: `& < >` in text, and `"` too in an
  /// [attribute].
  void escaped(String s, {required bool attribute}) {
    final length = s.length;
    // `&quot;` is the longest replacement: 6 bytes for one unit.
    _room(length * 6);
    final b = _b;
    var n = _n;
    for (var i = 0; i < length; i++) {
      final c = s.codeUnitAt(i);
      if (c < 0x80) {
        switch (c) {
          case 0x26: // &
            b[n++] = 0x26;
            b[n++] = 0x61; // a
            b[n++] = 0x6d; // m
            b[n++] = 0x70; // p
            b[n++] = 0x3b; // ;
          case 0x3c: // <
            b[n++] = 0x26;
            b[n++] = 0x6c; // l
            b[n++] = 0x74; // t
            b[n++] = 0x3b;
          case 0x3e: // >
            b[n++] = 0x26;
            b[n++] = 0x67; // g
            b[n++] = 0x74; // t
            b[n++] = 0x3b;
          case 0x22 when attribute: // "
            b[n++] = 0x26;
            b[n++] = 0x71; // q
            b[n++] = 0x75; // u
            b[n++] = 0x6f; // o
            b[n++] = 0x74; // t
            b[n++] = 0x3b;
          default:
            b[n++] = c;
        }
      } else {
        n = _encode(s, i, c, n);
        if (_pairAt == i) i++;
      }
    }
    _n = n;
  }

  // The index of the high surrogate the last [_encode] paired (it used the
  // next unit too), or -1.
  int _pairAt = -1;

  /// Writes the non-ASCII unit [c] at [i] of [s] at [n]; the new end.
  int _encode(String s, int i, int c, int n) {
    final b = _b;
    _pairAt = -1;
    if (c < 0x800) {
      b[n++] = 0xc0 | (c >> 6);
      b[n++] = 0x80 | (c & 0x3f);
    } else if (c & 0xfc00 == 0xd800 &&
        i + 1 < s.length &&
        s.codeUnitAt(i + 1) & 0xfc00 == 0xdc00) {
      final r = 0x10000 + ((c & 0x3ff) << 10) + (s.codeUnitAt(i + 1) & 0x3ff);
      b[n++] = 0xf0 | (r >> 18);
      b[n++] = 0x80 | ((r >> 12) & 0x3f);
      b[n++] = 0x80 | ((r >> 6) & 0x3f);
      b[n++] = 0x80 | (r & 0x3f);
      _pairAt = i;
    } else if (c & 0xf800 == 0xd800) {
      // An unpaired surrogate: U+FFFD, as utf8.encode writes it.
      b[n++] = 0xef;
      b[n++] = 0xbf;
      b[n++] = 0xbd;
    } else {
      b[n++] = 0xe0 | (c >> 12);
      b[n++] = 0x80 | ((c >> 6) & 0x3f);
      b[n++] = 0x80 | (c & 0x3f);
    }
    return n;
  }
}

/// The mark of a scroll view (`SingleChildScrollView`, `ListView`,
/// `GridView`), never written: it becomes `tabindex="0"` (a keyboard reaches
/// and scrolls the region, WCAG 2.1.1; axe `scrollable-region-focusable`)
/// unless something focusable inside already is the way in.
const scrollFocusAttr = 'data-t-scrollfocus';

/// What a scroll view's [scrollFocusAttr] is written as: ` tabindex="0"` (and
/// `role="region"` if the app named it with `Semantics(label:)`, so the stop
/// is announced) when no descendant can take focus, nothing otherwise or when
/// the element has its own `tabindex`.
///
/// `// web:` the region may not overflow at all (the markup cannot tell): it
/// is a tab stop anyway; a view that never scrolls
/// (`NeverScrollableScrollPhysics`) is not marked.
String _scrollFocus(ElementNode node) {
  final attributes = node.attributes!;
  if (attributes.containsKey('tabindex') || _hasTabStop(node)) return '';
  final named =
      !attributes.containsKey('role') &&
      (attributes.containsKey('aria-label') ||
          attributes.containsKey('aria-labelledby'));
  return named ? ' tabindex="0" role="region"' : ' tabindex="0"';
}

/// Whether a descendant of [parent] is reached by Tab: a link with an
/// `href`, an enabled control, a `summary`, anything with `tabindex` of 0
/// or more or editable, media with `controls`, a frame, another scroll view
/// (which will have its own stop), or raw HTML that looks like any of them.
bool _hasTabStop(ParentNode parent) {
  for (final child in parent.children) {
    switch (child) {
      case ElementNode():
        // A `<template>` is inert: what the engine stamps out later is not
        // in the tab order now.
        if (child.tag.toLowerCase() == 'template') continue;
        if (_isTabStop(child) || _hasTabStop(child)) return true;
      case TextNode(:final text, raw: true):
        if (_rawFocusable.hasMatch(text)) return true;
      case TextNode():
        break;
      case FragmentNode():
        if (_hasTabStop(child)) return true;
      case RootNode():
        break;
    }
  }
  return false;
}

final _rawFocusable = RegExp(
  r'<(?:a\s[^>]*href|button|input|select|textarea|summary|iframe|embed|object|audio|video)\b|tabindex|contenteditable',
  caseSensitive: false,
);

bool _isTabStop(ElementNode e) {
  final a = e.attributes;
  if (a != null) {
    if (a.containsKey(scrollFocusAttr)) return true;
    if (a['tabindex'] case final t? when (int.tryParse(t.trim()) ?? -1) >= 0) {
      return true;
    }
    if (a['contenteditable'] case final c? when c != 'false') return true;
  }
  final disabled = a != null && a.containsKey('disabled');
  switch (e.tag.toLowerCase()) {
    case 'a' || 'area':
      return a != null && a.containsKey('href');
    case 'button' || 'select' || 'textarea':
      return !disabled;
    case 'input':
      return !disabled && a?['type']?.toLowerCase() != 'hidden';
    case 'summary' || 'iframe' || 'embed' || 'object':
      return true;
    case 'audio' || 'video':
      return a != null && a.containsKey('controls');
  }
  return false;
}

/// Writes `<tag` and its attributes: `id`, `class`, `style`, then the
/// rest in order (an empty value is a bare attribute). Returns the tag in
/// lowercase.
String _openTag(ElementNode node, StringBuffer out) {
  final tag = node.tag.toLowerCase();
  _checkName(tag, 'element');
  out
    ..write('<')
    ..write(tag);
  if (_takesNonce(tag, node)) out.write(' nonce="$_nonceToken"');
  if (node.id case final id?) {
    out
      ..write(' id="')
      ..write(_attributeEscape.convert(id))
      ..write('"');
  }
  if (node.classes case final classes? when classes.isNotEmpty) {
    out
      ..write(' class="')
      ..write(_attributeEscape.convert(classes))
      ..write('"');
  }
  if (node.styles case final styles? when styles.isNotEmpty) {
    out
      ..write(' style="')
      ..write(
        _attributeEscape.convert(
          [
            for (final MapEntry(:key, :value) in styles.entries) '$key: $value',
          ].join('; '),
        ),
      )
      ..write('"');
  }
  if (node.attributes case final attributes? when attributes.isNotEmpty) {
    for (final MapEntry(:key, :value) in attributes.entries) {
      if (key == scrollFocusAttr) {
        out.write(_scrollFocus(node));
        continue;
      }
      _checkName(key, 'attribute');
      if (runsCode(key, value)) continue;
      out
        ..write(' ')
        ..write(key);
      if (value.isNotEmpty) {
        out
          ..write('="')
          ..write(_attributeEscape.convert(value))
          ..write('"');
      }
    }
  }
  return tag;
}

/// Element and attribute names: a letter, `@` or `:` first, then letters,
/// digits and `-_:.`, ending in a lowercase letter or digit. Anything else
/// could break out of the tag, so it fails the page.
final _name = RegExp(r'^[@a-z:](?:[a-zA-Z0-9\-_:.]*[a-z0-9]+)?$');
final _validNames = <String>{};

void _checkName(String name, String kind) {
  if (!_isName(name)) throw ArgumentError('"$name" is not a valid $kind name.');
}

bool _isName(String name) {
  if (_validNames.contains(name)) return true;
  if (!_name.hasMatch(name)) return false;
  _validNames.add(name);
  return true;
}

/// Whether the HTML writer accepts [name] as an attribute name (it fails
/// the whole page on one it does not). `HtmlAttributes.custom` asks the same
/// question where the attributes are built.
bool isHtmlAttributeName(String name) => _isName(name);

/// The attributes whose value is a URL the browser follows or loads.
const _urlAttributeNames = {
  'href',
  'src',
  'action',
  'formaction',
  'xlink:href',
  'poster',
  'cite',
  'data',
  'background',
  'longdesc',
};

/// Whether attribute [name] with [value] would run code, so it is not
/// written: a `javascript:` or `vbscript:` URL, or a `data:` one that is a
/// document the browser runs (HTML, XML, SVG, a script). The
/// browser reads the scheme after dropping tabs and newlines anywhere and
/// the control characters and spaces at the start, and it ignores case, so
/// `Java\tScript:` runs: the same reading is made here. Every URL attribute
/// of every element goes through this (`Link(href:)`, `Image.network`,
/// `Form(action:)`, raw elements), so a value that came from a user can not
/// be code. `// web:` Flutter has no URL attributes; a link to another app
/// (`sms:`, `whatsapp:`) is not code and stays.
bool runsCode(String name, String value) {
  if (!_urlAttributeNames.contains(name.toLowerCase())) return false;
  // Most values have no scheme (`/path`, `#id`) or a web one: answered
  // without copying the value. The tabs and newlines the browser drops are
  // control characters, so the first unit past them is the one below.
  var first = 0;
  while (first < value.length && value.codeUnitAt(first) <= 0x20) {
    first++;
  }
  if (first == value.length ||
      !_isAlpha(value.codeUnitAt(first)) ||
      !value.contains(':', first) ||
      value.startsWith('https://') ||
      value.startsWith('http://')) {
    return false;
  }
  final units = [
    for (final c in value.codeUnits)
      if (c != 0x09 && c != 0x0A && c != 0x0D) c,
  ];
  var i = 0;
  while (i < units.length && units[i] <= 0x20) {
    i++;
  }
  final start = i;
  // `[a-zA-Z][a-zA-Z0-9+.-]*:` is a scheme.
  if (i >= units.length || !_isAlpha(units[i])) return false;
  while (i < units.length &&
      (_isAlpha(units[i]) ||
          (units[i] >= 0x30 && units[i] <= 0x39) ||
          units[i] == 0x2B ||
          units[i] == 0x2D ||
          units[i] == 0x2E)) {
    i++;
  }
  if (i >= units.length || units[i] != 0x3A) return false;
  final scheme = String.fromCharCodes(units.sublist(start, i)).toLowerCase();
  if (scheme == 'javascript' || scheme == 'vbscript') return true;
  if (scheme != 'data') return false;
  // A `data:` URL is code when it is a document the browser runs: HTML, XML,
  // SVG or a script. Plain text, images, audio, video and fonts are not (and
  // `data:,` is the empty favicon apps use to skip the request).
  final rest = String.fromCharCodes(
    units.sublist(i + 1),
  ).toLowerCase().trimLeft();
  var end = 0;
  while (end < rest.length && rest[end] != ';' && rest[end] != ',') {
    end++;
  }
  final media = rest.substring(0, end).trim();
  // By family, not by list: every XML type a browser may render as a
  // document (`application/xhtml+xml`, `vnd.wap.xhtml+xml`, `mathml+xml`,
  // `svg+xml`, `text/xml`), HTML in any spelling, and every script type
  // (`javascript`, `ecmascript`, `jscript`, `vbscript`), XSLT included.
  return media.endsWith('+xml') ||
      media.endsWith('/xml') ||
      media.contains('html') ||
      media.contains('script') ||
      media.contains('xsl');
}

bool _isAlpha(int c) => (c >= 0x61 && c <= 0x7A) || (c >= 0x41 && c <= 0x5A);

const _voidElements = {
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

/// Elements whose whitespace between words matters (inline text blocks):
/// line breaks go only where there is whitespace already.
const _keepsWhitespace = {
  'p',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'label',
  'li',
};

/// Elements whose content is written untouched (no added whitespace): the
/// text of a `<textarea>`, `<option>`, `<title>`, `<script>` or `<style>` is
/// its value, so indentation would change it.
const _keepsFormatting = {
  'span',
  'pre',
  'textarea',
  'option',
  'title',
  'script',
  'style',
};

final _whitespace = RegExp(r'\s');

/// The classes of the page whose stylesheet rule sets `white-space` to a
/// value that keeps the text's own spaces and line breaks (`pre`,
/// `pre-wrap`, `pre-line`, `break-spaces`), while an indented page is being
/// written: the content of those elements is written as it is, as in
/// release.
Set<String> _preservingClasses = const {};

final _rule = RegExp(r'([^{}]+)\{([^{}]*)\}');
final _preservingDeclaration = RegExp(
  r'white-space\s*:\s*(?:pre|pre-wrap|pre-line|break-spaces)\s*(?:!important\s*)?(?:;|$)',
);
final _lastCompoundClasses = RegExp(r'\.((?:\\.|[\w-])+)');

/// The classes of the `<style>` elements in [root] that preserve whitespace.
/// Only the last compound selector of a rule counts (`.a .b` styles `.b`).
Set<String> _classesThatPreserveWhitespace(Node root) {
  final classes = <String>{};
  void visit(Node node) {
    switch (node) {
      case ElementNode(tag: 'style'):
        for (final child in node.children) {
          if (child is! TextNode) continue;
          for (final rule in _rule.allMatches(child.text)) {
            if (!_preservingDeclaration.hasMatch(rule[2]!)) continue;
            for (final selector in rule[1]!.split(',')) {
              final last = selector.trim().split(RegExp(r'[\s>+~]+')).last;
              for (final m in _lastCompoundClasses.allMatches(last)) {
                classes.add(m[1]!.replaceAll(r'\', ''));
              }
            }
          }
        }
      case ParentNode():
        node.children.forEach(visit);
      case TextNode():
        break;
    }
  }

  visit(root);
  return classes;
}

/// Whether the element keeps its content's whitespace: a class or an inline
/// style sets `white-space` to a preserving value.
bool _preservesWhitespace(ElementNode node) {
  final inline = node.styles?['white-space'];
  if (inline != null) {
    return _preservingDeclaration.hasMatch('white-space:$inline;');
  }
  if (_preservingClasses.isEmpty) return false;
  final classes = node.classes;
  if (classes == null) return false;
  for (final name in classes.split(' ')) {
    if (_preservingClasses.contains(name)) return true;
  }
  return false;
}

const _textEscape = HtmlEscape(HtmlEscapeMode.element);
const _attributeEscape = HtmlEscape(HtmlEscapeMode.attribute);

/// The indented (debug) writer: the same HTML with line breaks and
/// indentation where they change nothing for the browser.
abstract final class _Pretty {
  /// Lines longer than this are broken.
  static const maxLine = 100;

  /// [node] as HTML, and whether it starts and ends with whitespace.
  static ({String html, bool leading, bool trailing}) node(
    Node node,
    bool strictFormatting,
    bool strictWhitespace,
    String indent,
  ) {
    switch (node) {
      case ElementNode():
        final out = StringBuffer();
        final tag = _openTag(node, out);
        if (_voidElements.contains(tag)) {
          out.write('/>');
          return (html: out.toString(), leading: false, trailing: false);
        }
        out.write('>');
        var leading = false;
        var trailing = false;
        if (node.children.isNotEmpty) {
          final inner = children(
            node,
            strictWhitespace,
            strictFormatting ||
                _keepsFormatting.contains(tag) ||
                _preservesWhitespace(node),
            strictWhitespace || _keepsWhitespace.contains(tag),
            indent,
          );
          out.write(inner.html);
          leading = inner.leading;
          trailing = inner.trailing;
        }
        out.write('</$tag>');
        return (html: out.toString(), leading: leading, trailing: trailing);
      case TextNode(:final text, :final raw):
        if (text.isEmpty) return (html: '', leading: false, trailing: false);
        final html = raw ? text : _textEscape.convert(text);
        return (
          html: strictFormatting ? html : html.replaceAll('\n', '\n$indent'),
          leading: html.startsWith(_whitespace),
          trailing: html.substring(html.length - 1).startsWith(_whitespace),
        );
      case FragmentNode():
        return children(
          node,
          strictWhitespace,
          strictFormatting,
          strictWhitespace,
          indent,
        );
      case RootNode():
        throw StateError('The root is written by writePage.');
    }
  }

  /// The children of [parent], with line breaks where allowed:
  /// - none inside strict formatting (`<pre>`, `<span>`) or when all the
  ///   children fit on one line with no break of their own;
  /// - with strict whitespace (`<p>`), only where a child already starts
  ///   or ends with whitespace and the line is too long;
  /// - otherwise before every child and before the closing tag.
  /// A fragment adds no indentation and no break before its first child.
  static ({String html, bool leading, bool trailing}) children(
    ParentNode parent,
    bool strictWhitespace,
    bool childStrictFormatting,
    bool childStrictWhitespace,
    String indent,
  ) {
    if (parent.children.isEmpty) {
      return (html: '', leading: false, trailing: false);
    }
    final isFragment = parent is FragmentNode;
    final childIndent = isFragment ? indent : '$indent  ';

    // Text that is only a line break and indentation first: markup that
    // was already formatted, kept as it is.
    final first = parent.children.first;
    if (first is TextNode &&
        first.text.contains('\n') &&
        first.text.trim().isEmpty) {
      childStrictFormatting = true;
    }

    final written =
        <({String html, bool leading, bool trailing, bool breaks})>[];
    var length = 0;
    var anyBreak = false;
    for (final child in parent.children) {
      final r = node(
        child,
        childStrictFormatting,
        childStrictWhitespace,
        childIndent,
      );
      if (r.html.isEmpty) continue;
      final breaks = r.html.contains('\n');
      written.add((
        html: r.html,
        leading: r.leading,
        trailing: r.trailing,
        breaks: breaks,
      ));
      length += r.html.length;
      anyBreak |= breaks;
    }
    if (written.isEmpty) return (html: '', leading: false, trailing: false);

    final breaksAllowed =
        !childStrictFormatting && (length > maxLine || anyBreak);
    var breakNext = breaksAllowed && !strictWhitespace;
    var line = 0;
    var leading = false;
    final out = StringBuffer();
    for (var i = 0; i < written.length; i++) {
      final child = written[i];
      if (breaksAllowed) {
        breakNext |= child.leading && line > maxLine;
        breakNext &= i > 0 || !isFragment;
        if (breakNext) {
          out.write('\n$childIndent');
          line = 0;
        }
      }
      if (i == 0) leading = child.leading || breakNext;
      out.write(child.html);
      if (breaksAllowed) {
        line = child.breaks
            ? child.html.length - child.html.lastIndexOf('\n')
            : line + child.html.length;
        breakNext =
            !childStrictWhitespace || (child.trailing && line > maxLine);
      }
    }
    bool trailing;
    if (breaksAllowed && !isFragment && (breakNext || !strictWhitespace)) {
      out.write('\n$indent');
      trailing = true;
    } else {
      trailing = written.last.trailing;
    }
    return (html: out.toString(), leading: leading, trailing: trailing);
  }
}
