/// Allowlist HTML sanitizer for untrusted markup (server side).
///
/// A library of its own, like `optimize.dart`: the browser entry
/// (`thor_engine.dart`, `client.dart`) never imports it, so `package:html`
/// stays out of the client. `thor_ui` re-exports it and builds `HtmlWidget`
/// on it; `thor_ui` itself cannot depend on `html` (`facade_test`).
library;

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

/// What [sanitizeHtml] lets through.
///
/// An allowlist, like DOMPurify's `ALLOWED_TAGS`/`ALLOWED_ATTR`, Rails'
/// `sanitize` and bluemonday's policies: what is not named is removed. The
/// defaults fit a product description or a CMS body (text, lists, links,
/// images, tables). Some things are never allowed whatever the lists say:
/// `<script>`, `<style>`, frames, `<svg>`/`<math>`, `on*` handlers, `style`
/// and `srcdoc` attributes, `id` and `name` (DOM clobbering), and URL
/// schemes other than [schemes]. When `class` is allowed, its tokens are
/// prefixed with `user-` so the content cannot reach the page's own
/// (generated) classes.
class HtmlPolicy {
  /// Creates a policy; every value has a safe default.
  const HtmlPolicy({
    this.tags = defaultTags,
    this.attributes = defaultAttributes,
    this.schemes = defaultSchemes,
    this.allowDataImages = false,
    this.linkTarget,
    this.nofollow = false,
    this.eagerImages = 0,
    this.maxLength = 1 << 20,
    this.maxDepth = 128,
    this.maxTags = 10000,
  }) : assert(
         linkTarget == null ||
             linkTarget == '_blank' ||
             linkTarget == '_self' ||
             linkTarget == '_parent' ||
             linkTarget == '_top',
         'linkTarget is a browsing context keyword: _blank, _self, _parent or _top',
       ),
       assert(eagerImages >= 0, 'eagerImages counts images: 0 or more');

  /// Tags kept. The rest is unwrapped (its text stays); the ones that run
  /// code or hide it (`script`, `style`, `iframe`, `svg`, `math`,
  /// `template`, `noscript`…) are dropped with everything inside.
  final Set<String> tags;

  /// Attributes kept, per tag; the `'*'` key applies to every tag. URL
  /// attributes (`href`, `src`…) are always checked against [schemes].
  final Map<String, Set<String>> attributes;

  /// URL schemes `href` and `src` accept. Relative URLs always pass.
  final Set<String> schemes;

  /// Whether `<img src="data:image/png;base64,…">` is kept (png, jpeg, gif,
  /// webp and avif only; never svg).
  final bool allowDataImages;

  /// The `target` of every link (`'_blank'` also adds
  /// `rel="noopener noreferrer"`); `null` leaves links in the same tab.
  /// The author's own `target` and `rel` are always removed.
  final String? linkTarget;

  /// Adds `nofollow` to every link's `rel` (user-written content).
  final bool nofollow;

  /// How many of the first images load right away; the rest get
  /// `loading="lazy"` and `decoding="async"`. An image at the top of the
  /// content (a post's cover) is often the page's largest paint, and lazy
  /// loading holds it back until layout; `1` loads it with the page.
  final int eagerImages;

  /// Input longer than this many UTF-16 units is cut (before parsing).
  final int maxLength;

  /// Elements nested deeper than this are dropped.
  final int maxDepth;

  /// The input is cut before its `maxTags + 1`-th `<`. The HTML5 tree
  /// builder is not linear on deep nesting (20 000 nested `<div>` take 15
  /// seconds in `package:html`), so a hostile body would be a denial of
  /// service; this bounds the parser's work before it starts.
  final int maxTags;

