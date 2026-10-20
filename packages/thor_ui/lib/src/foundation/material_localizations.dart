/// Flutter's `MaterialLocalizations` and `WidgetsLocalizations`, and
/// `ThorLocalizations` for the texts thor's widgets add: every string a
/// widget writes itself, for the locale of the page.
library;

import 'package:thor_style/thor_style.dart' show TextDirection;

import '../core/core.dart';
import 'localizations.dart';

// The resources of [type] for the nearest `Localizations`; without a
// delegate for it, [fallback] for the page's locale: the request's
// preferred one (a render outside a `ThorApp`), then English.
T _resolve<T extends Object>(
  BuildContext context,
  Type type,
  T Function(Locale locale) fallback,
) {
  final loaded = Localizations.of<T>(context, type);
  if (loaded != null) return loaded;
  final locale =
      Localizations.maybeLocaleOf(context) ??
      PreferredLocales.maybeOf(context)?.firstOrNull ??
      const Locale('en');
  return fallback(locale);
}

/// A delegate that supports every locale and answers with [load].
class _Delegate<T extends Object> extends LocalizationsDelegate<T> {
  const _Delegate(this._load);

  final T Function(Locale locale) _load;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<T> load(Locale locale) => SynchronousFuture<T>(_load(locale));

  @override
  bool shouldReload(covariant LocalizationsDelegate<T> old) => false;
}

// Instances by locale, so a page does not build one per read. Bounded: a
// visitor's locale never grows it past this many entries.
final _cache = <Type, Map<String, Object>>{};

T _cached<T extends Object>(Locale locale, T Function() create) {
  final byLocale = _cache[T] ??= {};
  final key = locale.toString();
  final hit = byLocale[key];
  if (hit != null) return hit as T;
  final made = create();
  if (byLocale.length < 64) byLocale[key] = made;
  return made;
}

// ---------------------------------------------------------------------------
// WidgetsLocalizations
// ---------------------------------------------------------------------------

/// Flutter's `WidgetsLocalizations`: the texts of the basic widgets, for the
/// page's locale.
///
/// ```dart
/// final l10n = WidgetsLocalizations.of(context);
/// l10n.reorderItemToStart;   // Move to the start
/// ```
///
/// `ThorApp` loads it (English and Spanish; another language answers in
/// English) unless the app's `localizationsDelegates` has its own. A page
/// rendered outside a `ThorApp` reads the request's locale.
abstract class WidgetsLocalizations {
  /// The texts of one language.
  const WidgetsLocalizations();

  /// The localized texts of [context], with the fallback of the class.
  static WidgetsLocalizations of(BuildContext context) =>
      _resolve(context, WidgetsLocalizations, _widgetsFor);

  /// The texts the app's delegates loaded, or `null` without one.
  static WidgetsLocalizations? maybeOf(BuildContext context) =>
      Localizations.of<WidgetsLocalizations>(context, WidgetsLocalizations);

  /// Loads English and Spanish; any other locale answers in English.
  static const LocalizationsDelegate<WidgetsLocalizations> delegate =
      _Delegate<WidgetsLocalizations>(_widgetsFor);

  /// The direction text runs in this language.
  TextDirection get textDirection;

  /// Reorder: move an item to the start of the list.
  String get reorderItemToStart;

  /// Reorder: move an item to the end of the list.
  String get reorderItemToEnd;

  /// Reorder: move an item up.
  String get reorderItemUp;

  /// Reorder: move an item down.
  String get reorderItemDown;

  /// Reorder: move an item left.
  String get reorderItemLeft;

  /// Reorder: move an item right.
  String get reorderItemRight;

  /// The label of a copy action.
  String get copyButtonLabel;

  /// The label of a cut action.
  String get cutButtonLabel;

  /// The label of a paste action.
  String get pasteButtonLabel;

  /// The label of a select-all action.
  String get selectAllButtonLabel;
}

