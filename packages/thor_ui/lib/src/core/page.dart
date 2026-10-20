/// A page from a component: build, `<head>` portals, the app stylesheet,
/// the document around it, and the HTML.
library;

import 'dart:async';
import 'dart:typed_data';

import '../foundation/css_rules.dart' show StyleRule;
import '../foundation/foundation.dart' show kDebugMode;
import 'document.dart';
import 'framework.dart';
import 'markup.dart';

/// The HTML of [root]. A [standalone] fragment gets no document around it
/// (no `<!DOCTYPE>`, `<html>`, `<head>` or `<body>` unless it builds
/// them). [styles] go at the end of the `<head>`; [compact] writes no
/// formatting whitespace.
///
/// A component that fails to build fails the page: its error propagates
/// (the route shows its error page), never a partial page or an error
/// message in the HTML.
String writeComponent(
  Widget root, {
  bool standalone = false,
  List<StyleRule> styles = const [],
  required bool compact,
}) => _page(
  root,
  standalone: standalone,
  styles: styles,
  compact: compact,
  write: (tree) => writePage(tree, compact: compact),
);

/// [writeComponent], compact, as UTF-8: the same bytes, written straight
/// from the tree (what a server sends).
Uint8List writeComponentUtf8(
  Widget root, {
  bool standalone = false,
  List<StyleRule> styles = const [],
}) => _page(
  root,
  standalone: standalone,
  styles: styles,
  compact: true,
  write: writePageUtf8,
);

T _page<T>(
  Widget root, {
  required bool standalone,
  required List<StyleRule> styles,
  required bool compact,
  required T Function(RootNode tree) write,
}) {
  final page = PageBuild();
  try {
    final tree = RootNode();
    page.buildRoot(root, tree);
    applyHeadPortals(page, tree);
    if (!standalone) applyHtmlAttributes(page, tree);
    if (styles.isNotEmpty) _addStylesheet(tree, styles, compact: compact);
    if (!standalone) {
      documentStructure(tree);
      if (!_hasDoctype(tree)) {
        tree.children.insert(0, TextNode('<!DOCTYPE html>', raw: true));
      }
    }
    final token = Zone.current[nonceTokenZoneKey] as String?;
    return stampingNonce(token, () => write(tree));
  } finally {
    page.dispose();
  }
}

/// The app stylesheet in a `<style>` at the end of the `<head>` (a head is
/// created at the start of the page if there is none).
void _addStylesheet(
  RootNode root,
  List<StyleRule> rules, {
  required bool compact,
}) {
  final ParentNode html =
      findElement(root, (e) => e.tag == 'html')?.node ?? root;
  var head = findElement(html, (e) => e.tag == 'head')?.node;
  if (head == null) {
    head = ElementNode('head');
    html.children.insert(0, head);
  }
  final css = [
    for (final rule in rules) rule.toCss() + (kDebugMode ? '\n' : ' '),
  ].join().trimRight();
  head.add(
    ElementNode('style')
      ..add(TextNode(compact ? minifyCss(css) : css, raw: true)),
  );
}

bool _hasDoctype(ParentNode parent) {
  for (final child in parent.children) {
    if (child is TextNode && child.raw && child.text.startsWith('<!DOCTYPE')) {
      return true;
    }
    if (child is FragmentNode && _hasDoctype(child)) return true;
  }
  return false;
}

/// [css] without formatting whitespace: line breaks, indentation and the
/// spaces around `{ } ; , >` and after `:`. Quoted strings are kept as
/// they are, and a space before `:` stays (`.a :hover` is a descendant).
String minifyCss(String css) {
  final out = StringBuffer();
  String? quote;
  var previous = '';
  var space = false;
  const tight = '{};,>';
  for (var i = 0; i < css.length; i++) {
    final c = css[i];
    if (quote != null) {
      out.write(c);
      if (c == r'\' && i + 1 < css.length) {
        out.write(css[++i]);
      } else if (c == quote) {
        quote = null;
      }
      previous = c;
      continue;
    }
    if (c == ' ' || c == '\n' || c == '\t' || c == '\r') {
      space = true;
      continue;
    }
    if (space &&
        previous.isNotEmpty &&
        !tight.contains(previous) &&
        previous != ':' &&
        !tight.contains(c)) {
      out.write(' ');
    }
    space = false;
    if (c == '"' || c == "'") quote = c;
    out.write(c);
    previous = c;
  }
  return out.toString();
}
