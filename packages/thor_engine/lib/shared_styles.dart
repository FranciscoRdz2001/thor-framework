/// Shared stylesheets for a built site (a build step, never in the browser).
///
/// Every page of a thor site carries its whole stylesheet inline: the first
/// page paints without waiting for another file, but the next page downloads
/// again the theme and the classes it has in common with the last one. This
/// step moves what most pages share into two files the browser keeps across
/// navigations (their names change with their content, so they are cached
/// as immutable), split by how often they change:
///
/// - `_thor/base.<hash>.css`: the layer order, the app stylesheet
///   (`initializeThor(styles:)`, with `thorResetStyles`) and the theme
///   (`thor.tokens`). It changes when the app's design does.
/// - `_thor/styles.<hash>.css`: the classes used by `minShare` of the pages
///   or more. It changes with almost any edit of a page.
///
/// Both are linked at once (one round trip, in parallel); each page keeps
/// inline only its own classes.
///
/// It runs before the short class names: a shared class gets one short name
/// on every page, and a page's own classes then take the names left free.
library;

import 'dart:io';

import 'css_text.dart';
import 'fingerprint.dart' show contentHash;
import 'optimize.dart' show shortClassName;
import 'src/generated_classes.dart';
import 'src/markup.dart';
import 'src/patch.dart';
import 'src/protocol.dart';

/// Result of [shareSiteStyles].
class SharedStylesReport {
  /// Wraps the results of a run.
  SharedStylesReport({
    required this.pages,
    required this.sharing,
    required this.sharedClasses,
    required this.sheet,
    required this.sheetBytes,
    this.base,
    this.baseBytes = 0,
    this.sharedAppStyles = false,
    this.named = const {},
  });

  /// Pages (`.html`) with a thor stylesheet.
  final int pages;

  /// Pages that load the shared stylesheet.
  final int sharing;

  /// Classes moved to the shared stylesheet.
  final int sharedClasses;

  /// Site-relative path of the shared classes' stylesheet, or null when no
  /// class is used by enough pages.
  final String? sheet;

  /// Its size in bytes.
  final int sheetBytes;

  /// Site-relative path of the base stylesheet (layer order, app
  /// stylesheet, theme), or null when there is nothing worth sharing (a
  /// site of one page).
  final String? base;

  /// Its size in bytes.
  final int baseBytes;

  /// Whether the app stylesheet moved to [base] (it stays inline when the
  /// pages don't all have the same one, or its keyframes clash with thor's).
  final bool sharedAppStyles;

  /// Pages whose classes already got their short names here (every page
  /// that loads the shared sheet): the per-page optimizer must skip them.
  final Set<String> named;
}

/// Where thor's own files go in a built site.
const sharedStylesDir = '_thor';

const _styleId = 'thor-styles';

/// The layer of the app theme in a page's stylesheet (`thorTokensLayer`).
const _tokensLayer = 'thor.tokens';
final _where = RegExp(r':where\([^)]*\)');

/// The rules of one class in one layer, in their order.
class _Class {
  _Class(this.layer, this.name);
  final String layer;
  final String name;
  final rules = <ClassRule>[];
  String get key =>
      '$layer\u0000$name\u0000${rules.map((r) => '${r.wrap}\u0001${r.rule}').join('\u0002')}';
}

/// A page's stylesheet split into what can be shared.
class _Sheet {
  _Sheet(this.page, this.doc, this.style) {
    final found = _appStyle(doc, style);
    app = found?.$1;
    appAfter = found?.$2 ?? false;
  }
  final File page;
  final MarkupDoc doc;
  final MElement style;

  /// The app stylesheet (`initializeThor(styles:)`): a `<style>` right
  /// next to thor's in the `<head>`, or null.
  MElement? app;

  /// Whether [app] comes after thor's stylesheet (then its keyframes beat
  /// thor's ones of the same name).
  bool appAfter = false;

  /// `@layer thor.reset, …;`
  String order = '';

  /// The body of `@layer thor.tokens{…}` (the theme), or null.
  String? theme;

  /// Classes per layer, in order.
  final layers = <String, List<_Class>>{};

