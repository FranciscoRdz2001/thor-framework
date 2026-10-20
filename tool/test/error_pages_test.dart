import 'dart:io';

import 'package:test/test.dart';

void main() {
  // The pages are for whoever builds an app: no engine talk, no repository
  // commands or paths, no decision ids, no links outside the guide.
  final internals = RegExp(
    r'\blite\b|dart2js|\bmotor\b|tool/|\bapps/|packages/|ADR-\d|[Rr]onda'
    r'|\.dart_tool|data-t[a-z-]*|thorElement|ChildRules|WrapData'
    r'|\]\(\.\./(?!guia/)|docs/\d|history/',
  );

  test('the index points at this site, not at an old address', () {
    final readme = File('docs/errores/README.md').readAsStringSync();
    expect(readme, isNot(contains('vercel.app')));
  });

  test('the error pages carry no repository internals', () {
    final pages = Directory('docs/errores').listSync().whereType<File>();
    expect(pages, isNotEmpty);
    for (final page in pages) {
      final text = page.readAsStringSync();
      expect(internals.firstMatch(text)?.group(0), isNull, reason: page.path);
    }
  });
}
