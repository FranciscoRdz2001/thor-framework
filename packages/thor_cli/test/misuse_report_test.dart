import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thor_cli/thor_cli.dart';

void main() {
  late Directory app;
  setUp(() {
    app = Directory.systemTemp.createTempSync('thor_report');
    File(p.join(app.path, 'lib', 'clicks.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        'class A {\n'
        '  void f() {\n'
        '\tonPressed: () => setState(() => n++),\n'
        '  }\n'
        '}\n',
      );
  });
  tearDown(() => app.deleteSync(recursive: true));

  test('a Warning line is not an error', () {
    expect(
      isMisuseWarning('lib/a.dart:3:4: Warning: frozen (THOR-S015)'),
      true,
    );
    expect(isMisuseWarning('lib/a.dart:3:4: Error: x (THOR-S011)'), false);
    expect(isMisuseWarning('lib/a.dart:3:4: Error: a Warning: inside'), false);
    // An error that quotes the location of a warning is still an error.
    expect(
      isMisuseWarning('lib/a.dart:3:4: Error: x lib/b.dart:1:2: Warning: y'),
      false,
    );
  });

  group('misuseReport', () {
    test('puts the source line and a caret under the column', () {
      final report = misuseReport(app.path, [
        'lib/clicks.dart:3:17: Error: setState does nothing (THOR-S014) Move it.',
      ]);
      expect(
        report,
        'lib/clicks.dart:3:17: Error: setState does nothing (THOR-S014) Move it.\n'
        '  3 | \tonPressed: () => setState(() => n++),\n'
        '    | \t               ^',
      );
    });

    test('a line it cannot place stays as it is', () {
      final lines = [
        'lib/gone.dart:1:1: Error: x',
        'lib/clicks.dart:99:1: Error: y',
        'not a location',
      ];
      expect(misuseReport(app.path, lines), lines.join('\n'));
    });

    test('several misuses are separated and each has its frame', () {
      final report = misuseReport(app.path, [
        'lib/clicks.dart:2:3: Error: a',
        'lib/clicks.dart:4:3: Error: b',
      ]);
      expect(report.split('\n'), hasLength(6));
      expect(report, contains('  2 |   void f() {'));
      expect(report, contains('  4 |   }'));
    });

    test('a long line is cut after the column', () {
      File(
        p.join(app.path, 'lib', 'long.dart'),
      ).writeAsStringSync('${'x' * 300}\n');
      final report = misuseReport(app.path, ['lib/long.dart:1:5: Error: z']);
      expect(report.split('\n')[1].length, lessThan(100));
      expect(report, contains('…'));
    });
  });
}
