@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// `ThorServer.setUpIsolates`: every isolate `serve` starts runs the
/// set-up before it answers (thor's entry registers the app's states so).
void main() {
  test('every isolate of serve runs the set-up before it answers', () async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    final server = await Process.start(Platform.resolvedExecutable, [
      'run',
      'test/fixtures/setup_server.dart',
      '$port',
    ]);
    addTearDown(server.kill);
    final ready = Completer<void>();
    server.stdout.transform(utf8.decoder).listen((line) {
      if (line.contains('thor: http') && !ready.isCompleted) ready.complete();
    });
    server.stderr.transform(utf8.decoder).listen(stderr.write);
    await ready.future.timeout(const Duration(seconds: 60));

    final seen = <String>{};
    for (var i = 0; i < 60 && seen.length < 3; i++) {
      // A new connection each time: the kernel spreads them across the
      // isolates that share the port.
      final client = HttpClient();
      final response = await (await client.get('127.0.0.1', port, '/')).close();
      final body = await response.transform(utf8.decoder).join();
      client.close(force: true);
      expect(body, startsWith('set up in'));
      seen.add(body);
    }
    expect(seen.length, greaterThan(1), reason: 'answers came from $seen');
  });
}