WidgetsLocalizations _widgetsFor(Locale locale) => _cached(
  locale,
  () => switch (locale.languageCode) {
    'es' => const WidgetsLocalizationsEs(),
    _ => const DefaultWidgetsLocalizations(),
  },
);

/// English [WidgetsLocalizations] (Flutter's `DefaultWidgetsLocalizations`).
class DefaultWidgetsLocalizations extends WidgetsLocalizations {
  /// The English texts.
  const DefaultWidgetsLocalizations();

  @override
  TextDirection get textDirection => TextDirection.ltr;
  @override
  String get reorderItemToStart => 'Move to the start';
  @override
  String get reorderItemToEnd => 'Move to the end';
  @override
  String get reorderItemUp => 'Move up';
  @override
  String get reorderItemDown => 'Move down';
  @override
  String get reorderItemLeft => 'Move left';
  @override
  String get reorderItemRight => 'Move right';
  @override
  String get copyButtonLabel => 'Copy';
  @override
  String get cutButtonLabel => 'Cut';
  @override
  String get pasteButtonLabel => 'Paste';
  @override
  String get selectAllButtonLabel => 'Select all';
}

/// Spanish [WidgetsLocalizations].
class WidgetsLocalizationsEs extends WidgetsLocalizations {
  /// The Spanish texts.
  const WidgetsLocalizationsEs();

  @override
  TextDirection get textDirection => TextDirection.ltr;
  @override
  String get reorderItemToStart => 'Mover al principio';
  @override
  String get reorderItemToEnd => 'Mover al final';
  @override
  String get reorderItemUp => 'Mover hacia arriba';
  @override
  String get reorderItemDown => 'Mover hacia abajo';
  @override
  String get reorderItemLeft => 'Mover hacia la izquierda';
  @override
  String get reorderItemRight => 'Mover hacia la derecha';
  @override
  String get copyButtonLabel => 'Copiar';
  @override
  String get cutButtonLabel => 'Cortar';
  @override
  String get pasteButtonLabel => 'Pegar';
  @override
  String get selectAllButtonLabel => 'Seleccionar todo';
}

// ---------------------------------------------------------------------------
// MaterialLocalizations
// ---------------------------------------------------------------------------

/// Flutter's `MaterialLocalizations`: the texts and date formats of the
/// Material widgets (date picker, app bar, chips, pagination…), for the
/// page's locale.
///
/// ```dart
/// final l10n = MaterialLocalizations.of(context);
/// Text(l10n.formatMonthYear(DateTime(2026, 9)));   // September 2026
/// l10n.okButtonLabel;                              // OK
/// ```
///
/// `ThorApp` loads it by itself: English and Spanish ship in `thor_ui`
/// (dates included), another language answers in English. For the dates,
/// months and weekdays of **any** locale (CLDR, through `package:intl`) add
/// `GlobalMaterialLocalizations.delegates` from `package:thor_ui/intl.dart`
/// to `ThorApp(localizationsDelegates:)`, as a Flutter app adds
/// `flutter_localizations`.
///
/// A widget's own parameter (`tooltip:`, `helpText:`…) always wins; this
/// supplies what it leaves out. `// web:` the members that Flutter does not
/// have ([monthNames] and the following) feed the date picker that the
/// browser runs.
abstract class MaterialLocalizations {
  /// The texts of one language.
  const MaterialLocalizations();

  /// The localized texts of [context]: the app's delegate, else the page's
  /// (or the request's) locale with the built-in English and Spanish, else
  /// English.
  static MaterialLocalizations of(BuildContext context) =>
      _resolve(context, MaterialLocalizations, _materialFor);

  /// The texts the app's delegates loaded, or `null` without one.
  static MaterialLocalizations? maybeOf(BuildContext context) =>
      Localizations.of<MaterialLocalizations>(context, MaterialLocalizations);

  /// Loads English and Spanish; any other locale answers in English (see
  /// `GlobalMaterialLocalizations` for every locale).
  static const LocalizationsDelegate<MaterialLocalizations> delegate =
      _Delegate<MaterialLocalizations>(_materialFor);

