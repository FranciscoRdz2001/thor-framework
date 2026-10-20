// The public API of thor, from what an app can import: the reference
// (docs/api/thor_ui.md, one page per topic and per extra import) and the
// API snapshot (docs/api/public_api.txt) that keeps it stable (the
// deprecation policy in CONTRIBUTING.md).
//
//   dart run tool/gen_api_docs.dart           write both (tool/thor docs)
//   dart run tool/gen_api_docs.dart --check   fail if the public API
//       changed without recording it, or lost a name that wasn't
//       @Deprecated in the recorded one (tool/thor check)
//
// Resolved with the analyzer: a symbol is public if a facade exports it,
// wherever it is declared. A declaration in a file with no topic fails the
// run (see [topics]).
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';

import 'api_check.dart';
import 'api_filter.dart';

/// The imports an app uses, in the order the reference shows them.
const facades = {
  'thor_ui.dart': 'thor_ui',
  'server.dart': 'server',
  'router.dart': 'router',
  'html.dart': 'html',
  'testing.dart': 'testing',
  'intl.dart': 'intl',
};

/// The libraries of the other packages an app imports (a dev dependency):
/// slug → path from the repository root. What they re-export from
/// `thor_ui` is listed under its own facade.
const packageFacades = {
  'thor_test': 'packages/thor_test/lib/thor_test.dart',
  'thor_studio': 'packages/thor_studio/lib/thor_studio.dart',
};

/// Libraries that are in the API snapshot but not in the reference:
/// what an app imports straight from the packages underneath
/// (`package:thor_engine/thor_engine.dart`…), slug → path from the repository
/// root. A name they re-export from `thor_ui` is listed under its facade.
const snapshotFacades = {
  'thor_engine': 'packages/thor_engine/lib/thor_engine.dart',
  'thor_server': 'packages/thor_server/lib/thor_server.dart',
  'thor_style': 'packages/thor_style/lib/thor_style.dart',
};

/// `package:thor_ui/web.dart` (experimental): snapshot only. It
/// re-exports `router.dart` and `thor_ui.dart`; only what it declares itself
/// (`src/web/`) is recorded under it.
const webFacade = ('web.dart', 'web');

