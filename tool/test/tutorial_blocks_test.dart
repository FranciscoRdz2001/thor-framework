import 'dart:io';

import 'package:test/test.dart';

import '../docs_blocks.dart';

/// tool/tutorial_check.dart writes each Dart block of the tutorial as a
/// file: a block with no path comment would be skipped silently.
void main() {
  final blocks = extractBlocks(
    File('docs/guia/es/primera-app.md').readAsStringSync(),
    file: 'docs/guia/es/primera-app.md',
  );

  test('every Dart block of the tutorial is a whole file with its path', () {
    final loose = [
      for (final b in blocks)
        if (b.lang == 'dart' && b.path == null) b.toString(),
    ];
    expect(loose, isEmpty, reason: 'start these blocks with `// lib/...`');
  });

  test('the commands the script runs are in the tutorial', () {
    final commands = [
      for (final b in blocks)
        if (b.lang == 'bash') ...b.code.split('\n').map((l) => l.trim()),
    ];
    expect(commands, containsAll(['thor create store', 'thor add state Cart']));
    expect(commands, contains('thor add page /product/:id:int'));
    expect(commands, containsAll(['thor test', 'thor build']));
  });
}
