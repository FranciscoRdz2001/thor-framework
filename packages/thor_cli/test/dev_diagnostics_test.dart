// The diagnostics channel of `thor dev`: what a lint or a build
// finds is shown ON the page, as an error (overlay) or a warning (badge),
// with file:line, message, fix and the code's page; nothing is added when
// there is nothing to show.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thor_cli/src/dev/inspect.dart';
import 'package:thor_cli/src/dev/overlay.dart';
import 'package:thor_cli/src/dev_proxy.dart';
import 'package:thor_cli/src/run.dart';

const _s011 =
    "lib/pages/home.dart:29:28: Error: The closure passed to 'onPressed' "
    "uses a ThorState, and the browser can't run a function. "
    '(THOR-S011 · https://thor-docs.vercel.app/errores/THOR-S011) '
    'Pass `counter.increment`.';

void main() {
  late Directory tmp;
  late SourceMap sources;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('thor_diag_');
    File(p.join(tmp.path, 'lib', 'pages', 'home.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync(List.generate(40, (i) => 'line ${i + 1}').join('\n'));
    sources = SourceMap(appDir: tmp.path, packages: const {});
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  group('an entry says what, where, the fix and the page', () {
    test('code, doc page and fix come apart from the message', () {
      final e = compileEntries('diagnostics', 'x', _s011, sources).single;
      expect(e['severity'], 'error');
      expect(e['code'], 'THOR-S011');
      expect(e['doc'], 'https://thor-docs.vercel.app/errores/THOR-S011');
      expect(e['fix'], 'Pass `counter.increment`.');
      expect(
        e['message'],
        "The closure passed to 'onPressed' uses a ThorState, and the "
        "browser can't run a function.",
      );
      final at = e['at']! as Map<String, Object?>;
      expect(at['file'], 'lib/pages/home.dart');
      expect(at['line'], 29);
      expect(at['column'], 28);
      // The excerpt is what the editor shows around the line.
      expect((at['code']! as List).any((l) => (l as List)[0] == 29), isTrue);
    });

    test('a Warning line is a warning, and an Error one is an error', () {
      final entries = compileEntries(
        'diagnostics',
        'x',
        '$_s011\n${_s011.replaceFirst('Error', 'Warning')}',
        sources,
      );
      expect(entries.map((e) => e['severity']), ['error', 'warning']);
    });

    test('a line with no code or fix keeps its whole message', () {
      final e = compileEntries(
        'diagnostics',
        'x',
        'lib/pages/home.dart:3:1: Error: plain failure',
        sources,
      ).single;
      expect(e['message'], 'plain failure');
      expect(e, isNot(contains('code')));
      expect(e, isNot(contains('fix')));
    });

    test('a text that is not a diagnostic is one error with all of it', () {
      final e = compileEntries('engine', 'x', 'boom\nbam', sources).single;
      expect(e['severity'], 'error');
      expect(e['message'], 'boom\nbam');
    });

    test('a file that is gone still gets its entry, without an excerpt', () {
      final e = compileEntries(
        'diagnostics',
        'x',
        _s011.replaceFirst('lib/pages/home.dart', 'lib/gone.dart'),
        sources,
      ).single;
      expect((e['at']! as Map)['code'], isEmpty);
    });
  });

  group('the diagnostics an app leaves in .dart_tool/thor', () {
    void write(String file, String text) => (File(
      p.join(tmp.path, '.dart_tool', 'thor', file),
    )..createSync(recursive: true)).writeAsStringSync(text);

    test('none: nothing', () => expect(diagnostics(tmp.path), isEmpty));

    test('state_misuses.txt and diagnostics.txt both count, in order', () {
      write('state_misuses.txt', '$_s011\n');
      write('diagnostics.txt', '\nlib/a.dart:1:1: Warning: x (THOR-S013)\n');
      expect(diagnostics(tmp.path), [
        _s011,
        'lib/a.dart:1:1: Warning: x (THOR-S013)',
      ]);
    });

    test('a warning does not fail a build; an error does', () {
      expect(diagnosticErrors(['lib/a.dart:1:1: Warning: x']), isEmpty);
      expect(diagnosticErrors([_s011, 'lib/a.dart:1:1: Warning: x']), [_s011]);
    });
  });

  group('the proxy shows them', () {
    late HttpServer app;
    late DevProxy proxy;
    final client = HttpClient();

    Future<String> page() async {
      final r = await (await client.get('localhost', proxy.port, '/')).close();
      return utf8.decodeStream(r);
    }

    setUp(() async {
      app = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      app.listen((r) async {
        // Like thor_server's pages: an ETag, and a 304 for a page the
        // browser already has (whatever the proxy changed in it since).
        if (r.headers.value(HttpHeaders.ifNoneMatchHeader) == '"v1"') {
          r.response.statusCode = HttpStatus.notModified;
        } else {
          r.response
            ..headers.contentType = ContentType.html
            ..headers.set(HttpHeaders.etagHeader, '"v1"')
            ..write('<html><body><p>hola</p></body></html>');
        }
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

    test('with 0 diagnostics the page has no overlay at all', () async {
      final html = await page();
      expect(html, isNot(contains('thor-dev-overlay')));
      expect(html, isNot(contains('__thorDevErrors')));
    });

    test('an error is in the page, and gone once it is cleared', () async {
      proxy.problem('diagnostics', 'The browser can not run this', _s011);
      var html = await page();
      expect(html, contains('__thorDevErrors'));
      expect(html, contains('"severity":"error"'));
      expect(html, contains('THOR-S011'));
      proxy.clearProblem('diagnostics');
      html = await page();
      expect(html, isNot(contains('__thorDevErrors')));
    });

    test('two errors in two files, and a warning, all of them', () async {
      File(p.join(tmp.path, 'lib', 'b.dart')).writeAsStringSync('x\ny\nz');
      proxy.problem(
        'diagnostics',
        't',
        [
          _s011,
          _s011.replaceFirst('lib/pages/home.dart:29:28', 'lib/b.dart:2:1'),
          'lib/pages/home.dart:5:1: Warning: careful (THOR-S013)',
        ].join('\n'),
      );
      final html = await page();
      expect('"severity":"error"'.allMatches(html), hasLength(2));
      expect('"severity":"warning"'.allMatches(html), hasLength(1));
      expect(html, contains('lib/b.dart'));
    });

    test(
      'a message with HTML cannot close the script or inject markup',
      () async {
        proxy.problem(
          'diagnostics',
          't',
          'lib/pages/home.dart:3:1: Error: </script><img src=x onerror=alert(1)>',
        );
        final html = await page();
        // Inside the JSON `<` is <: the only real </script> is ours.
        expect(html, isNot(contains('<img src=x')));
        expect(html, contains(r'</script>'));
      },
    );

    test('the same problem again does not reload the pages again', () async {
      final events = <String>[];
      final req = await client.get(
        'localhost',
        proxy.port,
        DevProxy.eventsPath,
      );
      final res = await req.close();
      final sub = res.transform(utf8.decoder).listen(events.add);
      proxy.problem('diagnostics', 't', _s011);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final first = events.join().split('event: reload').length - 1;
      proxy.problem('diagnostics', 't', _s011);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final second = events.join().split('event: reload').length - 1;
      expect(first, 1);
      expect(second, first, reason: 'nothing changed');
      proxy.clearProblem('diagnostics', reload: true);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(events.join().split('event: reload').length - 1, first + 1);
      await sub.cancel();
    });

    test('a page the browser has cached is sent again: the overlay is the '
        "proxy's, not the app's (a 304 kept the page as it was)", () async {
      Future<HttpClientResponse> revalidate() async {
        final req = await client.get('localhost', proxy.port, '/');
        req.headers
          ..set(HttpHeaders.acceptHeader, 'text/html')
          ..set(HttpHeaders.ifNoneMatchHeader, '"v1"');
        return req.close();
      }

      proxy.problem('diagnostics', 't', _s011);
      final r = await revalidate();
      expect(r.statusCode, 200);
      expect(r.headers.value(HttpHeaders.etagHeader), isNull);
      expect(r.headers.value(HttpHeaders.cacheControlHeader), 'no-store');
      expect(await utf8.decodeStream(r), contains('THOR-S011'));
    });

    test('a page carries the version it was served at; hello says the '
        'current one (a change while it loaded is not missed)', () async {
      final before = proxy.stamp;
      expect(await page(), contains("let run='$before'"));
      // A problem that arrives right after the page was served.
      proxy.problem('diagnostics', 't', _s011);
      expect(proxy.stamp, isNot(before));
      final req = await client.get(
        'localhost',
        proxy.port,
        DevProxy.eventsPath,
      );
      final res = await req.close();
      final first = await res
          .transform(utf8.decoder)
          .firstWhere((chunk) => chunk.contains('event: hello'));
      expect(first, contains('data: ${proxy.stamp}'));
      expect(first, isNot(contains(before)), reason: 'the page sees a change');
    });

    test('THOR_EDITOR none: the overlay carries no link to an editor', () {
      final script = overlayScript(
        compileEntries('diagnostics', 't', _s011, sources),
        InspectEditor.none,
      );
      expect(script, isNot(contains('vscode://')));
      final code = overlayScript(
        compileEntries('diagnostics', 't', _s011, sources),
        InspectEditor.cursor,
      );
      expect(code, contains('cursor://file'));
    });
  });
}
