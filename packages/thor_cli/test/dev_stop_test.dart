@TestOn('mac-os || linux')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_cli/src/commands/dev.dart';

void main() {
  test('a server that ignores SIGTERM is killed after the grace', () async {
    final process = await Process.start('bash', [
      '-c',
      'trap "" TERM; echo up; sleep 60',
    ]);
    await process.stdout.first;
    final clock = Stopwatch()..start();
    await stopGracefully(process, grace: const Duration(milliseconds: 500));
    expect(clock.elapsed, lessThan(const Duration(seconds: 10)));
    expect(await process.exitCode, isNot(0));
  });

  test('a server that stops on SIGTERM is not killed', () async {
    final process = await Process.start('sleep', ['60']);
    await stopGracefully(process, grace: const Duration(seconds: 5));
    expect(await process.exitCode, -ProcessSignal.sigterm.signalNumber);
  });
}
