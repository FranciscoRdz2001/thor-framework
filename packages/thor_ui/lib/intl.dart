/// Numbers, money and dates in the page's locale, with `package:intl`
/// (its CLDR data): what Flutter apps do with `NumberFormat` and
/// `DateFormat`, bound to `Localizations.localeOf(context)`.
///
/// ```dart
/// import 'package:thor_ui/intl.dart';
///
/// final f = LocaleFormat.of(context);
/// Text(f.currency(1234.5, name: 'EUR'));   // es: 1.234,50 €
/// Text(f.date(order.placedAt));             // es: 25 sept 2026
/// ```
///
/// For anything else, `package:intl` directly (`NumberFormat`,
/// `DateFormat` with `LocaleFormat.of(context).localeName`).
///
/// For widgets (the server). A `ThorState` that formats in the browser
/// would ship every locale's date data: pass it the formatted text, or
/// keep to the generated messages (plural rules only).
library;

import 'package:intl/date_symbol_data_local.dart' show initializeDateFormatting;
import 'package:intl/intl.dart';

import 'src/core/core.dart' show BuildContext;
import 'src/foundation/localizations.dart'
    show Locale, LocalizationsDelegate, Localizations, SynchronousFuture;
import 'src/foundation/material_localizations.dart'
    show
        MaterialLocalizations,
        MaterialStringsEn,
        MaterialStringsEs,
        ThorLocalizations,
        WidgetsLocalizations;

/// Formatting in one locale (a thin layer over `NumberFormat` and
/// `DateFormat`). A locale `intl` has no data for formats like its
/// language, else like English: never an exception in a page.
class LocaleFormat {
  /// Formats for [locale].
  LocaleFormat(Locale locale)
    : localeName = _verified(Intl.canonicalizedLocale(locale.toString()));

  /// Formats for the page's locale (`Localizations.localeOf`).
  factory LocaleFormat.of(BuildContext context) =>
      LocaleFormat(Localizations.localeOf(context));

  /// The `intl` locale name used (`es`, `pt_BR`).
  final String localeName;

  static bool _datesReady = false;

  static String _verified(String name) {
    if (!_datesReady) {
      // Synchronous despite the future: the data is in the program.
      initializeDateFormatting();
      _datesReady = true;
    }
    return Intl.verifiedLocale(
          name,
          (l) => NumberFormat.localeExists(l) && DateFormat.localeExists(l),
          onFailure: (_) => 'en',
        ) ??
        'en';
  }

  /// `1234.5` → `1,234.5` (en), `1.234,5` (es).
  String decimal(num value, {int? decimalDigits}) {
    final f = NumberFormat.decimalPattern(localeName);
    if (decimalDigits != null) {
      f
        ..minimumFractionDigits = decimalDigits
        ..maximumFractionDigits = decimalDigits;
    }
    return f.format(value);
  }

  /// `0.25` → `25%` (en), `25 %` (es).
  String percent(num value) =>
      NumberFormat.percentPattern(localeName).format(value);

  /// `1200000` → `1.2M` (en), `1,2 M` (es).
  String compact(num value) =>
      NumberFormat.compact(locale: localeName).format(value);

  /// Money: with [name] (ISO 4217, `EUR`) its symbol and digits
  /// (`1.234,50 €`); [symbol] and [decimalDigits] override.
  String currency(
    num value, {
    String? name,
    String? symbol,
    int? decimalDigits,
  }) =>
      (symbol == null && name != null
              ? NumberFormat.simpleCurrency(
                  locale: localeName,
                  name: name,
                  decimalDigits: decimalDigits,
                )
              : NumberFormat.currency(
                  locale: localeName,
                  name: name,
                  symbol: symbol,
                  decimalDigits: decimalDigits,
                ))
          .format(value);

  /// A date with a `DateFormat` [skeleton] (`yMMMd` by default: `Sep 25,
  /// 2026`, `25 sept 2026`).
  String date(
    DateTime value, [
    String skeleton = DateFormat.YEAR_ABBR_MONTH_DAY,
  ]) => DateFormat(skeleton, localeName).format(value);

  /// A time of day (`3:05 PM`, `15:05`).
  String time(DateTime value) => DateFormat.jm(localeName).format(value);
}

String _verifiedLocale(String name) => LocaleFormat._verified(name);

/// Flutter's `GlobalMaterialLocalizations`: [MaterialLocalizations] whose
/// dates, month and weekday names and first day of the week come from CLDR
/// (`package:intl`) for **any** locale, with the texts of English and
/// Spanish (another language keeps English texts until the app adds its own
/// delegate).
///
/// ```dart
/// import 'package:thor_ui/intl.dart';
///
/// ThorApp(
///   localizationsDelegates: [
///     AppLocalizations.delegate,
///     ...GlobalMaterialLocalizations.delegates,
///   ],
///   supportedLocales: AppLocalizations.supportedLocales,
///   child: …,
/// )
/// ```
///
/// Without it `ThorApp` loads the built-in [MaterialLocalizations] (English
/// and Spanish, no `intl` data in a production app that does not ask).
/// A locale `intl` has no data for formats like its language, else like
/// English: never an exception in a page.
abstract class GlobalMaterialLocalizations extends MaterialLocalizations {
  /// The CLDR dates of [locale].
  GlobalMaterialLocalizations(Locale locale)
    : localeName = _verifiedLocale(Intl.canonicalizedLocale(locale.toString()));

  /// The localizations for [locale]: Spanish texts for `es`, English
  /// otherwise, CLDR dates of [locale] in both.
  factory GlobalMaterialLocalizations.forLocale(Locale locale) =>
      switch (locale.languageCode) {
        'es' => _CldrEs(locale),
        _ => _CldrEn(locale),
      };

