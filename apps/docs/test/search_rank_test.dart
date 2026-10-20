import 'dart:io';

import 'package:test/test.dart';

/// The search page's ordering (`web/search.js`) is plain JavaScript: its
/// tests (`search_rank_test.mjs`) run with node's own runner.
void main() {
  test(
    'search results are ranked: exact titles first, sections by score',
    () {
      final result = Process.runSync('node', [
        '--test',
        'test/search_rank_test.mjs',
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    },
    skip: Process.runSync('which', ['node']).exitCode != 0 ? 'no node' : false,
  );
}
