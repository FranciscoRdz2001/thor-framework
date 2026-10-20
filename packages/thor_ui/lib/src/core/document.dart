/// The page document: `<html>`, `<head>`, `<body>`, and the portal that
/// moves `<head>` content built anywhere in the page into the head.
library;

import 'package:thor_server/thor_server.dart' show Locale;

import 'framework.dart';
import 'markup.dart';

/// A whole page: `<html>`, its `<head>` and `<body>`, the entry of a static
/// app (`runApp(Document(...))`).
///
/// ```dart
/// runApp(const Document(
///   title: 'Counter',
///   lang: Locale('es'),
///   body: ThorApp(child: Counter()),
/// ));
/// ```
///
/// `title` is the `<title>`, `lang` the `<html lang>` (its BCP 47 tag,
/// `Locale('pt', 'BR')` → `pt-BR`, like the router's), `dir` its text
/// direction (`rtl`; a localized `ThorApp` sets both), `base` the
/// `<base href>` relative URLs resolve against (`/` by default, null for
/// none), `charset` and `viewport` their `<meta>` (null: none), `meta` other
/// `<meta name content>` tags and `head` extra elements (links, preloads,
/// scripts). The app's stylesheet goes to `initializeThor(styles:)`; the
/// stylesheet thor generates for the widgets is added on its own.
abstract interface class Document implements Widget {
  const factory Document({
    Key? key,
    String? title,
    Locale? lang,
    String? dir,
    String? base,
    String? charset,
    String? viewport,
    Map<String, String> meta,
    List<Widget> head,
    required Widget body,
  }) = _PageDocument;

  /// Elements for the `<head>` from anywhere in the page (a stylesheet a
  /// widget needs, the page title). See [HeadPortal] for which one wins
  /// when two say the same.
  const factory Document.head({
    Key? key,
    String? title,
    Map<String, String>? meta,
    List<Widget>? children,
  }) = HeadPortal;
}

final class _PageDocument extends StatelessWidget implements Document {
  const _PageDocument({
    super.key,
    this.title,
    this.lang,
    this.dir,
    this.base = '/',
    this.charset = 'utf-8',
    this.viewport = 'width=device-width, initial-scale=1.0',
    this.meta = const {},
    this.head = const [],
    required this.body,
  });

  final String? title;
  final Locale? lang;
  final String? dir;
  final String? base;
  final String? charset;
  final String? viewport;
  final Map<String, String> meta;
  final List<Widget> head;
  final Widget body;

  /// [base] with a leading and a trailing `/`.
  String? get _base {
    var base = this.base;
    if (base == null) return null;
    if (!base.startsWith('/')) base = '/$base';
    if (!base.endsWith('/')) base = '$base/';
    return base;
  }

  @override
  Widget build(BuildContext context) => Widget.element(
    tag: 'html',
    attributes: {'lang': ?lang?.toLanguageTag(), 'dir': ?dir},
    children: [
      Widget.element(
        tag: 'head',
        children: [
          if (_base case final base?)
            Widget.element(tag: 'base', attributes: {'href': base}),
          if (charset case final charset?)
            Widget.element(tag: 'meta', attributes: {'charset': charset}),
          HeadPortal(title: title, meta: {'viewport': ?viewport, ...meta}),
          ...head,
        ],
      ),
      Widget.element(tag: 'body', children: [body]),
    ],
  );
}

/// Content for the page's `<head>`, built where it is and moved to the end
/// of the head ([leading]: to its start).
///
/// Two elements with the same `id`, two `<title>`s, two `<base>`s or two
/// `<meta>` with the same `name` are one: the later one replaces the first
/// (in the first one's place) unless it is shallower in the tree.
class HeadPortal extends PageComponent implements Document {
  /// Content for the head: a [title], [meta] by name and [children].
  const HeadPortal({
    super.key,
    this.title,
    this.meta,
    this.children,
    this.leading = false,
  });

  /// Whether the content goes to the start of the head, right after its
  /// `<base>` and `<meta charset>`, before the document's own head elements
  /// (an inline script that must run before any stylesheet: one after an
  /// external stylesheet waits for it, and holds the parser that long).
  final bool leading;

  /// The page title (`<title>`).
  final String? title;

  /// `<meta name content>` entries.
  final Map<String, String>? meta;

  /// More elements for the head.
  final List<Widget>? children;

