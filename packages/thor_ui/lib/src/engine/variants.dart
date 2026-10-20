/// The states of a `Watch` as the page ships them: the live one as
/// markup, every other one as a patch of the live element (`data-tp-<n>`)
/// when it only differs in attributes and texts, or as a full
/// `<template>` when its structure differs.
///
/// Done while the page is built, on the markup nodes (never by parsing
/// HTML), so server-rendered pages get the same compact output as a
/// static build.
library;

import 'package:thor_engine/thor_engine.dart';

import '../core/core.dart';
import '../core/framework.dart' show BuildChild, PageBuild, PageComponent;
import '../core/markup.dart';
import '../foundation/style_registry.dart' show ThorStyleRegistry;

/// The live state [live] (its element carries `data-tv="[id]"`) and the
/// [others], by state index.
final class VariantStates extends PageComponent {
  /// States of the binding [id].
  const VariantStates({
    super.key,
    required this.id,
    required this.live,
    required this.others,
  });

  /// The binding id (`data-tv`).
  final String id;

  /// The current state, marked with `data-tv`.
  final Widget live;

  /// Every other state, by index.
  final Map<int, Widget> others;

  @override
  void buildInto(
    PageBuild page,
    Element element,
    ParentNode into,
    BuildChild build,
  ) {
    final liveNode = FragmentNode();
    final states = <int, FragmentNode>{
      for (final index in others.keys) index: FragmentNode(),
    };
    // The states are alternatives: a `Hero` tag may repeat among them.
    final registry = ThorStyleRegistry.active(element);
    final builds = [
      () => build(live, element, liveNode),
      for (final MapEntry(key: index, value: widget) in others.entries)
        () => build(widget, element, states[index]!),
    ];
    if (registry == null) {
      for (final b in builds) {
        b();
      }
    } else {
      registry.claimAlternatives(builds);
    }
    into.add(liveNode);
    final liveNodes = _flat(liveNode);
    final at = liveNodes.indexWhere(
      (n) => n is ElementNode && n.attributes?[variantAttr] == id,
    );
    final root = at < 0 ? null : liveNodes[at] as ElementNode;
    // An `AnimatedSwitcher` around the states: the page ships its timing.
    if (root?.attributes?[switcherAttr] case final timing?) {
      registry?.addSwitcher(timing);
    }
    final patches = <String, String>{};
    for (final MapEntry(key: index, value: _) in others.entries) {
      final built = states[index]!;
      final ops = <PatchOp>[];
      if (root != null && _diffStates(liveNodes, at, _flat(built), ops)) {
        patches['$patchAttr-$index'] = encodePatch(ops);
      } else {
        into.add(
          ElementNode(
            'template',
            attributes: {variantTemplateAttr: id, variantIndexAttr: '$index'},
          )..children.addAll(built.children),
        );
      }
    }
    // A fresh map: a node's attributes may be a widget's constant.
    if (patches.isNotEmpty) {
      root!.attributes = {...?root.attributes, ...patches};
    }
  }
}

/// The states of a `row.watch` in a list's row template: [live] (its
/// element carries `data-tvf="[id]"`) and every other state as a patch of
/// that element (`data-tp-<n>`) when it only differs in attributes and
/// texts — the engine builds that state's source from the template's
/// element and the patch — or, when its structure differs, as the
/// `<template data-tvft>` in [templates].
final class RowVariantStates extends PageComponent {
  /// States of the row binding [id].
  const RowVariantStates({
    super.key,
    required this.id,
    required this.live,
    required this.patchable,
    required this.templates,
  });

  /// The row binding id (`data-tvf`).
  final String id;

  /// The template's state (index 0), marked with `data-tvf`.
  final Widget live;

  /// Every other state, marked like [live] so only the look differs.
  final Map<int, Widget> patchable;

  /// Every other state as its `<template data-tvft>`, for a state a patch
  /// can't say.
  final Map<int, Widget> templates;

  @override
  void buildInto(
    PageBuild page,
    Element element,
    ParentNode into,
    BuildChild build,
  ) {
    final liveNode = FragmentNode();
    build(live, element, liveNode);
    into.add(liveNode);
    final liveNodes = _flat(liveNode);
    final at = liveNodes.indexWhere(
      (n) => n is ElementNode && n.attributes?[rowVariantAttr] == id,
    );
    final root = at < 0 ? null : liveNodes[at] as ElementNode;
    final patches = <String, String>{};
    for (final MapEntry(key: index, value: widget) in patchable.entries) {
      final built = FragmentNode();
      build(widget, element, built);
      final ops = <PatchOp>[];
      if (root != null && _diffStates(liveNodes, at, _flat(built), ops)) {
        patches['$patchAttr-$index'] = encodePatch(ops);
      } else if (templates[index] case final template?) {
        build(template, element, into);
      }
    }
    // A fresh map: a node's attributes may be a widget's constant.
    if (patches.isNotEmpty) {
      root!.attributes = {...?root.attributes, ...patches};
    }
  }
}

/// Whether a state built as [variant] is the live state ([live], whose
/// element is at [at]) with other attributes and texts, and [ops] say how.
/// What is built next to the element (a scoped `<style>` without a
/// `ThorApp`) must be the same.
bool _diffStates(
  List<Node> live,
  int at,
  List<Node> variant,
  List<PatchOp> ops,
) {
  if (variant.length != live.length) return false;
  for (var i = 0; i < live.length; i++) {
    if (i != at && !_same(live[i], variant[i])) return false;
  }
  final v = variant[at];
  return v is ElementNode &&
      _diff(live[at] as ElementNode, v, const [], ops, isRoot: true);
}