/// The pages of `package:thor_ui/thor_ui.dart`: slug, title, and the
/// files whose declarations go there.
const topics = <(String, String, List<String>)>[
  (
    'widgets',
    'El modelo de widgets',
    [
      'thor_ui/src/core/framework.dart',
      'thor_ui/src/core/notifier.dart',
      'thor_engine/src/notifier.dart',
      'thor_ui/src/widgets/cached.dart',
      'thor_ui/src/widgets/tombstones.dart',
      'thor_ui/src/foundation/const_memo.dart',
      'thor_ui/src/foundation/widget.dart',
      'thor_ui/src/foundation/foundation.dart',
      'thor_ui/src/foundation/localizations.dart',
      'thor_server/src/locale.dart',
      'thor_server/src/route_url.dart',
      'thor_ui/src/foundation/material_localizations.dart',
      'thor_ui/src/foundation/inspect.dart',
      'meta/meta.dart',
    ],
  ),
  (
    'layout',
    'Layout',
    [
      'thor_ui/src/widgets/basic.dart',
      'thor_ui/src/widgets/flex.dart',
      'thor_ui/src/widgets/grid.dart',
      'thor_ui/src/widgets/table.dart',
      'thor_ui/src/widgets/stack.dart',
      'thor_ui/src/widgets/scroll.dart',
      'thor_ui/src/widgets/slivers.dart',
      'thor_ui/src/widgets/page_view.dart',
      'thor_ui/src/widgets/scaffold.dart',
      'thor_ui/src/widgets/divider.dart',
      'thor_ui/src/widgets/split_pane.dart',
      'thor_style/src/geometry.dart',
      'thor_style/src/edge_insets.dart',
      'thor_style/src/matrix4.dart',
      'thor_style/src/alignment.dart',
      'thor_style/src/layout_enums.dart',
      'thor_style/src/length.dart',
      'thor_style/src/web_layout.dart',
      'thor_style/src/web_values.dart',
    ],
  ),
  (
    'texto',
    'Texto, íconos e imágenes',
    [
      'thor_ui/src/widgets/text.dart',
      'thor_ui/src/widgets/rich_text.dart',
      'thor_ui/src/widgets/ratio_text.dart',
      'thor_ui/src/widgets/html_widget.dart',
      'thor_engine/sanitize.dart',
      'thor_ui/src/widgets/icon.dart',
      'thor_ui/src/widgets/icons.dart',
      'thor_ui/src/widgets/image.dart',
      'thor_ui/src/widgets/iframe.dart',
      'thor_ui/src/foundation/image_manifest_scope.dart',
      'thor_ui/src/foundation/image_preload.dart',
      'thor_server/image_manifest.dart',
      'thor_style/src/text_style.dart',
      'thor_style/src/icon_data.dart',
    ],
  ),
  (
    'controles',
    'Controles, formularios y gestos',
    [
      'thor_ui/src/widgets/buttons.dart',
      'thor_ui/src/widgets/form.dart',
      'thor_ui/src/widgets/autofill_group.dart',
      'thor_ui/src/widgets/form_scope.dart',
      'thor_ui/src/router/page_actions.dart',
      'thor_ui/src/widgets/text_field.dart',
      'thor_ui/src/foundation/html_attributes.dart',
      'thor_ui/src/widgets/selection_controls.dart',
      'thor_ui/src/widgets/dropdown_menu.dart',
      'thor_ui/src/widgets/autocomplete.dart',
      'thor_ui/src/widgets/interaction.dart',
      'thor_ui/src/widgets/gesture.dart',
      'thor_ui/src/widgets/gesture_detector.dart',
      'thor_ui/src/widgets/gesture_details.dart',
      'thor_ui/src/widgets/dismissible.dart',
      'thor_ui/src/widgets/draggable.dart',
      'thor_ui/src/widgets/native_draggable.dart',
      'thor_ui/src/widgets/reorderable.dart',
      'thor_ui/src/widgets/shortcuts.dart',
      'thor_ui/src/widgets/date_picker.dart',
      'thor_ui/src/foundation/widget_state.dart',
      'thor_engine/src/keyboard.dart',
      'thor_engine/src/dates.dart',
    ],
  ),
  (
    'material',
    'Material y navegación',
    [
      'thor_ui/src/widgets/material.dart',
      'thor_ui/src/widgets/skeleton.dart',
      'thor_ui/src/widgets/data_table.dart',
      'thor_ui/src/widgets/navigation.dart',
      'thor_ui/src/widgets/app_bar.dart',
      'thor_ui/src/widgets/navigation_bar.dart',
      'thor_ui/src/widgets/navigation_rail.dart',
      'thor_ui/src/widgets/pagination.dart',
      'thor_ui/src/widgets/tab_bar.dart',
      'thor_ui/src/foundation/page_navigation.dart',
      'thor_ui/src/widgets/hero.dart',
    ],
  ),
  (
    'estilos',
    'Estilos y tema',
    [
      'thor_ui/src/widgets/theme.dart',
      'thor_ui/src/widgets/component_themes.dart',
      'thor_ui/src/foundation/responsive.dart',
      'thor_ui/src/web/style.dart',
      'thor_ui/src/foundation/stylesheet.dart',
      'thor_ui/src/foundation/css_alias.dart',
      'thor_ui/src/foundation/css_rules.dart',
      'thor_ui/src/foundation/base_styles.dart',
      'thor_style/src/color.dart',
      'thor_style/src/color_swatch.dart',
      'thor_style/src/color_token.dart',
      'thor_style/src/decoration.dart',
      'thor_style/src/css.dart',
      'thor_style/src/css_variable.dart',
      'thor_style/src/adaptive.dart',
    ],
  ),
  (
    'animacion',
    'Animación y efectos',
    [
      'thor_ui/src/widgets/animated_size.dart',
      'thor_ui/src/widgets/animated_list.dart',
      'thor_ui/src/widgets/implicit_animations.dart',
      'thor_ui/src/widgets/transitions.dart',
      'thor_ui/src/widgets/animated_switcher.dart',
      'thor_ui/src/animation/tween.dart',
      'thor_engine/src/animation.dart',
      'thor_ui/src/widgets/effects.dart',
      'thor_style/src/curves.dart',
    ],
  ),
  (
    'estado',
    'Estado en el navegador',
    [
      'thor_engine/src/reactive.dart',
      'thor_engine/src/row_probes.dart',
      'thor_engine/src/thor_state.dart',
      'thor_engine/src/controllers.dart',
      'thor_engine/src/clipboard.dart',
      'thor_engine/src/feedback.dart',
      'thor_engine/src/frame_messages.dart',
      'thor_engine/src/navigation.dart',
      'thor_engine/src/query.dart',
      'thor_engine/src/async_snapshot.dart',
      'thor_ui/src/foundation/deferred.dart',
      'thor_engine/src/command.dart',
      'thor_engine/src/server_error.dart',
      'thor_server/server_messages.dart',
      'thor_ui/src/engine/watch.dart',
      'thor_ui/src/engine/engine_script.dart',
      'thor_ui/src/widgets/flutter_view.dart',
    ],
  ),
  (
    'autores',
    'Para autores de widgets',
    [
      'thor_ui/src/foundation/element.dart',
      'thor_ui/src/foundation/child_rules.dart',
      'thor_ui/src/foundation/parent_data.dart',
      'thor_ui/src/foundation/layout_hint.dart',
      'thor_ui/src/foundation/style_registry.dart',
      'thor_ui/src/foundation/debug_inspector.dart',
    ],
  ),
];

