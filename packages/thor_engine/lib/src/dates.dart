/// Dates and times of day for the date and time pickers, with Flutter's
/// names ([DateUtils], [TimeOfDay], [DatePickerMode]), plus the page
/// protocol the server and `DatePickerFeature` share (ISO values, the mask
/// of disabled days, the markers).
///
/// Pure Dart: the server renders the first month with the same math the
/// browser uses for the others.
library;

/// Flutter's `SelectableDayPredicate`: whether [day] can be picked.
typedef SelectableDayPredicate = bool Function(DateTime day);

/// Flutter's `DatePickerMode`: what the calendar shows first.
enum DatePickerMode {
  /// The days of a month.
  day,

  /// A list of years.
  year,
}

/// Flutter's `DateUtils` (the parts a calendar needs).
abstract final class DateUtils {
  /// [date] at midnight (local), without the time.
  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Whether [dateA] and [dateB] are the same day (null never is).
  static bool isSameDay(DateTime? dateA, DateTime? dateB) =>
      dateA?.year == dateB?.year &&
      dateA?.month == dateB?.month &&
      dateA?.day == dateB?.day &&
      dateA != null;

  /// Whether [dateA] and [dateB] fall in the same month (null never does).
  static bool isSameMonth(DateTime? dateA, DateTime? dateB) =>
      dateA?.year == dateB?.year &&
      dateA?.month == dateB?.month &&
      dateA != null;

  /// Months from [startDate]'s month to [endDate]'s (negative if before).
  static int monthDelta(DateTime startDate, DateTime endDate) =>
      (endDate.year - startDate.year) * 12 + endDate.month - startDate.month;

  /// The first day of the month [monthsToAdd] months after [monthDate]'s.
  static DateTime addMonthsToMonthDate(DateTime monthDate, int monthsToAdd) =>
      DateTime(monthDate.year, monthDate.month + monthsToAdd);

  /// [date] plus [days] calendar days (midnight, whatever the DST).
  static DateTime addDaysToDate(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  /// Days in [month] (1–12) of [year].
  static int getDaysInMonth(int year, int month) {
    if (month == DateTime.february) {
      final leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
      return leap ? 29 : 28;
    }
    const days = [31, -1, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month - 1];
  }
}

/// Flutter's `DayPeriod`.
enum DayPeriod {
  /// Midnight to noon.
  am,

  /// Noon to midnight.
  pm,
}

/// Flutter's `TimeOfDay`: an hour and a minute, no date or time zone.
final class TimeOfDay implements Comparable<TimeOfDay> {
  /// [hour] (0–23) and [minute] (0–59).
  const TimeOfDay({required this.hour, required this.minute});

  /// The time of day of [time].
  TimeOfDay.fromDateTime(DateTime time)
    : hour = time.hour,
      minute = time.minute;

  /// The current time of day (on the server: the server's clock).
  factory TimeOfDay.now() => TimeOfDay.fromDateTime(DateTime.now());

  /// Hours in a day.
  static const hoursPerDay = 24;

  /// Hours in a period (am/pm).
  static const hoursPerPeriod = 12;

  /// Minutes in an hour.
  static const minutesPerHour = 60;

  /// The hour, 0–23.
  final int hour;

  /// The minute, 0–59.
  final int minute;

  /// This time with [hour] and/or [minute] replaced.
  TimeOfDay replacing({int? hour, int? minute}) =>
      TimeOfDay(hour: hour ?? this.hour, minute: minute ?? this.minute);

  /// Whether it is before or after noon.
  DayPeriod get period => hour < hoursPerPeriod ? DayPeriod.am : DayPeriod.pm;

  /// The hour on a 12-hour clock (12 for noon and midnight).
  int get hourOfPeriod => hour == 0 || hour == 12 ? 12 : hour % 12;

  /// Hours [period] adds: 0 or 12.
  int get periodOffset => period == DayPeriod.am ? 0 : hoursPerPeriod;

  /// Whether this time comes before [other] in the day.
  bool isBefore(TimeOfDay other) => compareTo(other) < 0;

  /// Whether this time comes after [other] in the day.
  bool isAfter(TimeOfDay other) => compareTo(other) > 0;

  /// Whether this is the same time as [other].
  bool isAtSameTimeAs(TimeOfDay other) => compareTo(other) == 0;

  @override
  int compareTo(TimeOfDay other) =>
      (hour * minutesPerHour + minute) -
      (other.hour * minutesPerHour + other.minute);