/// The children of [parent] as the browser sees them: fragments
/// flattened, empty texts dropped (they are not written).
List<Node> _flat(ParentNode parent, [List<Node>? out]) {
  final nodes = out ?? <Node>[];
  for (final child in parent.children) {
    switch (child) {
      case FragmentNode():
        _flat(child, nodes);
      case TextNode(:final text) when text.isEmpty:
        break;
      default:
        nodes.add(child);
    }
  }
  return nodes;
}

/// Every attribute of [node] as written (`id`, `class`, `style`, the rest).
Map<String, String> _attributes(ElementNode node) => {
  'id': ?node.id,
  if (node.classes case final classes? when classes.isNotEmpty)
    'class': classes,
  if (node.styles case final styles? when styles.isNotEmpty)
    'style': [
      for (final MapEntry(:key, :value) in styles.entries) '$key: $value',
    ].join('; '),
  ...?node.attributes,
};

/// Engine markers: hydration reads them once, so a state may not add,
/// remove or change them — except its actions and their argument, which
/// the engine reads when the event happens.
bool _isMarker(String name) =>
    name.startsWith('data-t') &&
    name != onAttr &&
    name != argAttr &&
    name != argWithValueAttr;

/// Subtrees a patch never goes into, only equal on both sides: another
/// state or a list (the engine changes them on their own), a `<template>`
/// (its content is not in the page), and elements the HTML parser
/// restructures or doesn't parse (`<table>` gets a `<tbody>`, `<noscript>`
/// is text), which would break the element paths.
bool _opaque(ElementNode node) {
  final attributes = node.attributes;
  if (attributes != null &&
      (attributes.containsKey(variantAttr) ||
          attributes.containsKey(listAttr) ||
          attributes.containsKey(rowVariantAttr))) {
    return true;
  }
  return switch (node.tag.toLowerCase()) {
    'template' || 'table' || 'noscript' => true,
    _ => false,
  };
}

/// Whether the element's content is a binding's (a text, a row field).
bool _bound(ElementNode node) {
  final attributes = node.attributes;
  return attributes != null &&
      (attributes.containsKey(textAttr) || attributes.containsKey(fieldAttr));
}

/// Appends the ops that turn [live] into [variant]; false when they can't
/// say it (another structure, a marker that differs): the state then
/// ships as a template. [path] indexes element children, like the
/// engine's `children`.
bool _diff(
  ElementNode live,
  ElementNode variant,
  List<int> path,
  List<PatchOp> ops, {
  bool isRoot = false,
}) {
  if (live.tag.toLowerCase() != variant.tag.toLowerCase()) return false;
  final a = _attributes(live), b = _attributes(variant);
  if (isRoot) {
    // The live element's own marker and patches are not the look.
    a.removeWhere((k, _) => k == variantAttr || k.startsWith('$patchAttr-'));
    b.removeWhere((k, _) => k == variantAttr || k.startsWith('$patchAttr-'));
  }
  for (final k in {...a.keys, ...b.keys}) {
    final x = a[k], y = b[k];
    if (x == y) continue;
    if (_isMarker(k)) return false;
    ops.add(PatchOp(path, k, y));
  }
  // A bound text shows the binding's value, whatever the state.
  if (_bound(live)) return true;

  final lc = _flat(live), vc = _flat(variant);
  final leaf = lc.every((n) => n is TextNode) && vc.every((n) => n is TextNode);
  if (leaf) {
    final raw =
        lc.any((n) => (n as TextNode).raw) ||
        vc.any((n) => (n as TextNode).raw);
    // Markup written as is (an inline SVG) can't be a text: equal or not
    // patchable.
    if (raw) return _sameNodes(lc, vc);
    final x = lc.map((n) => (n as TextNode).text).join();
    final y = vc.map((n) => (n as TextNode).text).join();
    if (x != y) ops.add(PatchOp(path, '#', y));
    return true;
  }
  if (lc.length != vc.length) return false;
  // Raw markup next to elements shifts the browser's element indices.
  if (lc.any(_rawMarkup) || vc.any(_rawMarkup)) return _sameNodes(lc, vc);
  var index = 0;
  for (var i = 0; i < lc.length; i++) {
    final x = lc[i], y = vc[i];
    if (x is TextNode) {
      if (y is! TextNode || x.text != y.text || x.raw != y.raw) return false;
      continue;
    }
    if (x is! ElementNode || y is! ElementNode) return false;
    if (_opaque(x) || _opaque(y)) {
      if (!_same(x, y)) return false;
    } else if (!_diff(x, y, [...path, index], ops)) {
      return false;
    }
    index++;
  }
  return true;
}

bool _rawMarkup(Node node) =>
    node is TextNode && node.raw && node.text.contains('<');

/// Whether [a] and [b] write the same HTML.
bool _same(Node a, Node b) => switch ((a, b)) {
  (final TextNode x, final TextNode y) => x.text == y.text && x.raw == y.raw,
  (final ElementNode x, final ElementNode y) =>
    x.tag.toLowerCase() == y.tag.toLowerCase() &&
        _sameMap(_attributes(x), _attributes(y)) &&
        _sameNodes(_flat(x), _flat(y)),
  _ => false,
};

bool _sameNodes(List<Node> a, List<Node> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!_same(a[i], b[i])) return false;
  }
  return true;
}

bool _sameMap(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final MapEntry(:key, :value) in a.entries) {
    if (b[key] != value) return false;
  }
  return true;
}