const _reference = 'docs/api/thor_ui.md';

/// The reference in English, for the site's English pages (the topics'
/// slugs, the code and its doc comments are the same).
const _referenceEn = 'docs/api/en/thor_ui.md';

/// The topics' titles in English, by slug (`topics` has the Spanish ones).
const topicTitlesEn = {
  'widgets': 'The widget model',
  'layout': 'Layout',
  'texto': 'Text, icons and images',
  'controles': 'Controls, forms and gestures',
  'material': 'Material and navigation',
  'estilos': 'Styles and theme',
  'animacion': 'Animation and effects',
  'estado': 'State in the browser',
  'autores': 'For widget authors',
};
const _snapshot = 'docs/api/public_api.txt';
const _widgetsFile = 'docs/api/widgets.json';

Future<void> main(List<String> args) async {
  final api = await _publicApi();
  final snapshot = _snapshotOf(api);
  if (args.contains('--check')) {
    exit(_check(snapshot) ? 0 : 1);
  }
  // The snapshot keeps every exported name; the reference and the
  // site's widget pages show only what an app writes (`api_filter.dart`).
  final shown = [
    for (final s in api)
      if (_published(s)) s,
  ];
  File(_reference).writeAsStringSync(_markdown(shown));
  File(_referenceEn)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(_markdown(shown, english: true));
  File(_snapshot).writeAsStringSync(snapshot);
  File(_widgetsFile).writeAsStringSync(_widgetsJson(shown));
  File('docs/api/README.md').writeAsStringSync(
    '# Referencia de API\n\n'
    'Generada desde lo que exportan las fachadas con `tool/thor docs`: '
    'no editar a mano.\n\n'
    '- [`thor_ui`](thor_ui.md): ${shown.length} símbolos públicos, por tema '
    'y por import (`thor_test`, la `dev_dependency` de test, y '
    '`thor_studio`, el sistema de diseño, van en su propia sección).\n'
    '- [`public_api.txt`](public_api.txt): la API pública registrada '
    '(la que vigila `tool/thor api`).\n'
    '- [`widgets.json`](widgets.json): cada widget público (firma, '
    'parámetros, documentación): lo que el sitio convierte en una página '
    'por widget.\n',
  );
  stdout.writeln(
    '$_reference: ${shown.length} symbols (${api.length} exported); '
    '$_snapshot recorded',
  );
}

/// One exported symbol.
class _Symbol {
  _Symbol(
    this.facade,
    this.name,
    this.element,
    this.page, {
    this.inReference = true,
  });
  final String facade;
  final String name;
  final Element element;

  /// The reference page: a topic slug, or the facade's name.
  final String page;

  /// Whether the reference may show it (false: snapshot only).
  final bool inReference;
}

