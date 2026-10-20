@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:thor_engine_oracle/client.dart';
import 'package:web/web.dart' as web;

web.HTMLElement mount(String html) {
  final root = web.document.createElement('div') as web.HTMLElement;
  root.innerHTML = html.toJS;
  web.document.body!.append(root);
  // A lambda: tear-offs of interop members are not allowed.
  // ignore: unnecessary_lambdas
  addTearDown(() => root.remove());
  return root;
}

void key(web.Element el, String key, {bool shift = false}) => el.dispatchEvent(
  web.KeyboardEvent(
    'keydown',
    web.KeyboardEventInit(
      key: key,
      shiftKey: shift,
      bubbles: true,
      cancelable: true,
    ),
  ),
);

void click(web.Element el) => (el as web.HTMLElement).click();

String _attr(String name, String? value) => value == null
    ? ''
    : value.isEmpty
    ? ' $name'
    : ' $name="$value"';

/// The markup thor_ui renders for a calendar (without its styles), from
/// the same layout and configuration code.
String calendar({
  required DateTime first,
  required DateTime last,
  DateTime? selected,
  DateTime? today,
  String mask = '',
  bool dialog = false,
  String input = '',
  List<String>? months,
  List<String>? shortMonths,
  List<String>? shortWeekdays,
  String monthYear = '{M} {y}',
  String mediumDate = '{w}, {m} {d}',
  int firstDayOfWeek = 0,
  String digits = latinDigits,
}) {
  final shown = selected ?? today ?? first;
  final month = DateTime.utc(shown.year, shown.month);
  final config = DatePickerConfig(
    first: first,
    last: last,
    today: today,
    firstDayOfWeek: firstDayOfWeek,
    digits: digits,
    months:
        months ??
        const [
          'January', 'February', 'March', 'April', 'May', 'June', 'July', //
          'August', 'September', 'October', 'November', 'December',
        ],
    shortMonths:
        shortMonths ??
        const [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', //
          'Oct', 'Nov', 'Dec',
        ],
    shortWeekdays:
        shortWeekdays ??
        const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
    monthYear: monthYear,
    mediumDate: mediumDate,
    noDate: 'Date',
    mask: mask.isEmpty ? null : mask,
  );
  final dayMask = mask.isEmpty ? null : DayMask.decode(mask, first);
  final cells = layoutMonth(
    month: month,
    firstDayOfWeek: firstDayOfWeek,
    selected: selected,
    today: today,
    enabled: (d) =>
        !d.isBefore(first) &&
        !d.isAfter(last) &&
        (dayMask == null || !dayMask.isDisabled(daysBetween(first, d))),
  );
  final rows = StringBuffer();
  for (var r = 0; r < 6; r++) {
    rows.write('<tr>');
    for (var c = 0; c < 7; c++) {
      final cell = cells[r * 7 + c];
      rows.write(
        cell.day == null
            ? '<td></td>'
            : '<td tabindex="${cell.stop ? 0 : -1}"'
                  '${_attr('autofocus', dialog && cell.stop ? '' : null)}'
                  '${_attr('aria-selected', cell.selected ? 'true' : null)}'
                  '${_attr('aria-current', cell.today ? 'date' : null)}'
                  '${_attr('aria-disabled', cell.disabled ? 'true' : null)}'
                  '>${config.num(cell.day!)}</td>',
      );
    }
    rows.write('</tr>');
  }
  final ym = isoDate(month).substring(0, 7);
  return '<div $datePickerAttr="${config.encode()}" $dateMonthAttr="$ym" '
      '$dateModeAttr="day">'
      '<div><button type="button" $dateYearsAttr aria-expanded="false">'
      '<span>x</span></button>'
      '<button type="button" $dateNavAttr="-1" id="prev">‹</button>'
      '<button type="button" $dateNavAttr="1" id="next">›</button></div>'
      '<table role="grid"><tbody $dateDaysAttr>$rows</tbody></table>'
      '<div $dateYearListAttr><template><button type="button"></button>'
      '</template></div>'
      '<input type="hidden" $dateValueAttr'
      '${selected == null ? '' : ' value="${isoDate(selected)}"'}$input>'
      '</div>';
}

