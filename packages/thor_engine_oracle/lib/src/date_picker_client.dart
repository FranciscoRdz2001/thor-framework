/// The date and time pickers in the page ([DatePickerFeature]).
library;

import 'dart:js_interop';

import 'package:thor_engine/src/dates.dart';
import 'package:thor_engine_oracle/client.dart' show EngineFeature, EngineRun;
import 'package:thor_engine_oracle/src/dom_scan.dart';
import 'package:web/web.dart' as web;

/// `CalendarDatePicker`, `DatePickerDialog`, `TimePickerDialog` and the
/// date fields: month navigation, the year list, picking a day, the ARIA
/// date-grid keyboard, and the dialogs' confirm / cancel.
///
/// The server renders the first month (6 × 7 cells, always); the browser
/// rewrites the texts and attributes of those same cells for the others,
/// so it never creates an element with a new style. Selecting a day writes
/// `yyyy-mm-dd` into the calendar's hidden input and fires `change` there,
/// where `onDateChanged` is bound like any control's callback.
final class DatePickerFeature extends EngineFeature {
  /// The feature.
  const DatePickerFeature();

  @override
  void Function()? installLate(web.Element part, EngineRun run) {
    _prepare(part);
    return null;
  }

  // What the markup of a picker needs once the engine runs: controls that
  // only work with it show, the calendars mark the reader's today, the
  // fields say they are ready.
  void _prepare(web.Element scope) {
    for (final el in withRoot(scope, '[$dateOpenAttr][hidden]')) {
      el.removeAttribute('hidden');
    }
    // Calendars that mark the server's today: mark the reader's.
    for (final root in withRoot(scope, '[$datePickerAttr]')) {
      final c = _Calendar.of(root);
      if (c.config.today == null) c.refresh();
    }
    for (final el in withRoot(scope, '[$dateFieldAttr]')) {
      el.setAttribute(dateReadyAttr, '');
    }
  }

  @override
  void Function()? install(web.Element scope, EngineRun run) {
    _prepare(scope);

    final click = ((web.MouseEvent e) {
      final t = _element(e.target);
      if (t == null) return;
      final cell = t.closest('td');
      final root = t.closest('[$datePickerAttr]');
      if (root != null && cell != null && root.contains(cell)) {
        _Calendar.of(root).pick(cell);
        return;
      }
      final nav = t.closest('[$dateNavAttr]');
      if (root != null && nav != null) {
        final c = _Calendar.of(root);
        c.show(
          DateTime.utc(
            c.month.year,
            c.month.month + int.parse(nav.getAttribute(dateNavAttr)!),
          ),
        );
        return;
      }
      if (root != null && t.closest('[$dateYearsAttr]') != null) {
        _Calendar.of(root).toggleYears();
        return;
      }
      final year = t.closest('[$dateYearListAttr] button');
      if (root != null && year != null) {
        _Calendar.of(
          root,
        ).pickYear(int.parse((year as web.HTMLButtonElement).value));
        return;
      }
      final ok = t.closest('[$pickerConfirmAttr]');
      if (ok != null) {
        final dialog = ok.closest('dialog');
        if (dialog != null) _confirm(dialog as web.HTMLDialogElement);
        return;
      }
      final open = t.closest('[$dateOpenAttr]');
      if (open != null) {
        // Before the command opens it: start from the field's value.
        final dialog = web.document.getElementById(
          open.getAttribute('commandfor') ?? '',
        );
        if (dialog != null) _reset(dialog);
      }
    }).toJS;

    final keys = ((web.KeyboardEvent e) {
      final t = _element(e.target);
      if (t == null || t.localName != 'td') return;
      final root = t.closest('[$datePickerAttr]');
      if (root == null) return;
      if (_Calendar.of(root).key(t, e)) e.preventDefault();
    }).toJS;

    // `close` doesn't bubble: captured. Closing without confirming
    // (Cancel, Esc, the backdrop, a controller) drops the pending value.
    final close = ((web.Event e) {
      final t = _element(e.target);
      if (t != null && t.hasAttribute(pickerDialogAttr)) _reset(t);
    }).toJS;

    // A cleared date field has no date for `onDateSubmitted`.
    final change = ((web.Event e) {
      final t = _element(e.target);
      if (t != null &&
          t.hasAttribute(dateFieldAttr) &&
          (t as web.HTMLInputElement).value.isEmpty) {
        e.stopImmediatePropagation();
      }
    }).toJS;

    scope
      ..addEventListener('click', click)
      ..addEventListener('keydown', keys)
      ..addEventListener('close', close, true.toJS)
      ..addEventListener('change', change, true.toJS);
    return () => scope
      ..removeEventListener('click', click)
      ..removeEventListener('keydown', keys)
      ..removeEventListener('close', close, true.toJS)
      ..removeEventListener('change', change, true.toJS);
  }
}

