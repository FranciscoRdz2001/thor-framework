@TestOn('vm')
@Timeout(Duration(minutes: 4))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';

/// The render caches (the element style memo and `Cached` fragments) are
/// invisible: every route, for a guest and two signed-in users, renders
/// byte for byte the same with them off, on and cold, and on and warm
/// (fragments kept for one user replayed for another), in debug and in
/// release. Needs `node` (test/e2e/mock_api serves the data).
void main() {
  late Process api;
  late int port;

  setUpAll(() async {
    port = await _freePort();
    api = await Process.start('node', [
      '../../../e2e/mock_api/server.mjs',
      '--port',
      '$port',
    ]);
    final ready = Completer<void>();
    api.stdout.transform(utf8.decoder).listen((l) {
      if (l.contains('mock api on') && !ready.isCompleted) ready.complete();
    });
    api.stderr.transform(utf8.decoder).listen(stderr.write);
    await ready.future.timeout(const Duration(seconds: 20));
  });
  tearDownAll(() => api.kill());

  Future<Map<String, String>> run(List<String> defines) async {
    // Through thor's wrapper: it registers the app's states first.
    final r = await runAppScript(
      'test/fixtures/render_caches.dart',
      dartArgs: defines,
      environment: {'REALWORLD_API': 'http://127.0.0.1:$port/api'},
    );
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final out = r.stdout as String;
    expect(out, isNot(contains('DIFF')), reason: out);
    return {
      for (final line in LineSplitter.split(out))
        if (line.split(' ') case [final k, final v]) k: v,
    };
  }

  void pagesRendered(Map<String, String> result) {
    expect(result['differ'], '0');
    expect(int.parse(result['pages']!), 32);
    // Real pages, not a wall of error pages: all but /no-such-page.
    expect(int.parse(result['ok']!), 29);
    // The users see their own favorites: sharing a preview between them
    // is only right because the key holds everything it shows.
    expect(result['personal'], 'true');
  }

  test('release: kept fragments replay the same bytes', () async {
    final result = await run(['-Dthor.release=true']);
    pagesRendered(result);
    expect(int.parse(result['kept']!), greaterThan(0));
  });

  test('debug: Cached inside components always builds, the output is the '
      'same', () async {
    final result = await run([]);
    pagesRendered(result);
    // Only the article body is kept: its Cached sits in the page, outside
    // any component (debug class names don't depend on it). The previews'
    // are inside ArticlePreview's parents and always build.
    expect(result['kept'], '1');
  });
}

Future<int> _freePort() async {
  final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = s.port;
  await s.close();
  return port;
}
