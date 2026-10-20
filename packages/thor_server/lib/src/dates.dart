/// Reading the dates a backend sends: the same result as `DateTime.parse`,
/// without its regular expression for the form APIs use.
library;

/// `DateTime.parse(text)`, fast for the UTC form backends send
/// (`2026-09-26T12:00:00Z`, with up to six fraction digits); any other form
/// goes to `DateTime.parse` itself, so the result is always the same.
///
/// `DateTime.parse` matches every input with a regular expression, which
/// costs about a microsecond: a list page parses one or two dates per item
/// on every request.
DateTime parseIsoDateTime(String text) {
  final n = text.length;
  // YYYY-MM-DDTHH:MM:SS then an optional .fraction, then Z.
  if (n >= 20 &&
      n <= 27 &&
      text.codeUnitAt(4) == _dash &&
      text.codeUnitAt(7) == _dash &&
      text.codeUnitAt(10) == _t &&
      text.codeUnitAt(13) == _colon &&
      text.codeUnitAt(16) == _colon &&
      text.codeUnitAt(n - 1) == _z) {
    final year = _digits(text, 0, 4);
    final month = _digits(text, 5, 7);
    final day = _digits(text, 8, 10);
    final hour = _digits(text, 11, 13);
    final minute = _digits(text, 14, 16);
    final second = _digits(text, 17, 19);
    var micros = 0;
    var ok =
        year >= 0 &&
        month >= 0 &&
        day >= 0 &&
        hour >= 0 &&
        minute >= 0 &&
        second >= 0;
    if (ok && n > 20) {
      // `.` and 1–6 digits, padded on the right to microseconds.
      final fraction = n - 21;
      if (text.codeUnitAt(19) != _dot || fraction < 1) {
        ok = false;
      } else {
        final value = _digits(text, 20, n - 1);
        if (value < 0) {
          ok = false;
        } else {
          micros = value * _scale[fraction];
        }
      }
    }
    if (ok) {
      return DateTime.utc(year, month, day, hour, minute, second, 0, micros);
    }
  }
  return DateTime.parse(text);
}

/// The number in `text[start, end)`, or -1 when a character isn't a digit.
int _digits(String text, int start, int end) {
  var value = 0;
  for (var i = start; i < end; i++) {
    final d = text.codeUnitAt(i) - 0x30;
    if (d < 0 || d > 9) return -1;
    value = value * 10 + d;
  }
  return value;
}

const _dash = 0x2D;
const _colon = 0x3A;
const _dot = 0x2E;
const _t = 0x54;
const _z = 0x5A;
// Microseconds per unit of an n-digit fraction (index = n).
const _scale = [0, 100000, 10000, 1000, 100, 10, 1];