web.Element? _element(web.EventTarget? t) =>
    t != null && t.isA<web.Element>() ? t as web.Element : null;

/// Where a picker dialog's result goes: the field it names, or its own
/// hidden input.
web.HTMLInputElement? _outOf(web.Element dialog) {
  final target = dialog.getAttribute(pickerDialogAttr);
  final el = target == null || target.isEmpty
      ? dialog.querySelector('[$pickerOutAttr]')
      : web.document.getElementById(target);
  return el as web.HTMLInputElement?;
}

web.HTMLInputElement? _pendingOf(web.Element dialog) =>
    dialog.querySelector('[$pickerPendingAttr]') as web.HTMLInputElement?;

/// OK: the pending value becomes the result (`change` on the output, where
/// `onDatePicked` / `onTimePicked` / the field's callback listen).
void _confirm(web.HTMLDialogElement dialog) {
  final out = _outOf(dialog);
  final pending = _pendingOf(dialog);
  if (out != null && pending != null && out.value != pending.value) {
    out.value = pending.value;
    out.dispatchEvent(web.Event('change', web.EventInit(bubbles: true)));
  }
  dialog.close();
}

/// The pending value back to the result (on open and on cancel).
void _reset(web.Element dialog) {
  final out = _outOf(dialog);
  final pending = _pendingOf(dialog);
  if (out == null || pending == null) return;
  final root = pending.closest('[$datePickerAttr]');
  if (root == null) {
    pending.value = out.value;
  } else {
    _Calendar.of(root).reset(out.value);
  }
}

final _calendars = Expando<_Calendar>('thor.calendar');

/// One calendar of the page (read from its markup on first use).
final class _Calendar {
  _Calendar(this.root)
    : config = DatePickerConfig.decode(root.getAttribute(datePickerAttr)!) {
    // Without the page's currentDate: the reader's today, not the
    // server's (a static page may be read days after its build).
    final now = DateTime.now();
    today = config.today ?? DateTime.utc(now.year, now.month, now.day);
    month = parseIsoDate(root.getAttribute(dateMonthAttr))!;
  }

  static _Calendar of(web.Element root) => _calendars[root] ??= _Calendar(root);

  final web.Element root;
  final DatePickerConfig config;
  late final DateTime today;

  DateTime get first => config.first;
  DateTime get last => config.last;

  /// The 1st of the month shown.
  late DateTime month;

  web.HTMLInputElement get _input =>
      root.querySelector('[$dateValueAttr]')! as web.HTMLInputElement;

  DateTime? get value => parseIsoDate(_input.value);

  web.NodeList get _cells => root.querySelectorAll('[$dateDaysAttr] td');

  bool get _inDialog => root.closest('dialog') != null;

  late final DayMask? _mask = config.mask == null
      ? null
      : DayMask.decode(config.mask!, first);

  bool enabled(DateTime day) =>
      !day.isBefore(first) &&
      !day.isAfter(last) &&
      !(_mask?.isDisabled(daysBetween(first, day)) ?? false);

  DateTime _clamp(DateTime day) => day.isBefore(first)
      ? first
      : day.isAfter(last)
      ? last
      : day;

