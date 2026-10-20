import 'dart:io';

import 'package:test/test.dart';

import '../ratchet_count.dart';

void main() {
  group('countSource', () {
    test('counts ignores and raw arguments in code', () {
      final c = countSource('''
// ignore: thor_lints/avoid_raw_css
final a = StyleProps(raw: {'x': 'y'});
final b = css('.x').styles(raw: _map);
// ignore: thor_lints/a, thor_lints/b
''');
      expect(c, (ignores: 3, rawUses: 2));
    });

    test('file-level ignores count; other linters do not', () {
      expect(
        countSource('// ignore_for_file: thor_lints/avoid_raw_css\n').ignores,
        1,
      );
      expect(countSource('// ignore: unused_element\n').ignores, 0);
    });

    test('docs, comments and strings do not count', () {
      final c = countSource(r'''
/// Silence it with `// ignore: thor_lints/avoid_raw_css`.
/// Use `raw: {...}` for the rest.
// raw: {'a': 'b'} was removed.
final s = 'raw: {x}';
final t = "// ignore: thor_lints/avoid_raw_css";
final u = Foo(rawValue: 1, drawRaw: 2, x.raw: 3);
''');
      expect(c, (ignores: 0, rawUses: 0));
    });

    test('a // inside a string does not hide the code after it', () {
      expect(
        countSource("final a = Foo(url: 'http://x', raw: {});\n").rawUses,
        1,
      );
    });
  });

  group('countRepo', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('ratchet_test'));
    tearDown(() => root.deleteSync(recursive: true));

    void write(String path, String text) {
      File('${root.path}/$path')
        ..createSync(recursive: true)
        ..writeAsStringSync(text);
    }

    test('counts per package, skips test/, build output and hidden dirs', () {
      write('packages/a/pubspec.yaml', 'name: a\n');
      write('packages/a/lib/a.dart', 'final x = P(raw: {});\n');
      write('packages/a/test/a_test.dart', 'final x = P(raw: {});\n');
      write('packages/a/build/b.dart', 'final x = P(raw: {});\n');
      write('packages/a/.dart_tool/b.dart', 'final x = P(raw: {});\n');
      write('apps/b/pubspec.yaml', 'name: b\n');
      write(
        'apps/b/lib/b.dart',
        '// ignore: thor_lints/avoid_raw_css\nfinal x = P(raw: {});\n',
      );
      write('apps/clean/pubspec.yaml', 'name: clean\n');
      write('apps/clean/lib/c.dart', 'final x = 1;\n');
      expect(countRepo(root), {
        'packages/a': {'ignores': 0, 'raw': 1},
        'apps/b': {'ignores': 1, 'raw': 1},
      });
    });
  });

  group('baseline', () {
    test('formats sorted, drops zeros and parses back', () {
      final counts = {
        'b': {'ignores': 2, 'raw': 0},
        'a': {'ignores': 0, 'raw': 3},
      };
      final text = formatBaseline(counts);
      expect(text, contains('a\traw\t3\nb\tignores\t2\n'));
      expect(text, isNot(contains('\t0')));
      expect(parseBaseline(text), {
        'a': {'raw': 3},
        'b': {'ignores': 2},
      });
    });

    test('a bad line is an error', () {
      expect(() => parseBaseline('a\tfoo\t1\n'), throwsFormatException);
    });
  });

  group('compareRatchet', () {
    final baseline = {
      'a': {'ignores': 2, 'raw': 5},
    };

    test('a rise fails, including in a package new to the baseline', () {
      final change = compareRatchet(baseline, {
        'a': {'ignores': 3, 'raw': 5},
        'new': {'ignores': 0, 'raw': 1},
      });
      expect(change.rose.map((c) => c.toString()), [
        'a: ignores 2 -> 3',
        'new: raw 0 -> 1',
      ]);
      expect(change.fell, isEmpty);
    });

    test('a fall is reported to lower the baseline, not a failure', () {
      final change = compareRatchet(baseline, {
        'a': {'ignores': 1, 'raw': 5},
      });
      expect(change.rose, isEmpty);
      expect(change.fell.map((c) => c.toString()), ['a: ignores 2 -> 1']);
    });

    test('the same counts change nothing', () {
      final change = compareRatchet(baseline, baseline);
      expect(change.rose, isEmpty);
      expect(change.fell, isEmpty);
    });
  });
}
