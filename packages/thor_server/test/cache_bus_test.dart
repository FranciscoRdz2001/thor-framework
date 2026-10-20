// The page cache of every isolate is cleared when one of them writes. A
// real process with several isolates sharing a port:
// the kernel picks the isolate of each new connection, so the tests warm
// the page until every isolate has it cached.
@TestOn('!windows')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

Future<int> _freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

class _Answer {
  _Answer(this.status, this.body);
  final int status;
  final String body;

  int get version => int.parse(RegExp(r'v=(\d+)').firstMatch(body)!.group(1)!);
  String get isolate => RegExp(r'iso=(\S+)').firstMatch(body)!.group(1)!;
}

/// One request on a connection of its own (so the kernel may pick another
/// isolate every time).
Future<_Answer> _send(
  int port,
  String method,
  String path, {
  Map<String, String> headers = const {},
  String body = '',
}) async {
  final client = HttpClient();
  try {
    final request = await client.open(method, '127.0.0.1', port, path);
    request.headers.set('connection', 'close');
    request.headers.set('origin', 'http://127.0.0.1:$port');
    headers.forEach(request.headers.set);
    if (body.isNotEmpty) request.write(body);
    final response = await request.close();
    return _Answer(response.statusCode, await utf8.decodeStream(response));
  } finally {
    client.close(force: true);
  }
}

void main() {
  late Process process;
  late int port;
  late Directory data;
  const isolates = 3;

  setUp(() async {
    data = Directory.systemTemp.createTempSync('thor_bus');
    port = await _freePort();
    process = await Process.start(
      Platform.resolvedExecutable,
      ['run', 'test/fixtures/cache_server.dart', '$port', '$isolates'],
      environment: {'CACHE_DATA': data.path},
    );
    final ready = Completer<void>();
    process.stdout.transform(utf8.decoder).listen((line) {
      if (line.contains('thor: http://') && !ready.isCompleted) {
        ready.complete();
      }
    });
    process.stderr.transform(utf8.decoder).listen(stderr.write);
    await ready.future.timeout(const Duration(seconds: 60));
  });

  tearDown(() {
    process.kill(ProcessSignal.sigkill);
    data.deleteSync(recursive: true);
  });

  /// GETs until every isolate answered (each one cached the page).
  Future<Set<String>> warm([String path = '/']) async {
    final seen = <String>{};
    for (var i = 0; i < 400 && seen.length < isolates; i++) {
      seen.add((await _send(port, 'GET', path)).isolate);
    }
    expect(
      seen,
      hasLength(isolates),
      reason: 'the kernel reached every isolate',
    );
    return seen;
  }

  /// [n] GETs: what version each answered, and which isolates did.
  Future<(Set<int>, Set<String>)> sweep(int n, [String path = '/']) async {
    final versions = <int>{};
    final seen = <String>{};
    for (var i = 0; i < n; i++) {
      final a = await _send(port, 'GET', path);
      versions.add(a.version);
      seen.add(a.isolate);
    }
    return (versions, seen);
  }

  test('a form action in one isolate refreshes the page in all', () async {
    await warm();
    final post = await _send(port, 'POST', '/?/bump', body: 'x=1');
    expect(post.status, 200);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final (versions, seen) = await sweep(90);
    expect(seen, hasLength(isolates));
    expect(versions, {1}, reason: 'no isolate serves the version before');
  });

  test('a command in one isolate refreshes the page in all', () async {
    await warm();
    final post = await _send(
      port,
      'POST',
      '/',
      headers: {
        'x-thor-command': 'Data.bump',
        'content-type': 'application/json',
      },
      body: '{}',
    );
    expect(post.status, 200);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final (versions, seen) = await sweep(90);
    expect(seen, hasLength(isolates));
    expect(versions, {1});
  });

  test('a failed action or command clears no isolate', () async {
    await warm();
    // Changed behind the server's back: only a clear would show it.
    for (var i = 0; i < 7; i++) {
      File('${data.path}/outside$i').writeAsStringSync('');
    }
    final failed = await _send(port, 'POST', '/?/fail', body: 'x=1');
    expect(failed.status, 422);
    final refused = await _send(
      port,
      'POST',
      '/',
      headers: {
        'x-thor-command': 'Data.bump',
        'content-type': 'application/json',
      },
      body: '{"arg": "fail"}',
    );
    expect(refused.status, 409);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final (versions, _) = await sweep(60);
    expect(versions, {0}, reason: 'the cached page stays');
  });

  test('many writes in a burst still end fresh everywhere', () async {
    await warm();
    final posts = await Future.wait([
      for (var i = 0; i < 40; i++) _send(port, 'POST', '/?/bump', body: 'x=1'),
    ]);
    expect(posts.map((p) => p.status).toSet(), {200});
    expect(data.listSync(), hasLength(40));
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final (versions, seen) = await sweep(90);
    expect(seen, hasLength(isolates));
    expect(versions, {40});
  });

  test('revalidateTag in one isolate refreshes the tagged page in all, and a '
      'plain write clears it too', () async {
    await warm('/tagged');
    await _send(port, 'POST', '/?/bump', body: 'x=1');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final (versions, _) = await sweep(60, '/tagged');
    expect(versions, {
      1,
    }, reason: 'a write clears a tagged page: no stale data');
    final post = await _send(port, 'POST', '/tagged?/touch', body: 'x=1');
    expect(post.status, 200);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final (after, seen) = await sweep(90, '/tagged');
    expect(seen, hasLength(isolates));
    expect(after, {2}, reason: 'the bump and the touch, in every isolate');
  });

  test('a page with invalidateOnWrite: false waits for its tag in all '
      'isolates', () async {
    await warm('/pinned');
    await _send(port, 'POST', '/?/bump', body: 'x=1');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final (versions, _) = await sweep(60, '/pinned');
    expect(versions, {0}, reason: 'a write does not clear it');
    final post = await _send(port, 'POST', '/pinned?/touch', body: 'x=1');
    expect(post.status, 200);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final (after, seen) = await sweep(90, '/pinned');
    expect(seen, hasLength(isolates));
    expect(after, {2});
  });
}