  DateTime? _dateOf(web.Element cell) {
    // By position, not by text: the digits may not be ASCII.
    final cells = _cells;
    var i = -1;
    for (var k = 0; k < cells.length; k++) {
      if (cells.item(k) == cell) i = k;
    }
    final offset = ((month.weekday % 7 - config.firstDayOfWeek) % 7 + 7) % 7;
    final n = i - offset + 1;
    final count = DateTime.utc(month.year, month.month + 1, 0).day;
    return i < 0 || n < 1 || n > count
        ? null
        : DateTime.utc(month.year, month.month, n);
  }

  /// Shows [newMonth] (clamped to the range); [focus] gets the roving
  /// tab stop (and the keyboard focus when [moveFocus]).
  void show(DateTime newMonth, {DateTime? focus, bool moveFocus = false}) {
    final m = DateTime.utc(newMonth.year, newMonth.month);
    final lo = DateTime.utc(first.year, first.month);
    final hi = DateTime.utc(last.year, last.month);
    final target = m.isBefore(lo) ? lo : (m.isAfter(hi) ? hi : m);
    final changed = target != month;
    month = target;
    _render(focus);
    if (changed) {
      root.setAttribute(dateMonthAttr, isoDate(month).substring(0, 7));
      root.dispatchEvent(
        web.CustomEvent(
          displayedMonthEvent,
          web.CustomEventInit(bubbles: true, detail: isoDate(month).toJS),
        ),
      );
    }
    if (moveFocus) _focused()?.focus();
  }

  /// Renders the month again (today may differ from the server's).
  void refresh() => _render(null);

  web.HTMLElement? _focused() =>
      root.querySelector('[$dateDaysAttr] td[tabindex="0"]')
          as web.HTMLElement?;

  void _render(DateTime? focus) {
    final y = month.year, m = month.month;
    final layout = layoutMonth(
      month: month,
      firstDayOfWeek: config.firstDayOfWeek,
      selected: value,
      today: today,
      focus: focus,
      enabled: enabled,
    );
    final autofocus = _inDialog;
    final cells = _cells;
    for (var i = 0; i < cells.length && i < layout.length; i++) {
      final cell = cells.item(i)! as web.Element;
      final c = layout[i];
      final text = c.day == null ? '' : config.num(c.day!);
      if (cell.textContent != text) cell.textContent = text;
      if (c.day == null) {
        for (final a in _cellAttrs) {
          cell.removeAttribute(a);
        }
        continue;
      }
      cell.setAttribute('tabindex', c.stop ? '0' : '-1');
      _flag(cell, 'autofocus', autofocus && c.stop, '');
      _flag(cell, 'aria-selected', c.selected, 'true');
      _flag(cell, 'aria-current', c.today, 'date');
      _flag(cell, 'aria-disabled', c.disabled, 'true');
    }
    final label = config.monthYear
        .replaceAll('{M}', config.months[m - 1])
        .replaceAll('{y}', config.num(y));
    root.querySelector('[$dateYearsAttr] span')?.textContent = label;
    root.querySelector('[role="grid"]')?.setAttribute('aria-label', label);
    final navs = root.querySelectorAll('[$dateNavAttr]');
    for (var i = 0; i < navs.length; i++) {
      final nav = navs.item(i)! as web.Element;
      final next = nav.getAttribute(dateNavAttr) == '1';
      final end = next ? last : first;
      _flag(nav, 'disabled', DateUtils.isSameMonth(end, month), '');
    }
  }

  static const _cellAttrs = [
    'tabindex',
    'autofocus',
    'aria-selected',
    'aria-current',
    'aria-disabled',
  ];

  static void _flag(web.Element el, String name, bool on, String value) {
    if (on) {
      if (el.getAttribute(name) != value) el.setAttribute(name, value);
    } else {
      el.removeAttribute(name);
    }
  }

  /// A click on [cell]: selects its day.
  void pick(web.Element cell) {
    final day = _dateOf(cell);
    if (day == null) return;
    (cell as web.HTMLElement).focus();
    select(day);
  }

  void select(DateTime day) {
    if (!enabled(day)) return;
    final input = _input;
    final text = isoDate(day);
    if (input.value != text) {
      input.value = text;
      input.dispatchEvent(web.Event('change', web.EventInit(bubbles: true)));
    }
    _render(day);
    _headline();
  }

