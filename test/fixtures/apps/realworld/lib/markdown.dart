/// Article bodies: markdown to HTML, then an allowlist sanitizer (the body is
/// user input; raw HTML in markdown must not run).
library;

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:markdown/markdown.dart' as md;

const _allowed = {
  'p',
  'br',
  'hr',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'strong',
  'em',
  'b',
  'i',
  'del',
  'code',
  'pre', //
  'blockquote',
  'ul',
  'ol',
  'li',
  'a',
  'img',
  'table',
  'thead',
  'tbody',
  'tr',
  'th',
  'td',
};

const _attributes = {
  'a': {'href', 'title'},
  'img': {'src', 'alt', 'title'},
  'th': {'align'},
  'td': {'align'},
  'code': {'class'},
};

/// [source] (markdown) as safe HTML.
String renderMarkdown(String source) {
  final dirty = md.markdownToHtml(
    source,
    extensionSet: md.ExtensionSet.gitHubFlavored,
  );
  final fragment = html.parseFragment(dirty);
  _clean(fragment);
  return fragment.outerHtml;
}

void _clean(Node node) {
  for (final child in [...node.nodes]) {
    if (child is Element) {
      final tag = child.localName!;
      if (!_allowed.contains(tag)) {
        // Unknown or dangerous (script, style, iframe…): dropped; harmless
        // wrappers keep their text.
        if (const {
          'script',
          'style',
          'iframe',
          'object',
          'embed',
          'template',
          'svg',
          'math',
        }.contains(tag)) {
          child.remove();
        } else {
          _clean(child);
          child.replaceWith(Text(child.text));
        }
        continue;
      }
      final keep = _attributes[tag] ?? const {};
      child.attributes.removeWhere(
        (k, v) =>
            !keep.contains(k) ||
            (k is String && (k == 'href' || k == 'src') && !_safeUrl(v)),
      );
      if (tag == 'code' &&
          !(child.attributes['class']?.startsWith('language-') ?? true)) {
        child.attributes.remove('class');
      }
      if (tag == 'a') child.attributes['rel'] = 'nofollow noopener noreferrer';
      // A code block scrolls sideways: reachable with the keyboard (axe
      // scrollable-region-focusable).
      if (tag == 'pre') child.attributes['tabindex'] = '0';
      // Like `marked`: a code block ends with one line break, not two.
      if (tag == 'code' &&
          child.parent?.localName == 'pre' &&
          child.nodes.length == 1 &&
          child.nodes.first is Text) {
        final t = child.text;
        if (t.endsWith('\n\n')) {
          child.text = t.replaceFirst(RegExp(r'\n+$'), '\n');
        }
      }
      _clean(child);
    } else if (child is Comment) {
      child.remove();
    }
  }
}

bool _safeUrl(String url) {
  final u = url.trim().toLowerCase();
  return u.startsWith('http://') ||
      u.startsWith('https://') ||
      u.startsWith('/') ||
      u.startsWith('#') ||
      u.startsWith('mailto:');
}
