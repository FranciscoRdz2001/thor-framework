import 'package:thor_engine/thor_engine.dart'
    show
        DatePickerConfig,
        DatePickerMode,
        DateUtils,
        DayCell,
        DialogController,
        FocusNode,
        SelectableDayPredicate,
        TimeOfDay,
        dateDaysAttr,
        dateFieldAttr,
        dateModeAttr,
        dateMonthAttr,
        dateNavAttr,
        dateOpenAttr,
        datePickerAttr,
        dateReadyAttr,
        dateValueAttr,
        dateYearListAttr,
        dateYearsAttr,
        dialogControllerAttr,
        displayedMonthEvent,
        encodeDayMask,
        isoDate,
        isoTime,
        layoutMonth,
        pickerConfirmAttr,
        pickerDialogAttr,
        pickerHeadlineAttr,
        pickerOutAttr,
        pickerPendingAttr;
import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../engine/watch.dart' show engineAttributes;
import '../foundation/child_rules.dart';
import '../foundation/clock.dart';
import '../foundation/dialog_scope.dart' show DialogScope;
import '../foundation/element.dart';
import '../foundation/html_attributes.dart';
import '../foundation/material_localizations.dart'
    show MaterialLocalizations, ThorLocalizations;
import '../foundation/native_id.dart' show nativeId;
import '../foundation/parent_data.dart';
import '../foundation/style_registry.dart';
import '../foundation/theme_tokens.dart';
import '../foundation/widget_state.dart';
import 'backdrop.dart'
    show fadingBackdrop, lockScrollWhileModal, modalOverscroll;
import 'buttons.dart' show ButtonStyle, TextButton;
import 'icon.dart' show Icon;
import 'material.dart' show DialogClose;
import 'shortcuts.dart' show controllerIdOf;
import 'text.dart' show Text;
import 'text_field.dart' show InputDecoration, OutlineInputBorder, TextField;
import 'theme.dart' show Theme, ThemeText;

// Material 3 date and time pickers. The calendar is an ARIA date grid
// (`<table role="grid">`, 6 × 7 cells, a roving tab stop); the server
// renders the first month and the engine's DatePickerFeature the others
// (it only rewrites the cells' texts and attributes: every look is a
// condition of the cell's one class). The dialogs are native `<dialog>`s
// opened like `AlertDialog`; the fields are native date inputs (no JS).

const _primary = ThemeTokens.primary;
const _onPrimary = ThemeTokens.onPrimary;
const _onSurface = ThemeTokens.onSurface;
const _onSurfaceVariant = ThemeTokens.onSurfaceVariant;
const _outlineVariant = ThemeTokens.outlineVariant;
const _surfaceContainerHigh = ThemeTokens.surfaceContainerHigh;
const _surfaceContainerHighest = ThemeTokens.surfaceContainerHighest;
const _disabled = 'color-mix(in srgb, $_onSurface 38%, transparent)';
const _stateLayer = 'color-mix(in srgb, currentColor 8%, transparent)';
const _focusLayer = 'color-mix(in srgb, currentColor 10%, transparent)';

/// Flutter's `DatePickerThemeData`: how the date pickers look. Put it in
/// `ThemeData(datePickerTheme:)`, or around a subtree with
/// [DatePickerTheme]. Null fields keep the Material 3 defaults (the
/// theme's color roles).
///
/// The per-state colors are `WidgetStateProperty`s like in Flutter,
/// resolved for [WidgetState.selected], [WidgetState.disabled],
/// [WidgetState.hovered] and [WidgetState.focused].
class DatePickerThemeData {
  /// A date picker theme; null fields keep the defaults.
  const DatePickerThemeData({
    this.backgroundColor,
    this.headerBackgroundColor,
    this.headerForegroundColor,
    this.headerHeadlineStyle,
    this.headerHelpStyle,
    this.weekdayStyle,
    this.dayStyle,
    this.dayForegroundColor,
    this.dayBackgroundColor,
    this.dayOverlayColor,
    this.dayShape,
    this.todayForegroundColor,
    this.todayBackgroundColor,
    this.todayBorder,
    this.yearStyle,
    this.yearForegroundColor,
    this.yearBackgroundColor,
    this.yearOverlayColor,
    this.yearShape,
    this.dividerColor,
    this.shape,
    this.cancelButtonStyle,
    this.confirmButtonStyle,
    this.daySize,
  });

  /// The dialog's fill.
  final Color? backgroundColor;

  /// The dialog header's fill.
  final Color? headerBackgroundColor;

  /// The dialog header's text color (help text and headline).
  final Color? headerForegroundColor;

  /// The headline (the chosen date).
  final TextStyle? headerHeadlineStyle;

  /// The help text above the headline.
  final TextStyle? headerHelpStyle;

  /// The weekday initials over the days.
  final TextStyle? weekdayStyle;

  /// The day numbers.
  final TextStyle? dayStyle;

  /// Day text color per state (selected, disabled…).
  final WidgetStateProperty<Color?>? dayForegroundColor;

  /// Day fill per state.
  final WidgetStateProperty<Color?>? dayBackgroundColor;

  /// The layer over a hovered or focused day.
  final WidgetStateProperty<Color?>? dayOverlayColor;

  /// A day's shape (a circle by default).
  final WidgetStateProperty<OutlinedBorder?>? dayShape;

  /// Today's text color per state.
  final WidgetStateProperty<Color?>? todayForegroundColor;

  /// Today's fill per state.
  final WidgetStateProperty<Color?>? todayBackgroundColor;

  /// The ring around today.
  final BorderSide? todayBorder;

  /// The years of the year list.
  final TextStyle? yearStyle;

  /// Year text color per state.
  final WidgetStateProperty<Color?>? yearForegroundColor;

