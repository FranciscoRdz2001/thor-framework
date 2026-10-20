@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

/// Runs the fixture page with `THOR_RENDER_TO=<target>` (and [env]).
Future<ProcessResult> _render(
  String target, [
  Map<String, String>? env,
  String page = 'render_page.dart',
]) => Process.run(
  Platform.resolvedExecutable,
  ['run', '-Dthor.release=true', 'test/fixtures/$page'],
  environment: {'THOR_RENDER_TO': target, ...?env},
);

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('thor_static'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('renders the page once to the file and exits, no server', () async {
    final target = '${tmp.path}/index.html';
    final result = await _render(target);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final html = File(target).readAsStringSync();
    expect(html, contains('<title>Fixture</title>'));
    expect(html, contains('hello'));
    expect(html, isNot(contains('data-thor')), reason: 'release');
  });

  test('creates the folders the target needs', () async {
    final target = '${tmp.path}/a/b/c/index.html';
    final result = await _render(target);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(File(target).existsSync(), isTrue);
  });

  test('a page that throws fails the process and writes nothing', () async {
    final target = '${tmp.path}/index.html';
    final result = await _render(target, {'FIXTURE_THROW': '1'});
    expect(result.exitCode, isNot(0));
    expect('${result.stderr}', contains('the page failed on purpose'));
    expect(File(target).existsSync(), isFalse);
  });

  group('THOR_LOCALE', () {
    Future<(int, String?)> localized(String locale) async {
      final target = '${tmp.path}/$locale.html';
      final result = await _render(target, {
        'THOR_LOCALE': locale,
      }, 'render_localized_page.dart');
      final file = File(target);
      return (
        result.exitCode,
        file.existsSync() ? file.readAsStringSync() : null,
      );
    }

    test('renders the page in that locale, with lang and dir', () async {
      final (code, html) = await localized('ar');
      expect(code, 0);
      expect(html, contains('<html lang="ar" dir="rtl">'));
      expect(html, contains('in ar'));
    });

    test('an unsupported locale renders the first supported one', () async {
      final (code, html) = await localized('fr-CA');
      expect(code, 0);
      expect(html, contains('<html lang="en" dir="ltr">'));
    });

    test('a value that is not a language tag fails, writing nothing', () async {
      final (code, html) = await localized('e"><x');
      expect(code, 64);
      expect(html, isNull);
    });
  });
}
