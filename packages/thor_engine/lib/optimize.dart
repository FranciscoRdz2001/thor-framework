/// Export optimizer for pages that use thor_engine.
///
/// Runs on the generated HTML (build step), never in the browser: short
/// names for thor's generated classes and, for markup from other servers,
/// every variant `<template>` rewritten into a compact patch (only the
/// classes/attributes/texts that differ from the live element). thor_ui
/// writes those patches itself while it renders, so a server-rendered page
/// is already compact without this step.
///
/// The markup is edited in place, never parsed and serialized again: that
/// would move a `<template>` out of a `<tbody>` (see `src/markup.dart`).
library;

import 'src/generated_classes.dart';
import 'src/markup.dart';
import 'src/patch.dart';
import 'src/protocol.dart';

export 'src/patch.dart';

/// Result of [optimizeHtml].
class OptimizeReport {
  /// Wraps the results of a single [optimizeHtml] run.
  OptimizeReport(this.html, this.templates, this.patched, this.renamed);

  /// The optimized page markup.
  final String html;

  /// Number of variant templates found in the source.
  final int templates;

  /// Templates turned into patches (the rest kept: structure differed).
  final int patched;

  /// Generated classes given a short name.
  final int renamed;
}

// Attributes that belong to the engine protocol, not to the look.
const _ignored = {
  variantAttr,
  variantTemplateAttr,
  variantIndexAttr,
  patchAttr,
};

/// [shortClasses]: renames thor's generated classes (`t1k7hcps`) to the
/// shortest free names, most used first. Only safe when no client code
/// generates classes at runtime — true for thor_engine pages, whose
/// variants are precompiled (not for pages hydrated as islands).
///
/// [patchVariants]: turns variant templates into patches. thor_ui already
/// renders them that way (a `Watch` keeps a template only when a patch
/// can't say the state), so `thor build` passes false: this pass is for
/// markup from other servers.
OptimizeReport optimizeHtml(
  String source, {
  bool shortClasses = true,
  bool patchVariants = true,
}) {
  var doc = MarkupDoc(source);
  final templates = [
    for (final e in doc.all)
      if (e.name == 'template' && e.has(variantTemplateAttr)) e,
  ];
  var patched = 0;
  var text = source;
  if (patchVariants) {
    for (final t in templates) {
      final id = t.attr(variantTemplateAttr)!;
      final live = _owner(doc, t, id);
      final kids = _kids(doc, t);
      if (live == null || kids.length != 1) continue;
      final ops = <PatchOp>[];
      if (!_diff(doc, live, kids.first, const [], ops)) continue;
      // The patch moves onto the live element; the template disappears.
      doc.setAttr(
        live,
        '$patchAttr-${t.attr(variantIndexAttr)}',
        encodePatch(ops),
      );
      doc.remove(t);
      patched++;
    }
    if (patched > 0) {
      text = doc.render();
      doc = MarkupDoc(text);
    }
  }
  var renamed = 0;
  final r = shortClasses ? _shortenClasses(doc) : (0, null);
  renamed = r.$1;
  text = r.$2 ?? doc.render();
  return OptimizeReport(text, templates.length, patched, renamed);
}

/// The child elements of [e] that are still in the page.
List<MElement> _kids(MarkupDoc doc, MElement e) => [
  for (final c in e.children)
    if (!doc.isGone(c)) c,
];

/// The element whose state [template] is: the one right before its run of
/// templates (the same state can be watched more than once on a page, each
/// element with its own templates).
MElement? _owner(MarkupDoc doc, MElement template, String id) {
  for (var e = template.previousElement; e != null; e = e.previousElement) {
    if (doc.isGone(e)) continue;
    if (e.attr(variantAttr) == id) return e;
    if (e.attr(variantTemplateAttr) != id) return null;
  }
  return null;
}

Iterable<String> _patchKeys(MElement el) =>
    el.attrs.map((a) => a.name).where((k) => k.startsWith('$patchAttr-'));