Future<List<_Symbol>> _publicApi() async {
  final root = Directory.current.path;
  final collection = AnalysisContextCollection(
    includedPaths: [
      '$root/packages/thor_ui',
      for (final path in [...packageFacades.values, ...snapshotFacades.values])
        '$root/${path.split('/lib/').first}',
    ],
  );
  final symbols = <_Symbol>[];
  final unplaced = <String>{};
  final libraries = [
    for (final MapEntry(key: file, value: facade) in facades.entries)
      (facade, '$root/packages/thor_ui/lib/$file'),
    for (final MapEntry(key: facade, value: file) in packageFacades.entries)
      (facade, '$root/$file'),
    (webFacade.$2, '$root/packages/thor_ui/lib/${webFacade.$1}'),
    for (final MapEntry(key: facade, value: file) in snapshotFacades.entries)
      (facade, '$root/$file'),
  ];
  for (final (facade, path) in libraries) {
    final file = path.split('/').last;
    final result = await collection
        .contextFor(path)
        .currentSession
        .getResolvedLibrary(path);
    if (result is! ResolvedLibraryResult) {
      stderr.writeln('$file did not resolve');
      exit(2);
    }
    final names = result.element.exportNamespace.definedNames2;
    for (final name in names.keys.toList()..sort()) {
      if (name.endsWith('=')) continue; // a setter: its getter speaks for it
      final element = names[name]!;
      // What `thor_test` re-exports from thor_ui is that facade's already.
      final uri = '${element.library?.uri}';
      if (packageFacades.containsKey(facade) &&
          uri.startsWith('package:thor_ui/')) {
        continue;
      }
      // `web.dart` records only its own declarations; the rest is the
      // `router` and `thor_ui` facades'.
      if (facade == webFacade.$2 &&
          !uri.startsWith('package:thor_ui/src/web/')) {
        continue;
      }
      // The snapshot-only packages record what they declare themselves.
      if (snapshotFacades.containsKey(facade) &&
          !uri.startsWith('package:$facade/')) {
        continue;
      }
      var page = facade;
      if (facade == 'thor_ui') {
        final path = uri.replaceFirst('package:', '');
        final topic = topics.where((t) => t.$3.contains(path)).firstOrNull;
        if (topic == null) {
          unplaced.add(path);
          continue;
        }
        page = movedNames[name] ?? topic.$1;
      }
      symbols.add(
        _Symbol(
          facade,
          name,
          element,
          page,
          inReference:
              facade != webFacade.$2 && !snapshotFacades.containsKey(facade),
        ),
      );
    }
  }
  if (unplaced.isNotEmpty) {
    stderr.writeln(
      'Public declarations in files with no topic (add them to `topics` in '
      'tool/gen_api_docs.dart):\n  ${unplaced.join('\n  ')}',
    );
    exit(2);
  }
  return symbols;
}

/// Whether the reference shows [s]: an app can write it (see
/// `api_filter.dart`).
bool _published(_Symbol s) =>
    s.inReference &&
    !_tombstone(s.element) &&
    !internalNames.contains(s.name) &&
    !internalTopics.contains(s.page) &&
    !_internalElement(s.element);

/// Whether [e] is marked `@internal` or `@visibleForTesting`.
bool _internalElement(Element e) => e.metadata.annotations.any(
  (a) => internalAnnotations.any(a.toSource().startsWith),
);

String _kind(Element e) => switch (e) {
  EnumElement() => 'enum',
  MixinElement() => 'mixin',
  ExtensionTypeElement() => 'extension type',
  ClassElement(isSealed: true) => 'sealed class',
  ClassElement(isAbstract: true) => 'abstract class',
  ClassElement() => 'class',
  ExtensionElement() => 'extension',
  TypeAliasElement() => 'typedef',
  TopLevelFunctionElement() => 'function',
  TopLevelVariableElement(isConst: true) => 'const',
  TopLevelVariableElement() => 'variable',
  GetterElement() => 'getter',
  _ => e.kind.displayName,
};

bool _deprecated(Element e) => e.metadata.hasDeprecated;

/// Whether [e] carries `@Tombstone()` (`thor_ui/src/widgets/tombstones.dart`):
/// a name kept only to guide a Flutter developer. It is in the snapshot
/// as `@tombstone`, apart from the real deprecations, and has no reference
/// entry.
bool _tombstone(Element e) =>
    e.metadata.annotations.any((a) => a.toSource().startsWith('@Tombstone'));

