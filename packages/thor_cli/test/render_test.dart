// `thor render`: the report read from a page (pure), the arguments, and
// one real render of test/fixtures/apps/realworld without a browser.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thor_cli/src/commands/render.dart';
import 'package:thor_cli/src/render/render.dart';
import 'package:thor_cli/thor_cli.dart';

import 'support/generated.dart';

const _page =
    '<!DOCTYPE html><html><head><style>.a{color:red}</style>'
    '<link rel="stylesheet" href="/_thor/styles.1.css"></head><body>'
    '<header><nav aria-label="Principal"><a href="/">Inicio</a></nav></header>'
    '<main><h1>Artículos <b>nuevos</b></h1>'
    '<img src="x.png"><img src="y.png" alt="Logo">'
    '<form><input type="hidden" name="csrf"><input name="email" '
    'placeholder="Correo"><button>Entrar</button></form>'
    '<script>const t = "<h2>no</h2>";</script>'
    '<!-- <h3>comment</h3> --></main>'
    '<script type="application/json" id="thor-dev-error">'
    '{"phase":"load","type":"StateError","message":"boom (THOR-S003)"}'
    '</script></body></html>';

void main() {
  group('report', () {
    final report = RenderReport(target: '/', status: 200, html: _page);

    test('the outline reads landmarks, names and missing alts', () {
      final outline = staticOutline(_page);
      expect(outline, contains('- banner'));
      expect(outline, contains('  - navigation "Principal"'));
      expect(outline, contains('    - link "Inicio" → /'));
      expect(outline, contains('- heading 1 "Artículos nuevos"'));
      expect(outline, contains('- img (no alt!)'));
      expect(outline, contains('- img "Logo"'));
      expect(outline, contains('- input[text] "Correo"'));
      expect(outline, contains('- button "Entrar"'));
      // Hidden inputs, scripts and comments are not the page.
      expect(outline, isNot(contains('csrf')));
      expect(outline, isNot(contains('heading 2')));
      expect(outline, isNot(contains('comment')));
    });

    test('server errors and their codes', () {
      expect(report.serverErrors.single['type'], 'StateError');
      expect(report.codes, {'THOR-S003'});
      expect(report.toText(), contains('/errores/THOR-S003'));
    });

    test('a broken error block is ignored, not a crash', () {
      final broken = RenderReport(
        target: '/',
        status: 500,
        html:
            '<script type="application/json" id="thor-dev-error">{nope'
            '</script>',
      );
      expect(broken.serverErrors, isEmpty);
    });

    test('JSON: sizes always, texts only when full', () {
      final full = report.toJson();
      expect((full['html']! as Map)['text'], _page);
      expect((full['css']! as Map)['text'], contains('.a{color:red}'));
      final short = report.toJson(full: false);
      expect((short['html']! as Map).containsKey('text'), isFalse);
      expect((short['html']! as Map)['gzip'], greaterThan(0));
      // Survives a round trip (what the MCP server sends).
      expect(jsonDecode(jsonEncode(full)), isA<Map<String, Object?>>());
    });

    test('the browser result wins over the static outline', () {
      final withBrowser = RenderReport(
        target: '/',
        status: 200,
        html: _page,
        browser: BrowserResult.fromJson({
          'aria': '- main',
          'warnings': [
            {
              'widget': 'Row',
              'message': 'Expanded in a Row without a width (THOR-L001)',
              'source': '/app/lib/x.dart:3:1',
            },
          ],
          'console': ['error: x'],
          'screenshots': [
            {'width': 390, 'path': '/o/390.png', 'overflowX': true},
          ],
        }),
      );
      expect(withBrowser.accessibility, '- main');
      expect(withBrowser.codes, containsAll(['THOR-L001', 'THOR-S003']));
      expect(withBrowser.toText(), contains('⚠ horizontal scroll'));
      expect(withBrowser.toText(), contains('/app/lib/x.dart:3:1'));
    });
  });

  // A launcher that prints before thor (`dart pub global
  // run` resolving) broke `thor render --json > page.json`.
  group('output', () {
    final report = RenderReport(target: '/', status: 200, html: _page);

    test('--report writes the JSON to a file; stdout gets none', () async {
      final dir = Directory.systemTemp.createTempSync('thor_render');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = p.join(dir.path, 'page.json');
      final out = StringBuffer();
      writeRenderOutput(report, out: out, file: file);
      final json = jsonDecode(File(file).readAsStringSync()) as Map;
      expect(json['status'], 200);
      expect(out.toString(), isNot(contains('{')));
    });

    test('--json alone is the JSON on stdout', () {
      final out = StringBuffer();
      writeRenderOutput(report, out: out, json: true);
      expect(jsonDecode(out.toString()), isA<Map<String, Object?>>());
    });
  });

  group('arguments', () {
    test('cookies are name=value', () {
      expect(parseCookies(['s=a=b', 'lang=es']), {'s': 'a=b', 'lang': 'es'});
      expect(() => parseCookies(['=x']), throwsA(isA<ThorException>()));
      expect(() => parseCookies(['plain']), throwsA(isA<ThorException>()));
    });

    test('widths are sane numbers', () {
      expect(parseWidths('390, 1440'), [390, 1440]);
      for (final bad in ['', 'wide', '100', '390,,800', '99999']) {
        expect(() => parseWidths(bad), throwsA(isA<ThorException>()));
      }
    });

    test('only the app\'s own stylesheets are fetched', () {
      expect(
        localStylesheets(
          '<link rel="stylesheet" href="/_thor/a.css">'
          '<link href="//fonts.example/css" rel="stylesheet">'
          '<link rel="stylesheet" href="https://cdn.example/b.css">'
          '<link rel="icon" href="/favicon.png">',
        ).toList(),
        ['/_thor/a.css'],
      );
    });

    test('a widget entry calls the name (class or function) in ThorApp', () {
      final entry = widgetEntry(Uri.file('/app/lib/card.dart'), 'Card');
      expect(entry, contains("import 'file:///app/lib/card.dart' as target;"));
      expect(entry, contains('ThorApp(child: target.Card())'));
      expect(entry, isNot(contains('registerThorStates')));
      // An app with states: registered before the render.
      final withStates = widgetEntry(
        Uri.file('/app/lib/card.dart'),
        'Card',
        states: true,
      );
      expect(withStates, contains("import '../states.dart';"));
      expect(
        withStates.indexOf('registerThorStates();'),
        lessThan(withStates.indexOf('renderDocument(')),
      );
    });
  });

  test(
    'a real route: status, HTML with sources, no process left',
    () async {
      final app = Project.find(
        p.join('..', '..', 'test', 'fixtures', 'apps', 'realworld'),
      )!;
      // A clean checkout has no generated registries yet.
      await generateOnce(app.dir);
      final report = await render(
        app,
        const RenderRequest('/login', browser: false, codegen: false),
      );
      expect(report.status, 200);
      expect(report.html, contains('data-thor-src="${app.dir}'));
      expect(report.accessibility, contains('button'));
      expect(report.serverErrors, isEmpty);
      final missing = await render(
        app,
        const RenderRequest('/no/such/page', browser: false, codegen: false),
      );
      expect(missing.status, 404);
      // The server is gone.
      final ps = Process.runSync('pgrep', ['-f', 'realworld.*bin/server']);
      expect('${ps.stdout}'.trim(), isEmpty);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('a widget that does not exist is a clear error', () async {
    final app = Project.find(
      p.join('..', '..', 'test', 'fixtures', 'apps', 'realworld'),
    )!;
    expect(
      () => render(
        app,
        const RenderRequest('lib/nope.dart#X', widget: true, codegen: false),
      ),
      throwsA(
        isA<ThorException>().having(
          (e) => e.message,
          'message',
          'No file '
              '${p.join(app.dir, 'lib', 'nope.dart')}.',
        ),
      ),
    );
    expect(
      () => render(app, const RenderRequest('lib/x.dart', widget: true)),
      throwsA(isA<ThorException>()),
    );
  });
}
