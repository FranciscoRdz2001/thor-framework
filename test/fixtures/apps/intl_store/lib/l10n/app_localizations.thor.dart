// GENERATED CODE - DO NOT MODIFY BY HAND (thor_builder).
// The messages of lib/l10n/*.arb (template: app_en.arb).
// ignore_for_file: type=lint

import 'package:intl/date_symbol_data_local.dart' as intl_dates;
import 'package:intl/intl.dart' as intl;
import 'package:thor_ui/thor_ui.dart';

/// The app's messages, one subclass per locale of `lib/l10n/`.
///
/// ```dart
/// ThorApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   child: …,
/// )
/// AppLocalizations.of(context).someMessage
/// ```
abstract class AppLocalizations {
  /// Messages in [locale] (`es`, `pt_BR`).
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale);

  /// The locale these messages are in.
  final String localeName;

  static bool _datesReady = false;

  /// Loads intl's date symbols, on the first date formatted: only
  /// the messages with a date carry them (and the browser, only
  /// if it calls one).
  static void initDates() {
    if (_datesReady) return;
    // Synchronous: the data is in the program.
    intl_dates.initializeDateFormatting();
    _datesReady = true;
  }

  /// The messages of the nearest `Localizations` (`ThorApp`).
  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  /// Loads these messages for `Localizations`.
  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// For `ThorApp(localizationsDelegates:)`.
  static const List<LocalizationsDelegate<Object?>> localizationsDelegates = [
    delegate,
  ];

  /// The locales of `lib/l10n/`, the template's first.
  static const List<Locale> supportedLocales = [Locale('en'), Locale('es')];

  /// Name of the shop, in the header and the <title>.
  ///
  /// In the template: `Corner shop`
  String get storeTitle;

  /// In the template: `Small things, carefully chosen.`
  String get tagline;

  /// Greets the visitor by the name in ?name=.
  ///
  /// In the template: `Welcome, {name}!`
  String welcome(String name);

  /// A product price, in euros.
  ///
  /// In the template: `{amount}`
  String price(double amount);

  /// In the template: `{count, plural, =0{Sold out} =1{Last one!} other{{count} in stock}}`
  String stock(int count);

  /// Cart summary; computed in the browser as the count changes.
  ///
  /// In the template: `{count, plural, =0{Your cart is empty} one{# item in your cart} other{# items in your cart}}`
  String cartItems(int count);

  /// In the template: `Add to cart`
  String get addToCart;

  /// In the template: `Empty cart`
  String get emptyCart;

  /// In the template: `Details`
  String get details;

  /// In the template: `In the shop since {date}`
  String since(DateTime date);

  /// In the template: `Back to the shop`
  String get back;

  /// In the template: `Language`
  String get language;

  /// In the template: `This page doesn't exist.`
  String get notFound;
}

/// The messages in `en` (app_en.arb).
class AppLocalizationsEn extends AppLocalizations {
  /// Messages in [locale].
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get storeTitle => 'Corner shop';

  @override
  String get tagline => 'Small things, carefully chosen.';

  @override
  String welcome(String name) => 'Welcome, ${name}!';

  @override
  String price(double amount) {
    final amountString = intl.NumberFormat.simpleCurrency(
      locale: localeName,
      name: 'EUR',
    ).format(amount);
    return '${amountString}';
  }

  @override
  String stock(int count) => (count == 0
      ? 'Sold out'
      : count == 1
      ? 'Last one!'
      : '${count} in stock');

  @override
  String cartItems(int count) => (count == 0
      ? 'Your cart is empty'
      : intl.Intl.pluralLogic(
          count,
          locale: localeName,
          one: '${count} item in your cart',
          other: '${count} items in your cart',
          useExplicitNumberCases: false,
        ));

  @override
  String get addToCart => 'Add to cart';

  @override
  String get emptyCart => 'Empty cart';

  @override
  String get details => 'Details';

  @override
  String since(DateTime date) {
    AppLocalizations.initDates();
    final dateString = intl.DateFormat.yMMMd(localeName).format(date);
    return 'In the shop since ${dateString}';
  }

  @override
  String get back => 'Back to the shop';

  @override
  String get language => 'Language';

  @override
  String get notFound => 'This page doesn\'t exist.';
}

/// The messages in `es` (app_es.arb).
class AppLocalizationsEs extends AppLocalizations {
  /// Messages in [locale].
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get storeTitle => 'La tiendita';

  @override
  String get tagline => 'Cosas pequeñas, elegidas con cuidado.';

  @override
  String welcome(String name) => '¡Hola, ${name}!';

  @override
  String price(double amount) {
    final amountString = intl.NumberFormat.simpleCurrency(
      locale: localeName,
      name: 'EUR',
    ).format(amount);
    return '${amountString}';
  }

  @override
  String stock(int count) => (count == 0
      ? 'Agotado'
      : count == 1
      ? '¡Queda uno!'
      : 'Quedan ${count}');

  @override
  String cartItems(int count) => (count == 0
      ? 'Tu carrito está vacío'
      : intl.Intl.pluralLogic(
          count,
          locale: localeName,
          one: '${count} artículo en tu carrito',
          other: '${count} artículos en tu carrito',
          useExplicitNumberCases: false,
        ));

  @override
  String get addToCart => 'Agregar al carrito';

  @override
  String get emptyCart => 'Vaciar el carrito';

  @override
  String get details => 'Detalles';

  @override
  String since(DateTime date) {
    AppLocalizations.initDates();
    final dateString = intl.DateFormat.yMMMd(localeName).format(date);
    return 'En la tienda desde el ${dateString}';
  }

  @override
  String get back => 'Volver a la tienda';

  @override
  String get language => 'Idioma';

  @override
  String get notFound => 'Esta página no existe.';
}

/// The messages for [locale]: its region's, else its language's.
/// Throws for a language the app lacks (see `AppLocalizations.supportedLocales`).
AppLocalizations lookupAppLocalizations(Locale locale) {
  final region = [
    locale.languageCode,
    ?locale.scriptCode,
    ?locale.countryCode,
  ].join('_');
  switch (region) {}
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }
  throw UnsupportedError(
    'AppLocalizations has no messages for $locale: add lib/l10n/ ARB files or '
    'resolve against AppLocalizations.supportedLocales',
  );
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));

  @override
  bool isSupported(Locale locale) =>
      const {'en', 'es'}.contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
