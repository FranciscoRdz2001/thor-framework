@TestOn('vm')
library;

// The lite part `drag_drop` finds a draggable's templates past a wrapper the
// server wrote beside it (a `Tooltip`'s bubble), up to the next draggable.
// Runs the part's own `templateOf` on fake siblings in node.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

final _hasNode = Process.runSync('node', ['--version']).exitCode == 0;

void main() {
  test(
    'templateOf looks past the next sibling, not past the next draggable',
    skip: _hasNode ? false : 'needs node',
    () async {
      final part = File('lib/lite/parts/drag_drop.js').readAsStringSync();
      final fn = RegExp(
        r'const templateOf = \(src, attr\) => \{.*?\n  \};',
        dotAll: true,
      ).firstMatch(part);
      expect(fn, isNotNull, reason: 'templateOf moved');
      final js =
          '''
const el = (tag, attrs = {}) => ({ tagName: tag, a: attrs, hasAttribute(n) { return n in this.a; }, querySelectorAll: () => [] });
const row = (...els) => { els.forEach((e, i) => (e.nextElementSibling = els[i + 1] ?? null)); return els; };
${fn![0]}
const [a, tip, fb] = row(el('SPAN', { 'data-t-dg': '' }), el('SPAN', { role: 'tooltip' }), el('TEMPLATE', { 'data-t-dg-fb': '' }));
const [b, c, fb2] = row(el('SPAN', { 'data-t-dg': '' }), el('SPAN', { 'data-t-dg': '' }), el('TEMPLATE', { 'data-t-dg-fb': '' }));
console.log(JSON.stringify({ past: templateOf(a, 'data-t-dg-fb') === fb, other: templateOf(b, 'data-t-dg-fb') }));
''';
      final r = await Process.run('node', ['-e', js]);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      final out = jsonDecode('${r.stdout}'.trim()) as Map<String, Object?>;
      expect(out['past'], isTrue);
      // The template after another draggable is that one's.
      expect(out['other'], isNull);
    },
  );
}
