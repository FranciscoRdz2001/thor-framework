// The markdown renderer and the example registry paint with thor_studio
// tokens only: no CSS in strings, no literal colors.
import 'dart:io';

import 'package:test/test.dart';

/// The Dart files of [dir] (relative to apps/docs).
List<File> _files(String dir) {
  final root = Directory(dir).existsSync() ? dir : 'apps/docs/$dir';
  return [
    for (final f in Directory(root).listSync(recursive: true))
      if (f is File && f.path.endsWith('.dart')) f,
  ];
}

final _literalColor = RegExp(r'Color\(\s*0x');

void main() {
  test('core/content has no literal colors and no CSS in strings', () {
    for (final file in _files('lib/core/content')) {
      final lines = file.readAsLinesSync();
      for (final (i, line) in lines.indexed) {
        final where = '${file.path}:${i + 1}';
        expect(line, isNot(matches(_literalColor)), reason: where);
        expect(line, isNot(contains('css(')), reason: where);
        expect(line, isNot(contains('.styles(')), reason: where);
        expect(line, isNot(contains('StudioColors')), reason: where);
        expect(line, isNot(contains('StudioText.')), reason: where);
        // A `raw:` is an exception with its reason: the lint's ignore above.
        if (line.contains('raw:')) {
          expect(
            lines[i - 1],
            contains('thor_lints/avoid_raw_css'),
            reason: '$where: raw CSS without its ignore and reason',
          );
        }
      }
    }
  });

  test('the example registry\'s code has none either', () {
    for (final name in ['examples.dart', 'example_view.dart']) {
      final file = _files(
        'lib/modules/guide/examples',
      ).firstWhere((f) => f.path.endsWith('/$name'));
      final text = file.readAsStringSync();
      expect(text, isNot(matches(_literalColor)), reason: name);
      expect(text, isNot(contains('raw:')), reason: name);
      expect(text, isNot(contains('css(')), reason: name);
    }
  });

  test('the bench examples use raw CSS only with its reason', () {
    for (final file in _files('lib/modules/guide/examples/bench')) {
      final lines = file.readAsLinesSync();
      for (final (i, line) in lines.indexed) {
        expect(line, isNot(matches(_literalColor)), reason: file.path);
        if (line.contains('raw:')) {
          expect(lines[i - 1], contains('thor_lints/avoid_raw_css'));
        }
      }
    }
  });
}
