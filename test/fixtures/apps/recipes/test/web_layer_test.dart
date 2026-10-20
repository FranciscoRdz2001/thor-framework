// The same screen in three modes — Flutter widgets (/card, /panel), the
// web layer's `Style` (/web/…/style) and its utilities (/web/…) — renders
// the same number of elements, and `Style` and `tw()` write the same
// declarations for each one. Prints the sizes (`dart test -r expanded`).
import 'dart:convert';
import 'dart:io';

import 'package:recipes/app.dart';
import 'package:recipes/router.dart';
import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';
import 'package:thor_ui/router.dart';

void main() {
  final handler = RouteHandler(
    routes: router.routes,
    renderer: recipesRenderer(),
  );

  Future<String> get(String path) async {
    final r = await handler.client().get(path);
    expect(r.status, 200, reason: path);
    return r.text;
  }

  for (final (name, flutter, style, tw) in [
    ('card', '/card', '/web/card/style', '/web/card'),
    ('panel', '/panel', '/web/panel/style', '/web/panel'),
  ]) {
    test(
      '$name: three modes, same elements; Style and tw() the same CSS',
      () async {
        final pages = {
          'Flutter': _Page(await get(flutter)),
          'Style': _Page(await get(style)),
          'tw()': _Page(await get(tw)),
        };
        final elements = {
          for (final e in pages.entries) e.key: e.value.elements.length,
        };
        // The web layer never adds an element over the Flutter widgets but
        // one: the layout's `Container` around the page merges into a
        // Flutter page's `Column`, not into a web `FlexBox`.
        expect(elements['Style'], elements['tw()']);
        expect(elements['tw()']!, lessThanOrEqualTo(elements['Flutter']! + 1));
        expect(
          pages['Style']!.declarationsPerElement,
          pages['tw()']!.declarationsPerElement,
        );
        stdout.writeln(
          '\n$name            elements  main HTML gz  its CSS gz  page gz',
        );
        for (final e in pages.entries) {
          final p = e.value;
          stdout.writeln(
            '  ${e.key.padRight(8)}  ${'${elements[e.key]}'.padLeft(8)}  '
            '${'${p.mainGz}'.padLeft(12)}  ${'${p.cssGz}'.padLeft(10)}  '
            '${'${p.pageGz}'.padLeft(7)}',
          );
        }
      },
    );
  }
}

class _Page {
  _Page(this.html);

  final String html;

  /// The page's own content: what `<main>` holds.
  String get main {
    final start = html.indexOf('<main');
    return html.substring(start, html.indexOf('</main>', start) + 7);
  }

  /// The start tags inside `<main>` (not counting it).
  List<String> get elements => [
    for (final m in RegExp(r'<([a-z][a-z0-9]*)\b[^>]*>').allMatches(main))
      if (m[1] != 'template') m[0]!,
  ].skip(1).toList();

  static String _classOf(String tag) =>
      RegExp(r'class="([^"]*)"').firstMatch(tag)?[1] ?? '';

  String get _css {
    final start = html.indexOf('<style id="thor-styles">');
    return html.substring(start, html.indexOf('</style>', start));
  }

  /// Each element's declarations (with the condition they apply in), as a
  /// sorted set: order and class names aside, what the element gets.
  List<List<String>> get declarationsPerElement => [
    for (final tag in elements)
      ([
        for (final cls in _classOf(tag).split(' '))
          if (cls.isNotEmpty) ..._declarationsOf(cls),
      ]..sort()),
  ];

  List<String> _declarationsOf(String cls) {
    final out = <String>[];
    // `@media …{.c{…}}`, `.c:hover{…}`, `.c{…}` inside the layers.
    final rule = RegExp(
      r'(@(?:media|container)[^{]*\{)?([^{}]*\.' +
          cls +
          r'(?=[\s{:,])[^{}]*)\{([^}]*)\}',
    );
    for (final m in rule.allMatches(_css)) {
      final at = (m[1] ?? '').replaceAll('{', '');
      final selector = m[2]!.replaceAll(RegExp('^.*\\.$cls'), '');
      for (final d in m[3]!.split(';')) {
        if (d.trim().isNotEmpty) out.add('$at$selector ${d.trim()}');
      }
    }
    return out;
  }

  int _gz(String s) => gzip.encode(utf8.encode(s)).length;

  int get mainGz => _gz(main);

  /// The CSS of the classes `<main>` uses.
  int get cssGz => _gz(
    {
      for (final tag in elements)
        for (final cls in _classOf(tag).split(' '))
          if (cls.isNotEmpty) ..._declarationsOf(cls),
    }.join('\n'),
  );

  int get pageGz => _gz(html);
}
