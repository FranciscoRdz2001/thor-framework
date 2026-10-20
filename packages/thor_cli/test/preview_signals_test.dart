// `thor preview` under a hostile server: one that ignores SIGTERM, one that
// exits with its own code, a second Ctrl-C.
@TestOn('mac-os || linux')
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

bool _alive(int pid) => Process.runSync('kill', ['-0', '$pid']).exitCode == 0;

Future<T> _until<T>(T? Function() probe, String what) async {
  final clock = Stopwatch()..start();
  while (true) {
    final value = probe();
    if (value != null) return value;
    if (clock.elapsed > const Duration(seconds: 20)) {
      fail('timed out waiting for $what');
    }
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

  tearDown(() {
    for (final pid in [?preview?.pid, ?server]) {
      if (_alive(pid)) Process.killPid(pid, ProcessSignal.sigkill);
    }
    app.deleteSync(recursive: true);
    preview = null;
    server = null;
  });

  /// Starts preview over a server whose shell body is [body].
  Future<void> start(String body) async {
    app = Directory.systemTemp.createTempSync('devpids_adv_preview_');
    File(p.join(app.path, 'pubspec.yaml')).writeAsStringSync(
      'name: probe\nenvironment:\n  sdk: ^3.0.0\n'
      'dependencies:\n  thor_ui: any\n',
    );
    final bin = File(p.join(app.path, 'build', 'server'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        '#!/bin/sh\necho \$\$ > "${app.path}/server.pid"\n$body\n',
      );
    Process.runSync('chmod', ['+x', bin.path]);
    preview = await Process.start('dart', [
      script,
      'preview',
      '-p',
      '${25000 + pid % 1000}',
    ], workingDirectory: app.path);
    unawaited(preview!.stdout.drain<void>());
    unawaited(preview!.stderr.drain<void>());
    server = await _until(() {
      final f = File(p.join(app.path, 'server.pid'));
      return f.existsSync() ? int.tryParse(f.readAsStringSync().trim()) : null;
    }, 'the server to start');
  }

  test('a server that ignores SIGTERM is killed after the grace', () async {
    await start("trap '' TERM INT HUP\nexec sleep 600");
    final clock = Stopwatch()..start();
    preview!.kill();
    final code = await preview!.exitCode.timeout(
      const Duration(seconds: 15),
      onTimeout: () => fail('preview never gave up on the server'),
    );
    expect(clock.elapsed, greaterThan(const Duration(seconds: 4)));
    expect(clock.elapsed, lessThan(const Duration(seconds: 9)));
    expect(code, 137);
    await _until(() => _alive(server!) ? null : true, 'the server to die');
  });

  test('the server exit code is the preview exit code', () async {
    await start('sleep 1\nexit 3');
    expect(await preview!.exitCode, 3);
  });

  test('a second Ctrl-C does not leave the server alive or hang', () async {
    await start("trap '' TERM INT HUP\nexec sleep 600");
    preview!.kill(ProcessSignal.sigint);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    preview!.kill(ProcessSignal.sigint);
    await preview!.exitCode.timeout(
      const Duration(seconds: 15),
      onTimeout: () => fail('preview hung after two Ctrl-C'),
    );
    await _until(() => _alive(server!) ? null : true, 'the server to die');
  });
}