  @override
  bool operator ==(Object other) =>
      other is TimeOfDay && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => 'TimeOfDay(${isoTime(this)})';
}

// ---------------------------------------------------------------------------
// Page protocol (server ↔ DatePickerFeature). Not re-exported by thor_ui.

/// A calendar root (`CalendarDatePicker`); its value is the calendar's
/// [DatePickerConfig] (range, today, names, disabled days).
const datePickerAttr = 'data-t-date';

/// The month a calendar shows (`2026-09`).
const dateMonthAttr = 'data-t-month';

/// What a calendar shows: `day` or `year`.
const dateModeAttr = 'data-t-mode';

/// The calendar's value holder: an `<input type="hidden">` (`yyyy-mm-dd`).
const dateValueAttr = 'data-t-value';

/// A month step button (`-1` / `1`).
const dateNavAttr = 'data-t-nav';

/// The button that toggles the year list.
const dateYearsAttr = 'data-t-years';

/// The container the browser fills with the years.
const dateYearListAttr = 'data-t-year-list';

/// The `<tbody>` of the days (6 rows × 7 cells, always).
const dateDaysAttr = 'data-t-days';

/// A picker dialog; its value names the field it writes to (an element
/// id), or is empty when its own hidden input does.
const pickerDialogAttr = 'data-t-picker';

/// What a picker dialog edits until it is confirmed (the calendar's value
/// holder, or a time input).
const pickerPendingAttr = 'data-t-pick';

/// A picker dialog's own output (`<input type="hidden">`).
const pickerOutAttr = 'data-t-pick-out';

/// A picker dialog's confirm button.
const pickerConfirmAttr = 'data-t-pick-ok';

/// The dialog headline that shows the pending date.
const pickerHeadlineAttr = 'data-t-headline';

/// A date field's calendar button (hidden until the engine runs).
const dateOpenAttr = 'data-t-date-open';

/// A native date input the pickers write to.
const dateFieldAttr = 'data-t-date-field';

/// Set by the engine on a date field whose calendar button works.
const dateReadyAttr = 'data-t-ready';

/// The custom event a calendar dispatches when it shows another month
/// (`onDisplayedMonthChanged`; detail: `yyyy-mm-dd`, the 1st).
const displayedMonthEvent = 'thor-month';

/// The ASCII digits, zero first.
const latinDigits = '0123456789';

/// A calendar's configuration in the page ([datePickerAttr]): fields
/// separated by `|`, lists by `,` (no JSON: no escaped quotes in the
/// attribute).
final class DatePickerConfig {
  /// A configuration.
  const DatePickerConfig({
    required this.first,
    required this.last,
    this.today,
    required this.firstDayOfWeek,
    required this.months,
    required this.shortMonths,
    required this.shortWeekdays,
    required this.monthYear,
    required this.mediumDate,
    required this.noDate,
    this.mask,
    this.digits = latinDigits,
  });

  /// The configuration [text] ([encode]) describes.
  factory DatePickerConfig.decode(String text) {
    final f = text.split('|');
    return DatePickerConfig(
      first: parseIsoDate(f[0])!,
      last: parseIsoDate(f[1])!,
      today: parseIsoDate(f[2]),
      firstDayOfWeek: int.parse(f[3]),
      months: f[4].split(','),
      shortMonths: f[5].split(','),
      shortWeekdays: f[6].split(','),
      monthYear: f[7],
      mediumDate: f[8],
      noDate: f[9],
      mask: f[10].isEmpty ? null : f[10],
      digits: f.length > 11 && f[11].isNotEmpty ? f[11] : latinDigits,
    );
  }

  /// First and last selectable dates.
  final DateTime first, last;

  /// Today (`currentDate`), or null: the reader's.
  final DateTime? today;

  /// Index of the first day of the week (0 = Sunday).
  final int firstDayOfWeek;

  /// Month names, short month names and short weekday names (Sunday
  /// first).
  final List<String> months, shortMonths, shortWeekdays;

  /// Month–year template (`{M}`, `{y}`).
  final String monthYear;

  /// Medium date template (`{w}`, `{m}`, `{d}`).
  final String mediumDate;

  /// The dialog headline with no date.
  final String noDate;

  /// Disabled days ([encodeDayMask]).
  final String? mask;

  /// The ten digits of the page's locale, zero first (`0123456789`,
  /// `٠١٢٣٤٥٦٧٨٩`): the browser writes the day numbers and the year with
  /// them, like the server does.
  final String digits;

  /// [n] written with [digits].
  String num(int n) {
    final d = digits.runes.toList();
    if (d.length != 10) return '$n';
    return String.fromCharCodes([
      for (final c in '$n'.codeUnits) c >= 0x30 && c <= 0x39 ? d[c - 0x30] : c,
    ]);
  }

