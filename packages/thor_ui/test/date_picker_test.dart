@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart' show DatePickerConfig, DayMask;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// The member list thor generates for [DueState], by hand (tests don't run the build).
abstract class _DueStateMembers extends ThorState {
  @override
  String get $type => 'DueState';

  @override
  List<ThorMember> get $members {
    final s = this as DueState;
    return [
      ThorMember(
        'setDue',
        s.setDue,
        arity: 1,
        call: (a) => s.setDue(DateTime.parse(a!)),
      ),
      ThorMember(
        'setMonth',
        s.setMonth,
        arity: 1,
        call: (a) => s.setMonth(DateTime.parse(a!)),
      ),
      ThorMember(
        'setAt',
        s.setAt,
        arity: 1,
        call: (a) => s.setAt(
          TimeOfDay(
            hour: int.parse(a!.substring(0, 2)),
            minute: int.parse(a.substring(3, 5)),
          ),
        ),
      ),
    ];
  }
}

class DueState extends _DueStateMembers {
  DateTime? due, month;
  TimeOfDay? at;
  void setDue(DateTime d) => due = d;
  void setMonth(DateTime d) => month = d;
  void setAt(TimeOfDay t) => at = t;
}

final dueState = DueState();

CalendarDatePicker calendar({
  DateTime? initialDate,
  DateTime? first,
  DateTime? last,
  DateTime? today,
  SelectableDayPredicate? selectable,
  String? name,
  ValueChanged<DateTime>? onDateChanged,
}) => CalendarDatePicker(
  initialDate: initialDate,
  firstDate: first ?? DateTime(2020),
  lastDate: last ?? DateTime(2030, 12, 31),
  currentDate: today ?? DateTime(2026, 9, 20),
  onDateChanged: onDateChanged ?? (_) {},
  selectableDayPredicate: selectable,
  name: name,
);

/// The attributes of every `<td>`, in order.
List<String> cells(String html) => [
  for (final m in RegExp(r'<td([^>]*)>([^<]*)</td>').allMatches(html))
    '${m[2]}${m[1]!.replaceAll(RegExp(r'\s*class="[^"]*"'), '')}',
];

String cellOf(String html, int day) =>
    cells(html).firstWhere((c) => c.startsWith('$day '));

/// The body of a page with [w] (styles in the head: plain classes).
Future<String> render(Widget w) async =>
    bodyOfPage(await renderDocument(ThorApp(child: w)));

