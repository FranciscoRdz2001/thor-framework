// `thor preview` serving build/server: it lives exactly as long as the
// server (no orphan wrapper) and passes a stop signal on to it.
@TestOn('mac-os || linux')
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

bool _alive(int pid) => Process.runSync('kill', ['-0', '$pid']).exitCode == 0;

Future<T> _until<T>(
  T? Function() probe,
  String what, [
  Duration timeout = const Duration(seconds: 20),
]) async {
  final clock = Stopwatch()..start();
  while (true) {
    final value = probe();
    if (value != null) return value;
    if (clock.elapsed > timeout) fail('timed out waiting for $what');
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}

void main() {
  late Directory app;
  late String script;
  Process? preview;
  int? server;

  setUpAll(() async {
    final library = await Isolate.resolvePackageUri(
      Uri.parse('package:thor_cli/thor_cli.dart'),
    );
    script = p.normalize(
      p.join(p.dirname(library!.toFilePath()), '..', 'bin', 'thor.dart'),
    );
  });

  setUp(() async {
    app = Directory.systemTemp.createTempSync('devpids_probe_preview_');
    File(p.join(app.path, 'pubspec.yaml')).writeAsStringSync(
      'name: probe\nenvironment:\n  sdk: ^3.0.0\n'
      'dependencies:\n  thor_ui: any\n',
    );
    final bin = File(p.join(app.path, 'build', 'server'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        '#!/bin/sh\necho \$\$ > "${app.path}/server.pid"\nexec sleep 600\n',
      );
    Process.runSync('chmod', ['+x', bin.path]);
    // Whatever happens, no process of this test outlives it.
    addTearDown(() async {
      for (final pid in [?preview?.pid, ?server]) {
        if (_alive(pid)) Process.killPid(pid, ProcessSignal.sigkill);
      }
      app.deleteSync(recursive: true);
    });
    preview = await Process.start('dart', [
      script,
      'preview',
      '-p',
      '${24000 + pid % 1000}',
    ], workingDirectory: app.path);
    unawaited(preview!.stdout.drain<void>());
    unawaited(preview!.stderr.drain<void>());
    server = await _until(() {
      final f = File(p.join(app.path, 'server.pid'));
      return f.existsSync() ? int.tryParse(f.readAsStringSync().trim()) : null;
    }, 'the server to start');
  });

  test('exits when its server exits, with its code', () async {
    Process.killPid(server!, ProcessSignal.sigkill);
    final code = await preview!.exitCode.timeout(
      const Duration(seconds: 4),
      onTimeout: () => fail('preview stayed alive after its server died'),
    );
    expect(code, 137);
  });

  test('SIGTERM to preview stops the server too', () async {
    preview!.kill();
    await preview!.exitCode.timeout(
      const Duration(seconds: 6),
      onTimeout: () => fail('preview ignored SIGTERM'),
    );
    await _until(() => _alive(server!) ? null : true, 'the server to stop');
  });

  test('SIGINT to preview stops the server too', () async {
    preview!.kill(ProcessSignal.sigint);
    await preview!.exitCode.timeout(
      const Duration(seconds: 6),
      onTimeout: () => fail('preview ignored SIGINT'),
    );
    await _until(() => _alive(server!) ? null : true, 'the server to stop');
  });
}