  /// `@keyframes …{…}` and anything else outside the known layers, as text.
  final other = <String>[];
}

/// Moves the thor styles shared by at least [minShare] of the pages of
/// [siteDir] (and by two pages at least) into `_thor/base.<hash>.css` and
/// `_thor/styles.<hash>.css`.
SharedStylesReport shareSiteStyles(String siteDir, {double minShare = 0.1}) {
  final root = Directory(siteDir).absolute;
  final sheets = <_Sheet>[];
  for (final f in root.listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.html')) continue;
    final doc = MarkupDoc(f.readAsStringSync());
    final style = doc.byId(_styleId);
    if (style == null || style.name != 'style') continue;
    sheets.add(_read(_Sheet(f, doc, style), style.text));
  }
  final threshold = [
    2,
    (sheets.length * minShare).ceil(),
  ].reduce((a, b) => a > b ? a : b);
  SharedStylesReport none() => SharedStylesReport(
    pages: sheets.length,
    sharing: 0,
    sharedClasses: 0,
    sheet: null,
    sheetBytes: 0,
  );
  if (sheets.length < 2) return none();

  // The theme most pages have; a page with another one keeps its whole
  // stylesheet inline (the shared theme would otherwise apply under its own).
  final (theme, users) = _sharedTheme(sheets);
  if (users.length < threshold) return none();

  // The app stylesheet most pages have; shared when enough pages have that
  // exact one and no keyframes of it clash with one of thor's (the later
  // definition wins, and moving it first would flip that).
  final apps = <String, int>{};
  for (final s in users) {
    final text = s.app?.text;
    if (text != null) apps[text] = (apps[text] ?? 0) + 1;
  }
  final app = apps.isEmpty
      ? null
      : apps.entries.reduce((a, b) => b.value > a.value ? b : a);
  final thorKeyframes = {
    for (final s in users)
      if (s.appAfter)
        for (final k in s.other) ?_keyframesName(k),
  };
  final appText =
      app != null &&
          app.value >= threshold &&
          !_keyframesNames(app.key).any(thorKeyframes.contains)
      ? app.key
      : null;

  // A page with another app stylesheet (or none) keeps its whole
  // stylesheet inline, like one with another theme: the base would add
  // the shared one's rules to it.
  if (appText != null) users.removeWhere((s) => s.app?.text != appText);

  final count = <String, int>{};
  final keyframes = <String, int>{};
  for (final s in users) {
    for (final c in {for (final l in s.layers.values) ...l.map((c) => c.key)}) {
      count[c] = (count[c] ?? 0) + 1;
    }
    for (final k in s.other.toSet()) {
      keyframes[k] = (keyframes[k] ?? 0) + 1;
    }
  }
  bool frequent(_Class c) => count[c.key]! >= threshold;

  // The shared sheet: layer order, theme, shared classes (first seen first,
  // grouped per condition), shared keyframes.
  final order = users.first.order;
  final layerNames = <String>[];
  final sharedByLayer = <String, Map<String, _Class>>{};
  for (final s in users) {
    for (final MapEntry(key: layer, value: classes) in s.layers.entries) {
      if (!layerNames.contains(layer)) layerNames.add(layer);
      for (final c in classes) {
        if (frequent(c)) {
          (sharedByLayer[layer] ??= {}).putIfAbsent(c.key, () => c);
        }
      }
    }
  }
  // A name with two different contents (a hash collision one page salted)
  // stays on its pages.
  final contents = <String, Set<String>>{};
  for (final s in users) {
    for (final l in s.layers.values) {
      for (final c in l) {
        (contents[c.name] ??= {}).add(c.key);
      }
    }
  }
  for (final l in sharedByLayer.values) {
    l.removeWhere((_, c) => contents[c.name]!.length > 1);
  }
  final sharedNames = {
    for (final l in sharedByLayer.values)
      for (final c in l.values) c.name,
  };
  if (sharedNames.isEmpty && theme == null && appText == null) return none();
  final sharedKeys = {for (final l in sharedByLayer.values) ...l.keys};
  bool shared(_Class c) => sharedKeys.contains(c.key);

  // Short names for the shared classes, the same on every page, most used
  // first.
  final uses = <String, int>{};
  for (final s in users) {
    _countClasses(s.doc, (c) {
      if (sharedNames.contains(c)) uses[c] = (uses[c] ?? 0) + 1;
    });
  }
  final taken = <String>{};
  for (final s in users) {
    _countClasses(s.doc, (c) {
      if (!_isGenerated(c)) taken.add(c);
    });
  }
  final names = <String, String>{};
  var n = 0;
  for (final c
      in sharedNames.toList()
        ..sort((a, b) => (uses[b] ?? 0).compareTo(uses[a] ?? 0))) {
    String name;
    do {
      name = shortClassName(n++);
    } while (taken.contains(name));
    names[c] = name;
  }
  String renameCss(String css) => renameGeneratedClasses(css, names);

  String write(String kind, String text) {
    final path = '$sharedStylesDir/$kind.${contentHash(text.codeUnits)}.css';
    File('${root.path}/$path')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(text);
    return path;
  }

  // The base: what changes with the app's design, not with its pages. The
  // order goes first so the app's layered rules (the reset) and the theme
  // land in thor's layers; an `@import` of the app stays valid after it.
  final baseText = StringBuffer(order);
  if (appText != null) baseText.write(appText);
  if (theme != null) baseText.write('@layer $_tokensLayer{$theme}');
  final basePath = write('base', baseText.toString());

  final sheet = StringBuffer(order);
  var sharedRules = false;
  for (final layer in layerNames) {
    final classes = sharedByLayer[layer]?.values;
    if (classes == null || classes.isEmpty) continue;
    sheet.write(
      '@layer $layer{${groupClassRules([for (final c in classes) c.rules])}}',
    );
    sharedRules = true;
  }
  for (final e in keyframes.entries) {
    if (e.value >= threshold) {
      sheet.write(e.key);
      sharedRules = true;
    }
  }
  final text = renameCss(sheet.toString());
  final path = sharedRules ? write('styles', text) : null;

  // Each page: the link, then its own rules.
  for (final s in users) {
    final local = StringBuffer(s.order);
    for (final MapEntry(key: layer, value: classes) in s.layers.entries) {
      final own = [
        for (final c in classes)
          if (!shared(c)) c.rules,
      ];
      if (own.isNotEmpty) local.write('@layer $layer{${groupClassRules(own)}}');
    }
    for (final k in s.other) {
      if ((keyframes[k] ?? 0) < threshold) local.write(k);
    }
    // The page's own classes get short names here too, never one of the
    // shared sheet's (even those this page doesn't use: its rule would
    // apply). The optimizer after this finds nothing left to rename.
    final ownNames = {
      for (final l in s.layers.values)
        for (final c in l)
          if (!shared(c)) c.name,
    };
    final pageUses = <String, int>{};
    final pageTaken = {...taken, ...names.values};
    _countClasses(s.doc, (c) {
      if (ownNames.contains(c)) {
        pageUses[c] = (pageUses[c] ?? 0) + 1;
      } else if (!_isGenerated(c)) {
        pageTaken.add(c);
      }
    });
    final pageNames = {...names};
    var k = 0;
    for (final c
        in ownNames.toList()
          ..sort((a, b) => (pageUses[b] ?? 0).compareTo(pageUses[a] ?? 0))) {
      String name;
      do {
        name = shortClassName(k++);
      } while (pageTaken.contains(name));
      pageNames[c] = name;
    }
    s.doc.setContent(
      s.style,
      renameGeneratedClasses(local.toString(), pageNames),
    );
    _renameClasses(s.doc, pageNames);
    for (final href in [basePath, ?path]) {
      s.doc.insertBefore(
        s.style,
        '<link rel="stylesheet" href="/${escapeAttribute(href)}">',
      );
    }
    if (appText != null && s.app?.text == appText) s.doc.remove(s.app!);
    s.page.writeAsStringSync(s.doc.render());
  }
  return SharedStylesReport(
    pages: sheets.length,
    sharing: users.length,
    sharedClasses: sharedNames.length,
    sheet: path,
    sheetBytes: path == null ? 0 : text.length,
    base: basePath,
    baseBytes: baseText.length,
    sharedAppStyles: appText != null,
    named: {for (final s in users) s.page.path},
  );
}

