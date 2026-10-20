import 'dart:math';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

/// `parseIsoDateTime(s)` is `DateTime.parse(s)`: the same value, or the
/// same kind of error.
void expectSame(String s) {
  Object? expected, actual;
  try {
    expected = DateTime.parse(s);
  } on FormatException {
    expected = FormatException;
  }
  try {
    actual = parseIsoDateTime(s);
  } on FormatException {
    actual = FormatException;
  }
  expect(actual, expected, reason: s);
  if (expected is DateTime) {
    expect((actual as DateTime).isUtc, expected.isUtc, reason: s);
  }
}

void main() {
  test('the UTC form backends send, with every fraction length', () {
    for (final s in [
      '2026-09-26T12:34:56Z',
      '2026-09-26T12:34:56.7Z',
      '2026-09-26T12:34:56.78Z',
      '2026-09-26T12:34:56.789Z',
      '2026-09-26T12:34:56.7891Z',
      '2026-09-26T12:34:56.78912Z',
      '2026-09-26T12:34:56.789123Z',
      '0001-01-01T00:00:00.000Z',
      '9999-12-31T23:59:59.999999Z',
      '2024-02-29T00:00:00.000Z',
    ]) {
      expectSame(s);
    }
  });

  test(
    'out of range values normalize (or fail) exactly like DateTime.parse',
    () {
      for (final s in [
        '2023-02-29T00:00:00Z',
        '2026-13-01T00:00:00Z',
        '2026-00-10T00:00:00Z',
        '2026-01-32T00:00:00Z',
        '2026-01-01T24:00:00Z',
        '2026-01-01T23:60:00Z',
        '2026-01-01T23:59:60Z',
        '2026-01-01T99:99:99.999Z',
      ]) {
        expectSame(s);
      }
    },
  );

  test('every other form goes to DateTime.parse', () {
    for (final s in [
      '2026-09-26',
      '2026-09-26 12:34:56Z',
      '2026-09-26t12:34:56z',
      '2026-09-26T12:34:56',
      '2026-09-26T12:34:56+02:00',
      '2026-09-26T12:34:56.1234567Z',
      '2026-09-26T12:34:56.Z',
      '2026-09-26T12:34:56,5Z',
      '+002026-09-26T12:34:56Z',
      '-2026-09-26T12:34:56Z',
      '2026-9-26T12:34:56Z',
      '2026-09-26T12:34:5aZ',
      '2026-09-26T12:34:56.x5Z',
      'nope',
      '',
    ]) {
      expectSame(s);
    }
  });

  test('random strings shaped like the fast form', () {
    final r = Random(7);
    const chars = '0123456789-:.TZtz +x';
    for (var i = 0; i < 20000; i++) {
      final shape = r.nextBool()
          ? '${r.nextInt(10000).toString().padLeft(4, '0')}-'
                '${r.nextInt(14).toString().padLeft(2, '0')}-'
                '${r.nextInt(33).toString().padLeft(2, '0')}T'
                '${r.nextInt(26).toString().padLeft(2, '0')}:'
                '${r.nextInt(62).toString().padLeft(2, '0')}:'
                '${r.nextInt(62).toString().padLeft(2, '0')}'
                '${r.nextBool() ? '' : '.${r.nextInt(1000000)}'}Z'
          : String.fromCharCodes([
              for (var j = 0; j < 20 + r.nextInt(8); j++)
                chars.codeUnitAt(r.nextInt(chars.length)),
            ]);
      expectSame(shape);
    }
  });
}
