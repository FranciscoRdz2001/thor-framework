// ThorServer.serve(onShutdown:): the hook runs on SIGTERM/SIGINT before the
// server closes (and under `thor dev`, which otherwise exits at once), and a
// hook that throws or hangs does not keep the process alive. A real process:
// signals can't be sent to the test's own isolate.
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

Future<int> _status(int port, String path) async {
  final client = HttpClient();
  try {
    final request = await client.get('127.0.0.1', port, path);
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  } finally {
    client.close(force: true);
  }
}

void main() {
  late Directory tmp;
  late Process process;
  late int port;
  late File log;

  setUp(() => tmp = Directory.systemTemp.createTempSync('thor_hook_'));
  tearDown(() {
    process.kill(ProcessSignal.sigkill);
    tmp.deleteSync(recursive: true);
  });

  Future<void> start(String mode, {bool dev = false}) async {
    port = await _freePort();
    log = File('${tmp.path}/log.txt');
    process = await Process.start(
      Platform.resolvedExecutable,
      ['run', 'test/fixtures/hook_server.dart', '$port', log.path, mode],
      environment: {if (dev) 'THOR_DEV': '1'},
    );
    final ready = Completer<void>();
    process.stdout.transform(utf8.decoder).listen((text) {
      if (text.contains('thor: http://') && !ready.isCompleted) {
        ready.complete();
      }
    });
    process.stderr.transform(utf8.decoder).listen(stderr.write);
    await ready.future.timeout(const Duration(seconds: 60));
  }

  test('SIGTERM waits for the hook, serving meanwhile, then exits 0', () async {
    await start('ok');
    process.kill(ProcessSignal.sigterm);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    // The hook is running and the server has not closed yet.
    expect(log.readAsStringSync(), 'start\n');
    expect(await _status(port, '/'), 200);
    expect(await process.exitCode.timeout(const Duration(seconds: 10)), 0);
    expect(log.readAsStringSync(), 'start\nend\n');
  });

  test('a hook that throws still stops the server and exits 0', () async {
    await start('throws');
    process.kill(ProcessSignal.sigterm);
    expect(await process.exitCode.timeout(const Duration(seconds: 10)), 0);
    expect(log.readAsStringSync(), 'start\n');
  });

  test('a hook that hangs is cut at shutdownTimeout', () async {
    await start('hangs');
    final watch = Stopwatch()..start();
    process.kill(ProcessSignal.sigterm);
    expect(await process.exitCode.timeout(const Duration(seconds: 15)), 0);
    expect(watch.elapsed, lessThan(const Duration(seconds: 8)));
  });

  test('under thor dev the hook runs too, then the process exits 0', () async {
    await start('ok', dev: true);
    process.kill(ProcessSignal.sigterm);
    expect(await process.exitCode.timeout(const Duration(seconds: 10)), 0);
    expect(log.readAsStringSync(), 'start\nend\n');
  });
}