/// The theme the most pages share, and those pages. A page may leave out
/// the custom properties it doesn't read (thor_ui publishes only the text
/// roles a page reads), so pages match on the rest of the theme and on the
/// value most of them give each property; the shared theme then holds
/// every property any of them has, each at its place (a breakpoint rule
/// after the `:root` it overrides).
(String?, List<_Sheet>) _sharedTheme(List<_Sheet> sheets) {
  final shapes = <String?, List<_Sheet>>{};
  for (final s in sheets) {
    final theme = s.theme;
    (shapes[theme == null ? null : _themeShape(theme)] ??= []).add(s);
  }
  final group = shapes.values.reduce((a, b) => b.length > a.length ? b : a);
  if (group.first.theme == null) return (null, group);
  final first = group.first.theme!;
  if (group.every((s) => s.theme == first)) return (first, group);
  final rules = {for (final s in group) s: _themeRules(s.theme!)};
  final votes = <String, Map<String, int>>{};
  for (final list in rules.values) {
    for (final r in list) {
      for (final (name, value) in r.decls) {
        final v = votes['${r.key}\u0001$name'] ??= {};
        v[value] = (v[value] ?? 0) + 1;
      }
    }
  }
  String winner(String key) =>
      votes[key]!.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  final users = [
    for (final s in group)
      if (rules[s]!.every(
        (r) => r.decls.every((d) => winner('${r.key}\u0001${d.$1}') == d.$2),
      ))
        s,
  ];
  // Every rule in page order (a rule some pages lack goes after the one
  // before it on the pages that have it), with every declaration; pages
  // by path, so every machine writes the same text.
  final order = <String>[];
  final byKey = <String, _ThemeRule>{};
  final decls = <String, Map<String, String>>{};
  for (final s in [
    ...users,
  ]..sort((a, b) => a.page.path.compareTo(b.page.path))) {
    var at = -1;
    for (final r in rules[s]!) {
      var i = order.indexOf(r.key);
      if (i < 0) {
        order.insert(i = at + 1, r.key);
        byKey[r.key] = r;
      }
      at = i;
      final all = decls[r.key] ??= {};
      for (final (name, value) in r.decls) {
        all[name] = value;
      }
    }
  }
  final theme = StringBuffer();
  for (final key in order) {
    final r = byKey[key]!;
    final body = [
      for (final e in decls[key]!.entries) '${e.key}:${e.value}',
    ].join(';');
    final rule = '${r.selector}{$body}';
    theme.write(r.wrap == null ? rule : '${r.wrap}{$rule}');
  }
  return (theme.toString(), users);
}