/// Renames the generated classes of [doc]; returns how many and the new
/// text (null when nothing changed).
(int, String?) _shortenClasses(MarkupDoc doc) {
  final sheet = doc.byId('thor-styles');
  if (sheet == null) return (0, null);
  final css = sheet.text;
  final generated = generatedClasses(css).toSet();
  if (generated.isEmpty) return (0, null);

  // Usage counts (templates' patches included) and names already taken.
  final uses = <String, int>{};
  final taken = <String>{};
  void count(String classes) {
    for (final c in classes.split(RegExp(r'\s+'))) {
      if (c.isEmpty) continue;
      if (generated.contains(c)) {
        uses[c] = (uses[c] ?? 0) + 1;
      } else {
        taken.add(c);
      }
    }
  }

  final all = [
    for (final e in doc.all)
      if (e.has('class') || e.has(variantAttr)) e,
  ];
  for (final el in all) {
    final cls = el.attr('class');
    if (cls != null) count(cls);
    for (final k in _patchKeys(el)) {
      for (final op in decodePatch(el.attr(k)!)) {
        if (op.attr == 'class' && op.value != null) count(op.value!);
      }
    }
  }
  final order = generated.toList()
    ..sort((a, b) => (uses[b] ?? 0).compareTo(uses[a] ?? 0));
  final names = <String, String>{};
  var n = 0;
  for (final c in order) {
    String name;
    do {
      name = shortClassName(n++);
    } while (taken.contains(name));
    names[c] = name;
  }

  String rename(String classes) =>
      classes.split(' ').map((c) => names[c] ?? c).join(' ');
  for (final el in all) {
    final cls = el.attr('class');
    if (cls != null) doc.setAttr(el, 'class', rename(cls));
    for (final k in _patchKeys(el)) {
      doc.setAttr(
        el,
        k,
        encodePatch([
          for (final op in decodePatch(el.attr(k)!))
            op.attr == 'class' && op.value != null
                ? PatchOp(op.path, op.attr, rename(op.value!))
                : op,
        ]),
      );
    }
  }
  doc.setContent(sheet, renameGeneratedClasses(css, names));
  return (names.length, doc.render());
}

const _alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

/// The [i]th short class name: `a`…`z`, `A`…`Z`, then two characters
/// (valid CSS identifiers).
String shortClassName(int i) {
  var n = i;
  final b = StringBuffer();
  do {
    b.write(_alphabet[n % _alphabet.length]);
    n = n ~/ _alphabet.length - 1;
  } while (n >= 0);
  return b.toString();
}

/// Appends the ops that turn [live] into [variant]; false when the
/// structures differ (the template is then kept as is).
bool _diff(
  MarkupDoc doc,
  MElement live,
  MElement variant,
  List<int> path,
  List<PatchOp> ops,
) {
  if (live.name != variant.name) return false;
  final keys =
      {
        ...live.attrs.map((a) => a.name),
        ...variant.attrs.map((a) => a.name),
      }.where(
        // A patch an earlier template of the element left (`data-tp-<n>`).
        (k) => !_ignored.contains(k) && !k.startsWith('$patchAttr-'),
      );
  for (final k in keys) {
    final a = live.attr(k), b = variant.attr(k);
    if (a != b) ops.add(PatchOp(path, k, b));
  }
  final lc = _kids(doc, live), vc = _kids(doc, variant);
  if (lc.length != vc.length) return false;
  if (lc.isEmpty) {
    if (live.text != variant.text) ops.add(PatchOp(path, '#', variant.text));
    return true;
  }
  // Mixed content: text siblings of elements must match exactly.
  String texts(MElement e) =>
      e.nodes.whereType<MText>().map((n) => n.data).join('\u0000');
  if (texts(live) != texts(variant)) return false;
  for (var i = 0; i < lc.length; i++) {
    // A nested text binding keeps its own (dynamic) content.
    if (lc[i].has(textAttr) && _kids(doc, lc[i]).isEmpty) continue;
    if (!_diff(doc, lc[i], vc[i], [...path, i], ops)) return false;
  }
  return true;
}
