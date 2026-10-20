// ThorServer on a host: the health path, and SIGTERM finishing the
// requests in flight before exiting 0. A real process: signals
// can't be sent to the test's own isolate.
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

Future<(int, String)> _get(int port, String path) async {
  final client = HttpClient();
  try {
    final request = await client.get('127.0.0.1', port, path);
    final response = await request.close();
    return (response.statusCode, await utf8.decodeStream(response));
  } finally {
    client.close(force: true);
  }
}

Future<(Process, int)> _start(int isolates) async {
  final port = await _freePort();
  final process = await Process.start(Platform.resolvedExecutable, [
    'run',
    'test/fixtures/drain_server.dart',
    '$port',
    '$isolates',
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
  for (final isolates in [1, 2]) {
    group('$isolates isolate(s)', () {
      late Process process;
      late int port;

      setUp(() async => (process, port) = await _start(isolates));
      tearDown(() => process.kill(ProcessSignal.sigkill));

      test('the health path answers 200 and JSON', () async {
        final (status, body) = await _get(port, '/_thor/health');
        expect(status, 200);
        expect(jsonDecode(body), {'status': 'ok'});
      });

      test('SIGTERM lets a request in flight finish, then exits 0', () async {
        final slow = _get(port, '/slow');
        await Future<void>.delayed(const Duration(milliseconds: 300));
        process.kill(ProcessSignal.sigterm);
        final (status, body) = await slow;
        expect(status, 200);
        expect(body, 'slow done');
        expect(await process.exitCode.timeout(const Duration(seconds: 10)), 0);
        // Gone: nothing listens on the port anymore.
        await expectLater(_get(port, '/'), throwsA(isA<SocketException>()));
      });
    });
  }
}