/// A theme rule: its at-rule, selector and declarations (`name`, `value`);
/// `key` tells apart two rules of the same selector.
typedef _ThemeRule = ({
  String key,
  String? wrap,
  String selector,
  List<(String, String)> decls,
});

List<_ThemeRule> _themeRules(String theme) {
  final seen = <String, int>{};
  return [
    for (final r in flattenRules(splitCssStatements(theme)))
      for (final st in splitCssStatements(r.rule))
        () {
          final base = '${r.wrap ?? ''}\u0000${st.prelude}';
          final n = seen[base] = (seen[base] ?? 0) + 1;
          return (
            key: '$base\u0000$n',
            wrap: r.wrap,
            selector: st.prelude,
            decls: [
              for (final d in splitCssStatements(st.body ?? ''))
                _declaration(d.prelude),
            ],
          );
        }(),
  ];
}

(String, String) _declaration(String text) {
  final colon = text.indexOf(':');
  return colon < 0
      ? (text, '')
      : (text.substring(0, colon).trim(), text.substring(colon + 1).trim());
}

/// [theme] without its custom properties (and the rules that only had
/// those): what pages that share a theme have in common.
String _themeShape(String theme) {
  final out = StringBuffer();
  for (final r in _themeRules(theme)) {
    final own = [
      for (final (name, value) in r.decls)
        if (!name.startsWith('--')) '$name:$value',
    ];
    if (own.isNotEmpty) out.write('${r.wrap}\u0000${r.selector}{$own}');
  }
  return out.toString();
}

