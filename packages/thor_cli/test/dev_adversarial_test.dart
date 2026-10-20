// Adversarial checks of the diagnostics channel of `thor dev`:
// paths with spaces, thousands of findings, lines that are not
// diagnostics, a stale `diagnostics.txt`, hostile text in the page.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thor_cli/src/dev/overlay.dart';
import 'package:thor_cli/src/dev_proxy.dart';
import 'package:thor_cli/src/run.dart';

/// Steps that write what the test says as if `thor_builder:entries` had.
class _Steps extends BuilderSteps {
  _Steps(this.onEntries);
  final void Function(String dir) onEntries;
  var runs = 0;

  @override
  Future<String> entries(String dir, {required bool allFeatures}) async {
    runs++;
    onEntries(dir);
    return '';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late Directory tmp;
  late SourceMap sources;

  File thor(String name) =>
      File(p.join(tmp.path, '.dart_tool', 'thor', name))
        ..createSync(recursive: true);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('thor_adv_');
    File(p.join(tmp.path, 'pubspec.yaml')).writeAsStringSync('name: adv\n');
    File(p.join(tmp.path, 'lib', 'a.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync(List.generate(60, (i) => 'line ${i + 1}').join('\n'));
    sources = SourceMap(appDir: tmp.path, packages: const {});
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  group('a path with spaces is still a diagnostic', () {
    const spaced = 'lib/my pages/home page.dart';

    test('a warning there does not fail a build', () {
      expect(
        diagnosticErrors(['$spaced:3:1: Warning: x (THOR-S013)']),
        isEmpty,
      );
      expect(diagnosticErrors(['$spaced:3:1: Error: x']), hasLength(1));
    });

    test('the overlay entry has its file and line', () {
      File(p.join(tmp.path, spaced))
        ..createSync(recursive: true)
        ..writeAsStringSync('a\nb\nc\nd\n');
      final e = compileEntries(
        'diagnostics',
        't',
        '$spaced:3:1: Warning: x (THOR-S013) fix',
        sources,
      ).single;
      expect(e['severity'], 'warning');
      expect((e['at']! as Map)['line'], 3);
      expect((e['at']! as Map)['file'], spaced);
    });
  });

  group('thousands of findings', () {
    late List<String> lines;
    setUp(() {
      File(p.join(tmp.path, 'lib', 'big.dart')).writeAsStringSync(
        List.generate(30000, (i) => 'line ${i + 1} ' * 6).join('\n'),
      );
      lines = [
        for (var i = 1; i <= 10000; i++)
          'lib/big.dart:${i * 2}:1: Warning: finding $i (THOR-S011) fix `a`',
      ];
    });

    test('are read in a moment and the page carries a bounded overlay', () {
      final clock = Stopwatch()..start();
      final entries = compileEntries(
        'diagnostics',
        't',
        lines.join('\n'),
        sources,
      );
      final script = overlayScript(entries);
      expect(clock.elapsed, lessThan(const Duration(seconds: 5)));
      expect(script.length, lessThan(400 * 1024));
      expect(script, contains('more'), reason: 'says how many are not shown');
    });

    test('an error is never the one cut', () {
      final entries = compileEntries(
        'diagnostics',
        't',
        '${lines.join('\n')}\nlib/a.dart:9:1: Error: the one that matters',
        sources,
      );
      expect(overlayScript(entries), contains('the one that matters'));
    });

    test('when errors are cut too, the rest is an error', () {
      final entries = compileEntries(
        'diagnostics',
        't',
        [
          for (var i = 1; i <= 300; i++) 'lib/a.dart:$i:1: Error: e$i',
        ].join('\n'),
        sources,
      );
      expect(
        overlayScript(entries),
        contains(
          '"severity":"error","message":"'
          '201 more',
        ),
      );
    });

    test('a minified line is cut in the code shown', () {
      File(p.join(tmp.path, 'lib', 'min.dart')).writeAsStringSync('x' * 500000);
      final e = compileEntries(
        'diagnostics',
        't',
        'lib/min.dart:1:1: Error: long',
        sources,
      );
      expect(jsonEncode(e).length, lessThan(20000));
    });
  });

  group('lines that are not diagnostics', () {
    test('next to a good one they are errors too, not dropped', () {
      final entries = compileEntries(
        'diagnostics',
        't',
        'lib/a.dart:1:1: Warning: fine\nsomething broke badly',
        sources,
        keepUnparsed: true,
      );
      expect(entries.map((e) => e['severity']), ['warning', 'error']);
      expect(entries.last['message'], 'something broke badly');
    });

    test('a compiler output keeps its noise out by default', () {
      final entries = compileEntries(
        'compile',
        't',
        'Compiling…\nlib/a.dart:1:1: Error: bad\nDone.',
        sources,
      );
      expect(entries, hasLength(1));
    });
  });

  group('a diagnostics.txt of an old run', () {
    const error = 'lib/a.dart:1:1: Error: old\n';
    final now = DateTime.now();

    File wrote(String text, {required DateTime source, DateTime? tool}) {
      File(p.join(tmp.path, 'lib', 'a.dart')).setLastModifiedSync(source);
      return thor('diagnostics.txt')
        ..writeAsStringSync(text)
        ..setLastModifiedSync(tool ?? now);
    }

    Future<void> build() =>
        generate(tmp.path, strict: true, warn: false, steps: _Steps((_) {}));

    test('about code that changed since does not fail the build', () async {
      wrote(error, source: now.add(const Duration(minutes: 1)));
      await build();
      expect(staleDiagnostics(tmp.path), hasLength(1));
    });

    test('about a file that is gone does not either', () async {
      wrote('lib/gone.dart:1:1: Error: old\n', source: now);
      await build();
    });

    test('about code as it was when the tool ran does fail it', () async {
      wrote(error, source: now.subtract(const Duration(minutes: 1)));
      expect(build(), throwsA(isA<Exception>()));
    });

    test('a line that names no file always fails it', () async {
      wrote('something broke\n', source: now.add(const Duration(minutes: 1)));
      expect(build(), throwsA(isA<Exception>()));
    });

    test('state_misuses.txt is the builder\'s: never stale', () async {
      wrote('', source: now);
      thor('state_misuses.txt').writeAsStringSync(error);
      File(
        p.join(tmp.path, 'lib', 'a.dart'),
      ).setLastModifiedSync(now.add(const Duration(minutes: 1)));
      expect(build(), throwsA(isA<Exception>()));
    });

    test('dev keeps showing it (the file is the tool\'s)', () {
      wrote(error, source: now.add(const Duration(minutes: 1)));
      expect(diagnostics(tmp.path), hasLength(1));
    });
  });

  group('hostile text', () {
    test('markup, a closing script and bidi controls are data', () {
      final e = compileEntries(
        'diagnostics',
        't',
        'lib/a.dart:2:1: Error: </script><img src=x onerror=1> \u202Eevil '
            '\u2028 (THOR-S011 · https://x.dev/a"onmouseover="1) `</script>`',
        sources,
      );
      final script = overlayScript(e);
      // Only the closing tag of the overlay's own script.
      expect('</script>'.allMatches(script), hasLength(1));
      expect(script, isNot(contains('\u202E')), reason: 'bidi override');
    });
  });

  group('the proxy in front of the app, with a finding on the page', () {
    late HttpServer app;
    late DevProxy proxy;
    final client = HttpClient();
    final seen = <String>[];

    setUp(() async {
      seen.clear();
      app = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      app.listen((r) async {
        final body = await utf8.decodeStream(r);
        seen.add(
          '${r.method} ${r.uri.path} ${r.headers.value('if-none-match')}'
          ' [$body]',
        );
        final res = r.response;
        switch (r.uri.path) {
          case '/form':
            res
              ..statusCode = HttpStatus.seeOther
              ..headers.set(HttpHeaders.locationHeader, '/done')
              ..headers.add(HttpHeaders.setCookieHeader, 'a=1; Path=/')
              ..headers.add(HttpHeaders.setCookieHeader, 'b=2; Path=/');
          case '/app.js':
            if (r.headers.value('if-none-match') == '"js1"') {
              res.statusCode = HttpStatus.notModified;
            } else {
              res
                ..headers.contentType = ContentType('text', 'javascript')
                ..headers.set(HttpHeaders.etagHeader, '"js1"')
                ..headers.set(HttpHeaders.cacheControlHeader, 'max-age=600')
                ..write('1');
            }
          case '/latin':
            res
              ..headers.contentType = ContentType(
                'text',
                'html',
                charset: 'iso-8859-1',
              )
              ..add([
                ...utf8.encode('<html><body>caf'),
                0xE9,
                ...utf8.encode('</body></html>'),
              ]);
          default:
            res
              ..headers.contentType = ContentType.html
              ..write('<html><body>hola</body></html>');
        }
        await res.close();
      });
      proxy = DevProxy(upstream: app.port, sources: sources);
      await proxy.start(0);
      proxy.ready();
      proxy.problem('diagnostics', 't', 'lib/a.dart:1:1: Error: boom');
    });
    tearDown(() async {
      await proxy.close();
      await app.close(force: true);
    });

    test('a form post redirects as the app said, cookies and all', () async {
      final req = await client.post('localhost', proxy.port, '/form');
      req.followRedirects = false;
      req.headers
        ..set(HttpHeaders.acceptHeader, 'text/html')
        ..set(
          HttpHeaders.contentTypeHeader,
          'application/x-www-form-urlencoded',
        );
      req.write('x=1');
      final r = await req.close();
      await r.drain<void>();
      expect(r.statusCode, HttpStatus.seeOther);
      expect(r.headers.value(HttpHeaders.locationHeader), '/done');
      expect(r.headers[HttpHeaders.setCookieHeader], hasLength(2));
      expect(seen.single, 'POST /form null [x=1]');
    });

    test(
      'an asset is still revalidated: a 304 and its cache headers',
      () async {
        final req = await client.get('localhost', proxy.port, '/app.js');
        req.headers.set(HttpHeaders.ifNoneMatchHeader, '"js1"');
        final r = await req.close();
        await r.drain<void>();
        expect(r.statusCode, HttpStatus.notModified);
        final first = await (await client.get(
          'localhost',
          proxy.port,
          '/app.js',
        )).close();
        await first.drain<void>();
        expect(
          first.headers.value(HttpHeaders.cacheControlHeader),
          'max-age=600',
        );
        expect(first.headers.value(HttpHeaders.etagHeader), '"js1"');
      },
    );

    test('a page in another charset is shown, not a bad gateway', () async {
      final r = await (await client.get(
        'localhost',
        proxy.port,
        '/latin',
      )).close();
      expect(r.statusCode, 200);
      expect(await utf8.decodeStream(r), contains('café'));
    });

    test('HEAD of a page answers with headers only', () async {
      final r = await (await client.head('localhost', proxy.port, '/')).close();
      expect(r.statusCode, 200);
      expect(r.headers.value(HttpHeaders.cacheControlHeader), 'no-store');
    });
  });
}
