@TestOn('vm')
@Timeout(Duration(minutes: 4))
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Pages rendered in order by `fixtures/css_cache.dart`, in release (the
/// stylesheet text is kept per process there), by name.
Future<Map<String, List<String>>> _render(List<String> names) async {
  final result = await Process.run(Platform.resolvedExecutable, [
    'run',
    '-Dthor.release=true',
    'test/fixtures/css_cache.dart',
    ...names,
  ]);
  expect(result.exitCode, 0, reason: '${result.stderr}');
  final pages = <String, List<String>>{};
  for (final line in LineSplitter.split(result.stdout as String)) {
    final [name, html] = line.split(' ');
    (pages[name] ??= []).add(utf8.decode(base64.decode(html)));
  }
  return pages;
}

void main() {
  test('a page gets the stylesheet it builds, whatever came before', () async {
    const names = ['plain', 'row', 'row-blue', 'row-dark', 'padded'];
    // Each page alone: a cold cache, the reference.
    final alone = {
      for (final name in names) name: (await _render([name]))[name]!.single,
    };
    // All of them in one process, twice and interleaved: warm hits, and
    // pages with the same classes and other theme variables in between.
    final together = await _render([
      ...names,
      'row-dark',
      'row',
      'padded',
      'row-blue',
      'plain',
      'row',
    ]);
    for (final name in names) {
      for (final html in together[name]!) {
        expect(html, alone[name], reason: name);
      }
    }
    // The themes do change the stylesheet: the check compares something.
    expect(alone['row'], isNot(alone['row-blue']));
    expect(alone['row-blue'], isNot(alone['row-dark']));
  });
}
