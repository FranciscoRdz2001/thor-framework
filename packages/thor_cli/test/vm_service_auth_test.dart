// The VM service `thor dev` starts for hot reload is a full remote control
// of the app: a page of another site (DNS rebinding, or plain CORS: the
// service answers `access-control-allow-origin: *`) must not be able to
// use it, so it needs its auth code.
@TestOn('mac-os || linux')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thor_cli/src/dev/vm_client.dart';

void main() {
  late Directory tmp;
  Process? app;

  setUp(() => tmp = Directory.systemTemp.createTempSync('thor_vm_'));
  tearDown(() async {
    app?.kill();
    await app?.exitCode;
    tmp.deleteSync(recursive: true);
  });

  test(
    'the service needs its auth code, and thor dev still connects',
    () async {
      final script = File(p.join(tmp.path, 'a.dart'))
        ..writeAsStringSync(
          'void main() async {\n'
          '  await Future<void>.delayed(const Duration(minutes: 2));\n'
          '}\n',
        );
      final info = File(p.join(tmp.path, 'vm.json'));
      app = await Process.start('dart', [
        'run',
        ...vmServiceArgs(info),
        script.path,
      ]);
      // Drain: a full pipe would stop it.
      unawaited(app!.stdout.drain<void>());
      unawaited(app!.stderr.drain<void>());

      // What thor dev does: connect with the address the VM wrote.
      late VmClient client;
      for (var attempt = 0; ; attempt++) {
        try {
          client = await VmClient.connect(info);
          break;
        } on SocketException {
          // The file is written a moment before the port listens.
          if (attempt == 50) rethrow;
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
      await client.dispose();

      // What a page does: the same port, no code.
      final uri = Uri.parse(
        (jsonDecode(info.readAsStringSync()) as Map)['uri'] as String,
      );
      final http = HttpClient();
      for (final path in ['/getVersion', '/ws']) {
        final request = await http.getUrl(
          Uri(scheme: 'http', host: uri.host, port: uri.port, path: path),
        );
        request.headers.host = 'attacker.example';
        final response = await request.close();
        await response.drain<void>();
        expect(response.statusCode, isNot(200), reason: path);
        expect(response.statusCode, isNot(101), reason: path);
      }
      http.close(force: true);
    },
  );
}
