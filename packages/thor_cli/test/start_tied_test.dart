@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_cli/src/commands/dev.dart' show startTied;

void main() {
  final skip = Platform.isWindows ? 'the tie is POSIX only' : null;

  test(
    'a tied child that exits by itself ends the process with its code',
    () async {
      final proc = await startTied('sh', ['-c', 'exit 3'], dir: '.');
      addTearDown(proc.kill);
      final code = await proc.exitCode.timeout(const Duration(seconds: 5));
      expect(code, 3);
    },
    skip: skip,
  );

  test('closing stdin (the parent gone) kills a long-running child', () async {
    final proc = await startTied('sleep', ['60'], dir: '.');
    addTearDown(proc.kill);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await proc.stdin.close();
    await proc.exitCode.timeout(const Duration(seconds: 5));
  }, skip: skip);
}
