import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_lints/lite.dart';

void main() {
  test('the THOR-B012 page names every construct the hint table knows', () {
    final doc = File('../../docs/errores/THOR-B012.md').readAsStringSync();
    final missing = [
      for (final h in liteHints)
        if (!doc.contains('`${h.construct}`')) h.construct,
    ];
    expect(
      missing,
      isEmpty,
      reason: 'add these to the table of docs/errores/THOR-B012.md (es and en)',
    );
  });

  test(
    'every hint has a construct, a short concrete suggestion and a matcher',
    () {
      final seen = <String>{};
      for (final h in liteHints) {
        expect(
          seen.add(h.construct),
          isTrue,
          reason: 'duplicate ${h.construct}',
        );
        expect(
          h.suggestion.length,
          inInclusiveRange(10, 260),
          reason: h.construct,
        );
        expect(
          h.message != null || h.node != null,
          isTrue,
          reason: h.construct,
        );
      }
    },
  );

  test('every row of the doc table is a construct of the hint table', () {
    final doc = File('../../docs/errores/THOR-B012.md').readAsStringSync();
    final start = doc.indexOf('| Construcción | Qué hacer |');
    expect(start, greaterThan(0));
    final rows = doc
        .substring(start)
        .split('\n')
        .skip(2)
        .takeWhile((l) => l.startsWith('|'));
    final known = {
      for (final h in liteHints) h.construct,
      liteGeneratedConstruct,
    };
    final inCells = <String>{};
    for (final row in rows) {
      final cell = row.substring(1, row.indexOf(' | ', 1));
      // What is in parentheses only describes; the rest are constructs.
      final out = StringBuffer();
      var tick = false, depth = 0;
      for (final c in cell.split('')) {
        if (c == '`') tick = !tick;
        if (!tick && c == '(') depth++;
        if (depth == 0) out.write(c);
        if (!tick && c == ')' && depth > 0) depth--;
      }
      final bare = '$out';
      for (final m in RegExp(r'`([^`]+)`').allMatches(bare)) {
        expect(known, contains(m[1]), reason: 'row "$cell" names ${m[1]}');
        inCells.add(m[1]!);
      }
    }
    expect(known.difference(inCells), isEmpty);
  });
}