  /// Year fill per state.
  final WidgetStateProperty<Color?>? yearBackgroundColor;

  /// The layer over a hovered or focused year.
  final WidgetStateProperty<Color?>? yearOverlayColor;

  /// A year's shape (a stadium by default).
  final WidgetStateProperty<OutlinedBorder?>? yearShape;

  /// The line under the dialog's header.
  final Color? dividerColor;

  /// The dialog's shape. `// web:` an `OutlinedBorder` (Flutter's
  /// `ShapeBorder`): its corners and outline.
  final OutlinedBorder? shape;

  /// The dialog's cancel button.
  final ButtonStyle? cancelButtonStyle;

  /// The dialog's confirm button.
  final ButtonStyle? confirmButtonStyle;

  /// `// web:` the side of a day cell (px; Flutter sizes it from the
  /// dialog). Default 40.
  final double? daySize;
}

/// Flutter's `DatePickerTheme`: a [DatePickerThemeData] for the pickers
/// below.
class DatePickerTheme extends InheritedWidget implements InheritedMemoKey {
  /// Applies [data] to the date pickers in [child].
  const DatePickerTheme({super.key, required this.data, required super.child});

  /// The theme.
  final DatePickerThemeData data;

  /// The nearest [DatePickerTheme]'s data, else the app theme's
  /// `datePickerTheme`, else the defaults.
  static DatePickerThemeData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DatePickerTheme>()?.data ??
      Theme.of(context).datePickerTheme ??
      const DatePickerThemeData();

  @override
  bool updateShouldNotify(covariant DatePickerTheme oldWidget) =>
      !identical(oldWidget.data, data);

  /// Readers see only this value.
  @override
  Object? get memoKey => data;
}

/// The pickers' texts in the page's language: `MaterialLocalizations` (dates,
/// buttons, tooltips) and `ThorLocalizations` (the empty-date label).
class _Strings {
  const _Strings(this.m, this.t);

  final MaterialLocalizations m;
  final ThorLocalizations t;

  static _Strings of(BuildContext context) => _Strings(
    MaterialLocalizations.of(context),
    ThorLocalizations.of(context),
  );

  List<String> get months => m.monthNames;
  List<String> get shortMonths => m.shortMonthNames;
  List<String> get weekdays => m.weekdayNames;
  List<String> get shortWeekdays => m.shortWeekdayNames;
  List<String> get narrowWeekdays => m.narrowWeekdays;
  int get firstDayOfWeek => m.firstDayOfWeekIndex;
  String get monthYear => m.monthYearPattern;
  String get mediumDate => m.mediumDatePattern;
  String get help => m.datePickerHelpText;
  String get cancel => m.cancelButtonLabel;
  String get ok => m.okButtonLabel;
  String get previousMonth => m.previousMonthTooltip;
  String get nextMonth => m.nextMonthTooltip;
  String get selectYear => m.selectYearSemanticsLabel;
  String get noDate => t.noDateSelectedLabel;
  String get dateInput => m.dateInputLabel;
  String get openCalendar => m.calendarModeButtonLabel;
  String get timeHelp => m.timePickerInputHelpText;
  String get digits => m.digits;

  String formatMonthYear(DateTime d) => m.formatMonthYear(d);
  String formatMediumDate(DateTime d) => m.formatMediumDate(d);
}

// web: `matchTextDirection`: previous / next point the other way in RTL.
const _chevronLeft = IconData.svg(
  'thor-chevron-left',
  '<path d="M15.41 7.41 14 6l-6 6 6 6 1.41-1.41L10.83 12z"/>',
  matchTextDirection: true,
);
const _chevronRight = IconData.svg(
  'thor-chevron-right',
  '<path d="M10 6 8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6z"/>',
  matchTextDirection: true,
);
const _arrowDropDown = IconData.svg(
  'thor-arrow-drop-down',
  '<path d="m7 10 5 5 5-5z"/>',
);
const _calendarIcon = IconData.svg(
  'thor-calendar-today',
  '<path d="M20 3h-1V1h-2v2H7V1H5v2H4c-1.1 0-2 .9-2 2v16c0 1.1.9 2 2 2h16'
      'c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 18H4V8h16v13z"/>',
);

const _yearMode = CssCondition.within('[$dateModeAttr="year"]');

const _plainButton = {
  'appearance': 'none',
  'margin': '0',
  'border': '0',
  'background': 'transparent',
  'font': 'inherit',
  'cursor': 'pointer',
};

const _hoverLayer = ConditionalCss(CssCondition.hoverEnabled, {
  'background-image': 'linear-gradient($_stateLayer, $_stateLayer)',
});

const _focusRing = ConditionalCss(CssCondition.focused, {
  'outline': '2px solid $_primary',
  'outline-offset': '2px',
});

String _layer(String color) => 'linear-gradient($color, $color)';

/// A widget state's color from [p] (theme) or [fallback].
String? _resolve(
  WidgetStateProperty<Color?>? p,
  Set<WidgetState> states,
  String? fallback,
) => p?.resolve(states)?.css ?? fallback;