  /// The same policy with some values changed.
  HtmlPolicy copyWith({
    Set<String>? tags,
    Map<String, Set<String>>? attributes,
    Set<String>? schemes,
    bool? allowDataImages,
    String? linkTarget,
    bool? nofollow,
    int? eagerImages,
    int? maxLength,
    int? maxDepth,
    int? maxTags,
  }) => HtmlPolicy(
    tags: tags ?? this.tags,
    attributes: attributes ?? this.attributes,
    schemes: schemes ?? this.schemes,
    allowDataImages: allowDataImages ?? this.allowDataImages,
    linkTarget: linkTarget ?? this.linkTarget,
    nofollow: nofollow ?? this.nofollow,
    eagerImages: eagerImages ?? this.eagerImages,
    maxLength: maxLength ?? this.maxLength,
    maxDepth: maxDepth ?? this.maxDepth,
    maxTags: maxTags ?? this.maxTags,
  );

  /// Text, lists, links, images and tables. No `h1` (the page has its own:
  /// an `<h1>` in the content becomes an `<h2>`).
  static const defaultTags = {
    'p', 'br', 'hr', 'div', 'span', //
    'h2', 'h3', 'h4', 'h5', 'h6',
    'strong', 'em', 'b', 'i', 'u', 's', 'del', 'ins', 'mark', 'small', 'sub',
    'sup', 'abbr',
    'code', 'pre', 'blockquote',
    'ul', 'ol', 'li', 'dl', 'dt', 'dd',
    'a', 'img', 'figure', 'figcaption',
    'table', 'caption', 'colgroup', 'col', 'thead', 'tbody', 'tfoot', 'tr',
    'th', 'td',
  };

  /// `title`, `lang` and `dir` anywhere; `href`, `src`, `alt` and the table
  /// and list counters where they mean something.
  static const defaultAttributes = <String, Set<String>>{
    '*': {'title', 'lang', 'dir'},
    'a': {'href'},
    'img': {'src', 'alt'},
    'th': {'colspan', 'rowspan'},
    'td': {'colspan', 'rowspan'},
    'col': {'span'},
    'ol': {'start'},
  };

  /// `http`, `https`, `mailto` and `tel`.
  static const defaultSchemes = {'http', 'https', 'mailto', 'tel'};
}

/// [source] as HTML that is safe to put in a page: parsed with the HTML5
/// algorithm (the browser's own, so what is checked is what the browser
/// will build), walked against [policy], and written back by this function
/// (not by the parser), so the output never depends on how a browser
/// re-parses it.
///
/// Comments, doctypes and processing instructions are removed; entities are
/// decoded and written again (`&`, `<`, `>`, `"` and the no-break space
/// escaped); every URL is cleaned the way a browser reads it (tabs and
/// newlines removed, control characters refused) before its scheme is
/// checked.
String sanitizeHtml(String source, {HtmlPolicy policy = const HtmlPolicy()}) {
  var input = source;
  if (input.length > policy.maxLength) {
    var end = policy.maxLength;
    // Never cut a surrogate pair in half.
    if (end > 0 && _isHighSurrogate(input.codeUnitAt(end - 1))) end--;
    input = input.substring(0, end);
  }
  var tags = 0;
  for (var i = input.indexOf('<'); i != -1; i = input.indexOf('<', i + 1)) {
    if (++tags > policy.maxTags) {
      input = input.substring(0, i);
      break;
    }
  }
  // Dropping or renaming elements can leave a tree the parser would not
  // build from its own output (`<h2><details><h1>` becomes an `<h2>` inside
  // an `<h2>`, which a browser re-parses into siblings). Writing again from
  // the output until it stops changing makes the markup a fixed point: the
  // tree that was checked is the tree a browser builds.
  var out = _once(input, policy);
  for (var pass = 0; pass < 8; pass++) {
    final next = _once(out, policy);
    if (next == out) return out;
    out = next;
  }
  // Does not settle (not seen so far): refuse rather than guess.
  return '';
}

String _once(String input, HtmlPolicy policy) {
  final out = StringBuffer();
  _Writer(policy, out).children(html.parseFragment(input), 0);
  return out.toString();
}

bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;