  @override
  void buildInto(
    PageBuild page,
    Element element,
    ParentNode into,
    BuildChild build,
  ) {
    build(
      Widget.fragment([
        if (title case final title?)
          Widget.element(tag: 'title', children: [Widget.text(title)]),
        if (meta case final meta?)
          for (final MapEntry(:key, :value) in meta.entries)
            Widget.element(
              tag: 'meta',
              attributes: {'name': key, 'content': value},
            ),
        ...?children,
      ]),
      element,
      into,
    );
    page.headPortals.add((
      node: into.last as FragmentNode,
      parent: into,
      depth: element.depth,
      leading: leading,
    ));
  }
}

/// Attributes of the page's `<html>` set from inside it (a localized
/// `ThorApp` sets `lang` and `dir`): they replace the document's own. The
/// last one built wins. Builds nothing where it is.
class DocumentAttributes extends PageComponent {
  /// [attributes] for `<html>`.
  const DocumentAttributes({super.key, required this.attributes});

  /// Name → value.
  final Map<String, String> attributes;

  @override
  void buildInto(
    PageBuild page,
    Element element,
    ParentNode into,
    BuildChild build,
  ) {
    page.htmlAttributes.addAll(attributes);
  }
}

/// Sets the [DocumentAttributes] of [page] on the `<html>` of [root].
void applyHtmlAttributes(PageBuild page, RootNode root) {
  if (page.htmlAttributes.isEmpty) return;
  final html = documentStructure(root).html;
  html.attributes = {...?html.attributes, ...page.htmlAttributes};
}

/// The `<html>`, `<head>` and `<body>` of [root], created where missing:
/// what is outside them goes into the body.
({ElementNode html, ElementNode head, ElementNode body}) documentStructure(
  RootNode root,
) {
  var html = findElement(root, (e) => e.tag == 'html')?.node;
  if (html == null) {
    html = ElementNode('html')..children.addAll(root.children);
    root.children
      ..clear()
      ..add(html);
  }
  final found = html;
  var head = findElement(found, (e) => e.tag == 'head')?.node;
  var body = findElement(found, (e) => e.tag == 'body')?.node;
  if (head == null) {
    head = ElementNode('head');
    if (body == null) {
      body = ElementNode('body')..children.addAll(found.children);
      found.children
        ..clear()
        ..addAll([head, body]);
    } else {
      found.children.insert(0, head);
    }
  } else if (body == null) {
    // Around the head: what was before it and after it, in that order.
    final at = found.children.indexOf(head);
    body = ElementNode('body')
      ..children.addAll([
        ...found.children.sublist(0, at),
        ...found.children.sublist(at + 1),
      ]);
    found.children
      ..clear()
      ..addAll([head, body]);
  }
  return (html: found, head: head, body: body);
}

/// Moves the [HeadPortal]s' content into the head, one of each key.
void applyHeadPortals(PageBuild page, RootNode root) {
  if (page.headPortals.isEmpty) return;
  final head = documentStructure(root).head;

  String? keyOf(Node node) => switch (node) {
    ElementNode(:final id?) when id.isNotEmpty => id,
    ElementNode(tag: 'title' || 'base') => '__${node.tag}',
    ElementNode(tag: 'meta', attributes: {'name': final String name}) =>
      '__meta:$name',
    _ => null,
  };

  final leading = <Node>[];
  final nodes = <Node>[];
  final seen = <String, ({List<Node> list, int index, int depth})>{};
  void visit(Node node, int depth, List<Node> into) {
    if (node is FragmentNode) {
      for (final child in node.children) {
        visit(child, depth, into);
      }
      return;
    }
    final key = keyOf(node);
    if (key == null) {
      into.add(node);
      return;
    }
    final first = seen[key];
    if (first == null) {
      into.add(node);
      seen[key] = (list: into, index: into.length - 1, depth: depth);
    } else if (depth >= first.depth) {
      first.list[first.index] = node;
    }
  }

  for (final portal in page.headPortals) {
    portal.parent.children.remove(portal.node);
    visit(portal.node, portal.depth, portal.leading ? leading : nodes);
  }
  if (leading.isNotEmpty) {
    // After the `<base>` and `<meta charset>` the document starts with (the
    // charset within the first bytes, the base before any URL).
    var at = 0;
    while (at < head.children.length &&
        switch (head.children[at]) {
          ElementNode(tag: 'base') => true,
          ElementNode(tag: 'meta', attributes: final a?) => a.containsKey(
            'charset',
          ),
          _ => false,
        }) {
      at++;
    }
    head.children.insertAll(at, leading);
  }
  head.children.addAll(nodes);
}
