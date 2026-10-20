import 'package:test/test.dart';
import 'package:thor_cli/thor_cli.dart';

void main() {
  group('thor test passes dart test options through without --', () {
    test('the options it does not know go after a --', () {
      expect(
        expandTestArgs(['test', 'test/a_test.dart', '--plain-name', 'adds']),
        ['test', '--', 'test/a_test.dart', '--plain-name', 'adds'],
      );
      expect(expandTestArgs(['test', '-N', 'a b', '-t', 'slow', '-j', '2']), [
        'test',
        '--',
        '-N',
        'a b',
        '-t',
        'slow',
        '-j',
        '2',
      ]);
    });

    test('its own options stay in front, whatever the order', () {
      expect(
        expandTestArgs(['test', '-n', 'x', '--no-codegen', '-a', 'shop']),
        ['test', '--no-codegen', '-a', 'shop', '--', '-n', 'x'],
      );
      expect(expandTestArgs(['test', '--app=shop', '--record']), [
        'test',
        '--app=shop',
        '--record',
      ]);
    });

    test('an explicit -- is kept as written; other commands are untouched', () {
      expect(expandTestArgs(['test', 'a_test.dart', '--', '-N', 'x']), [
        'test',
        '--',
        'a_test.dart',
        '-N',
        'x',
      ]);
      expect(expandTestArgs(['dev', '-N', 'x']), ['dev', '-N', 'x']);
      expect(expandTestArgs(['--help']), ['--help']);
    });

    test('the runner parses them instead of "Could not find an option"', () {
      for (final args in [
        ['test', 'test/a_test.dart', '--plain-name', 'adds'],
        ['test', '-N', 'adds'],
        ['test', '--name', 'a', '-x', 'slow', '-r', 'expanded', '-j', '1'],
        ['test', '--tags', 'ui', '--exclude-tags', 'slow'],
      ]) {
        final parsed = thorRunner().parse(args).command!;
        expect(parsed.name, 'test', reason: '$args');
        expect(parsed.rest, args.sublist(1), reason: '$args');
      }
    });

    test('--help lists the options that go through', () {
      final usage = thorRunner().commands['test']!.usage;
      for (final option in ['--plain-name', '--name', '--tags', '--reporter']) {
        expect(usage, contains(option));
      }
    });

    test('a value option left without its value is an error, not a path', () {
      expect(danglingValueOption(['-N']), '-N');
      expect(
        danglingValueOption(['a_test.dart', '--plain-name']),
        '--plain-name',
      );
      expect(danglingValueOption(['-N', 'x']), isNull);
      expect(danglingValueOption(['-N=x', '-j4']), isNull);
      expect(danglingValueOption(['--bogus']), isNull);
    });

    test('values with spaces, equals and bundles go through as written', () {
      expect(
        expandTestArgs([
          'test',
          '-N',
          'adds a line',
          '-j4',
          '-rjson',
          '--name=a.b',
        ]),
        ['test', '--', '-N', 'adds a line', '-j4', '-rjson', '--name=a.b'],
      );
      expect(expandTestArgs(['test', '-N', 'x', '--app', 'shop', '--record']), [
        'test',
        '--app',
        'shop',
        '--record',
        '--',
        '-N',
        'x',
      ]);
    });
  });
}
