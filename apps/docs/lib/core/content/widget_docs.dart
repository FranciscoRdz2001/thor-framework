/// The page per widget: every public widget of `thor_ui`, from
/// `docs/api/widgets.json` (written by `tool/thor docs`: signature,
/// parameters and documentation straight from the code), as Markdown the
/// site renders like a guide.
library;

import 'dart:convert';
import 'dart:io';

import '../../modules/api/api_routes.dart' show apiWidgetRoute;
import '../i18n/docs_locale.dart';
import 'library.dart';
import 'widget_summaries.dart';

/// A constructor of a widget.
class ConstructorDoc {
  /// A constructor.
  const ConstructorDoc(this.name, this.signature, this.summary, this.params);

  /// `Container`, `FilledButton.icon`.
  final String name;

  /// Its declaration, as Dart.
  final String signature;

  /// What it does, in one sentence.
  final String? summary;

  /// Its parameters (without `key`).
  final List<ParamDoc> params;
}

/// A parameter of a constructor.
class ParamDoc {
  /// A parameter.
  const ParamDoc(
    this.name,
    this.type,
    this.isRequired,
    this.defaultValue,
    this.doc, {
    this.deprecated = false,
  });

  /// Its name.
  final String name;

  /// Its type.
  final String type;

  /// Whether it must be given.
  final bool isRequired;

  /// Its default, as written.
  final String? defaultValue;

  /// What it does.
  final String? doc;

  /// Whether the code marks it `@Deprecated`.
  final bool deprecated;
}

/// A public widget.
class WidgetDoc {
  /// A widget.
  const WidgetDoc({
    required this.name,
    required this.topic,
    required this.doc,
    required this.flutter,
    required this.constructors,
  });

  /// Its class name.
  final String name;

  /// The topic of the reference it is listed under (`layout`, `material`…).
  final String topic;

  /// Its documentation comment, as Markdown (dartdoc references included).
  final String? doc;

  /// The library that documents the same widget in Flutter (`widgets`,
  /// `material`…), or null when Flutter has no such class.
  final String? flutter;

  /// Its constructors, the unnamed one first.
  final List<ConstructorDoc> constructors;

  /// Its URL.
  String get path => apiWidgetRoute.link({
    'package': apiPackages.first,
    'folder': topic,
    'name': name,
  });

  /// Where Flutter documents it, or null.
  String? get flutterUrl => flutter == null
      ? null
      : 'https://api.flutter.dev/flutter/$flutter/$name-class.html';
}

final _cache = <String, List<WidgetDoc>>{};

/// Every public widget, by name.
List<WidgetDoc> widgetDocs({String? dir}) {
  final root = dir ?? docsDir();
  return _cache[root] ??= () {
    final file = File('$root/api/widgets.json');
    if (!file.existsSync()) return const <WidgetDoc>[];
    return [
      for (final w
          in (jsonDecode(file.readAsStringSync()) as List)
              .cast<Map<String, Object?>>())
        _widget(w),
    ];
  }();
}

WidgetDoc _widget(Map<String, Object?> w) => WidgetDoc(
  name: w['name']! as String,
  topic: w['topic']! as String,
  doc: w['doc'] as String?,
  flutter: w['flutter'] as String?,
  constructors: [
    for (final c in (w['constructors']! as List).cast<Map<String, Object?>>())
      ConstructorDoc(
        c['name'] as String,
        c['signature'] as String,
        c['summary'] as String?,
        [
          for (final p in (c['params'] as List).cast<Map<String, Object?>>())
            ParamDoc(
              p['name'] as String,
              p['type'] as String,
              p['required'] as bool,
              p['default'] as String?,
              p['doc'] as String?,
              deprecated: p['deprecated'] == true,
            ),
        ],
      ),
  ],
);

/// The widget [name] of [topic], or null.
WidgetDoc? widgetDoc(String topic, String name, {String? dir}) {
  for (final w in widgetDocs(dir: dir)) {
    if (w.name == name && w.topic == topic) return w;
  }
  return null;
}