web.HTMLElement? cellOf(web.Element root, int day) {
  final cells = root.querySelectorAll('td');
  for (var i = 0; i < cells.length; i++) {
    final c = cells.item(i)! as web.HTMLElement;
    if (c.textContent == '$day') return c;
  }
  return null;
}

String label(web.Element root) =>
    root.querySelector('[$dateYearsAttr] span')!.textContent!;

web.Element? get focused => web.document.activeElement;

/// Waits for [ready] (something the browser does in a queued task) with a
/// deadline, not for a fixed time a loaded machine can stretch.
Future<void> _until(bool Function() ready) async {
  final end = DateTime.now().add(const Duration(seconds: 20));
  while (!ready() && DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

void main() {
  final first = DateTime.utc(2026, 1, 15);
  final last = DateTime.utc(2027, 2, 10);

  test('months: previous / next rewrite the same cells; the ends of the '
      'range disable them; the displayed month event', () {
    final page = mount(
      calendar(
        first: first,
        last: last,
        selected: DateTime.utc(2026, 9, 25),
        today: DateTime.utc(2026, 9, 20),
      ),
    );
    final root = page.querySelector('[$datePickerAttr]')!;
    root.setAttribute(onAttr, 'thor-month:month');
    final months = <String?>[];
    final undo = hydrate(
      [Action('month', months.add)],
      root: page,
      features: const [DatePickerFeature()],
    );
    addTearDown(undo);
    final before = page.querySelectorAll('td').length;
    click(page.querySelector('#next')!);
    expect(label(root), 'October 2026');
    expect(root.getAttribute(dateMonthAttr), '2026-10');
    expect(page.querySelectorAll('td').length, before, reason: 'no new cells');
    // 1 Oct 2026 is a Thursday: 4 blanks, then the 1st.
    expect(page.querySelectorAll('td').item(4)!.textContent, '1');
    expect(page.querySelectorAll('td').item(3)!.textContent, '');
    expect(page.querySelector('td[aria-selected]'), isNull);
    expect(months, ['2026-10-01']);
    expect(
      root.querySelector('[role="grid"]')!.getAttribute('aria-label'),
      'October 2026',
    );

    for (var i = 0; i < 5; i++) {
      click(page.querySelector('#next')!);
    }
    expect(label(root), 'February 2027');
    expect(page.querySelector('#next')!.hasAttribute('disabled'), isTrue);
    expect(cellOf(root, 11)!.getAttribute('aria-disabled'), 'true');
    expect(cellOf(root, 10)!.hasAttribute('aria-disabled'), isFalse);
    // A disabled next button can't go past the range anyway.
    click(page.querySelector('#next')!);
    expect(label(root), 'February 2027');
  });

  test('picking a day: the hidden input, change (onDateChanged), the '
      'selection; disabled days do nothing', () {
    // Every Sunday disabled (the mask the server writes).
    final mask = encodeDayMask(
      DateTime(2026, 1, 15),
      DateTime(2027, 2, 10),
      (d) => d.weekday != DateTime.sunday,
    )!;
    final page = mount(
      calendar(
        first: first,
        last: last,
        selected: DateTime.utc(2026, 9, 25),
        today: DateTime.utc(2026, 9, 20),
        mask: mask,
        input: ' name="due" data-t-on="change:pick"',
      ),
    );
    final picked = <String?>[];
    addTearDown(
      hydrate(
        [Action('pick', picked.add)],
        root: page,
        features: const [DatePickerFeature()],
      ),
    );
    final root = page.querySelector('[$datePickerAttr]')!;
    final input = page.querySelector('input')! as web.HTMLInputElement;
    click(cellOf(root, 10)!);
    expect(input.value, '2026-09-10');
    expect(picked, ['2026-09-10']);
    expect(cellOf(root, 10)!.getAttribute('aria-selected'), 'true');
    expect(cellOf(root, 25)!.hasAttribute('aria-selected'), isFalse);
    expect(cellOf(root, 10)!.getAttribute('tabindex'), '0');
    expect(focused, cellOf(root, 10));
    // Sunday the 13th is disabled.
    expect(cellOf(root, 13)!.getAttribute('aria-disabled'), 'true');
    click(cellOf(root, 13)!);
    expect(input.value, '2026-09-10');
    expect(picked, hasLength(1));
    // A blank cell is nothing.
    click(page.querySelectorAll('td').item(0)! as web.Element);
    expect(picked, hasLength(1));
    // The same day again: no change event.
    click(cellOf(root, 10)!);
    expect(picked, hasLength(1));
  });

  test('keyboard: the ARIA date grid (arrows, Home / End, Page Up / Down, '
      'Shift for years, Enter), clamped to the range', () {
    final page = mount(
      calendar(
        first: first,
        last: last,
        selected: DateTime.utc(2026, 9, 25),
        today: DateTime.utc(2026, 9, 20),
      ),
    );
    addTearDown(
      hydrate(const [], root: page, features: const [DatePickerFeature()]),
    );
    final root = page.querySelector('[$datePickerAttr]')!;
    final input = page.querySelector('input')! as web.HTMLInputElement;
    cellOf(root, 25)!.focus();
    key(focused!, 'ArrowRight');
    expect(focused!.textContent, '26');
    expect(cellOf(root, 26)!.getAttribute('tabindex'), '0');
    expect(cellOf(root, 25)!.getAttribute('tabindex'), '-1');
    key(focused!, 'ArrowDown'); // Oct 3
    expect(label(root), 'October 2026');
    expect(focused!.textContent, '3');
    key(focused!, 'ArrowUp'); // Sep 26
    expect(label(root), 'September 2026');
    key(focused!, 'Home'); // Sunday Sep 20
    expect(focused!.textContent, '20');
    key(focused!, 'End'); // Saturday Sep 26
    expect(focused!.textContent, '26');
    key(focused!, 'ArrowLeft');
    expect(focused!.textContent, '25');
    key(focused!, 'PageDown');
    expect(label(root), 'October 2026');
    expect(focused!.textContent, '25');
    key(focused!, 'PageUp', shift: true);
    // October 2025 is before the range: clamped to the first day.
    expect(root.getAttribute(dateMonthAttr), '2026-01');
    expect(focused!.textContent, '15');
    key(focused!, 'ArrowLeft');
    expect(focused!.textContent, '15');
    // Month ends: Jan 31 → Feb 28.
    for (var i = 0; i < 16; i++) {
      key(focused!, 'ArrowRight');
    }
    expect(focused!.textContent, '31');
    key(focused!, 'PageDown');
    expect(label(root), 'February 2026');
    expect(focused!.textContent, '28');
    expect(input.value, '2026-09-25', reason: 'moving never selects');
    key(focused!, 'Enter');
    expect(input.value, '2026-02-28');
    key(focused!, 'ArrowRight');
    key(focused!, ' ');
    expect(input.value, '2026-03-01');
  });

  test('years: the list is filled once from the template; picking one '
      'shows that month', () {
    final page = mount(
      calendar(
        first: first,
        last: last,
        selected: DateTime.utc(2026, 9, 25),
        today: DateTime.utc(2026, 9, 20),
      ),
    );
    addTearDown(
      hydrate(const [], root: page, features: const [DatePickerFeature()]),
    );
    final root = page.querySelector('[$datePickerAttr]')!;
    final toggle = root.querySelector('[$dateYearsAttr]')!;
    click(toggle);
    expect(root.getAttribute(dateModeAttr), 'year');
    expect(toggle.getAttribute('aria-expanded'), 'true');
    final years = root.querySelectorAll('[$dateYearListAttr] button');
    expect(years.length, 2);
    expect(
      (years.item(0)! as web.Element).getAttribute('aria-pressed'),
      'true',
    );
    expect(focused, years.item(0));
    click(years.item(1)! as web.Element);
    expect(root.getAttribute(dateModeAttr), 'day');
    // September 2027 is past the range: its last month.
    expect(label(root), 'February 2027');
    click(toggle);
    expect(root.querySelectorAll('[$dateYearListAttr] button').length, 2);
    click(toggle);
    expect(root.getAttribute(dateModeAttr), 'day');
  });

  group('the page\'s locale', () {
    const fr = (
      months: [
        'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', //
        'août', 'septembre', 'octobre', 'novembre', 'décembre',
      ],
      short: [
        'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', //
        'sept.', 'oct.', 'nov.', 'déc.',
      ],
      days: ['dim.', 'lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.'],
    );

    test('French names and a Monday-first grid; same cells, other month', () {
      final page = mount(
        calendar(
          first: first,
          last: last,
          selected: DateTime.utc(2026, 9, 25),
          today: DateTime.utc(2026, 9, 20),
          months: fr.months,
          shortMonths: fr.short,
          shortWeekdays: fr.days,
          firstDayOfWeek: 1,
        ),
      );
      addTearDown(
        hydrate(const [], root: page, features: const [DatePickerFeature()]),
      );
      final root = page.querySelector('[$datePickerAttr]')!;
      click(page.querySelector('#next')!);
      expect(label(root), 'octobre 2026');
      // 1 Oct 2026 is a Thursday: three blanks when Monday comes first.
      expect(page.querySelectorAll('td').item(3)!.textContent, '1');
      expect(page.querySelectorAll('td').item(2)!.textContent, '');
      click(page.querySelectorAll('td').item(3)! as web.Element);
      expect(
        (page.querySelector('[$dateValueAttr]')! as web.HTMLInputElement).value,
        '2026-10-01',
      );
    });

    test('a template that puts the year first (hungarian, basque)', () {
      final page = mount(
        calendar(
          first: first,
          last: last,
          selected: DateTime.utc(2026, 9, 25),
          today: DateTime.utc(2026, 9, 20),
          months: fr.months,
          monthYear: '{y}. {M}',
        ),
      );
      addTearDown(
        hydrate(const [], root: page, features: const [DatePickerFeature()]),
      );
      final root = page.querySelector('[$datePickerAttr]')!;
      click(page.querySelector('#next')!);
      expect(label(root), '2026. octobre');
    });

    test(
      'the digits of the locale: cells, year, list; picking by position',
      () {
        const arabic = '٠١٢٣٤٥٦٧٨٩';
        final page = mount(
          calendar(
            first: first,
            last: last,
            selected: DateTime.utc(2026, 9, 25),
            today: DateTime.utc(2026, 9, 20),
            digits: arabic,
            monthYear: '{M} {y}',
          ),
        );
        addTearDown(
          hydrate(const [], root: page, features: const [DatePickerFeature()]),
        );
        final root = page.querySelector('[$datePickerAttr]')!;
        click(page.querySelector('#next')!);
        expect(label(root), 'October ٢٠٢٦');
        // 1 Oct 2026 is a Thursday.
        expect(page.querySelectorAll('td').item(4)!.textContent, '١');
        expect(page.querySelectorAll('td').item(13)!.textContent, '١٠');
        click(page.querySelectorAll('td').item(13)! as web.Element);
        expect(
          (page.querySelector('[$dateValueAttr]')! as web.HTMLInputElement)
              .value,
          '2026-10-10',
        );
        click(root.querySelector('[$dateYearsAttr]')!);
        final years = root.querySelectorAll('[$dateYearListAttr] button');
        expect((years.item(0)! as web.Element).textContent, '٢٠٢٦');
        click(years.item(1)! as web.Element);
        expect(label(root), 'February ٢٠٢٧');
      },
    );
  });

  test('without currentDate the reader\'s today is marked', () {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    // The server's "today" was another day of this month.
    final server = DateTime.utc(now.year, now.month, now.day == 1 ? 2 : 1);
    final page = mount(
      calendar(
        first: DateTime.utc(now.year - 1),
        last: DateTime.utc(now.year + 1, 12, 31),
        today: server,
      ).replaceFirst('|${isoDate(server)}|', '||'),
    );
    final root = page.querySelector('[$datePickerAttr]')!;
    expect(cellOf(root, server.day)!.getAttribute('aria-current'), 'date');
    addTearDown(
      hydrate(const [], root: page, features: const [DatePickerFeature()]),
    );
    expect(cellOf(root, today.day)!.getAttribute('aria-current'), 'date');
    expect(cellOf(root, server.day)!.hasAttribute('aria-current'), isFalse);
  });

  group('dialog', () {
    String dialog({String target = '', String out = ''}) =>
        '<dialog id="due" $pickerDialogAttr="$target">'
        '<span $pickerHeadlineAttr>Fri, Sep 25</span>'
        '${calendar(first: first, last: last, selected: DateTime.utc(2026, 9, 25), today: DateTime.utc(2026, 9, 20), dialog: true, input: ' $pickerPendingAttr')}'
        '<button type="button" id="cancel">Cancel</button>'
        '<button type="button" id="ok" $pickerConfirmAttr>OK</button>'
        '$out</dialog>';

    test('OK writes the pending day to the output (change → onDatePicked); '
        'Cancel / Esc drop it', () async {
      final page = mount(
        dialog(
          out:
              '<input type="hidden" $pickerOutAttr name="due" '
              'value="2026-09-25" data-t-on="change:picked">',
        ),
      );
      final picked = <String?>[];
      addTearDown(
        hydrate(
          [Action('picked', picked.add)],
          root: page,
          features: const [DatePickerFeature()],
        ),
      );
      final d = page.querySelector('dialog')! as web.HTMLDialogElement;
      final root = d.querySelector('[$datePickerAttr]')!;
      final out = d.querySelector('[$pickerOutAttr]')! as web.HTMLInputElement;
      d.showModal();
      expect(focused, cellOf(root, 25), reason: 'autofocus on the selection');
      click(cellOf(root, 3)!);
      expect(
        d.querySelector('[$pickerHeadlineAttr]')!.textContent,
        'Thu, Sep 3',
      );
      expect(out.value, '2026-09-25', reason: 'not confirmed yet');
      expect(picked, isEmpty);
      click(d.querySelector('#ok')!);
      expect(out.value, '2026-09-03');
      expect(picked, ['2026-09-03']);
      expect(d.open, isFalse);

      // Next time: navigate and pick, then close without OK.
      d.showModal();
      click(root.querySelector('#next')!);
      click(cellOf(root, 7)!);
      expect(
        d.querySelector('[$pickerHeadlineAttr]')!.textContent,
        'Wed, Oct 7',
      );
      d.close(); // Cancel (DialogClose), Esc and the backdrop all close it.
      // `close` is a queued task: its handler puts the result back.
      await _until(
        () =>
            d.querySelector('[$pickerHeadlineAttr]')!.textContent ==
            'Thu, Sep 3',
      );
      expect(out.value, '2026-09-03');
      expect(picked, hasLength(1));
      expect(label(root), 'September 2026', reason: 'back to the result');
      expect(cellOf(root, 3)!.getAttribute('aria-selected'), 'true');
      expect(
        d.querySelector('[$pickerHeadlineAttr]')!.textContent,
        'Thu, Sep 3',
      );
      expect(
        (d.querySelector('[$pickerPendingAttr]')! as web.HTMLInputElement)
            .value,
        '2026-09-03',
      );
    });

    test('a date field: the calendar button appears with the engine, the '
        'dialog starts from the typed value and writes back into the '
        'field', () {
      final page = mount(
        '<input type="date" id="f" name="f" $dateFieldAttr '
        'value="2026-09-25" data-t-on="change:changed">'
        '<button type="button" hidden $dateOpenAttr id="open" '
        'commandfor="due" command="show-modal">cal</button>'
        '${dialog(target: 'f')}',
      );
      final changed = <String?>[];
      final open = page.querySelector('#open')!;
      final field = page.querySelector('#f')! as web.HTMLInputElement;
      expect(open.hasAttribute('hidden'), isTrue);
      addTearDown(
        hydrate(
          [Action('changed', changed.add)],
          root: page,
          features: const [DatePickerFeature(), CommandsFeature()],
        ),
      );
      expect(open.hasAttribute('hidden'), isFalse);
      expect(field.hasAttribute(dateReadyAttr), isTrue);

      field.value = '2026-11-02'; // typed
      final d = page.querySelector('dialog')! as web.HTMLDialogElement;
      final root = d.querySelector('[$datePickerAttr]')!;
      click(open);
      if (!d.open) d.showModal(); // browsers without Invoker Commands
      expect(label(root), 'November 2026');
      expect(cellOf(root, 2)!.getAttribute('aria-selected'), 'true');
      click(cellOf(root, 4)!);
      click(d.querySelector('#ok')!);
      expect(field.value, '2026-11-04');
      expect(changed, ['2026-11-04']);

      // A cleared field has no date: no call.
      field.value = '';
      field.dispatchEvent(web.Event('change', web.EventInit(bubbles: true)));
      expect(changed, hasLength(1));
    });
  });
}
