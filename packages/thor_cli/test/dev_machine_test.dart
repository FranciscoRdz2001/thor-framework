// The machine side of `thor dev`: `DevProxy.results` (the `result`
// events as a stream), `injectScripts` (a file in every page) and
// `Say.json` (`--json`: log lines as events).
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_cli/src/dev_proxy.dart';
import 'package:thor_cli/src/run.dart';

void main() {
  late HttpServer app;
  late Directory tmp;
  DevProxy? proxy;
  final client = HttpClient();

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('thor_dev_machine');
    app = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    app.listen((r) async {
      r.response.headers.contentType = ContentType.html;
      r.response.write('<html><body>hi</body></html>');
      await r.response.close();
    });
  });

  tearDown(() async {
    Say.json = null;
    await proxy?.close();
    await app.close(force: true);
    tmp.deleteSync(recursive: true);
  });

  Future<String> page() async {
    final req = await client.open('GET', 'localhost', proxy!.port, '/');
    final res = await req.close();
    return res.transform(utf8.decoder).join();
  }

  Future<void> start({List<File> inject = const []}) async {
    proxy = DevProxy(upstream: app.port, injectScripts: inject);
    await proxy!.start(0);
    proxy!.ready();
  }

  test('results streams the status of every change', () async {
    await start();
    final seen = <Map<String, Object?>>[];
    proxy!.results.listen(seen.add);
    proxy!.problem('engine', 'The engine failed', 'a.dart:1:1: Error: boom');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(seen, isNotEmpty);
    expect(seen.last['ok'], isFalse);
    expect(seen.last['problems'], isNotEmpty);
    proxy!.clearProblem('engine', reload: true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(seen.last['ok'], isTrue);
    expect(seen.last['problems'], isEmpty);
  });

  test('an injected script goes in every page, read on each request', () async {
    final bridge = File('${tmp.path}/bridge.js')
      ..writeAsStringSync('window.__bridge = 1;');
    await start(inject: [bridge, File('${tmp.path}/gone.js')]);
    var html = await page();
    expect(html, contains('<script>window.__bridge = 1;</script>'));
    expect(html.indexOf('__bridge'), lessThan(html.lastIndexOf('</body>')));
    bridge.writeAsStringSync('window.__bridge = 2; "</script><b>x</b>";');
    html = await page();
    expect(html, contains('window.__bridge = 2;'));
    // the file cannot close its own tag
    expect(html, isNot(contains('"</script><b>')));
    expect(html, contains(r'<\/script><b>'));
  });

  test('without --inject the page has no extra script', () async {
    await start();
    expect(await page(), isNot(contains('__bridge')));
  });

  test('Say.json turns the console lines into events', () {
    final events = <Map<String, Object?>>[];
    Say.json = events.add;
    Say.step('Code generation');
    Say.info('compiling');
    Say.ok('done');
    Say.warn('careful');
    Say.error('broken');
    expect(events, [
      {'event': 'log', 'level': 'step', 'message': 'Code generation'},
      {'event': 'log', 'level': 'info', 'message': 'compiling'},
      {'event': 'log', 'level': 'ok', 'message': 'done'},
      {'event': 'log', 'level': 'warn', 'message': 'careful'},
      {'event': 'log', 'level': 'error', 'message': 'broken'},
    ]);
  });
}
