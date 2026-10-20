@TestOn('vm')
library;

// The lite part `shortcuts`: a spec with `o` (`overrideTextInput`) answers
// while a text field has the key; one without it does not. `matches` runs in
// node.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart';

final _hasNode = Process.runSync('node', ['--version']).exitCode == 0;

void main() {
  test('the spec carries o only when asked', () {
    expect(
      const SingleActivator(
        LogicalKeyboardKey.arrowDown,
        overrideTextInput: true,
      ).spec,
      'o+arrowdown',
    );
    expect(
      const SingleActivator(LogicalKeyboardKey.arrowDown).spec,
      '+arrowdown',
    );
    expect(
      const SingleActivator(
        LogicalKeyboardKey.keyK,
        meta: true,
        skipWithTextSelection: true,
        overrideTextInput: true,
      ).spec,
      'mto+k',
    );
    expect(const CharacterActivator('?', overrideTextInput: true).spec, 'o=63');
    // The Dart matcher ignores the flag (it is the page's business).
    expect(
      shortcutMatches(
        'o+arrowdown',
        'ArrowDown',
        control: false,
        shift: false,
        alt: false,
        meta: false,
      ),
      isTrue,
    );
  });

  test(
    'matches: with own, only o specs answer',
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
const W = { getSelection: () => ({ isCollapsed: true }) };
${cut('const phys = ', ';\n')}
${cut('function matches(spec, e, own) {', '\n  }\n')}
const down = { key: 'ArrowDown', code: 'ArrowDown', metaKey: false, ctrlKey: false, altKey: false, shiftKey: false };
const out = {};
out.freeNoOwn = matches('+arrowdown', down, false);
out.freeOwn = matches('+arrowdown', down, true);
out.optInOwn = matches('o+arrowdown', down, true);
out.optInFree = matches('o+arrowdown', down, false);
out.charOwn = matches('o=40', { ...down, key: '(' }, true);
console.log(JSON.stringify(out));
''';
      final r = await Process.run('node', ['-e', js]);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(jsonDecode('${r.stdout}'.trim()), {
        'freeNoOwn': true,
        'freeOwn': false,
        'optInOwn': true,
        'optInFree': true,
        'charOwn': true,
      });
    },
  );
}
