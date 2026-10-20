import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart';

void main() {
  test('DateUtils: month lengths, deltas, same day / month', () {
    expect(DateUtils.getDaysInMonth(2024, 2), 29);
    expect(DateUtils.getDaysInMonth(2100, 2), 28, reason: 'not a leap year');
    expect(DateUtils.getDaysInMonth(2000, 2), 29);
    expect(DateUtils.getDaysInMonth(2026, 9), 30);
    expect(DateUtils.monthDelta(DateTime(2025, 11), DateTime(2026, 2)), 3);
    expect(
      DateUtils.addMonthsToMonthDate(DateTime(2026, 11, 15), 3),
      DateTime(2027, 2),
    );
    expect(
      DateUtils.isSameDay(DateTime(2026, 9, 25, 8), DateTime(2026, 9, 25)),
      isTrue,
    );
    expect(DateUtils.isSameDay(null, null), isFalse);
    expect(
      DateUtils.isSameMonth(DateTime(2026, 9), DateTime(2026, 9, 30)),
      isTrue,
    );
    expect(
      DateUtils.dateOnly(DateTime(2026, 9, 25, 13, 5)),
      DateTime(2026, 9, 25),
    );
  });

  test('TimeOfDay: periods, comparison, ISO text', () {
    const t = TimeOfDay(hour: 0, minute: 5);
    expect(t.period, DayPeriod.am);
    expect(t.hourOfPeriod, 12);
    expect(const TimeOfDay(hour: 13, minute: 0).hourOfPeriod, 1);
    expect(const TimeOfDay(hour: 12, minute: 0).period, DayPeriod.pm);
    expect(t.isBefore(const TimeOfDay(hour: 0, minute: 6)), isTrue);
    expect(t.replacing(hour: 9), const TimeOfDay(hour: 9, minute: 5));
    expect(isoTime(t), '00:05');
    expect('$t', 'TimeOfDay(00:05)');
  });

  test('ISO dates: round trip, invalid input is null (no exception)', () {
    expect(isoDate(DateTime(2026, 9, 5)), '2026-09-05');
    expect(isoDate(DateTime(987, 1, 2)), '0987-01-02');
    expect(parseIsoDate('2026-09-05'), DateTime.utc(2026, 9, 5));
    expect(parseIsoDate('2026-09'), DateTime.utc(2026, 9));
    for (final bad in ['', '2026', '2026-13-01', '2026-02-30', 'x-y-z', null]) {
      expect(parseIsoDate(bad), isNull, reason: '$bad');
    }
  });

  group('layoutMonth', () {
    bool all(DateTime _) => true;

    test('offset by the first day of the week', () {
      // 1 Sep 2026 is a Tuesday.
      final sunday = layoutMonth(
        month: DateTime(2026, 9),
        firstDayOfWeek: 0,
        enabled: all,
      );
      expect(sunday, hasLength(42));
      expect(sunday.indexWhere((c) => c.day == 1), 2);
      final monday = layoutMonth(
        month: DateTime(2026, 9),
        firstDayOfWeek: 1,
        enabled: all,
      );
      expect(monday.indexWhere((c) => c.day == 1), 1);
      // A month starting on the first day of the week: no blank.
      expect(
        layoutMonth(
          month: DateTime(2026, 2),
          firstDayOfWeek: 0,
          enabled: all,
        ).first.day,
        1,
      );
    });

    test('exactly one tab stop: focus, then an enabled selection or today, '
        'then the first enabled day', () {
      int stop(List<DayCell> cells) => cells.singleWhere((c) => c.stop).day!;
      final month = DateTime(2026, 9);
      bool weekdays(DateTime d) => d.weekday < 6;
      expect(
        stop(
          layoutMonth(
            month: month,
            firstDayOfWeek: 0,
            selected: DateTime(2026, 9, 25),
            today: DateTime(2026, 9, 2),
            focus: DateTime(2026, 9, 13),
            enabled: weekdays,
          ),
        ),
        13,
        reason: 'the keyboard may rest on a disabled day',
      );
      expect(
        stop(
          layoutMonth(
            month: month,
            firstDayOfWeek: 0,
            selected: DateTime(2026, 9, 26),
            today: DateTime(2026, 9, 2),
            enabled: weekdays,
          ),
        ),
        2,
        reason: 'a disabled selection is skipped',
      );
      expect(
        stop(
          layoutMonth(
            month: month,
            firstDayOfWeek: 0,
            selected: DateTime(2026, 10, 1),
            enabled: (d) => d.day > 20,
          ),
        ),
        21,
      );
      expect(
        stop(
          layoutMonth(month: month, firstDayOfWeek: 0, enabled: (_) => false),
        ),
        1,
      );
    });
  });

  group('day mask', () {
    /// [mask] read back for every day of the range, against [selectable].
    void roundTrip(
      DateTime first,
      DateTime last,
      bool Function(DateTime) selectable,
      String mask,
    ) {
      final decoded = DayMask.decode(mask, first);
      final days = daysBetween(first, last) + 1;
      for (var i = 0; i < days; i++) {
        final day = DateTime.utc(first.year, first.month, first.day + i);
        expect(decoded.isDisabled(i), !selectable(day), reason: '$day');
      }
      expect(decoded.isDisabled(-1), isFalse);
    }

    test('nothing disabled is null; weekdays only is the header', () {
      final first = DateTime(2026, 1, 1), last = DateTime(2026, 12, 31);
      expect(encodeDayMask(first, last, (_) => true), isNull);
      bool weekdays(DateTime d) => d.weekday < 6;
      final mask = encodeDayMask(first, last, weekdays)!;
      expect(mask.length, 2, reason: 'the weekends are in the header');
      roundTrip(first, last, weekdays, mask);
    });

    test('1900 to 2100: a weekly rule is small, holidays add a little', () {
      final first = DateTime(1900), last = DateTime(2100, 12, 31);
      bool weekdays(DateTime d) => d.weekday < 6;
      final weekly = encodeDayMask(first, last, weekdays)!;
      expect(weekly.length, 2, reason: 'the weekends are in the header');
      roundTrip(first, last, weekdays, weekly);
      // Christmas and New Year's Day of every year, on top.
      bool working(DateTime d) =>
          weekdays(d) &&
          !(d.month == 12 && d.day == 25) &&
          !(d.month == 1 && d.day == 1);
      final holidays = encodeDayMask(first, last, working)!;
      // Two runs a year (about 4 characters each) over 201 years, against
      // 12,236 characters for six days per character.
      expect(holidays.length, lessThan(1000));
      roundTrip(first, last, working, holidays);
    });

    test('an irregular rule falls back to six days per character', () {
      final first = DateTime(2026, 1, 1), last = DateTime(2026, 12, 31);
      // Alternating days: a run per day is dearer than the bitmap.
      bool odd(DateTime d) => d.day.isOdd;
      final mask = encodeDayMask(first, last, odd)!;
      expect(mask.length, 2 + (365 / 6).ceil());
      roundTrip(first, last, odd, mask);
    });

    test('ranges of a few days, one day, and the first day disabled', () {
      final d = DateTime(2026, 9, 10);
      for (final length in [1, 2, 3, 6, 7, 8, 40]) {
        final last = DateTime(2026, 9, 10 + length - 1);
        for (final rule in <bool Function(DateTime)>[
          (x) => x.day != 10,
          (x) => x.day.isEven,
          (x) => x.weekday != DateTime.sunday,
          (x) => false,
        ]) {
          final mask = encodeDayMask(d, last, rule);
          if (mask == null) {
            expect([
              for (var i = 0; i < length; i++) rule(DateTime(2026, 9, 10 + i)),
            ], everyElement(isTrue));
            continue;
          }
          roundTrip(d, last, rule, mask);
        }
      }
    });

    test('dates before 1970 and across a DST change count calendar days', () {
      bool noMondays(DateTime x) => x.weekday != DateTime.monday;
      final old = encodeDayMask(
        DateTime(1950, 6, 1),
        DateTime(1951, 6, 1),
        noMondays,
      )!;
      roundTrip(DateTime(1950, 6, 1), DateTime(1951, 6, 1), noMondays, old);
      // The predicate gets UTC dates, one per calendar day.
      final seen = <DateTime>[];
      encodeDayMask(DateTime(2026, 3, 1), DateTime(2026, 4, 1), (d) {
        seen.add(d);
        return true;
      });
      expect(seen, hasLength(32));
      expect(seen.every((d) => d.isUtc), isTrue);
      expect(seen.first, DateTime.utc(2026, 3, 1));
      expect(seen.last, DateTime.utc(2026, 4, 1));
      expect(daysBetween(DateTime(2026, 3, 1), DateTime(2026, 4, 1)), 31);
    });

    test('the lite engine reads the same mask', () {
      if (!_hasNode) return markTestSkipped('node is not installed');
      final source = File('lib/lite/parts/date_picker.js').readAsStringSync();
      final from = source.indexOf('  const ALPHA = ');
      final to = source.indexOf('  const el = ');
      expect(from, greaterThan(0));
      final decoder = source.substring(from, to);
      final first = DateTime(2026, 1, 15), last = DateTime(2027, 2, 10);
      final rules = <bool Function(DateTime)>[
        (d) => d.weekday < 6,
        (d) => d.weekday < 6 && d.day != 25,
        (d) => d.day.isEven,
        (d) => d.weekday != DateTime.sunday && d.month != 3,
      ];
      final days = daysBetween(first, last) + 1;
      for (final rule in rules) {
        final mask = encodeDayMask(first, last, rule)!;
        final js =
            '''
const wd = (t) => new Date(t).getUTCDay();
$decoder
const f = decodeMask('$mask', Date.UTC(2026, 0, 15));
let out = '';
for (let i = -1; i <= $days; i++) out += f(i) ? '1' : '0';
console.log(out);
''';
        final r = Process.runSync('node', ['-e', js]);
        if (r.exitCode != 0) fail('node failed:\n${r.stderr}');
        final decoded = DayMask.decode(mask, first);
        final expected = [
          for (var i = -1; i <= days; i++) decoded.isDisabled(i) ? '1' : '0',
        ].join();
        expect((r.stdout as String).trim(), expected);
      }
    });
  });

  test('DatePickerConfig round trip', () {
    final config = DatePickerConfig(
      first: DateTime.utc(2020),
      last: DateTime.utc(2030, 12, 31),
      firstDayOfWeek: 1,
      months: const ['enero', 'febrero'],
      shortMonths: const ['ene', 'feb'],
      shortWeekdays: const ['dom', 'lun'],
      monthYear: '{M} de {y}',
      mediumDate: '{w}, {d} {m}',
      noDate: 'Fecha',
      mask: 'AB',
      digits: '٠١٢٣٤٥٦٧٨٩',
    );
    final back = DatePickerConfig.decode(config.encode());
    expect(back.first, config.first);
    expect(back.last, config.last);
    expect(back.today, isNull);
    expect(back.firstDayOfWeek, 1);
    expect(back.months, config.months);
    expect(back.monthYear, '{M} de {y}');
    expect(back.mask, 'AB');
    expect(back.digits, '٠١٢٣٤٥٦٧٨٩');
    expect(back.num(2026), '٢٠٢٦');
    // An older text (eleven fields) keeps the ASCII digits.
    final old = config.encode().split('|').take(11).join('|');
    expect(DatePickerConfig.decode(old).num(7), '7');
    expect(
      DatePickerConfig.decode(
        DatePickerConfig(
          first: DateTime.utc(2020),
          last: DateTime.utc(2021),
          today: DateTime.utc(2020, 5, 6),
          firstDayOfWeek: 0,
          months: const [],
          shortMonths: const [],
          shortWeekdays: const [],
          monthYear: '',
          mediumDate: '',
          noDate: '',
        ).encode(),
      ).today,
      DateTime.utc(2020, 5, 6),
    );
  });
}

final _hasNode = () {
  try {
    return Process.runSync('node', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}();