  /// The tooltip of the button that opens the navigation drawer.
  String get openAppDrawerTooltip;

  /// The tooltip of a back button.
  String get backButtonTooltip;

  /// The tooltip of a close button.
  String get closeButtonTooltip;

  /// The label of a close button.
  String get closeButtonLabel;

  /// The tooltip of a delete button (a chip's).
  String get deleteButtonTooltip;

  /// The tooltip of a button that opens a menu (`PopupMenuButton`).
  String get showMenuTooltip;

  /// The tooltip of a "more" button.
  String get moreButtonTooltip;

  /// The label of a search field.
  String get searchFieldLabel;

  /// The tooltip of the previous-page button.
  String get previousPageTooltip;

  /// The tooltip of the next-page button.
  String get nextPageTooltip;

  /// The label of a confirmation button.
  String get okButtonLabel;

  /// The label of a cancel button.
  String get cancelButtonLabel;

  /// The accessible name of the barrier behind a modal, which dismisses it.
  String get modalBarrierDismissLabel;

  /// The title of a date picker.
  String get datePickerHelpText;

  /// The tooltip of the date picker's previous-month button.
  String get previousMonthTooltip;

  /// The tooltip of the date picker's next-month button.
  String get nextMonthTooltip;

  /// The label of a date text field.
  String get dateInputLabel;

  /// The label of the button that switches a date field to the calendar.
  String get calendarModeButtonLabel;

  /// The label of the button that switches the calendar to the text field.
  String get inputDateModeButtonLabel;

  /// The accessible name of the year selector.
  String get selectYearSemanticsLabel;

  /// The title of a time picker.
  String get timePickerInputHelpText;

  /// `2026`.
  String formatYear(DateTime date);

  /// `September 2026` (en), `septiembre de 2026` (es).
  String formatMonthYear(DateTime date);

  /// `Fri, Sep 25` (en), `vie, 25 sept` (es).
  String formatMediumDate(DateTime date);

  /// `Friday, September 25, 2026`.
  String formatFullDate(DateTime date);

  /// `Sep 25`.
  String formatShortMonthDay(DateTime date);

  /// `Sep 25, 2026`.
  String formatShortDate(DateTime date);

  /// One letter per weekday, Sunday first (`S M T W T F S`).
  List<String> get narrowWeekdays;

  /// The first day of the week: 0 is Sunday, 1 Monday… 6 Saturday (the
  /// index of [narrowWeekdays]).
  int get firstDayOfWeekIndex;

  /// Flutter's `formatDecimal`: [number] written with the digits of the
  /// locale (`12` → `١٢` in Arabic).
  // web: no digit grouping (Flutter writes `1,234`): the calendar only
  // formats days and years, and grouping would need intl's NumberFormat.
  String formatDecimal(int number) {
    final d = digits.runes.toList();
    if (d.length != 10) return '$number';
    return String.fromCharCodes([
      for (final c in '$number'.codeUnits)
        c >= 0x30 && c <= 0x39 ? d[c - 0x30] : c,
    ]);
  }

  /// `// web:` the ten digits of the locale, zero first: the browser writes
  /// the date picker's numbers with them (`0123456789` by default).
  String get digits => '0123456789';

  /// `// web:` the 12 month names, January first.
  List<String> get monthNames;

  /// `// web:` the 12 short month names.
  List<String> get shortMonthNames;

  /// `// web:` the 7 weekday names, Sunday first.
  List<String> get weekdayNames;

  /// `// web:` the 7 short weekday names, Sunday first.
  List<String> get shortWeekdayNames;

  /// `// web:` how the browser writes a month and year: `{M}` is the month
  /// name of [monthNames], `{y}` the year (`{M} {y}`, `{M} de {y}`).
  String get monthYearPattern;

