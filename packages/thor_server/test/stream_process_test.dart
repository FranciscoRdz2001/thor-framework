// Adversarial tests that need a real server process: slow request headers
// (dart:io's idle timeout is the only header deadline) and a graceful
// shutdown with event streams open.
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

Future<(Process, int)> _start({int isolates = 1, int idleMs = 120000}) async {
  final port = await _freePort();
  final process = await Process.start(Platform.resolvedExecutable, [
    'run',
    'test/fixtures/stream_server.dart',
    '$port',
    '$isolates',
    '$idleMs',
  ]);
  final ready = Completer<void>();
  process.stdout.transform(utf8.decoder).listen((line) {
    if (line.contains('thor: http://') && !ready.isCompleted) {
      ready.complete();
    }
  });
  process.stderr.transform(utf8.decoder).listen(stderr.write);
  await ready.future.timeout(const Duration(seconds: 60));
  return (process, port);
}

void main() {
  late Process process;
  late int port;
  tearDown(() => process.kill(ProcessSignal.sigkill));

  test('request headers that trickle in are cut at the idle timeout', () async {
    (process, port) = await _start(idleMs: 1000);
    final socket = await Socket.connect('127.0.0.1', port);
    final watch = Stopwatch()..start();
    var closedAt = -1;
    socket.listen(
      (_) {},
      onDone: () => closedAt = watch.elapsedMilliseconds,
      onError: (_) => closedAt = watch.elapsedMilliseconds,
    );
    final head = 'GET / HTTP/1.1\r\nHost: x\r\nX-A: '.codeUnits;
    for (var i = 0; i < 12 && closedAt < 0; i++) {
      try {
        socket.add([head[i % head.length]]);
        await socket.flush();
      } on SocketException {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    socket.destroy();
    expect(closedAt, inInclusiveRange(1, 3500));
  });

  for (final isolates in [1, 2]) {
    test(
      'SIGTERM ends the open event streams at once ($isolates isolate(s))',
      () async {
        (process, port) = await _start(isolates: isolates);
        final clients = <HttpClient>[];
        final ended = <Future<void>>[];
        for (var i = 0; i < 6; i++) {
          final client = HttpClient();
          clients.add(client);
          final request = await client.get('127.0.0.1', port, '/events');
          final response = await request.close();
          expect(response.statusCode, 200);
          ended.add(response.drain<void>());
        }
        final watch = Stopwatch()..start();
        process.kill(ProcessSignal.sigterm);
        await Future.wait(ended).timeout(const Duration(seconds: 4));
        expect(await process.exitCode.timeout(const Duration(seconds: 4)), 0);
        expect(watch.elapsed, lessThan(const Duration(seconds: 4)));
        for (final c in clients) {
          c.close(force: true);
        }
      },
    );
  }

  test('many clients that leave free every subscription', () async {
    (process, port) = await _start();
    final sockets = <Socket>[];
    for (var i = 0; i < 40; i++) {
      final s = await Socket.connect('127.0.0.1', port);
      s.add(utf8.encode('GET /events HTTP/1.1\r\nHost: x\r\n\r\n'));
      s.listen((_) {}, onError: (_) {});
      sockets.add(s);
    }
    Future<int> open() async {
      final client = HttpClient();
      try {
        final r = await (await client.get('127.0.0.1', port, '/open')).close();
        return (jsonDecode(await utf8.decodeStream(r))
                as Map<String, Object?>)['open']!
            as int;
      } finally {
        client.close(force: true);
      }
    }

    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(await open(), 40);
    for (final s in sockets) {
      s.destroy();
    }
    var left = 40;
    for (var i = 0; i < 20 && left > 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      left = await open();
    }
    expect(left, 0);
  });
}