/// The ids of the guide's live examples that show [widget]
/// (`cat-filled-button` for `FilledButton`, and its `-variants` and
/// `-states`), among [available].
List<String> exampleIdsFor(String widget, Iterable<String> available) {
  final kebab = widget
      .replaceAllMapped(RegExp('(?<=[a-z0-9])([A-Z])'), (m) => '-${m[1]}')
      .toLowerCase();
  final base = 'cat-$kebab';
  return [
    for (final id in available)
      if (id == base || id == '$base-variants' || id == '$base-states') id,
  ]..sort();
}

/// The Markdown of the page of [w]: what it is, its live [examples], its
/// signatures and parameters, and where Flutter documents it.
String widgetMarkdown(
  WidgetDoc w,
  AppLocalizations t, {
  List<String> examples = const [],
}) {
  final b = StringBuffer('# ${w.name}\n\n');
  final doc = _dartdoc(localizedWidgetDoc(t.localeName, w.name, w.doc ?? ''));
  b.writeln(doc.isEmpty ? t.widgetDefaultDoc(w.name) : doc);
  if (examples.isNotEmpty) {
    b.writeln('\n## ${t.widgetExampleHeading}\n');
    for (final id in examples) {
      b.writeln(':::example $id\n:::\n');
    }
  }
  b.writeln('\n## ${t.widgetSignatureHeading}\n');
  for (final c in w.constructors) {
    if (w.constructors.length > 1) {
      b.writeln('### `${c.name}`\n');
      if (c.summary != null) b.writeln('${_dartdoc(c.summary!)}\n');
    }
    b.writeln('```dart\n${c.signature}\n```\n');
  }
  void table(ConstructorDoc c) {
    // A table whose parameters say nothing drops its "what it does" column:
    // an empty column reads as an unfinished page. A blank row is a dash.
    final described = c.params.any((p) => (p.doc ?? '').trim().isNotEmpty);
    b.writeln(
      '| ${t.widgetColParam} | ${t.widgetColType} |'
      '${described ? ' ${t.widgetColDoc} |' : ''}',
    );
    b.writeln('| --- | ---${described ? ' | ---' : ''} |');
    for (final p in c.params) {
      final name = [
        '`${p.name}`',
        if (p.isRequired) t.widgetRequired,
        if (p.deprecated) '**${t.widgetDeprecated}**',
      ].join(' ');
      final type = p.defaultValue == null
          ? '`${_cell(p.type)}`'
          : '`${_cell(p.type)}` = `${_cell(p.defaultValue!)}`';
      final text = _cell(_dartdoc(p.doc ?? '')).trim();
      b.writeln(
        '| $name | $type |'
        '${described ? ' ${text.isEmpty ? '—' : text} |' : ''}',
      );
    }
  }

  final main = w.constructors.firstOrNull;
  if (main != null && main.params.isNotEmpty) {
    b.writeln('## ${t.widgetParamsHeading}\n');
    table(main);
  }
  // Each named constructor has its own parameters (`FilledButton.icon`
  // takes an `icon` and a `label`, not a `child`).
  for (final c in w.constructors.skip(1)) {
    if (c.params.isEmpty) continue;
    b.writeln('\n### ${t.widgetParamsOf(c.name)}\n');
    table(c);
  }
  b.writeln('\n## ${t.widgetInFlutterHeading}\n');
  final url = w.flutterUrl;
  b.writeln(
    url == null
        ? t.widgetFlutterNone(w.name)
        : t.widgetFlutterSame(w.name, url),
  );
  return b.toString();
}

/// A dartdoc `[reference]` as code (`[child]` → `` `child` ``); links with a
/// target and code spans are left as they are.
String _dartdoc(String text) => text.replaceAllMapped(
  RegExp(r'(`[^`]*`)|\[([A-Za-z_][\w.<>?]*)\](?![(\[])'),
  (m) => m[1] ?? '`${m[2]}`',
);

String _cell(String text) => text.replaceAll('|', r'\|').replaceAll('\n', ' ');

/// The rendered page of [w], with [examples] shown.
DocPage widgetPage(
  WidgetDoc w,
  AppLocalizations t, {
  List<String> examples = const [],
}) => renderMarkdown(
  widgetMarkdown(w, t, examples: examples),
  source: 'docs/api/widgets.json',
  fileDir: 'api',
  locale: t.localeName,
);