  /// The attribute value.
  String encode() => [
    isoDate(first),
    isoDate(last),
    if (today case final t?) isoDate(t) else '',
    '$firstDayOfWeek',
    months.join(','),
    shortMonths.join(','),
    shortWeekdays.join(','),
    monthYear,
    mediumDate,
    noDate,
    mask ?? '',
    digits,
  ].join('|');
}

/// [date] as `yyyy-mm-dd` (what `<input type="date">` submits).
String isoDate(DateTime date) =>
    '${_pad(date.year, 4)}-${_pad(date.month, 2)}-${_pad(date.day, 2)}';

/// [time] as `hh:mm` (what `<input type="time">` submits).
String isoTime(TimeOfDay time) =>
    '${_pad(time.hour, 2)}:${_pad(time.minute, 2)}';

String _pad(int n, int width) => '$n'.padLeft(width, '0');

/// `yyyy-mm-dd` (or `yyyy-mm`, the 1st) as a UTC date, or null. No
/// `RegExp`: the browser build stays small.
DateTime? parseIsoDate(String? text) {
  if (text == null) return null;
  final parts = text.split('-');
  if (parts.length < 2 || parts.length > 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = parts.length == 3 ? int.tryParse(parts[2]) : 1;
  if (y == null || m == null || d == null || m < 1 || m > 12 || d < 1) {
    return null;
  }
  if (d > DateUtils.getDaysInMonth(y, m)) return null;
  return DateTime.utc(y, m, d);
}

/// Cells before the 1st of [month] in a calendar whose weeks start on
/// [firstDayOfWeek] (0 = Sunday, Flutter's `firstDayOfWeekIndex`).
int firstDayOffset(int year, int month, int firstDayOfWeek) {
  // DateTime.weekday: Monday = 1 … Sunday = 7 → Sunday = 0.
  final weekday = DateTime.utc(year, month).weekday % 7;
  return (weekday - firstDayOfWeek) % 7;
}

/// Whole days from [from] to [to] (calendar days, whatever the time zone).
int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

const _maskAlphabet =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';

const _msPerDay = 86400000;

/// The days from [first] to [last] that [selectable] rejects, or null when
/// every day is selectable. The days are counted in UTC (no local
/// `DateTime` per day: no time zone lookup, and no day lost or doubled where
/// a DST change skips midnight), and [selectable] gets each one as a UTC
/// date.
///
/// Two characters of header, then the days. The weekdays disabled on every
/// day of the range are in the header (seven bits, Sunday first); the rest
/// are run lengths (see [DayMask]) or, when that is shorter, six days per
/// character. "No weekends" over 1900 to 2100 is the two characters of the
/// header and nothing else; a handful of holidays on top add a few
/// characters each.
String? encodeDayMask(
  DateTime first,
  DateTime last,
  SelectableDayPredicate selectable,
) {
  final days = daysBetween(first, last) + 1;
  final start =
      DateTime.utc(first.year, first.month, first.day).millisecondsSinceEpoch ~/
      _msPerDay;
  // 1970-01-01 was a Thursday (4, Sunday = 0).
  final weekday0 = (start + 4) % 7;
  final off = List<bool>.filled(days, false);
  // Per weekday: how many days it has in the range, and how many are off.
  final seen = List<int>.filled(7, 0), rejected = List<int>.filled(7, 0);
  var any = false;
  for (var i = 0; i < days; i++) {
    final day = DateTime.fromMillisecondsSinceEpoch(
      (start + i) * _msPerDay,
      isUtc: true,
    );
    final w = (weekday0 + i) % 7;
    seen[w]++;
    if (!selectable(day)) {
      off[i] = true;
      rejected[w]++;
      any = true;
    }
  }
  if (!any) return null;
  var weekdays = 0;
  for (var w = 0; w < 7; w++) {
    if (seen[w] > 0 && rejected[w] == seen[w]) weekdays |= 1 << w;
  }
  // Run lengths over the days the header does not cover (a covered day
  // joins the run it is in: it is disabled either way).
  final runs = StringBuffer();
  var current = false, length = 0;
  for (var i = 0; i < days; i++) {
    if (weekdays & (1 << ((weekday0 + i) % 7)) == 0 && off[i] != current) {
      _writeVarint(runs, length);
      length = 0;
      current = off[i];
    }
    length++;
  }
  // Six days per character.
  final bitmap = StringBuffer();
  for (var i = 0; i < days; i += 6) {
    var bits = 0;
    for (var b = 0; b < 6 && i + b < days; b++) {
      if (off[i + b]) bits |= 1 << b;
    }
    bitmap.write(_maskAlphabet[bits]);
  }
  final useBitmap = bitmap.length < runs.length;
  final head = weekdays | (useBitmap ? 1 << 7 : 0);
  return '${_maskAlphabet[head & 63]}${_maskAlphabet[head >> 6]}'
      '${useBitmap ? bitmap : runs}';
}

/// 5 bits per character, low first; bit 5 says another character follows.
void _writeVarint(StringBuffer out, int n) {
  while (n >= 32) {
    out.write(_maskAlphabet[32 | (n & 31)]);
    n >>= 5;
  }
  out.write(_maskAlphabet[n]);
}

/// The disabled days of a date picker, read from the mask [encodeDayMask]
/// wrote (the browser reads the same format). Decode once, ask for many
/// days.
final class DayMask {
  DayMask._(this._weekdays, this._weekday0, this._bitmap, this._toggles);

  /// Reads [mask], whose day 0 is [first].
  factory DayMask.decode(String mask, DateTime first) {
    final head =
        _maskAlphabet.indexOf(mask[0]) | (_maskAlphabet.indexOf(mask[1]) << 6);
    final weekday0 =
        DateTime.utc(first.year, first.month, first.day).weekday % 7;
    final body = mask.substring(2);
    if (head & (1 << 7) != 0) {
      return DayMask._(head & 127, weekday0, body, const []);
    }
    // The days at which the state flips: the sum of the run lengths so far.
    final toggles = <int>[];
    var at = 0, n = 0, shift = 0;
    for (var i = 0; i < body.length; i++) {
      final v = _maskAlphabet.indexOf(body[i]);
      n |= (v & 31) << shift;
      if (v & 32 != 0) {
        shift += 5;
        continue;
      }
      at += n;
      toggles.add(at);
      n = 0;
      shift = 0;
    }
    return DayMask._(head & 127, weekday0, null, toggles);
  }

  final int _weekdays;
  final int _weekday0;
  final String? _bitmap;
  final List<int> _toggles;

  /// Whether day [index] (0 = the first date) is disabled.
  bool isDisabled(int index) {
    if (index < 0) return false;
    if (_weekdays & (1 << ((_weekday0 + index) % 7)) != 0) return true;
    final bitmap = _bitmap;
    if (bitmap != null) {
      final c = index ~/ 6;
      if (c >= bitmap.length) return false;
      return (_maskAlphabet.indexOf(bitmap[c]) >> (index % 6)) & 1 == 1;
    }
    // The flips at or before [index]: an odd number leaves it disabled.
    var lo = 0, hi = _toggles.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_toggles[mid] <= index) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo.isOdd;
  }
}

/// One cell of a month grid ([layoutMonth]).
final class DayCell {
  /// A cell; [day] is null outside the month.
  const DayCell(
    this.day, {
    this.stop = false,
    this.selected = false,
    this.today = false,
    this.disabled = false,
  });