  /// `// web:` how the browser writes a medium date: `{w}` the short
  /// weekday, `{m}` the short month, `{d}` the day (`{w}, {m} {d}`).
  String get mediumDatePattern;
}

MaterialLocalizations _materialFor(Locale locale) => _cached(
  locale,
  () => switch (locale.languageCode) {
    'es' => const MaterialLocalizationsEs(),
    _ => const DefaultMaterialLocalizations(),
  },
);

/// The English strings of [MaterialLocalizations]; `GlobalMaterialLocalizations`
/// (CLDR dates for any locale) and [DefaultMaterialLocalizations] share them.
@internal
mixin MaterialStringsEn on MaterialLocalizations {
  @override
  String get openAppDrawerTooltip => 'Open navigation menu';
  @override
  String get backButtonTooltip => 'Back';
  @override
  String get closeButtonTooltip => 'Close';
  @override
  String get closeButtonLabel => 'Close';
  @override
  String get deleteButtonTooltip => 'Delete';
  @override
  String get showMenuTooltip => 'Show menu';
  @override
  String get moreButtonTooltip => 'More';
  @override
  String get searchFieldLabel => 'Search';
  @override
  String get previousPageTooltip => 'Previous page';
  @override
  String get nextPageTooltip => 'Next page';
  @override
  String get okButtonLabel => 'OK';
  @override
  String get cancelButtonLabel => 'Cancel';
  @override
  String get modalBarrierDismissLabel => 'Dismiss';
  @override
  String get datePickerHelpText => 'Select date';
  @override
  String get previousMonthTooltip => 'Previous month';
  @override
  String get nextMonthTooltip => 'Next month';
  @override
  String get dateInputLabel => 'Enter Date';
  @override
  String get calendarModeButtonLabel => 'Switch to calendar';
  @override
  String get inputDateModeButtonLabel => 'Switch to input';
  @override
  String get selectYearSemanticsLabel => 'Select year';
  @override
  String get timePickerInputHelpText => 'Enter time';
}

/// The Spanish strings of [MaterialLocalizations].
@internal
mixin MaterialStringsEs on MaterialLocalizations {
  @override
  String get openAppDrawerTooltip => 'Abrir menú de navegación';
  @override
  String get backButtonTooltip => 'Atrás';
  @override
  String get closeButtonTooltip => 'Cerrar';
  @override
  String get closeButtonLabel => 'Cerrar';
  @override
  String get deleteButtonTooltip => 'Eliminar';
  @override
  String get showMenuTooltip => 'Mostrar menú';
  @override
  String get moreButtonTooltip => 'Más';
  @override
  String get searchFieldLabel => 'Buscar';
  @override
  String get previousPageTooltip => 'Página anterior';
  @override
  String get nextPageTooltip => 'Página siguiente';
  @override
  String get okButtonLabel => 'Aceptar';
  @override
  String get cancelButtonLabel => 'Cancelar';
  @override
  String get modalBarrierDismissLabel => 'Cerrar';
  @override
  String get datePickerHelpText => 'Seleccionar fecha';
  @override
  String get previousMonthTooltip => 'Mes anterior';
  @override
  String get nextMonthTooltip => 'Mes siguiente';
  @override
  String get dateInputLabel => 'Introducir fecha';
  @override
  String get calendarModeButtonLabel => 'Cambiar a calendario';
  @override
  String get inputDateModeButtonLabel => 'Cambiar a entrada';
  @override
  String get selectYearSemanticsLabel => 'Seleccionar año';
  @override
  String get timePickerInputHelpText => 'Introducir hora';
}

/// Dates written from a table of names: what a language that `thor_ui` ships
/// needs, without the CLDR data of `package:intl`.
class _DateTable {
  const _DateTable({
    required this.months,
    required this.shortMonths,
    required this.weekdays,
    required this.shortWeekdays,
    required this.narrowWeekdays,
    required this.firstDayOfWeek,
    required this.monthYear,
    required this.mediumDate,
    required this.fullDate,
    required this.shortMonthDay,
    required this.shortDate,
  });

