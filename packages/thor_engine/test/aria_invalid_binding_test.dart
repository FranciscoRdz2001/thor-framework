@TestOn('vm')
library;

// `aria-invalid` bound to a field's error message (`InputDecoration(
// errorTextWatch:)`): any text but `false` or none turns it on.
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart';

void main() {
  test('a message is true, empty and false take it off', () {
    expect(safeAttributeValue('aria-invalid', 'Use dd.mm.yyyy'), 'true');
    expect(safeAttributeValue('aria-invalid', 'true'), 'true');
    expect(safeAttributeValue('aria-invalid', 'grammar'), 'grammar');
    expect(safeAttributeValue('aria-invalid', 'spelling'), 'spelling');
    expect(safeAttributeValue('aria-invalid', ''), isNull);
    expect(safeAttributeValue('aria-invalid', 'false'), isNull);
  });

  test('other aria attributes keep their text', () {
    expect(safeAttributeValue('aria-label', 'false'), 'false');
    expect(safeAttributeValue('aria-valuenow', ''), '');
  });

  test('the lite bundle part says the same', () {
    final js = File('lib/lite/parts/attributes.js').readAsStringSync();
    expect(js, contains("n === 'aria-invalid'"));
  });
}