  /// Loads [GlobalMaterialLocalizations] for every locale.
  static const LocalizationsDelegate<MaterialLocalizations> delegate =
      _GlobalDelegate();

  /// What `ThorApp(localizationsDelegates:)` takes to get dates in every
  /// locale: [delegate] and the Widgets and Thor ones.
  static const List<LocalizationsDelegate<Object?>> delegates = [
    GlobalMaterialLocalizations.delegate,
    WidgetsLocalizations.delegate,
    ThorLocalizations.delegate,
  ];

  /// The `intl` locale name used (`fr`, `pt_BR`).
  final String localeName;

  static final _instances = <String, GlobalMaterialLocalizations>{};

  // Instances by locale: a page reads them once per request. Bounded.
  static GlobalMaterialLocalizations _of(Locale locale) {
    final key = locale.toString();
    final hit = _instances[key];
    if (hit != null) return hit;
    final made = GlobalMaterialLocalizations.forLocale(locale);
    if (_instances.length < 64) _instances[key] = made;
    return made;
  }

  // Seven dates, one per weekday (2001-03-04 was a Sunday), and twelve, one
  // per month.
  static final _week = [for (var i = 0; i < 7; i++) DateTime(2001, 3, 4 + i)];
  static final _year = [for (var i = 1; i <= 12; i++) DateTime(2001, i, 15)];

  List<String> _names(String pattern, List<DateTime> dates) {
    final f = DateFormat(pattern, localeName);
    return List.unmodifiable([for (final d in dates) f.format(d)]);
  }

  // The picker's patterns, to see whether the locale writes names in a date
  // (`MMMM`, `EEE`) or standalone (`LLLL`, `ccc`).
  late final String _monthYearIcu = DateFormat.yMMMM(localeName).pattern ?? '';
  late final String _mediumDateIcu = DateFormat.MMMEd(localeName).pattern ?? '';

  @override
  late final List<String> narrowWeekdays = _names('ccccc', _week);
  @override
  late final List<String> weekdayNames = _names('cccc', _week);
  @override
  late final List<String> shortWeekdayNames = _names(
    _mediumDateIcu.contains('c') ? 'ccc' : 'EEE',
    _week,
  );
  @override
  late final List<String> monthNames = _names(
    _monthYearIcu.contains('LLLL') ? 'LLLL' : 'MMMM',
    _year,
  );
  @override
  late final List<String> shortMonthNames = _names(
    _mediumDateIcu.contains('L') ? 'LLL' : 'MMM',
    _year,
  );

  @override
  late final String monthYearPattern =
      _template(_monthYearIcu, const {
        'LLLL': '{M}',
        'MMMM': '{M}',
        'y': '{y}',
      }) ??
      '{M} {y}';
  @override
  late final String mediumDatePattern =
      _template(_mediumDateIcu, const {
        'EEE': '{w}',
        'ccc': '{w}',
        'MMM': '{m}',
        'LLL': '{m}',
        'd': '{d}',
      }) ??
      '{w}, {m} {d}';

  // An ICU date pattern as a template of the page's picker: a run of
  // letters is replaced by its slot, quoted text is literal. `null` when a
  // letter has no slot (the picker then keeps its default order).
  static String? _template(String icu, Map<String, String> slots) {
    final out = StringBuffer();
    var i = 0;
    while (i < icu.length) {
      final c = icu[i];
      if (c == "'") {
        if (i + 1 < icu.length && icu[i + 1] == "'") {
          out.write("'");
          i += 2;
          continue;
        }
        final end = icu.indexOf("'", i + 1);
        if (end < 0) return null;
        out.write(icu.substring(i + 1, end));
        i = end + 1;
      } else if (RegExp('[A-Za-z]').hasMatch(c)) {
        var j = i;
        while (j < icu.length && icu[j] == c) {
          j++;
        }
        // `y` and `d` are any length; the names have their length.
        final slot = slots[icu.substring(i, j)] ?? slots[c];
        if (slot == null) return null;
        out.write(slot);
        i = j;
      } else {
        out.write(c);
        i++;
      }
    }
    return out.toString();
  }

  @override
  late final String digits = () {
    // `yyyy` is only digits: the last one of 2000 + i is the digit i.
    final f = DateFormat('yyyy', localeName);
    final out = [
      for (var i = 0; i < 10; i++) f.format(DateTime(2000 + i)).runes.last,
    ];
    return String.fromCharCodes(out);
  }();

  // `intl` counts the week from Monday (0); Flutter and thor from Sunday.
  @override
  late final int firstDayOfWeekIndex =
      (DateFormat(null, localeName).dateSymbols.FIRSTDAYOFWEEK + 1) % 7;

  @override
  String formatYear(DateTime date) => DateFormat.y(localeName).format(date);
  @override
  String formatMonthYear(DateTime date) =>
      DateFormat.yMMMM(localeName).format(date);
  @override
  String formatMediumDate(DateTime date) =>
      DateFormat.MMMEd(localeName).format(date);
  @override
  String formatFullDate(DateTime date) =>
      DateFormat.yMMMMEEEEd(localeName).format(date);
  @override
  String formatShortMonthDay(DateTime date) =>
      DateFormat.MMMd(localeName).format(date);
  @override
  String formatShortDate(DateTime date) =>
      DateFormat.yMMMd(localeName).format(date);
}

class _CldrEn extends GlobalMaterialLocalizations with MaterialStringsEn {
  _CldrEn(super.locale);
}

class _CldrEs extends GlobalMaterialLocalizations with MaterialStringsEs {
  _CldrEs(super.locale);
}

class _GlobalDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _GlobalDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture(GlobalMaterialLocalizations._of(locale));

  @override
  bool shouldReload(
    covariant LocalizationsDelegate<MaterialLocalizations> old,
  ) => false;
}