  final List<String> months, shortMonths, weekdays, shortWeekdays;
  final List<String> narrowWeekdays;
  final int firstDayOfWeek;
  final String monthYear, mediumDate, fullDate, shortMonthDay, shortDate;
}

const _enDates = _DateTable(
  months: [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', //
    'August', 'September', 'October', 'November', 'December',
  ],
  shortMonths: [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', //
    'Oct', 'Nov', 'Dec',
  ],
  weekdays: [
    'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', //
    'Saturday',
  ],
  shortWeekdays: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
  narrowWeekdays: ['S', 'M', 'T', 'W', 'T', 'F', 'S'],
  firstDayOfWeek: 0,
  monthYear: '{M} {y}',
  mediumDate: '{w}, {m} {d}',
  fullDate: '{W}, {M} {d}, {y}',
  shortMonthDay: '{m} {d}',
  shortDate: '{m} {d}, {y}',
);

const _esDates = _DateTable(
  months: [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', //
    'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ],
  shortMonths: [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', //
    'oct', 'nov', 'dic',
  ],
  weekdays: [
    'domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', //
    'sábado',
  ],
  shortWeekdays: ['dom', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb'],
  narrowWeekdays: ['D', 'L', 'M', 'X', 'J', 'V', 'S'],
  firstDayOfWeek: 1,
  monthYear: '{M} de {y}',
  mediumDate: '{w}, {d} {m}',
  fullDate: '{W}, {d} de {M} de {y}',
  shortMonthDay: '{d} {m}',
  shortDate: '{d} {m} {y}',
);

/// The date members of a language from its [_DateTable].
mixin _TableDates on MaterialLocalizations {
  _DateTable get _table;

  String _fill(String pattern, DateTime d) => pattern
      .replaceAll('{M}', _table.months[d.month - 1])
      .replaceAll('{m}', _table.shortMonths[d.month - 1])
      .replaceAll('{W}', _table.weekdays[d.weekday % 7])
      .replaceAll('{w}', _table.shortWeekdays[d.weekday % 7])
      .replaceAll('{d}', '${d.day}')
      .replaceAll('{y}', '${d.year}');

  @override
  String formatYear(DateTime date) => '${date.year}';
  @override
  String formatMonthYear(DateTime date) => _fill(_table.monthYear, date);
  @override
  String formatMediumDate(DateTime date) => _fill(_table.mediumDate, date);
  @override
  String formatFullDate(DateTime date) => _fill(_table.fullDate, date);
  @override
  String formatShortMonthDay(DateTime date) =>
      _fill(_table.shortMonthDay, date);
  @override
  String formatShortDate(DateTime date) => _fill(_table.shortDate, date);
  @override
  List<String> get narrowWeekdays => _table.narrowWeekdays;
  @override
  int get firstDayOfWeekIndex => _table.firstDayOfWeek;
  @override
  List<String> get monthNames => _table.months;
  @override
  List<String> get shortMonthNames => _table.shortMonths;
  @override
  List<String> get weekdayNames => _table.weekdays;
  @override
  List<String> get shortWeekdayNames => _table.shortWeekdays;
  @override
  String get monthYearPattern => _table.monthYear;
  @override
  String get mediumDatePattern => _table.mediumDate;
}

/// English [MaterialLocalizations] (Flutter's `DefaultMaterialLocalizations`):
/// the fallback of every locale `thor_ui` has no texts for.
class DefaultMaterialLocalizations extends MaterialLocalizations
    with MaterialStringsEn, _TableDates {
  /// The English texts and dates.
  const DefaultMaterialLocalizations();

  @override
  _DateTable get _table => _enDates;
}

/// Spanish [MaterialLocalizations].
class MaterialLocalizationsEs extends MaterialLocalizations
    with MaterialStringsEs, _TableDates {
  /// The Spanish texts and dates.
  const MaterialLocalizationsEs();

  @override
  _DateTable get _table => _esDates;
}

// ---------------------------------------------------------------------------
// ThorLocalizations
// ---------------------------------------------------------------------------

/// The texts thor's widgets write that Flutter's localizations don't have:
/// the theme switch, the carousel, pagination, drag and reorder
/// announcements, autocomplete results, the upload progress, the language
/// switcher, the default error pages and the messages of form validation.
///
/// ```dart
/// final l10n = ThorLocalizations.of(context);
/// l10n.autocompleteResults(3);   // 3 results
/// ```
///
/// `ThorApp` loads it (English and Spanish; another language answers in
/// English) unless the app's `localizationsDelegates` has its own. A widget's
/// parameter (`previousLabel:`, `labels:`…) always wins. Another language is
/// a subclass registered through its own [LocalizationsDelegate]
/// (`ThorLocalizations`' type).
abstract class ThorLocalizations {
  /// The texts of one language.
  const ThorLocalizations();

  /// The localized texts of [context] (see [MaterialLocalizations.of]).
  static ThorLocalizations of(BuildContext context) =>
      _resolve(context, ThorLocalizations, forLocale);

  /// The texts the app's delegates loaded, or `null` without one.
  static ThorLocalizations? maybeOf(BuildContext context) =>
      Localizations.of<ThorLocalizations>(context, ThorLocalizations);

  /// The built-in texts of [locale]: Spanish for `es`, English otherwise.
  /// For code that has no [BuildContext] (a form's validation reads the
  /// request's locale).
  static ThorLocalizations forLocale(Locale? locale) =>
      switch (locale?.languageCode) {
        'es' => const ThorLocalizationsEs(),
        _ => const ThorLocalizationsEn(),
      };

  /// Loads English and Spanish; any other locale answers in English.
  static const LocalizationsDelegate<ThorLocalizations> delegate =
      _Delegate<ThorLocalizations>(forLocale);

  /// The three delegates `ThorApp` adds when the app has none for their
  /// type: Material, Widgets and Thor.
  static const List<LocalizationsDelegate<Object?>> delegates = [
    MaterialLocalizations.delegate,
    WidgetsLocalizations.delegate,
    ThorLocalizations.delegate,
  ];

  /// The name of the theme switch (a hidden checkbox).
  String get themeToggleLabel;

  /// The button of a scaffold's end drawer.
  String get openSecondaryMenuTooltip;

  /// The text of the skip link a `Scaffold` starts with (the first Tab
  /// stop, to its `<main>`).
  String get skipToContent;

  /// The `aria-roledescription` of a carousel.
  String get carouselRoleDescription;

  /// The carousel's previous button.
  String get carouselPrevious;

  /// The carousel's next button.
  String get carouselNext;

  /// A carousel slide's name is `"$carouselSlide 2 $carouselOf 5"`.
  String get carouselSlide;

  /// The "of" of a slide's name (`Slide 2 of 5`).
  String get carouselOf;

  /// The landmark of the pagination.
  String get paginationLabel;

  /// The pagination's link to the previous page.
  String get paginationPrevious;

  /// The pagination's link to the next page.
  String get paginationNext;

  /// A page link's name is `"$paginationPage 3"`.
  String get paginationPage;

  /// The name of a reorder handle; `{item}` is the item's name.
  String get reorderHandleLabel;

  /// The `aria-roledescription` of a reorder handle.
  String get reorderHandleRoleDescription;

  /// Said when the keyboard picks a list item up (`{item}`, `{position}`,
  /// `{count}`).
  String get reorderPickedUp;

  /// Said when an arrow key moves the picked-up item.
  String get reorderMoved;

  /// Said when the item is dropped.
  String get reorderDropped;

  /// Said when Escape puts the item back.
  String get reorderCancelled;

  /// The `aria-roledescription` of a draggable.
  String get dragRoleDescription;

  /// Said when the keyboard picks a draggable up (`{item}`).
  String get dragPickedUp;

  /// Said when the keyboard reaches a target that takes the draggable
  /// (`{target}`).
  String get dragOver;

  /// Said when the target does not take it.
  String get dragCannotDrop;

  /// Said when it is dropped (`{item}`, `{target}`).
  String get dragDropped;

  /// Said when Escape cancels (`{item}`).
  String get dragCancelled;

  /// What an autocomplete announces for several options; `{count}` is their
  /// number.
  String get autocompleteResultsOther;

  /// What an autocomplete announces for exactly one option.
  String get autocompleteResultsOne;

  /// What an autocomplete announces when the text leaves no option.
  String get autocompleteNoResults;

  /// The announcement for [count] options: none, one, or [count] of them
  /// (the plural rules of English and Spanish; a language with more forms
  /// overrides it, as `thor_ui` itself stays free of `package:intl`).
  String autocompleteResults(int count) => switch (count) {
    0 => autocompleteNoResults,
    1 => autocompleteResultsOne,
    _ => autocompleteResultsOther.replaceAll('{count}', '$count'),
  };

  /// The accessible name of a progress bar of an upload.
  String get uploadProgressLabel;

  /// The name of the language switcher's navigation.
  String get languageSwitcherLabel;

  /// What a date field says when no date is picked.
  String get noDateSelectedLabel;

  /// The title of the default 404 page.
  String get notFoundTitle;

  /// The title of the default error page for a [status].
  String errorPageTitle(int status);

  /// Form validation: a field of whole numbers got something else.
  String get formEnterWholeNumber;

  /// Form validation: a field of numbers got something else.
  String get formEnterNumber;

  /// Form validation: a date field got something else.
  String get formEnterValidDate;

  /// Form validation: a choice field got a value outside its options.
  String get formChooseOption;

  /// Form validation: a list field has fewer than [min] entries.
  String formAddAtLeast(int min);

  /// Form validation: a list field has more than [max] entries.
  String formAddAtMost(int max);
}

/// English [ThorLocalizations].
class ThorLocalizationsEn extends ThorLocalizations {
  /// The English texts.
  const ThorLocalizationsEn();

  @override
  String get themeToggleLabel => 'Switch light/dark theme';
  @override
  String get openSecondaryMenuTooltip => 'Open secondary menu';
  @override
  String get skipToContent => 'Skip to content';
  @override
  String get carouselRoleDescription => 'carousel';
  @override
  String get carouselPrevious => 'Previous';
  @override
  String get carouselNext => 'Next';
  @override
  String get carouselSlide => 'Slide';
  @override
  String get carouselOf => 'of';
  @override
  String get paginationLabel => 'Pagination';
  @override
  String get paginationPrevious => 'Previous';
  @override
  String get paginationNext => 'Next';
  @override
  String get paginationPage => 'Page';
  @override
  String get reorderHandleLabel => 'Reorder {item}';
  @override
  String get reorderHandleRoleDescription => 'drag handle';
  @override
  String get reorderPickedUp =>
      'Picked up {item}, position {position} of {count}. Use the arrow '
      'keys to move it, Space to drop it, Escape to cancel.';
  @override
  String get reorderMoved => '{item}, position {position} of {count}.';
  @override
  String get reorderDropped =>
      'Dropped {item} at position {position} of {count}.';
  @override
  String get reorderCancelled =>
      'Cancelled. {item} is back at position {position} of {count}.';
  @override
  String get dragRoleDescription => 'draggable';
  @override
  String get dragPickedUp =>
      'Picked up {item}. Use the arrow keys to choose where to drop it, '
      'Space to drop it, Escape to cancel.';
  @override
  String get dragOver => '{target}: it can be dropped here.';
  @override
  String get dragCannotDrop => '{target}: it cannot be dropped here.';
  @override
  String get dragDropped => 'Dropped {item} on {target}.';
  @override
  String get dragCancelled => 'Cancelled. {item} was not moved.';
  @override
  String get autocompleteResultsOther => '{count} results';
  @override
  String get autocompleteResultsOne => '1 result';
  @override
  String get autocompleteNoResults => 'No results';
  @override
  String get uploadProgressLabel => 'Upload progress';
  @override
  String get languageSwitcherLabel => 'Language';
  @override
  String get noDateSelectedLabel => 'Date';
  @override
  String get notFoundTitle => 'Not found';
  @override
  String errorPageTitle(int status) => 'Error $status';
  @override
  String get formEnterWholeNumber => 'Enter a whole number.';
  @override
  String get formEnterNumber => 'Enter a number.';
  @override
  String get formEnterValidDate => 'Enter a valid date.';
  @override
  String get formChooseOption => 'Choose one of the options.';
  @override
  String formAddAtLeast(int min) => 'Add at least $min.';
  @override
  String formAddAtMost(int max) => 'Add at most $max.';
}

/// Spanish [ThorLocalizations].
class ThorLocalizationsEs extends ThorLocalizations {
  /// The Spanish texts.
  const ThorLocalizationsEs();

  @override
  String get themeToggleLabel => 'Cambiar entre tema claro y oscuro';
  @override
  String get openSecondaryMenuTooltip => 'Abrir menú secundario';
  @override
  String get skipToContent => 'Saltar al contenido';
  @override
  String get carouselRoleDescription => 'carrusel';
  @override
  String get carouselPrevious => 'Anterior';
  @override
  String get carouselNext => 'Siguiente';
  @override
  String get carouselSlide => 'Diapositiva';
  @override
  String get carouselOf => 'de';
  @override
  String get paginationLabel => 'Paginación';
  @override
  String get paginationPrevious => 'Anterior';
  @override
  String get paginationNext => 'Siguiente';
  @override
  String get paginationPage => 'Página';
  @override
  String get reorderHandleLabel => 'Reordenar {item}';
  @override
  String get reorderHandleRoleDescription => 'control de arrastre';
  @override
  String get reorderPickedUp =>
      '{item} recogido, posición {position} de {count}. Usa las flechas '
      'para moverlo, Espacio para soltarlo, Escape para cancelar.';
  @override
  String get reorderMoved => '{item}, posición {position} de {count}.';
  @override
  String get reorderDropped =>
      '{item} soltado en la posición {position} de {count}.';
  @override
  String get reorderCancelled =>
      'Cancelado. {item} vuelve a la posición {position} de {count}.';
  @override
  String get dragRoleDescription => 'arrastrable';
  @override
  String get dragPickedUp =>
      '{item} recogido. Usa las flechas para elegir dónde soltarlo, '
      'Espacio para soltarlo, Escape para cancelar.';
  @override
  String get dragOver => '{target}: se puede soltar aquí.';
  @override
  String get dragCannotDrop => '{target}: no se puede soltar aquí.';
  @override
  String get dragDropped => '{item} soltado en {target}.';
  @override
  String get dragCancelled => 'Cancelado. {item} no se movió.';
  @override
  String get autocompleteResultsOther => '{count} resultados';
  @override
  String get autocompleteResultsOne => '1 resultado';
  @override
  String get autocompleteNoResults => 'Sin resultados';
  @override
  String get uploadProgressLabel => 'Progreso de la subida';
  @override
  String get languageSwitcherLabel => 'Idioma';
  @override
  String get noDateSelectedLabel => 'Fecha';
  @override
  String get notFoundTitle => 'Página no encontrada';
  @override
  String errorPageTitle(int status) => 'Error $status';
  @override
  String get formEnterWholeNumber => 'Introduce un número entero.';
  @override
  String get formEnterNumber => 'Introduce un número.';
  @override
  String get formEnterValidDate => 'Introduce una fecha válida.';
  @override
  String get formChooseOption => 'Elige una de las opciones.';
  @override
  String formAddAtLeast(int min) => 'Añade al menos $min.';
  @override
  String formAddAtMost(int max) => 'Añade como máximo $max.';
}