/// Public members of [e] (constructors, fields, getters, methods), each by
/// name.
Map<String, Element> _members(Element e) {
  // A typedef of a class has that class's members under its own name.
  if (e is TypeAliasElement) {
    final aliased = e.aliasedType.element;
    return aliased == null ? const {} : _members(aliased);
  }
  final out = <String, Element>{};
  if (e is InterfaceElement) {
    for (final c in e.constructors) {
      final n = c.name;
      if (n == null || !c.isPublic) continue;
      out[n] = c;
    }
  }
  if (e is InstanceElement) {
    for (final f in e.fields) {
      if (f.isPublic && f.isOriginDeclaration) out[f.name!] = f;
    }
    for (final g in e.getters) {
      if (g.isPublic && g.isOriginDeclaration) out[g.name!] = g;
    }
    for (final m in e.methods) {
      if (m.isPublic) out[m.name!] = m;
    }
  }
  return out;
}

String _snapshotOf(List<_Symbol> api) {
  final lines = <String>[];
  // A tombstone is no deprecation: it never goes through the
  // deprecate-then-remove policy, so it has its own mark.
  String mark(bool tombstone, bool deprecated) => tombstone
      ? tombstoneMark
      : deprecated
      ? deprecatedMark
      : '';
  for (final s in api) {
    final tombstone = _tombstone(s.element);
    final deprecated = _deprecated(s.element);
    lines.add(
      '${s.facade}\t${s.name}\t${_kind(s.element)}'
      '${mark(tombstone, deprecated)}',
    );
    for (final MapEntry(:key, :value) in _members(s.element).entries) {
      // A member of a deprecated name (or a tombstone) goes away with it.
      lines.add(
        '${s.facade}\t${s.name}.$key\t'
        '${value.displayString(preferTypeAlias: true).replaceAll('\n', ' ')}'
        '${mark(tombstone || _tombstone(value), deprecated || _deprecated(value))}',
      );
    }
  }
  return '${(lines..sort()).join('\n')}\n';
}

/// The recorded snapshot against [current] (the rule is in
/// `api_check.dart`).
bool _check(String current) {
  final file = File(_snapshot);
  if (!file.existsSync()) {
    stderr.writeln('No $_snapshot: run tool/thor docs.');
    return false;
  }
  switch (compareApi(file.readAsStringSync(), current)) {
    case ApiUnchanged(:final names, :final deprecated, :final tombstones):
      stdout.writeln(
        'Public API unchanged ($names names; $deprecated deprecated, '
        '$tombstones tombstones).',
      );
      return true;
    case ApiRemoved(:final names):
      stderr.writeln(
        'Public API removed without deprecation (CONTRIBUTING.md): mark it '
        "@Deprecated('Use …') for one minor version first, with a shim if "
        'possible:\n  ${names.join('\n  ')}',
      );
      return false;
    case ApiChanged(:final added, :final removed):
      stderr.writeln(
        'The public API changed ($added names added, $removed deprecated '
        'names removed, or signatures and deprecations changed) and is not '
        'recorded: run tool/thor docs, review docs/api/public_api.txt and '
        "note it in the package's CHANGELOG.",
      );
      return false;
  }
}

String _markdown(List<_Symbol> api, {bool english = false}) {
  String titleOf(String slug, String title) =>
      english ? topicTitlesEn[slug] ?? title : title;
  final page = english ? 'Page' : 'Página';
  final b = StringBuffer()
    ..writeln('# `thor_ui`\n')
    ..writeln(
      english
          ? 'Everything an app can import, by topic. '
                "`import 'package:thor_ui/thor_ui.dart';` brings the widgets "
                'and `thor_style`; the other imports are for the server, the '
                'routes, raw HTML and the tests.\n'
          : 'Todo lo que una app puede importar, por tema. '
                "`import 'package:thor_ui/thor_ui.dart';` trae los widgets y "
                '`thor_style`; las demás importaciones son para el servidor, '
                'las rutas, HTML crudo y los tests.\n',
    )
    ..writeln('| $page |')
    ..writeln('|---|');
  // The topics all come from `thor_ui.dart`: one column; the other imports
  // say which file they are.
  for (final (slug, title, _) in topics) {
    if (internalTopics.contains(slug)) continue;
    b.writeln('| [${titleOf(slug, title)}](thor_ui.md#$slug) |');
  }
  b
    ..writeln()
    ..writeln('| Import | $page |')
    ..writeln('|---|---|');
  for (final facade in facades.values.skip(1)) {
    b.writeln('| `$facade.dart` | [`$facade`](thor_ui.md#$facade) |');
  }
  for (final facade in packageFacades.keys) {
    b.writeln(
      '| `package:$facade/$facade.dart` | [`$facade`](thor_ui.md#$facade) |',
    );
  }
  final pages = <(String, String, String)>[
    for (final (slug, title, _) in topics)
      if (!internalTopics.contains(slug))
        (slug, titleOf(slug, title), 'thor_ui'),
    for (final f in facades.values.skip(1)) (f, '`package:thor_ui/$f.dart`', f),
    for (final f in packageFacades.keys) (f, '`package:$f/$f.dart`', f),
  ];
  for (final (slug, title, facade) in pages) {
    final symbols = [
      for (final s in api)
        if (s.page == slug && s.facade == facade) s,
    ];
    if (symbols.isEmpty) continue;
    b.writeln('\n## `$slug` · $title');
    for (final s in symbols) {
      b.write(_entry(s, english: english));
    }
  }
  return b.toString();
}

