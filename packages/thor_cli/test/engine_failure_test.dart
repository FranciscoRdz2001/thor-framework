// A build of the engine that fails in `thor dev` is loud ON the page (the
// app keeps being served, but nothing in it would work): an error with the
// THOR code, the message, file:line and what the page does now; in the
// browser's console too; gone with the next good build.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_cli/src/dev/engine_failure.dart';
import 'package:thor_cli/src/dev/overlay.dart';
import 'package:thor_cli/src/dev_proxy.dart';

const _url = 'https://thor-docs.vercel.app/errores/THOR-B012';

String _report(List<String> constructs) =>
    'dart run thor_builder:lite_state . build/lite/state.js --readable failed (1)\n'
    '${constructs.length} construct(s) outside the thor-lite subset:\n'
    '${constructs.map((c) => '$c\n  14 | code\n     | ^\n  fix: rewrite $c.').join('\n')}\n'
    'Move that work to the server: a `query(fn)`. (THOR-B012 · $_url)';

void main() {
  final sources = SourceMap(
    appDir: Directory.systemTemp.path,
    packages: const {},
  );

  group('EngineFailure', () {
    test('a lite build report becomes entries with code, file, line', () {
      final f = EngineFailure.of(
        'lite engine',
        _report([
          'lib/a.dart:14:22: unawaited (dart:async) is not in the lite subset.',
        ]),
        stale: false,
      );
      expect(f.code, 'THOR-B012');
      expect(f.title, contains('WITHOUT its engine'));
      expect(f.title, contains('interactivity disabled'));
      expect(f.banner, contains('ENGINE BUILD FAILED · THOR-B012'));
      final e = compileEntries('engine', f.title, f.detail, sources).single;
      expect(e['severity'], 'error');
      expect(e['code'], 'THOR-B012');
      expect(e['message'], contains('unawaited'));
      expect(e['fix'], startsWith('rewrite'));
    });

    test('two states failing are two entries', () {
      final f = EngineFailure.of(
        'lite engine',
        _report([
          'lib/a.dart:14:22: unawaited is not in the lite subset.',
          'lib/b.dart:3:5: Isolate is not in the lite subset.',
        ]),
        stale: false,
      );
      final entries = compileEntries('engine', f.title, f.detail, sources);
      expect(entries, hasLength(2));
      expect(entries.map((e) => e['code']), everyElement('THOR-B012'));
    });

    test('a failure after a good build says the engine is outdated', () {
      final f = EngineFailure.of(
        'lite engine',
        _report(['lib/a.dart:1:1: x.']),
        stale: true,
      );
      expect(f.title, contains('OUTDATED'));
      expect(f.title, isNot(contains('WITHOUT')));
    });

    test('a report that is not a list of constructs is kept whole', () {
      final f = EngineFailure.of('engine', 'boom\nbam', stale: false);
      expect(f.detail, 'boom\nbam');
      expect(f.code, isNull);
      expect(f.banner, contains('ENGINE BUILD FAILED'));
    });

    test('a dart2js error line keeps its own form', () {
      const out = 'lib/a.dart:1:1: Error: nope';
      expect(EngineFailure.of('engine', out, stale: false).detail, out);
    });

    test('a path with spaces or unicode is still a located construct', () {
      final f = EngineFailure.of(
        'lite engine',
        _report(['lib/mi módulo/estado ñ.dart:14:22: unawaited is out.']),
        stale: false,
      );
      final e = compileEntries('engine', f.title, f.detail, sources).single;
      expect(e['code'], 'THOR-B012');
      expect(e['message'], 'unawaited is out.');
      expect((e['at']! as Map)['file'], 'lib/mi módulo/estado ñ.dart');
    });

    test('a huge report is cut, not sent to every page whole', () {
      final f = EngineFailure.of(
        'engine',
        List.filled(20000, 'noise line of the compiler').join('\n'),
        stale: false,
      );
      expect(f.detail.length, lessThan(20000));
      expect(f.detail, isNotEmpty);
    });

    test('an empty report still says something', () {
      final f = EngineFailure.of('engine', '  \n', stale: false);
      expect(f.detail.trim(), isNotEmpty);
    });
  });

  group('on the page', () {
    late HttpServer app;
    late DevProxy proxy;
    final client = HttpClient();

    setUp(() async {
      app = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      app.listen((r) async {
        r.response
          ..headers.contentType = ContentType.html
          ..write('<html><body><p>hi</p></body></html>');
        await r.response.close();
      });
      proxy = DevProxy(upstream: app.port, sources: sources);
      await proxy.start(0);
      proxy.ready();
    });
    tearDown(() async {
      await proxy.close();
      await app.close(force: true);
    });

    Future<String> page() async {
      final req = await client.get('localhost', proxy.port, '/');
      return utf8.decodeStream(await req.close());
    }

    void fail(String file, {bool stale = false}) {
      final f = EngineFailure.of(
        'lite engine',
        _report(['$file:14:22: unawaited is not in the lite subset.']),
        stale: stale,
      );
      proxy.problem('engine', f.title, f.detail);
    }

    test('error, then fixed: gone; broken again: back', () async {
      expect(await page(), isNot(contains('__thorDevErrors')));
      fail('lib/a.dart');
      var html = await page();
      expect(html, contains('__thorDevErrors'));
      expect(html, contains('THOR-B012'));
      expect(html, contains('WITHOUT its engine'));
      expect(html, contains('console.error'));
      proxy.clearProblem('engine');
      expect(await page(), isNot(contains('__thorDevErrors')));
      fail('lib/a.dart');
      html = await page();
      expect(html, contains('THOR-B012'));
    });

    test(
      'HTML and </script> in a report cannot break out of the page',
      () async {
        const evil = '</script><img src=x onerror=alert(1)>"\'';
        final f = EngineFailure.of(
          'lite engine',
          _report(['lib/a.dart:14:22: $evil']),
          stale: false,
        );
        proxy.problem('engine', f.title, f.detail);
        final html = await page();
        final from = html.indexOf('<script id="thor-dev-overlay">');
        final to = html.indexOf('</script>', from);
        // The overlay's script ends at its own closing tag, after its code.
        expect(html.substring(from, to), contains('console.error'));
        expect(html.substring(from, to), isNot(contains('<img')));
        expect(html, isNot(contains('<img src=x')));
      },
    );

    test('a huge report keeps the page small', () async {
      final f = EngineFailure.of(
        'engine',
        List.filled(200000, 'noise line of the compiler').join('\n'),
        stale: false,
      );
      proxy.problem('engine', f.title, f.detail);
      expect((await page()).length, lessThan(200000));
    });

    test('the same failure again does not reload the pages', () async {
      fail('lib/a.dart');
      final stamp = proxy.stamp;
      fail('lib/a.dart');
      expect(proxy.stamp, stamp);
      fail('lib/b.dart');
      expect(proxy.stamp, isNot(stamp));
    });

    test('an engine error with a warning of the diagnostics channel', () async {
      proxy.problem(
        'diagnostics',
        'Problem in your code',
        'lib/w.dart:1:1: Warning: careful (THOR-S013 · https://thor-docs.vercel.app/errores/THOR-S013) Use `Watch`.',
        strict: true,
      );
      fail('lib/a.dart');
      var html = await page();
      expect(html, contains('careful'));
      expect(html, contains('THOR-B012'));
      // The engine is fixed: the warning stays, the error goes.
      proxy.clearProblem('engine');
      html = await page();
      expect(html, contains('careful'));
      expect(html, isNot(contains('THOR-B012')));
    });
  });
}
