@TestOn('vm')
library;

// The lite part `autocomplete`: the filter's matcher. Default: the whole
// phrase, any case; with `w`: every word, any order, accent-insensitive.
// `fold` and `matches` run in node.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

final _hasNode = Process.runSync('node', ['--version']).exitCode == 0;

void main() {
  test(
    'matches: phrase by default, every word with w',
    skip: _hasNode ? false : 'needs node',
    () async {
      final part = File('lib/lite/parts/autocomplete.js').readAsStringSync();
      String cut(String start, String end) {
        final at = part.indexOf(start);
        expect(at, isNonNegative, reason: '$start moved');
        return part.substring(at, part.indexOf(end, at) + end.length);
      }

      final js =
          '''
${cut('const fold = ', ';\n')}
${cut('const matches = ', '\n  };\n')}
const phrase = { words: false };
const words = { words: true };
const out = {
  phraseCase: matches(phrase, 'New York', 'new Y'),
  phraseOrder: matches(phrase, 'York, New', 'new york'),
  phraseAccent: matches(phrase, 'Café', 'cafe'),
  wordsOrder: matches(words, 'York, New', 'new york'),
  wordsAccent: matches(words, 'Café con leche', 'CAFE leche'),
  wordsMissing: matches(words, 'New Jersey', 'new york'),
  wordsSpaces: matches(words, 'New York', '  new   york '),
  wordsPartial: matches(words, 'Barcelona', 'bar'),
};
console.log(JSON.stringify(out));
''';
      final r = await Process.run('node', ['-e', js]);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(jsonDecode('${r.stdout}'.trim()), {
        'phraseCase': true,
        'phraseOrder': false,
        'phraseAccent': false,
        'wordsOrder': true,
        'wordsAccent': true,
        'wordsMissing': false,
        'wordsSpaces': true,
        'wordsPartial': true,
      });
    },
  );
}