/// Removed with everything inside: they run code, or their content is not
/// parsed as markup by a browser with scripting on, so keeping it as text
/// could turn into markup when the output is parsed again (mutation XSS).
const _dropWithContent = {
  'script',
  'style',
  'iframe',
  'frame',
  'frameset',
  'object',
  'embed',
  'applet',
  'template',
  'noscript',
  'noembed',
  'noframes',
  'xmp',
  'plaintext',
  'textarea',
  'title',
  'head',
  'svg',
  'math',
  'base',
  'link',
  'meta',
  'portal',
  'fencedframe',
  'slot',
  'select',
  'option',
  'optgroup',
  'datalist',
  'audio',
  'video',
  'source',
  'track',
  'canvas',
  'map',
  'area',
  'input',
  'button',
  'dialog',
};

const _voidTags = {'br', 'hr', 'img', 'col'};

const _htmlNamespace = 'http://www.w3.org/1999/xhtml';

/// Attributes that hold a URL.
const _urlAttributes = {'href', 'src', 'cite', 'poster', 'action', 'data'};

/// Attributes whose value is a small number.
const _numeric = {'colspan', 'rowspan', 'span', 'start', 'width', 'height'};

final _controls = RegExp(r'[\u0000-\u001f\u007f]');
final _tabsAndNewlines = RegExp(r'[\t\n\r]');
final _scheme = RegExp(r'^([^:/?#]*):');
final _schemeName = RegExp(r'^[a-z][a-z0-9+.-]*$');
final _dataImage = RegExp(
  r'^data:image/(?:png|jpe?g|gif|webp|avif);base64,[A-Za-z0-9+/]+={0,2}$',
  caseSensitive: false,
);
final _lang = RegExp(r'^[A-Za-z0-9-]{1,35}$');
final _classToken = RegExp(r'^[A-Za-z0-9_-]+$');

class _Writer {
  _Writer(this.policy, this.out);

  final HtmlPolicy policy;
  final StringBuffer out;
  bool _afterPre = false;

  /// The images written so far (for [HtmlPolicy.eagerImages]).
  int _images = 0;

  void children(Node parent, int depth) {
    for (final node in parent.nodes) {
      switch (node) {
        case Text():
          final text = node.data.replaceAll('\u0000', '');
          if (text.isEmpty) break;
          // The parser drops one newline right after `<pre>`; when the
          // text itself starts with one, write it twice so a second parse
          // (the browser's) builds the same text.
          if (_afterPre && text.startsWith('\n')) out.write('\n');
          _afterPre = false;
          out.write(_escape(text, false));
        case Element():
          element(node, depth);
        default:
          // Comments, doctypes, processing instructions, CDATA.
          break;
      }
    }
  }

  void element(Element el, int depth) {
    if (depth >= policy.maxDepth) return;
    // Foreign elements (svg, math) are dropped by namespace, not only by
    // name: their parsing rules differ from HTML's.
    if (el.namespaceUri != _htmlNamespace) return;
    var tag = el.localName!;
    if (_dropWithContent.contains(tag)) return;
    // web: the page owns the `<h1>`; one in the content is an `<h2>`.
    if (tag == 'h1' && !policy.tags.contains('h1')) tag = 'h2';
    if (!policy.tags.contains(tag)) {
      children(el, depth + 1);
      return;
    }
    final attrs = _attributes(el, tag);
    if (attrs == null) {
      // An element that is useless without its attribute (a link without
      // `href`, an image without `src`): its content stays.
      if (tag == 'img') return;
      children(el, depth + 1);
      return;
    }
    _afterPre = false;
    out
      ..write('<')
      ..write(tag);
    for (final MapEntry(:key, :value) in attrs.entries) {
      out
        ..write(' ')
        ..write(key)
        ..write('="')
        ..write(_escape(value, true))
        ..write('"');
    }
    out.write('>');
    if (_voidTags.contains(tag)) return;
    _afterPre = tag == 'pre';
    children(el, depth + 1);
    _afterPre = false;
    out
      ..write('</')
      ..write(tag)
      ..write('>');
  }