  /// The day of the month, or null for a blank cell.
  final int? day;

  /// Whether it holds the roving tab stop.
  final bool stop;

  /// Whether it is the selected day.
  final bool selected;

  /// Whether it is today.
  final bool today;

  /// Whether it can't be picked.
  final bool disabled;
}

/// The 42 cells (6 weeks) of [month] in a calendar whose weeks start on
/// [firstDayOfWeek]. The tab stop is [focus] if it is in the month, else
/// [selected] or [today] if enabled there, else the first [enabled] day,
/// else the 1st.
/// The server and the engine lay out the same grid with it.
List<DayCell> layoutMonth({
  required DateTime month,
  required int firstDayOfWeek,
  DateTime? selected,
  DateTime? today,
  DateTime? focus,
  required bool Function(DateTime day) enabled,
}) {
  final y = month.year, m = month.month;
  final offset = firstDayOffset(y, m, firstDayOfWeek);
  final count = DateUtils.getDaysInMonth(y, m);
  int? dayIn(DateTime? d) =>
      d != null && d.year == y && d.month == m ? d.day : null;
  int? enabledIn(DateTime? d) {
    final n = dayIn(d);
    return n != null && enabled(DateTime.utc(y, m, n)) ? n : null;
  }

  // The keyboard may rest on a disabled day; the first stop may not.
  var stop = dayIn(focus) ?? enabledIn(selected) ?? enabledIn(today);
  if (stop == null) {
    for (var d = 1; d <= count && stop == null; d++) {
      if (enabled(DateTime.utc(y, m, d))) stop = d;
    }
  }
  stop ??= 1;
  final sel = dayIn(selected), now = dayIn(today);
  return [
    for (var i = 0; i < 42; i++)
      if (i - offset + 1 case final n when n >= 1 && n <= count)
        DayCell(
          n,
          stop: n == stop,
          selected: n == sel,
          today: n == now,
          disabled: !enabled(DateTime.utc(y, m, n)),
        )
      else
        const DayCell(null),
  ];
}
