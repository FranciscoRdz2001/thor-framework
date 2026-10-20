import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../api_filter.dart';

void main() {
  final reference = File('docs/api/thor_ui.md').readAsStringSync();
  final shown = RegExp(
    r'^### `([^`]+)`',
    multiLine: true,
  ).allMatches(reference).map((m) => m[1]!).toSet();
  final widgets = [
    for (final w
        in jsonDecode(File('docs/api/widgets.json').readAsStringSync()) as List)
      (w as Map)['name'] as String,
  ];

  test('no internal name gets a page in the reference', () {
    expect(shown, isNotEmpty);
    expect(shown.intersection(internalNames), isEmpty);
    // Protocol constants and generated-code helpers an app never writes.
    for (final name in ['textAttr', 'encodePatch', 'registerRowProbes']) {
      expect(shown, isNot(contains(name)));
    }
  });

  test('no internal name gets a widget page', () {
    expect(widgets, isNotEmpty);
    expect(widgets.toSet().intersection(internalNames), isEmpty);
    for (final name in ['ChildRulesScope', 'WrapWith', 'ThorElementWidget']) {
      expect(widgets, isNot(contains(name)));
    }
  });

  test('the topics for authors of Thor itself have no page', () {
    for (final topic in internalTopics) {
      expect(reference, isNot(contains('## `$topic` ·')));
    }
    expect(shown, contains('ThorApp'));
  });

  test('every filtered name is still exported (the list has no typos)', () {
    final exported = {
      for (final line in File('docs/api/public_api.txt').readAsLinesSync())
        if (line.isNotEmpty) line.split('\t')[1],
    };
    expect(internalNames.difference(exported), isEmpty);
  });

  test('the reference carries no repository internals', () {
    final text = reference + File('docs/api/widgets.json').readAsStringSync();
    expect(text, isNot(matches(RegExp(r'ADR-\d|\.dart_tool|tool/thor'))));
  });

  test('scrubDoc drops decision ids', () {
    expect(
      scrubDoc('The memo (ADR-075): built once.'),
      'The memo: built once.',
    );
    expect(
      scrubDoc('A memo ([X], ADR-075) is added.'),
      'A memo ([X]) is added.',
    );
  });
}
