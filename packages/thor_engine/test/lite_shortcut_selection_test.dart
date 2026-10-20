@TestOn('vm')
library;

// The lite part `shortcuts` with `skipWithTextSelection` (spec flag `t`): the
// part's own `matches` run in node with a fake `getSelection()`.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

final _hasNode = Process.runSync('node', ['--version']).exitCode == 0;

void main() {
  test(
    'a spec with t does not match while the page has selected text',
    skip: _hasNode ? false : 'needs node',
    () async {
      final part = File('lib/lite/parts/shortcuts.js').readAsStringSync();
      String cut(String start, String end) {
        final at = part.indexOf(start);
        expect(at, isNonNegative, reason: '$start moved');
        return part.substring(at, part.indexOf(end, at) + end.length);
      }

      final js =
          '''
let selected = false;
const W = { getSelection: () => ({ isCollapsed: !selected }) };
${cut('const phys = ', ';\n')}
${cut('function matches(spec, e, own) {', '\n  }\n')}
const cmdC = { key: 'c', code: 'KeyC', metaKey: true, ctrlKey: false, altKey: false, shiftKey: false };
const out = {};
out.plain = matches('mt+c', cmdC);
selected = true;
out.selected = matches('mt+c', cmdC);
out.withoutFlag = matches('m+c', cmdC);
out.character = matches('t=99', { ...cmdC, metaKey: false });
console.log(JSON.stringify(out));
''';
      final r = await Process.run('node', ['-e', js]);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      final out = jsonDecode('${r.stdout}'.trim()) as Map<String, Object?>;
      expect(out, {
        'plain': true,
        'selected': false,
        'withoutFlag': true,
        'character': false,
      });
    },
  );
}