  /// The dialog's headline: the pending date.
  void _headline() {
    final h = root.closest('dialog')?.querySelector('[$pickerHeadlineAttr]');
    if (h == null) return;
    final d = value;
    h.textContent = d == null
        ? config.noDate
        : config.mediumDate
              .replaceAll('{w}', config.shortWeekdays[d.weekday % 7])
              .replaceAll('{m}', config.shortMonths[d.month - 1])
              .replaceAll('{d}', config.num(d.day));
  }

  /// Back to [text] (the dialog's result), showing its month.
  void reset(String text) {
    _input.value = text;
    _setMode(false);
    final d = parseIsoDate(text);
    show(d ?? today, focus: d);
    _headline();
  }

  /// The ARIA date grid keys on [cell]; whether it handled [e].
  bool key(web.Element cell, web.KeyboardEvent e) {
    final day = _dateOf(cell);
    if (day == null) return false;
    if (e.key == 'Enter' || e.key == ' ') {
      select(day);
      return true;
    }
    final rtl = root.closest('[dir="rtl"]') != null;
    final weekday = (day.weekday % 7 - config.firstDayOfWeek) % 7;
    DateTime byMonths(int n) {
      final target = DateTime.utc(day.year, day.month + n);
      final count = DateUtils.getDaysInMonth(target.year, target.month);
      return DateTime.utc(
        target.year,
        target.month,
        day.day > count ? count : day.day,
      );
    }

    DateTime byDays(int n) => DateTime.utc(day.year, day.month, day.day + n);
    final to = switch (e.key) {
      'ArrowLeft' => byDays(rtl ? 1 : -1),
      'ArrowRight' => byDays(rtl ? -1 : 1),
      'ArrowUp' => byDays(-7),
      'ArrowDown' => byDays(7),
      'Home' => byDays(-weekday),
      'End' => byDays(6 - weekday),
      'PageUp' => byMonths(e.shiftKey ? -12 : -1),
      'PageDown' => byMonths(e.shiftKey ? 12 : 1),
      _ => null,
    };
    if (to == null) return false;
    final target = _clamp(to);
    show(target, focus: target, moveFocus: true);
    return true;
  }

  void _setMode(bool years) {
    root.setAttribute(dateModeAttr, years ? 'year' : 'day');
    root
        .querySelector('[$dateYearsAttr]')
        ?.setAttribute('aria-expanded', '$years');
  }

  void toggleYears() {
    final years = root.getAttribute(dateModeAttr) != 'year';
    _setMode(years);
    if (!years) {
      _focused()?.focus();
      return;
    }
    final list = root.querySelector('[$dateYearListAttr]');
    if (list == null) return;
    if (list.querySelector('button') == null) {
      // Filled once, from the server's template button.
      final template =
          list.querySelector('template') as web.HTMLTemplateElement?;
      final proto = template?.content.firstElementChild;
      if (proto == null) return;
      for (var y = first.year; y <= last.year; y++) {
        final b = proto.cloneNode(true) as web.Element;
        b.textContent = config.num(y);
        (b as web.HTMLButtonElement).value = '$y';
        list.append(b);
      }
    }
    web.HTMLElement? current;
    final buttons = list.querySelectorAll('button');
    for (var i = 0; i < buttons.length; i++) {
      final b = buttons.item(i)! as web.HTMLElement;
      final y = int.parse((b as web.HTMLButtonElement).value);
      final on = y == month.year;
      _flag(b, 'aria-pressed', on, 'true');
      _flag(b, 'aria-current', y == today.year, 'date');
      if (on) current = b;
    }
    current
      ?..focus()
      ..scrollIntoView(web.ScrollIntoViewOptions(block: 'center'));
  }

  void pickYear(int year) {
    _setMode(false);
    final selected = value;
    show(
      DateTime.utc(year, month.month),
      focus: selected != null && selected.year == year ? selected : null,
      moveFocus: true,
    );
  }
}