  /// The attributes to write, or null when the element is dropped for lack
  /// of its URL.
  Map<String, String>? _attributes(Element el, String tag) {
    final allowed = <String>{
      ...?policy.attributes['*'],
      ...?policy.attributes[tag],
    };
    final kept = <String, String>{};
    for (final MapEntry(:key, :value) in el.attributes.entries) {
      final name = key.toString();
      if (!allowed.contains(name) || _neverAttribute(name)) continue;
      final clean = _value(name, value, tag);
      if (clean != null) kept[name] = clean;
    }
    if (tag == 'a') {
      if (!kept.containsKey('href')) return null;
      final target = policy.linkTarget;
      if (target != null) kept['target'] = target;
      final rel = [
        if (target == '_blank') ...['noopener', 'noreferrer'],
        if (policy.nofollow) 'nofollow',
      ];
      if (rel.isNotEmpty) kept['rel'] = rel.join(' ');
    } else if (tag == 'img') {
      if (!kept.containsKey('src')) return null;
      if (_images++ >= policy.eagerImages) {
        kept['loading'] = 'lazy';
        kept['decoding'] = 'async';
      }
    }
    return kept;
  }

  String? _value(String name, String value, String tag) {
    if (_urlAttributes.contains(name)) {
      return _url(value, image: tag == 'img' && name == 'src');
    }
    if (_numeric.contains(name)) {
      return RegExp(r'^\d{1,4}$').hasMatch(value.trim()) ? value.trim() : null;
    }
    switch (name) {
      case 'lang':
        return _lang.hasMatch(value) ? value : null;
      case 'dir':
        final v = value.toLowerCase();
        return const {'ltr', 'rtl', 'auto'}.contains(v) ? v : null;
      case 'class':
        final tokens = value
            .split(RegExp(r'\s+'))
            .where(_classToken.hasMatch)
            .toList();
        // The page's own classes (Thor's generated ones, a theme's) must
        // stay out of reach of the content: every token carries `user-`.
        final prefixed = [
          for (final t in tokens) t.startsWith('user-') ? t : 'user-$t',
        ];
        return prefixed.isEmpty ? null : prefixed.join(' ');
    }
    return value.replaceAll('\u0000', '');
  }

  /// The URL as a browser reads it, if its scheme is allowed.
  String? _url(String raw, {required bool image}) {
    // The URL parser removes tabs and newlines anywhere and trims C0
    // controls and spaces at both ends; the rest of the controls make the
    // value suspect. The cleaned value is what is written, so the check and
    // the browser see the same string.
    final s = raw
        .replaceAll(_tabsAndNewlines, '')
        .replaceAll(RegExp(r'^[\u0000- ]+|[\u0000- ]+$'), '');
    if (s.isEmpty || _controls.hasMatch(s)) return null;
    final m = _scheme.firstMatch(s);
    if (m == null) return s; // relative: no scheme before the first / ? #
    final scheme = m[1]!;
    if (!_schemeName.hasMatch(scheme.toLowerCase())) return null;
    if (policy.schemes.contains(scheme.toLowerCase())) return s;
    if (image && policy.allowDataImages && _dataImage.hasMatch(s)) return s;
    return null;
  }
}

bool _neverAttribute(String name) =>
    name.startsWith('on') ||
    name == 'style' ||
    name == 'srcdoc' ||
    name == 'srcset' ||
    name == 'xmlns' ||
    // DOM clobbering: `<a id=cookie>` shadows `document.cookie` and named
    // access (`window.x`); the page owns every id and name.
    name == 'id' ||
    name == 'name' ||
    name == 'target' ||
    name == 'rel' ||
    name == 'formaction' ||
    name == 'ping' ||
    name.contains(':');

String _escape(String s, bool attribute) {
  final b = StringBuffer();
  for (final c in s.runes) {
    switch (c) {
      case 0x26:
        b.write('&amp;');
      case 0x3C:
        b.write('&lt;');
      case 0x3E:
        b.write('&gt;');
      case 0xA0:
        b.write('&nbsp;');
      case 0x22 when attribute:
        b.write('&quot;');
      default:
        b.writeCharCode(c);
    }
  }
  return b.toString();
}