_Sheet _read(_Sheet s, String css) {
  for (final st in splitCssStatements(css)) {
    final body = st.body;
    if (body == null) {
      if (st.prelude.startsWith('@layer')) {
        s.order = cssStatementText(st);
      } else {
        s.other.add(cssStatementText(st));
      }
    } else if (st.prelude == '@layer $_tokensLayer') {
      s.theme = body;
    } else if (st.prelude.startsWith('@layer ')) {
      final layer = st.prelude.substring(7).trim();
      final byName = <String, _Class>{};
      final classes = s.layers[layer] = [];
      for (final rule in flattenRules(splitCssStatements(body))) {
        final selector = rule.rule.substring(0, rule.rule.indexOf('{'));
        final name = generatedClasses(
          selector.replaceAll(_where, ''),
        ).firstOrNull;
        // A rule without a generated class (never written by thor): kept
        // with the previous class, so it stays in place.
        final key = name ?? (classes.isEmpty ? '' : classes.last.name);
        final c = byName.putIfAbsent(key, () {
          final c = _Class(layer, key);
          classes.add(c);
          return c;
        });
        c.rules.add(rule);
      }
    } else {
      s.other.add(cssStatementText(st));
    }
  }
  return s;
}

(MElement, bool)? _appStyle(MarkupDoc doc, MElement thor) {
  final sheets = [
    for (final el in doc.byName('head')?.children ?? const <MElement>[])
      if (el == thor ||
          el.name == 'style' ||
          (el.name == 'link' &&
              (el.attr('rel') ?? '').split(' ').contains('stylesheet')))
        el,
  ];
  final at = sheets.indexOf(thor);
  if (at < 0) return null;
  bool isApp(MElement el) =>
      el.name == 'style' && (el.attr('id') ?? '').isEmpty;
  // The stylesheet right next to thor's: moved to the links just before
  // it, it keeps its place among the page's other stylesheets. Right
  // before it (an exported page) nothing changes; right after it, only
  // keyframes could (thor's are layered rules, the app's are not).
  if (at > 0 && isApp(sheets[at - 1])) return (sheets[at - 1], false);
  if (at + 1 < sheets.length && isApp(sheets[at + 1])) {
    return (sheets[at + 1], true);
  }
  return null;
}

final _keyframesRule = RegExp(r'@(?:-webkit-)?keyframes\s+([\w-]+)');

String? _keyframesName(String statement) =>
    _keyframesRule.matchAsPrefix(statement.trimLeft())?.group(1);

Iterable<String> _keyframesNames(String css) =>
    _keyframesRule.allMatches(css).map((m) => m[1]!);

bool _isGenerated(String c) => RegExp(r'^t[0-9a-z]+$').hasMatch(c);

Iterable<MElement> _classed(MarkupDoc doc) => [
  for (final e in doc.all)
    if (e.has('class') || e.has(variantAttr)) e,
];

Iterable<String> _patchKeys(MElement el) =>
    el.attrs.map((a) => a.name).where((k) => k.startsWith('$patchAttr-'));

void _countClasses(MarkupDoc doc, void Function(String) each) {
  for (final el in _classed(doc)) {
    for (final c in (el.attr('class') ?? '').split(RegExp(r'\s+'))) {
      if (c.isNotEmpty) each(c);
    }
    for (final k in _patchKeys(el)) {
      for (final op in decodePatch(el.attr(k)!)) {
        if (op.attr == 'class' && op.value != null) {
          for (final c in op.value!.split(RegExp(r'\s+'))) {
            if (c.isNotEmpty) each(c);
          }
        }
      }
    }
  }
}

void _renameClasses(MarkupDoc doc, Map<String, String> names) {
  String rename(String classes) =>
      classes.split(' ').map((c) => names[c] ?? c).join(' ');
  for (final el in _classed(doc)) {
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
}