void main() {
  initializeThorTests();

  group('CalendarDatePicker', () {
    test('an ARIA date grid of the initial month, 6 weeks, one class per '
        'kind of cell', () async {
      final html = await render(
        calendar(initialDate: DateTime(2026, 9, 25), name: 'due'),
      );
      expect(html, contains('<table'));
      expect(html, contains('role="grid" aria-label="September 2026"'));
      expect(cells(html), hasLength(42));
      // September 2026 starts on a Tuesday (Sunday first): 2 blanks.
      expect(cells(html).take(3), ['', '', '1 tabindex="-1"']);
      expect(
        RegExp(
          r'<td class="([^"]+)"',
        ).allMatches(html).map((m) => m[1]).toSet(),
        hasLength(1),
        reason: 'states are attributes + conditions of one class',
      );
      expect(
        cellOf(html, 25),
        '25 tabindex="0" aria-selected="true"',
        reason: 'the selected day holds the tab stop',
      );
      expect(cellOf(html, 20), '20 tabindex="-1" aria-current="date"');
      expect(RegExp('<th[^>]*scope="col"').allMatches(html), hasLength(7));
      expect(html, contains('abbr="Sunday">S</th>'));
      expect(
        html,
        contains(
          '<input type="hidden" data-t-value value="2026-09-25" '
          'name="due"',
        ),
      );
      expect(html, contains('data-t-month="2026-09"'));
      expect(html, contains('data-t-mode="day"'));
      expect(html, contains('aria-label="Previous month"'));
      expect(html, contains('<template><button'));
    });

    test(
      'disabled days: the predicate and the range; no tab stop on them',
      () async {
        final html = await render(
          calendar(
            first: DateTime(2026, 9, 10),
            last: DateTime(2026, 9, 28),
            today: DateTime(2026, 9, 5),
            selectable: (d) => d.weekday != DateTime.sunday,
          ),
        );
        expect(cellOf(html, 9), contains('aria-disabled="true"'));
        expect(cellOf(html, 10), isNot(contains('aria-disabled')));
        expect(
          cellOf(html, 13),
          contains('aria-disabled="true"'),
          reason: 'Sun',
        );
        expect(cellOf(html, 29), contains('aria-disabled="true"'));
        // No selection, today outside the range: the first enabled day.
        expect(cellOf(html, 10), contains('tabindex="0"'));
        // Both ends of the range are in this month.
        expect(
          RegExp(r'data-t-nav="-?1"[^>]*disabled').allMatches(html),
          hasLength(2),
        );
        // The mask travels in the configuration.
        final config = DatePickerConfig.decode(
          RegExp(r'data-t-date="([^"]*)"').firstMatch(html)![1]!,
        );
        expect(config.mask, isNotNull);
        expect(
          DayMask.decode(config.mask!, config.first).isDisabled(3),
          isTrue,
          reason: 'Sep 13 is a Sunday',
        );
      },
    );

    test('the initial month is clamped to the range', () async {
      final html = await render(
        calendar(first: DateTime(2027, 3, 4), last: DateTime(2028)),
      );
      expect(html, contains('March 2027'));
      expect(html, contains('data-t-month="2027-03"'));
      expect(
        html,
        contains('<input type="hidden" data-t-value/>'),
        reason: 'no date selected',
      );
    });

    test('Spanish: names, Monday first, month–year template', () async {
      final html = await render(
        Localizations(
          locale: const Locale('es'),
          delegates: const [],
          child: calendar(initialDate: DateTime(2026, 9, 25)),
        ),
      );
      expect(html, contains('septiembre de 2026'));
      expect(html, contains('abbr="lunes">L</th>'));
      expect(html, contains('aria-label="Mes anterior"'));
      // Monday first: Tuesday the 1st has one blank before it.
      expect(cells(html).take(2), ['', '1 tabindex="-1"']);
      final config = DatePickerConfig.decode(
        RegExp(r'data-t-date="([^"]*)"').firstMatch(html)![1]!,
      );
      expect(config.firstDayOfWeek, 1);
      expect(config.monthYear, '{M} de {y}');
    });

    test('a ThorState method: bound to the change of the hidden input, and '
        'the displayed month to its custom event', () async {
      final html = await render(
        CalendarDatePicker(
          initialDate: null,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          onDateChanged: dueState.setDue,
          onDisplayedMonthChanged: dueState.setMonth,
        ),
      );
      expect(html, contains('data-t-on="change:DueState.setDue"'));
      expect(html, contains('data-t-on="thor-month:DueState.setMonth"'));
      // Without currentDate the browser marks its own today.
      final config = DatePickerConfig.decode(
        RegExp(r'data-t-date="([^"]*)"').firstMatch(html)![1]!,
      );
      expect(config.today, isNull);
    });

    test('theme: per-state colors, day size and shape', () async {
      final theme = ThemeData(
        datePickerTheme: DatePickerThemeData(
          daySize: 48,
          dayBackgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? const Color(0xFF00897B)
                : null,
          ),
          dayShape: WidgetStateProperty.all(
            const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
          todayBorder: const BorderSide(color: Color(0xFFFF0000), width: 2),
        ),
      );
      final page = await renderDocument(
        ThorApp(
          theme: theme,
          child: calendar(initialDate: DateTime(2026, 9, 25)),
        ),
      );
      final css = headOfPage(page);
      expect(css, contains('width: 48px'));
      expect(css, contains('border-radius: 8px'));
      expect(
        RegExp(r'\[aria-selected="true"\]\s*\{[^}]*#00897b').hasMatch(css),
        isTrue,
      );
      expect(css, contains('inset 0 0 0 2px #ff0000'));
    });

    test('a page with a picker ships the engine, even with no state', () async {
      final page = await renderDocument(
        ThorApp(child: calendar(initialDate: DateTime(2026, 9, 25))),
      );
      expect(page, contains('data-thor-engine'));
      final plain = await renderDocument(const ThorApp(child: Text('x')));
      expect(plain, isNot(contains('data-thor-engine')));
    });
  });

  group('DatePickerDialog', () {
    test('a closed <dialog>: headline, pending calendar, output, OK and '
        'Cancel', () async {
      final html = await render(
        DatePickerDialog(
          id: 'due',
          initialDate: DateTime(2026, 9, 25),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          currentDate: DateTime(2026, 9, 20),
          name: 'due_on',
          onDatePicked: dueState.setDue,
        ),
      );
      expect(html, contains('<dialog id="due"'));
      expect(html, contains('data-t-picker aria-labelledby="due-help"'));
      expect(html, isNot(contains(' open')));
      expect(html, contains('id="due-help"'));
      expect(html, contains('>Select date</span>'));
      expect(html, contains('data-t-headline aria-live="polite">Fri, Sep 25<'));
      expect(
        html,
        contains('data-t-value value="2026-09-25" data-t-pick'),
        reason: 'the calendar edits a pending value',
      );
      expect(
        cellOf(html, 25),
        '25 tabindex="0" autofocus aria-selected="true"',
        reason: 'showModal focuses the selected day',
      );
      expect(
        html,
        contains(
          'data-t-pick-out name="due_on" value="2026-09-25" '
          'data-t-on="change:DueState.setDue"',
        ),
      );
      expect(html, contains('commandfor="due" command="close"'));
      expect(html, contains('data-t-pick-ok'));
      expect(html, contains('>OK</button>'));
    });

    test('no initial date: an empty headline and output', () async {
      final html = await render(
        Localizations(
          locale: const Locale('es'),
          delegates: const [],
          child: DatePickerDialog(
            id: 'd',
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            cancelText: 'Mejor no',
          ),
        ),
      );
      expect(html, contains('data-t-headline aria-live="polite">Fecha<'));
      expect(html, contains('data-t-pick-out/>'));
      expect(html, contains('>Mejor no</button>'));
      expect(html, contains('>Aceptar</button>'));
    });
  });

  group('date fields', () {
    test('InputDatePickerFormField: a native date input', () async {
      final html = await render(
        InputDatePickerFormField(
          initialDate: DateTime(2026, 9, 25),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030, 6, 30),
          name: 'born',
          onDateSubmitted: dueState.setDue,
        ),
      );
      expect(html, contains('type="date"'));
      expect(html, contains('name="born"'));
      expect(html, contains('value="2026-09-25"'));
      expect(html, contains('min="2020-01-01" max="2030-06-30" required'));
      expect(html, matches(RegExp(r'for="f-born"[^>]*>Enter Date<')));
      expect(html, isNot(contains('aria-label="Enter Date"')));
      expect(html, contains('data-t-on="change:DueState.setDue"'));
      final optional = await render(
        InputDatePickerFormField(
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          acceptEmptyDate: true,
        ),
      );
      expect(optional, isNot(contains('required')));
    });

    test('DatePickerFormField: the native input, a hidden calendar button '
        'and a dialog that writes into the input', () async {
      final html = await render(
        DatePickerFormField(
          id: 'when',
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          name: 'when',
        ),
      );
      expect(html, contains('id="when-input"'));
      expect(html, contains('type="date"'));
      expect(html, contains('data-t-date-field'));
      expect(
        RegExp(
          r'<button[^>]*hidden data-t-date-open commandfor="when" '
          'command="show-modal"',
        ).hasMatch(html),
        isTrue,
        reason: 'the button needs the engine: hidden until it runs',
      );
      expect(html, contains('<dialog id="when"'));
      expect(html, contains('data-t-picker="when-input"'));
      expect(html, isNot(contains('data-t-pick-out')));
    });
  });

  test('TimePickerDialog: a time input in the dialog, hh:mm out', () async {
    final html = await render(
      TimePickerDialog(
        id: 'at',
        initialTime: const TimeOfDay(hour: 9, minute: 5),
        name: 'at',
        onTimePicked: dueState.setAt,
      ),
    );
    expect(html, contains('<dialog id="at"'));
    expect(html, contains('>Enter time</span>'));
    expect(html, contains('type="time" value="09:05" autofocus'));
    expect(html, contains('data-t-pick'));
    expect(
      html,
      contains(
        'data-t-pick-out name="at" value="09:05" '
        'data-t-on="change:DueState.setAt"',
      ),
    );
  });

  test(
    'TimePickerDialog without an id labels its input by the dialog id',
    () async {
      final html = await render(
        const TimePickerDialog(initialTime: TimeOfDay(hour: 9, minute: 30)),
      );
      expect(html, isNot(contains('null-help')));
      final id = RegExp(r'<dialog id="([^"]+)"').firstMatch(html)!.group(1);
      // The input's own label, not the dialog's (which names it too).
      expect(
        html,
        contains(
          RegExp('<input[^>]*type="time"[^>]*aria-labelledby="$id-help"'),
        ),
      );
    },
  );

  group('DatePickerFormField id', () {
    test('without an id the page names the dialog and its input', () async {
      final html = await render(
        DatePickerFormField(
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          name: 'born',
        ),
      );
      final dialog = RegExp(r'<dialog[^>]*id="([^"]+)"').firstMatch(html)!;
      final id = dialog[1]!;
      expect(html, contains('id="$id-input"'));
      expect(html, contains('commandfor="$id"'));
    });

    test('the same page renders the same ids', () async {
      Widget field() => DatePickerFormField(
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      );
      expect(await render(field()), await render(field()));
    });

    test('a ValueKey names it and an id still wins', () async {
      final keyed = await render(
        DatePickerFormField(
          key: const ValueKey('due'),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        ),
      );
      expect(keyed, contains('id="datefield-due"'));
      final named = await render(
        DatePickerFormField(
          id: 'mine',
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        ),
      );
      expect(named, contains('id="mine"'));
      expect(named, contains('id="mine-input"'));
    });
  });
}