DateTime _utc(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// The calendar body shared by [CalendarDatePicker] and the dialog.
Widget _calendar(
  BuildContext context, {
  required DateTime? initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  required DateTime? currentDate,
  required DatePickerMode initialCalendarMode,
  required SelectableDayPredicate? selectableDayPredicate,
  Map<String, String> inputAttributes = const {},
  Map<String, String> rootAttributes = const {},
  bool inDialog = false,
}) {
  ThorStyleRegistry.active(context)?.useEngine();
  final s = _Strings.of(context);
  final t = DatePickerTheme.of(context);
  final first = DateUtils.dateOnly(firstDate);
  final last = DateUtils.dateOnly(lastDate);
  final selected = initialDate == null ? null : DateUtils.dateOnly(initialDate);
  // web: without currentDate the browser marks its own today (a static
  // page may be read days after it was built).
  final today = DateUtils.dateOnly(currentDate ?? thorNow());
  final shown = selected ?? today;
  var month = DateTime(shown.year, shown.month);
  if (month.isBefore(DateTime(first.year, first.month))) {
    month = DateTime(first.year, first.month);
  } else if (month.isAfter(DateTime(last.year, last.month))) {
    month = DateTime(last.year, last.month);
  }
  final mask = selectableDayPredicate == null
      ? null
      : encodeDayMask(first, last, selectableDayPredicate);
  // web: the predicate gets each day as a UTC date (the mask counts days in
  // UTC, with no time zone lookup per day): compare its fields or
  // `DateUtils.isSameDay`, not `==` with a local `DateTime`.
  bool enabled(DateTime d) =>
      !d.isBefore(first) &&
      !d.isAfter(last) &&
      (selectableDayPredicate?.call(_utc(d)) ?? true);
  final cells = layoutMonth(
    month: month,
    firstDayOfWeek: s.firstDayOfWeek,
    enabled: (d) => enabled(DateTime(d.year, d.month, d.day)),
    // The layout works in UTC dates.
    selected: selected == null ? null : _utc(selected),
    today: _utc(today),
  );
  final config = DatePickerConfig(
    first: first,
    last: last,
    today: currentDate == null ? null : today,
    firstDayOfWeek: s.firstDayOfWeek,
    months: s.months,
    shortMonths: s.shortMonths,
    shortWeekdays: s.shortWeekdays,
    monthYear: s.monthYear,
    mediumDate: s.mediumDate,
    noDate: s.noDate,
    mask: mask,
    digits: s.digits,
  ).encode();
  final label = s.formatMonthYear(month);
  final size = t.daySize ?? 40;
  const spacingY = 2.0;
  final years = initialCalendarMode == DatePickerMode.year;

  // Days: one class, every look a condition of it.
  final dayShape = t.dayShape?.resolve(const {});
  final dayCss = <String, String>{
    'box-sizing': 'border-box',
    'width': cssPx(size),
    'height': cssPx(size),
    'padding': '0',
    'text-align': 'center',
    'vertical-align': 'middle',
    'border-radius': dayShape?.radiusCss ?? '50%',
    if (dayShape != null && dayShape.side != BorderSide.none)
      'border': dayShape.side.css,
    'cursor': 'pointer',
    'user-select': 'none',
    ...(t.dayStyle ?? ThemeText.bodyLarge).toCss(),
    'color': _resolve(t.dayForegroundColor, const {}, _onSurface)!,
    'background-color': ?t.dayBackgroundColor?.resolve(const {})?.css,
  };
  final todayRing =
      t.todayBorder ??
      const BorderSide(
        color: Color.variable(
          CssVariable('--t-primary'),
          fallback: Color(0xFF6750A4),
        ),
      );
  final hover = _resolve(t.dayOverlayColor, const {
    WidgetState.hovered,
  }, _stateLayer)!;
  final focus = _resolve(t.dayOverlayColor, const {
    WidgetState.focused,
  }, _focusLayer)!;
  final dayConditions = [
    const ConditionalCss(CssCondition.selector(':empty'), {
      'cursor': 'default',
    }),
    ConditionalCss(const CssCondition.selector('[aria-current="date"]'), {
      'color': _resolve(t.todayForegroundColor, const {}, _primary)!,
      'background-color': ?t.todayBackgroundColor?.resolve(const {})?.css,
      if (todayRing.style != BorderStyle.none)
        'box-shadow':
            'inset 0 0 0 ${cssPx(todayRing.width)} ${todayRing.color.css}',
    }),
    ConditionalCss(const CssCondition.selector('[aria-selected="true"]'), {
      'color': _resolve(t.dayForegroundColor, const {
        WidgetState.selected,
      }, _onPrimary)!,
      'background-color': _resolve(t.dayBackgroundColor, const {
        WidgetState.selected,
      }, _primary)!,
    }),
    ConditionalCss(const CssCondition.selector('[aria-disabled="true"]'), {
      'color': _resolve(t.dayForegroundColor, const {
        WidgetState.disabled,
      }, _disabled)!,
      'cursor': 'default',
    }),
    ConditionalCss(
      const CssCondition.selector(
        ':hover:not(:empty):not([aria-disabled="true"])',
      ),
      {'background-image': _layer(hover)},
    ),
    ConditionalCss(CssCondition.focused, {
      'background-image': _layer(focus),
      'outline': '2px solid $_primary',
      'outline-offset': '-2px',
    }),
  ];

  Widget cell(DayCell c) => thorElement(
    'td',
    css: dayCss,
    conditions: dayConditions,
    attributes: c.day == null
        ? const {}
        : {
            'tabindex': c.stop ? '0' : '-1',
            if (inDialog && c.stop) 'autofocus': '',
            if (c.selected) 'aria-selected': 'true',
            if (c.today) 'aria-current': 'date',
            if (c.disabled) 'aria-disabled': 'true',
          },
    children: [if (c.day != null) Widget.text(s.m.formatDecimal(c.day!))],
  );

  final weekdayCss = {
    'box-sizing': 'border-box',
    'width': cssPx(size),
    'height': cssPx(size),
    'padding': '0',
    'text-align': 'center',
    'font-weight': '400',
    ...(t.weekdayStyle ?? ThemeText.bodyLarge).toCss(),
    if (t.weekdayStyle?.color == null) 'color': _onSurface,
  };

  final yearShape = t.yearShape?.resolve(const {});
  final yearHover = _resolve(t.yearOverlayColor, const {
    WidgetState.hovered,
  }, _stateLayer)!;
  final yearButton = thorElement(
    'button',
    css: {
      ..._plainButton,
      'width': '72px',
      'height': '36px',
      'border-radius': yearShape?.radiusCss ?? '18px',
      if (yearShape != null && yearShape.side != BorderSide.none)
        'border': yearShape.side.css,
      ...(t.yearStyle ?? ThemeText.bodyLarge).toCss(),
      'color': _resolve(t.yearForegroundColor, const {}, _onSurfaceVariant)!,
      'background-color': ?t.yearBackgroundColor?.resolve(const {})?.css,
    },
    conditions: [
      const ConditionalCss(CssCondition.selector('[aria-current="date"]'), {
        'color': _primary,
        'box-shadow': 'inset 0 0 0 1px $_primary',
      }),
      ConditionalCss(const CssCondition.selector('[aria-pressed="true"]'), {
        'color': _resolve(t.yearForegroundColor, const {
          WidgetState.selected,
        }, _onPrimary)!,
        'background-color': _resolve(t.yearBackgroundColor, const {
          WidgetState.selected,
        }, _primary)!,
      }),
      ConditionalCss(CssCondition.hoverEnabled, {
        'background-image': _layer(yearHover),
      }),
      _focusRing,
    ],
    attributes: const {'type': 'button'},
  );

  Widget navButton(int step) => thorElement(
    'button',
    css: const {
      ..._plainButton,
      'display': 'inline-grid',
      'place-items': 'center',
      'width': '48px',
      'height': '48px',
      'padding': '0',
      'border-radius': '50%',
      'color': _onSurfaceVariant,
    },
    conditions: const [
      _hoverLayer,
      _focusRing,
      ConditionalCss(CssCondition.disabled, {
        'opacity': '0.38',
        'cursor': 'default',
      }),
      ConditionalCss(_yearMode, {'visibility': 'hidden'}),
    ],
    attributes: {
      'type': 'button',
      dateNavAttr: '$step',
      'aria-label': step < 0 ? s.previousMonth : s.nextMonth,
      'title': step < 0 ? s.previousMonth : s.nextMonth,
      if (DateUtils.isSameMonth(step < 0 ? first : last, month)) 'disabled': '',
    },
    children: [Icon(step < 0 ? _chevronLeft : _chevronRight)],
  );

  return thorElement(
    'div',
    debugName: 'CalendarDatePicker',
    css: const {
      'display': 'flex',
      'flex-direction': 'column',
      'align-items': 'center',
      'color': _onSurface,
    },
    attributes: {
      datePickerAttr: config,
      dateMonthAttr: isoDate(month).substring(0, 7),
      dateModeAttr: years ? 'year' : 'day',
      ...rootAttributes,
    },
    children: [
      // Header: month and year (toggles the year list), previous / next.
      thorElement(
        'div',
        css: const {
          'display': 'flex',
          'align-items': 'center',
          'align-self': 'stretch',
          'box-sizing': 'border-box',
          'height': '52px',
          'padding-inline': '12px 4px',
        },
        children: [
          thorElement(
            'button',
            css: {
              ..._plainButton,
              'display': 'inline-flex',
              'align-items': 'center',
              'gap': '4px',
              'height': '40px',
              'padding-inline': '12px 4px',
              'margin-inline-end': 'auto',
              'border-radius': '20px',
              ...ThemeText.titleSmall.toCss(),
              'color': _onSurfaceVariant,
            },
            conditions: const [_hoverLayer, _focusRing],
            attributes: {
              'type': 'button',
              dateYearsAttr: '',
              'aria-expanded': '$years',
              'title': s.selectYear,
            },
            children: [
              thorElement(
                'span',
                attributes: const {'aria-live': 'polite'},
                children: [Widget.text(label)],
              ),
              thorElement(
                'span',
                css: const {
                  'display': 'inline-flex',
                  'transition-property': 'rotate',
                  'transition-duration': '200ms',
                },
                conditions: const [
                  ConditionalCss(_yearMode, {'rotate': '180deg'}),
                  ConditionalCss(CssCondition.reducedMotion, {
                    'transition-duration': '1ms',
                  }),
                ],
                children: const [Icon(_arrowDropDown)],
              ),
            ],
          ),
          navButton(-1),
          navButton(1),
        ],
      ),
      // Days.
      thorElement(
        'table',
        css: const {
          'border-collapse': 'separate',
          'border-spacing': '4px 2px',
          'table-layout': 'fixed',
        },
        conditions: const [
          ConditionalCss(_yearMode, {'display': 'none'}),
        ],
        attributes: {'role': 'grid', 'aria-label': label},
        children: [
          Widget.element(
            tag: 'thead',
            children: [
              Widget.element(
                tag: 'tr',
                children: [
                  for (var i = 0; i < 7; i++)
                    thorElement(
                      'th',
                      css: weekdayCss,
                      attributes: {
                        'scope': 'col',
                        'abbr': s.weekdays[(i + s.firstDayOfWeek) % 7],
                      },
                      children: [
                        Widget.text(
                          s.narrowWeekdays[(i + s.firstDayOfWeek) % 7],
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
          Widget.element(
            tag: 'tbody',
            attributes: const {dateDaysAttr: ''},
            children: [
              for (var r = 0; r < 6; r++)
                Widget.element(
                  tag: 'tr',
                  children: [
                    for (var c = 0; c < 7; c++) cell(cells[r * 7 + c]),
                  ],
                ),
            ],
          ),
        ],
      ),
      // Years: filled by the browser from the template the first time.
      thorElement(
        'div',
        css: {
          'display': 'none',
          'grid-template-columns': 'repeat(3, 1fr)',
          'justify-items': 'center',
          'align-content': 'start',
          'row-gap': '16px',
          'align-self': 'stretch',
          'box-sizing': 'border-box',
          'height': cssPx(7 * size + 8 * spacingY),
          'padding': '8px 0',
          'overflow-y': 'auto',
        },
        conditions: const [
          ConditionalCss(_yearMode, {'display': 'grid'}),
        ],
        attributes: {dateYearListAttr: '', 'aria-label': s.selectYear},
        children: [
          Widget.element(tag: 'template', children: [yearButton]),
        ],
      ),
      thorElement(
        'input',
        attributes: {
          'type': 'hidden',
          dateValueAttr: '',
          if (selected != null) 'value': isoDate(selected),
          ...inputAttributes,
        },
      ),
    ],
  );
}

/// Flutter's `CalendarDatePicker`: a month grid to pick a day, with
/// previous / next month and a year list.
///
/// An ARIA date grid: arrow keys move by day and week, Home / End to the
/// week's ends, Page Up / Page Down by month (with Shift by year), Enter
/// or Space picks. The server renders the first month; the engine
/// (`DatePickerFeature`) the others. [onDateChanged] (a `ThorState`
/// method taking a `DateTime`) runs in the browser on every pick.
///
/// `// web:` without JS the grid shows the initial month and can't change.
/// Inside a `<form>` a [name] posts the picked date as `yyyy-mm-dd`.
class CalendarDatePicker extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Creates a calendar showing [initialDate]'s month (or today's).
  CalendarDatePicker({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    this.currentDate,
    required this.onDateChanged,
    this.onDisplayedMonthChanged,
    this.initialCalendarMode = DatePickerMode.day,
    this.selectableDayPredicate,
    this.name,
  }) : assert(
         !lastDate.isBefore(firstDate),
         'lastDate must be on or after firstDate',
       ),
       assert(
         initialDate == null ||
             !DateUtils.dateOnly(
                   initialDate,
                 ).isBefore(DateUtils.dateOnly(firstDate)) &&
                 !DateUtils.dateOnly(
                   initialDate,
                 ).isAfter(DateUtils.dateOnly(lastDate)),
         'initialDate must be between firstDate and lastDate',
       );

  /// The day selected at first (none when null).
  final DateTime? initialDate;

  /// The earliest day that can be picked.
  final DateTime firstDate;

  /// The latest day that can be picked.
  final DateTime lastDate;

  /// Today (Flutter's default: `DateTime.now()`). `// web:` when null the
  /// browser marks its own today, and the server opens on `thorNow()` (a
  /// zone's `withClock`, or `THOR_NOW`).
  final DateTime? currentDate;

  /// Called with the picked day (a `ThorState` method `void f(DateTime)`).
  final ValueChanged<DateTime> onDateChanged;

  /// Called with the 1st of the month shown after navigating.
  final ValueChanged<DateTime>? onDisplayedMonthChanged;

  /// Days or years first.
  final DatePickerMode initialCalendarMode;

  /// Which days can be picked (the others are dimmed). `// web:`
  /// evaluated on the server for every day from [firstDate] to [lastDate]
  /// (a compact mask in the page), each day as a UTC date.
  final SelectableDayPredicate? selectableDayPredicate;

  // web: not in Flutter.
  /// Posts the picked date (`yyyy-mm-dd`) under this name.
  final String? name;

  @override
  Widget build(BuildContext context) => _calendar(
    context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    currentDate: currentDate,
    initialCalendarMode: initialCalendarMode,
    selectableDayPredicate: selectableDayPredicate,
    inputAttributes: {
      'name': ?name,
      ...engineAttributes({'change': onDateChanged}),
    },
    rootAttributes: engineAttributes({
      displayedMonthEvent: onDisplayedMonthChanged,
    }),
  );
}

/// The Material 3 shell of the picker dialogs.
Widget _pickerDialog(
  BuildContext context, {
  required String id,
  required String debugName,
  required String helpText,
  required Widget? headline,
  required Widget body,
  required String cancelText,
  required String confirmText,
  required DialogController? controller,
  required bool barrierDismissible,
  required String target,
  Widget? output,
}) {
  lockScrollWhileModal(context);
  final t = DatePickerTheme.of(context);
  final shape = t.shape;
  final headerColor = t.headerForegroundColor?.css ?? _onSurfaceVariant;
  return DialogScope(
    id: id,
    child: thorElement(
      'dialog',
      id: id,
      debugName: debugName,
      css: {
        'box-sizing': 'border-box',
        'width': '360px',
        'max-width': 'calc(100vw - 32px)',
        'max-height': 'calc(100dvh - 32px)',
        'padding': '0',
        'border': '0',
        'border-radius': shape?.radiusCss ?? '28px',
        if (shape != null && shape.side != BorderSide.none)
          'border': shape.side.css,
        'background-color': t.backgroundColor?.css ?? _surfaceContainerHigh,
        'color': _onSurface,
        'box-shadow': '0 8px 24px rgba(0, 0, 0, 0.2)',
        'overflow': 'auto',
        ...modalOverscroll,
      },
      conditions: [
        ...fadingBackdrop('150ms'),
        const ConditionalCss(CssCondition.selector('[open]'), {
          'display': 'flex',
          'flex-direction': 'column',
        }),
      ],
      attributes: {
        pickerDialogAttr: target,
        'aria-labelledby': '$id-help',
        'closedby': barrierDismissible ? 'any' : 'closerequest',
        dialogControllerAttr: ?controllerIdOf(controller),
      },
      children: [
        thorElement(
          'div',
          css: {
            'display': 'flex',
            'flex-direction': 'column',
            'justify-content': 'space-between',
            'gap': '36px',
            'box-sizing': 'border-box',
            'min-height': headline == null ? '0' : '120px',
            'padding': '16px 24px 12px',
            'border-bottom':
                '1px solid ${t.dividerColor?.css ?? _outlineVariant}',
            'color': headerColor,
            'background-color': ?t.headerBackgroundColor?.css,
          },
          children: [
            thorElement(
              'span',
              id: '$id-help',
              css: (t.headerHelpStyle ?? ThemeText.labelLarge).toCss(),
              children: [Widget.text(helpText)],
            ),
            ?headline,
          ],
        ),
        body,
        thorElement(
          'div',
          css: const {
            'display': 'flex',
            'justify-content': 'flex-end',
            'gap': '8px',
            'padding': '8px 12px 12px',
          },
          childRules: ChildRules.row,
          children: [
            DialogClose(
              id: id,
              child: TextButton(
                onPressed: _noop,
                style: t.cancelButtonStyle,
                child: Text(cancelText),
              ),
            ),
            WrapWith(
              const WrapData(attributes: {pickerConfirmAttr: ''}),
              child: TextButton(
                onPressed: _noop,
                style: t.confirmButtonStyle,
                child: Text(confirmText),
              ),
            ),
          ],
        ),
        ?output,
      ],
    ),
  );
}

void _noop() {}

Widget _headline(BuildContext context, String text) {
  final t = DatePickerTheme.of(context);
  return thorElement(
    'span',
    css: {
      ...(t.headerHeadlineStyle ?? ThemeText.headlineLarge).toCss(),
      if (t.headerHeadlineStyle?.color == null)
        'color': t.headerForegroundColor?.css ?? _onSurfaceVariant,
    },
    attributes: const {pickerHeadlineAttr: '', 'aria-live': 'polite'},
    children: [Widget.text(text)],
  );
}

/// The date dialog's markup, for [DatePickerDialog] and
/// [DatePickerFormField] (which writes into its field instead of an own
/// hidden input).
Widget _dateDialog(
  BuildContext context, {
  required String id,
  required DateTime? initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  required DateTime? currentDate,
  required SelectableDayPredicate? selectableDayPredicate,
  required String? cancelText,
  required String? confirmText,
  required String? helpText,
  required DatePickerMode initialCalendarMode,
  required DialogController? controller,
  required bool barrierDismissible,
  String target = '',
  Map<String, String>? output,
}) {
  final s = _Strings.of(context);
  final selected = initialDate == null ? null : DateUtils.dateOnly(initialDate);
  return _pickerDialog(
    context,
    id: id,
    debugName: 'DatePickerDialog',
    helpText: helpText ?? s.help,
    headline: _headline(
      context,
      selected == null ? s.noDate : s.formatMediumDate(selected),
    ),
    body: thorElement(
      'div',
      css: const {'padding': '0 12px'},
      children: [
        _calendar(
          context,
          initialDate: initialDate,
          firstDate: firstDate,
          lastDate: lastDate,
          currentDate: currentDate,
          initialCalendarMode: initialCalendarMode,
          selectableDayPredicate: selectableDayPredicate,
          inputAttributes: const {pickerPendingAttr: ''},
          inDialog: true,
        ),
      ],
    ),
    cancelText: cancelText ?? s.cancel,
    confirmText: confirmText ?? s.ok,
    controller: controller,
    barrierDismissible: barrierDismissible,
    target: target,
    output: output == null
        ? null
        : thorElement('input', attributes: {'type': 'hidden', ...output}),
  );
}

/// Flutter's `DatePickerDialog` (what `showDatePicker` shows): a Material 3
/// dialog with a [CalendarDatePicker], a headline with the chosen date,
/// and Cancel / OK.
///
/// `// web:` a closed native `<dialog>` in the page, like `AlertDialog`:
/// open it with `DialogTrigger(id: id)` or a [controller]. Flutter's
/// `await showDatePicker(…)` becomes [onDatePicked] (a `ThorState` method
/// taking a `DateTime`, called on OK), and [name] posts the date in a
/// `<form>` (`yyyy-mm-dd`). Cancel, Esc and the backdrop drop the change.
/// It needs the engine (JS); for a field that also works without it, see
/// [DatePickerFormField].
class DatePickerDialog extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Creates a date picker dialog.
  const DatePickerDialog({
    super.key,
    this.id,
    this.initialDate,
    required this.firstDate,
    required this.lastDate,
    this.currentDate,
    this.selectableDayPredicate,
    this.cancelText,
    this.confirmText,
    this.helpText,
    this.initialCalendarMode = DatePickerMode.day,
    this.onDatePicked,
    this.name,
    this.controller,
    this.barrierDismissible = true,
  });

  /// DOM id (the triggers point at it); optional, see `AlertDialog.id`.
  final String? id;

  /// The day selected at first (none when null).
  final DateTime? initialDate;

  /// The earliest day that can be picked.
  final DateTime firstDate;

  /// The latest day that can be picked.
  final DateTime lastDate;

  /// Today (see [CalendarDatePicker.currentDate]).
  final DateTime? currentDate;

  /// Which days can be picked.
  final SelectableDayPredicate? selectableDayPredicate;

  /// The cancel button's text (default: "Cancel").
  final String? cancelText;

  /// The confirm button's text (default: "OK").
  final String? confirmText;

  /// The text above the headline (default: "Select date").
  final String? helpText;

  /// Days or years first.
  final DatePickerMode initialCalendarMode;

  // web: not in Flutter.
  /// Called with the date on OK (Flutter: the `Future` of
  /// `showDatePicker`).
  final ValueChanged<DateTime>? onDatePicked;

  // web: not in Flutter.
  /// Posts the confirmed date (`yyyy-mm-dd`) under this name.
  final String? name;

  /// Opens and closes it from a `ThorState` method (a field of the state).
  final DialogController? controller;

  /// Backdrop click / Esc close it (`showDatePicker(barrierDismissible:)`).
  final bool barrierDismissible;

  @override
  Widget build(BuildContext context) => _dateDialog(
    context,
    id: nativeId(
      context,
      prefix: 'dlg',
      id: id,
      key: key,
      controller: controller,
    ),
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    currentDate: currentDate,
    selectableDayPredicate: selectableDayPredicate,
    cancelText: cancelText,
    confirmText: confirmText,
    helpText: helpText,
    initialCalendarMode: initialCalendarMode,
    controller: controller,
    barrierDismissible: barrierDismissible,
    output: {
      pickerOutAttr: '',
      'name': ?name,
      if (initialDate case final d?) 'value': isoDate(d),
      ...engineAttributes({'change': onDatePicked}),
    },
  );
}

/// The native date input both fields render.
Widget _dateInput({
  required DateTime? initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  required ValueChanged<DateTime>? onDateSubmitted,
  required String label,
  required bool autofocus,
  required bool acceptEmptyDate,
  required FocusNode? focusNode,
  required String? name,
  String? id,
  Widget? suffixIcon,
}) => TextField(
  id: id,
  name: name,
  autofocus: autofocus,
  focusNode: focusNode,
  initialValue: initialDate == null ? null : isoDate(initialDate),
  decoration: InputDecoration(
    labelText: label,
    border: const OutlineInputBorder(),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(
        color: Color.variable(
          CssVariable('--t-primary'),
          fallback: Color(0xFF6750A4),
        ),
        width: 2,
      ),
    ),
    suffixIcon: suffixIcon,
  ),
  inputAttributes: trustedAttributes({
    'type': 'date',
    'min': isoDate(firstDate),
    'max': isoDate(lastDate),
    if (!acceptEmptyDate) 'required': '',
    dateFieldAttr: '',
    ...engineAttributes({'change': onDateSubmitted}),
  }),
);

/// Flutter's `InputDatePickerFormField`: a field to type a date.
///
/// `// web:` a native `<input type="date">` (typing, the browser's own
/// picker, `min`/`max` and `required` validation, all without JS; it posts
/// `yyyy-mm-dd` under [name] whatever the display format).
/// [onDateSubmitted] runs on `change` (a complete date). Flutter's
/// `selectableDayPredicate` and error texts are not enforced by the input.
class InputDatePickerFormField extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Creates a date entry field.
  const InputDatePickerFormField({
    super.key,
    this.initialDate,
    required this.firstDate,
    required this.lastDate,
    this.onDateSubmitted,
    this.fieldLabelText,
    this.autofocus = false,
    this.acceptEmptyDate = false,
    this.focusNode,
    this.name,
  });

  /// The date in the field at first.
  final DateTime? initialDate;

  /// The earliest date accepted (`min`).
  final DateTime firstDate;

  /// The latest date accepted (`max`).
  final DateTime lastDate;

  /// Called with the entered date (a `ThorState` method taking a
  /// `DateTime`).
  final ValueChanged<DateTime>? onDateSubmitted;

  /// The field's label (default: "Enter Date").
  final String? fieldLabelText;

  /// Whether to focus it when the page opens.
  final bool autofocus;

  /// Whether it may be left empty (else `required`).
  final bool acceptEmptyDate;

  /// A `FocusNode` field of a `ThorState`.
  final FocusNode? focusNode;

  // web: not in Flutter.
  /// Form field name.
  final String? name;

  @override
  Widget build(BuildContext context) => _dateInput(
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    onDateSubmitted: onDateSubmitted,
    label: fieldLabelText ?? _Strings.of(context).dateInput,
    autofocus: autofocus,
    acceptEmptyDate: acceptEmptyDate,
    focusNode: focusNode,
    name: name,
  );
}

// web: not in Flutter.
/// A date field with a calendar button — what Flutter apps
/// build from a read-only `TextFormField` whose tap awaits
/// `showDatePicker`.
///
/// Renders an [InputDatePickerFormField] (the native date input, so it
/// types, validates and posts `yyyy-mm-dd` with no JS) and a
/// [DatePickerDialog] with the given [id]. With the engine, a calendar
/// button appears in the field and the dialog's OK writes into it (firing
/// [onDateChanged] and `change`); without JS the button stays hidden and
/// the browser's own picker is the only one.
class DatePickerFormField extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Creates a date field with a picker dialog.
  const DatePickerFormField({
    super.key,
    this.id,
    this.initialDate,
    required this.firstDate,
    required this.lastDate,
    this.currentDate,
    this.onDateChanged,
    this.selectableDayPredicate,
    this.name,
    this.fieldLabelText,
    this.helpText,
    this.cancelText,
    this.confirmText,
    this.acceptEmptyDate = false,
    this.autofocus = false,
    this.focusNode,
  });

  /// DOM id of the dialog (the input is `<id>-input`). Optional: without
  /// one the page names it (by its `ValueKey` or its place in the page, the
  /// same on every render), as `AlertDialog.id` does.
  ///
  /// `// web:` Flutter has no ids: `showDatePicker` pushes a route.
  final String? id;

  /// The date in the field at first.
  final DateTime? initialDate;

  /// The earliest date.
  final DateTime firstDate;

  /// The latest date.
  final DateTime lastDate;

  /// Today (see [CalendarDatePicker.currentDate]).
  final DateTime? currentDate;

  /// Called with the date, typed or picked (a `ThorState` method taking a
  /// `DateTime`).
  final ValueChanged<DateTime>? onDateChanged;

  /// Which days the calendar lets pick (the typed entry is not checked).
  final SelectableDayPredicate? selectableDayPredicate;

  /// Form field name.
  final String? name;

  /// The field's label (default: "Enter Date").
  final String? fieldLabelText;

  /// The dialog's help text (default: "Select date").
  final String? helpText;

  /// The dialog's cancel text.
  final String? cancelText;

  /// The dialog's confirm text.
  final String? confirmText;

  /// Whether it may be left empty (else `required`).
  final bool acceptEmptyDate;

  /// Whether to focus it when the page opens.
  final bool autofocus;

  /// A `FocusNode` field of a `ThorState`.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final s = _Strings.of(context);
    final id = nativeId(context, prefix: 'datefield', id: this.id, key: key);
    final inputId = '$id-input';
    return thorElement(
      'div',
      debugName: 'DatePickerFormField',
      css: const {'display': 'contents'},
      conditions: const [
        // The browser's own calendar icon, once ours works.
        ConditionalCss(
          CssCondition.selector(
            ' [$dateReadyAttr]::-webkit-calendar-picker-indicator',
          ),
          {'display': 'none'},
        ),
      ],
      children: [
        _dateInput(
          id: inputId,
          initialDate: initialDate,
          firstDate: firstDate,
          lastDate: lastDate,
          onDateSubmitted: onDateChanged,
          label: fieldLabelText ?? s.dateInput,
          autofocus: autofocus,
          acceptEmptyDate: acceptEmptyDate,
          focusNode: focusNode,
          name: name,
          suffixIcon: thorElement(
            'button',
            css: const {
              ..._plainButton,
              'display': 'inline-grid',
              'place-items': 'center',
              'width': '40px',
              'height': '40px',
              'padding': '0',
              'border-radius': '50%',
              'color': _onSurfaceVariant,
            },
            conditions: const [
              _hoverLayer,
              _focusRing,
              ConditionalCss(CssCondition.selector('[hidden]'), {
                'display': 'none',
              }),
            ],
            attributes: {
              'type': 'button',
              'hidden': '',
              dateOpenAttr: '',
              'commandfor': id,
              'command': 'show-modal',
              'aria-label': s.openCalendar,
              'title': s.openCalendar,
            },
            children: const [Icon(_calendarIcon)],
          ),
        ),
        _dateDialog(
          context,
          id: id,
          initialDate: initialDate,
          firstDate: firstDate,
          lastDate: lastDate,
          currentDate: currentDate,
          selectableDayPredicate: selectableDayPredicate,
          cancelText: cancelText,
          confirmText: confirmText,
          helpText: helpText,
          initialCalendarMode: DatePickerMode.day,
          controller: null,
          barrierDismissible: true,
          target: inputId,
        ),
      ],
    );
  }
}

/// Flutter's `TimePickerDialog` (what `showTimePicker` shows), in its
/// input mode: a native `<input type="time">` in a Material 3 dialog with
/// Cancel / OK.
///
/// `// web:` no dial: the browser's time input (its own 12/24-hour format
/// and, on phones, its own picker). Open it like [DatePickerDialog];
/// [onTimePicked] (a `ThorState` method taking a `TimeOfDay`) runs on OK
/// and [name] posts `hh:mm`. For a time field without a dialog, a
/// `TextField(inputAttributes: {'type': 'time'})` works with no JS.
class TimePickerDialog extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Creates a time picker dialog.
  const TimePickerDialog({
    super.key,
    this.id,
    required this.initialTime,
    this.cancelText,
    this.confirmText,
    this.helpText,
    this.onTimePicked,
    this.name,
    this.controller,
    this.barrierDismissible = true,
  });

  /// DOM id (the triggers point at it); optional, see `AlertDialog.id`.
  final String? id;

  /// The time shown at first.
  final TimeOfDay initialTime;

  /// The cancel button's text (default: "Cancel").
  final String? cancelText;

  /// The confirm button's text (default: "OK").
  final String? confirmText;

  /// The title (default: "Enter time").
  final String? helpText;

  // web: not in Flutter.
  /// Called with the time on OK (Flutter: the `Future` of
  /// `showTimePicker`).
  final ValueChanged<TimeOfDay>? onTimePicked;

  // web: not in Flutter.
  /// Posts the confirmed time (`hh:mm`) under this name.
  final String? name;

  /// Opens and closes it from a `ThorState` method.
  final DialogController? controller;

  /// Backdrop click / Esc close it.
  final bool barrierDismissible;

  @override
  Widget build(BuildContext context) {
    ThorStyleRegistry.active(context)?.useEngine();
    final s = _Strings.of(context);
    final value = isoTime(initialTime);
    final dialogId = nativeId(
      context,
      prefix: 'dlg',
      id: id,
      key: key,
      controller: controller,
    );
    return _pickerDialog(
      context,
      id: dialogId,
      debugName: 'TimePickerDialog',
      helpText: helpText ?? s.timeHelp,
      headline: null,
      body: thorElement(
        'input',
        css: {
          'box-sizing': 'border-box',
          'margin': '24px',
          'padding': '8px 16px',
          'border': '0',
          'border-radius': '8px',
          'background-color': _surfaceContainerHighest,
          'color': _onSurface,
          ...ThemeText.displayMedium.toCss(),
          'font-family': 'inherit',
        },
        conditions: const [
          ConditionalCss(CssCondition.focused, {
            'outline': '2px solid $_primary',
            'outline-offset': '0',
          }),
        ],
        attributes: {
          'type': 'time',
          'value': value,
          'autofocus': '',
          'required': '',
          'aria-labelledby': '$dialogId-help',
          pickerPendingAttr: '',
        },
      ),
      cancelText: cancelText ?? s.cancel,
      confirmText: confirmText ?? s.ok,
      controller: controller,
      barrierDismissible: barrierDismissible,
      target: '',
      output: thorElement(
        'input',
        attributes: {
          'type': 'hidden',
          pickerOutAttr: '',
          'name': ?name,
          'value': value,
          ...engineAttributes({'change': onTimePicked}),
        },
      ),
    );
  }
}