String _entry(_Symbol s, {bool english = false}) {
  final e = s.element;
  final out = StringBuffer('\n### `${s.name}` · ${_kind(e)}\n\n');
  if (_deprecated(e)) {
    out.writeln(english ? '**Deprecated.**\n' : '**Deprecado.**\n');
  }
  final summary = _summary(e.documentationComment);
  if (summary != null) out.writeln('$summary\n');
  final lines = <String>[];
  switch (e) {
    case TopLevelFunctionElement():
      lines.add('- `${_short(e.displayString(preferTypeAlias: true))}`');
    case EnumElement():
      lines.add(
        '- ${english ? 'values' : 'valores'}: ${e.constants.map((c) => '`${c.name}`').join(', ')}',
      );
    case InterfaceElement():
      for (final c in e.constructors.where(
        (c) => c.isPublic && !_internalElement(c),
      )) {
        final doc = _summary(c.documentationComment);
        lines.add(
          '- `${_short(c.displayString(preferTypeAlias: true))}`'
          '${_deprecated(c) ? ' (deprecado)' : ''}'
          '${doc == null ? '' : ' — $doc'}',
        );
      }
    default:
  }
  if (lines.isNotEmpty) out.writeln(lines.join('\n'));
  return out.toString();
}

String _short(String signature) => signature.length > 180
    ? '${signature.substring(0, signature.indexOf('(') + 1)}…)'
    : signature;

String? _summary(String? comment) {
  if (comment == null) return null;
  final paragraph = <String>[];
  for (final raw in comment.split('\n')) {
    final line = raw.trim().replaceFirst(RegExp(r'^///\s?'), '');
    if (line.trim().isEmpty || line.trimLeft().startsWith('```')) {
      if (paragraph.isNotEmpty) break;
      continue;
    }
    paragraph.add(line.trim());
  }
  return paragraph.isEmpty ? null : scrubDoc(paragraph.join(' '));
}

/// Whether [e] is a concrete widget: a class an app puts in a `build`.
bool _isWidget(Element e) =>
    e is ClassElement &&
    !e.isAbstract &&
    e.allSupertypes.any(
      (t) =>
          t.element.name == 'Widget' &&
          '${t.element.library.uri}'.startsWith('package:thor_ui/'),
    );

/// The comment as plain text: `///` dropped, paragraphs kept.
String? _docText(String? comment) {
  if (comment == null) return null;
  final text = comment
      .split('\n')
      .map((l) => l.trim().replaceFirst(RegExp(r'^///\s?'), ''))
      .join('\n')
      .trim();
  return text.isEmpty ? null : scrubDoc(text);
}

/// The declaration of [c] as Dart, one parameter per line.
String _signature(String name, ConstructorElement c) {
  final positional = <String>[];
  final named = <String>[];
  final optional = <String>[];
  for (final p in c.formalParameters) {
    final type = _paramType(p);
    final def = p.defaultValueCode == null ? '' : ' = ${p.defaultValueCode}';
    if (p.isNamed) {
      named.add('${p.isRequired ? 'required ' : ''}$type ${p.name}$def');
    } else if (p.isOptionalPositional) {
      optional.add('$type ${p.name}$def');
    } else {
      positional.add('$type ${p.name}');
    }
  }
  if (positional.isEmpty && optional.isEmpty && named.isEmpty) return '$name()';
  // Dart's own layout: positional first, then `[optional]` or `{named}`.
  final head = [
    ...positional,
    if (optional.isNotEmpty) '[${optional.join(', ')}]',
  ];
  final body = StringBuffer(name)..write('(');
  if (head.isNotEmpty) {
    body.write('\n  ${head.join(',\n  ')}');
    body.write(named.isEmpty ? ',\n' : ', {\n');
  } else {
    body.write('{\n');
  }
  if (named.isNotEmpty) {
    body.write('  ${named.join(',\n  ')},\n}');
  }
  return (body..write(')')).toString();
}

String _paramType(FormalParameterElement p) =>
    p.type.getDisplayString().replaceAll('\n', ' ');

/// Where Flutter documents each of `names`: its library (`widgets`, `material`…)
/// by scanning the SDK's sources (`flutter` on the PATH); the recorded
/// answer when there is no SDK.
Map<String, String> _flutterLibraries(Iterable<String> names) {
  final previous = <String, String>{};
  final file = File(_widgetsFile);
  if (file.existsSync()) {
    for (final w in (jsonDecode(file.readAsStringSync()) as List)) {
      final lib = (w as Map)['flutter'];
      if (lib is String) previous[w['name'] as String] = lib;
    }
  }
  final which = Process.runSync('which', ['flutter']);
  final bin = '${which.stdout}'.trim();
  if (which.exitCode != 0 || bin.isEmpty) return previous;
  final root = File(
    bin,
  ).resolveSymbolicLinksSync().replaceFirst(RegExp(r'/bin/flutter$'), '');
  final src = Directory('$root/packages/flutter/lib/src');
  if (!src.existsSync()) return previous;
  final wanted = names.toSet();
  final found = <String, String>{};
  final declaration = RegExp(
    r'^(?:abstract |final |base |sealed |interface |mixin )*class (\w+)',
    multiLine: true,
  );
  // The libraries a widget may live in, the likeliest first.
  for (final lib in [
    'widgets',
    'material',
    'painting',
    'rendering',
    'cupertino',
    'animation',
    'gestures',
    'services',
    'foundation',
  ]) {
    final dir = Directory('${src.path}/$lib');
    if (!dir.existsSync()) continue;
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      for (final m in declaration.allMatches(f.readAsStringSync())) {
        final name = m[1]!;
        if (wanted.contains(name)) found.putIfAbsent(name, () => lib);
      }
    }
  }
  return found;
}

