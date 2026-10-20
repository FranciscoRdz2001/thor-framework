@TestOn('vm')
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/server.dart';
import 'package:thor_ui/src/core/render.dart' as core;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _page(Document document) async =>
    utf8.decode((await core.renderPage(document)).body);

void main() {
  setUpAll(initializeThorTests);

  test(
    'defaults: base, charset and viewport, like a Flutter web page',
    () async {
      final html = await _page(const Document(body: Text('x')));
      expect(html, contains('<base href="/"'));
      expect(html, contains('<meta charset="utf-8"'));
      expect(html, contains('name="viewport"'));
    },
  );

  test('null base and viewport are left out, not emitted empty', () async {
    final html = await _page(
      const Document(base: null, viewport: null, body: Text('x')),
    );
    expect(html, isNot(contains('<base')));
    expect(html, isNot(contains('name="viewport"')));
  });

  test('title, lang, meta and head reach the page', () async {
    final html = await _page(
      const Document(
        title: 'My app',
        lang: Locale('es'),
        meta: {'description': 'A sample app'},
        head: [Text('marker')],
        body: Text('x'),
      ),
    );
    expect(html, contains('<html lang="es"'));
    expect(html, contains('<title>My app</title>'));
    expect(html, contains('content="A sample app"'));
    expect(html.indexOf('marker'), lessThan(html.indexOf('<body')));
  });

  test('data in the title or a meta cannot inject markup', () async {
    final html = await _page(
      const Document(
        title: '</title><script>alert(1)</script>',
        meta: {'description': '"><script>alert(2)</script>'},
        body: Text('x'),
      ),
    );
    expect(html, isNot(contains('<script>alert')));
  });
}
