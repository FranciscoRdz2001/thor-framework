@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

/// The page of `fixtures/render_mode.dart`, compiled with [defines].
Future<String> _render(List<String> defines) async {
  final result = await Process.run(Platform.resolvedExecutable, [
    'run',
    ...defines,
    'test/fixtures/render_mode.dart',
  ]);
  expect(result.exitCode, 0, reason: '${result.stderr}');
  return result.stdout as String;
}

/// Release: no debug attributes (`data-thor`, the inspector's) and no
/// line breaks between elements after the doctype.
bool _isRelease(String html) =>
    !html.contains('data-thor') &&
    !html.substring(html.indexOf('<html')).trimRight().contains('>\n');

void main() {
  test('no flag: a debug page (inspector attributes)', () async {
    expect(_isRelease(await _render(const [])), isFalse);
  });

  test("thor's flag: a release page (compact, no debug attributes)", () async {
    final html = await _render(const ['-Dthor.release=true']);
    expect(_isRelease(html), isTrue, reason: html);
  });

  test('only an exact true turns release on (fail-closed)', () async {
    for (final value in ['false', 'TRUE', '1', 'yes', '']) {
      final html = await _render(['-Dthor.release=$value']);
      expect(_isRelease(html), isFalse, reason: 'thor.release=$value');
    }
  });
}