/// `docs/api/widgets.json`: every public widget, for the site's page per
/// widget. Its signature, parameters (with the field's documentation) and
/// where Flutter documents the same widget.
String _widgetsJson(List<_Symbol> api) {
  final widgets = [
    for (final s in api)
      if (s.facade == 'thor_ui' &&
          !_deprecated(s.element) &&
          _isWidget(s.element))
        s,
  ];
  final flutter = _flutterLibraries([for (final w in widgets) w.name]);
  final out = <Map<String, Object?>>[];
  for (final w in widgets) {
    final e = w.element as ClassElement;
    final constructors = <Map<String, Object?>>[];
    for (final c in e.constructors.where(
      (c) => c.isPublic && !_deprecated(c) && !_internalElement(c),
    )) {
      final params = <Map<String, Object?>>[];
      for (final p in c.formalParameters) {
        if (p.name == 'key') continue;
        // The documentation lives on the field a `this.x` fills.
        String? doc;
        if (p is FieldFormalParameterElement) {
          doc = _summary(p.field?.documentationComment);
        }
        doc ??= _summary(
          e.getField(p.name ?? '')?.documentationComment ??
              e.getGetter(p.name ?? '')?.documentationComment,
        );
        params.add({
          'name': p.name,
          'type': _paramType(p),
          'required': p.isRequired,
          'default': p.defaultValueCode,
          'doc': doc,
          if (_deprecated(p)) 'deprecated': true,
        });
      }
      final cname = c.name == null || c.name == 'new' ? '' : '.${c.name}';
      constructors.add({
        'name': '${w.name}$cname',
        'signature': _signature('${w.name}$cname', c),
        'summary': _summary(c.documentationComment),
        'params': params,
      });
    }
    out.add({
      'name': w.name,
      'topic': w.page,
      'summary': _summary(e.documentationComment),
      'doc': _docText(e.documentationComment),
      'flutter': flutter[w.name],
      'constructors': constructors,
    });
  }
  return '${const JsonEncoder.withIndent(' ').convert(out)}\n';
}
