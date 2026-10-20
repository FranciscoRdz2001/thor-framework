// GENERATED CODE - DO NOT MODIFY BY HAND (thor_builder).
// The messages of lib/l10n/*.arb (template: app_es.arb).
// ignore_for_file: type=lint

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
  AppLocalizations(String locale) : localeName = locale;

  /// The locale these messages are in.
  final String localeName;

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
  static const List<Locale> supportedLocales = [Locale('es'), Locale('en')];

  /// Name of the app, in the bar and the page titles.
  ///
  /// In the template: `Recetas`
  String get recipes;

  /// In the template: `Recetas de thor`
  String get homeTitle;

  /// In the template: `Inicio`
  String get homeMeta;

  /// In the template: `Pantallas comunes escritas como se escriben en thor. Cada una es un archivo en lib/routes/ y tiene su test.`
  String get homeDescription;

  /// In the template: `Usa el menú para verlas.`
  String get homeHint;

  /// In the template: `Menú`
  String get menu;

  /// In the template: `Navegación`
  String get navigation;

  /// In the template: `Idioma`
  String get language;
}

/// The messages in `es` (app_es.arb).
class AppLocalizationsEs extends AppLocalizations {
  /// Messages in [locale].
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get recipes => 'Recetas';

  @override
  String get homeTitle => 'Recetas de thor';

  @override
  String get homeMeta => 'Inicio';

  @override
  String get homeDescription =>
      'Pantallas comunes escritas como se escriben en thor. Cada una es un archivo en lib/routes/ y tiene su test.';

  @override
  String get homeHint => 'Usa el menú para verlas.';

  @override
  String get menu => 'Menú';

  @override
  String get navigation => 'Navegación';

  @override
  String get language => 'Idioma';
}

/// The messages in `en` (app_en.arb).
class AppLocalizationsEn extends AppLocalizations {
  /// Messages in [locale].
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get recipes => 'Recipes';

  @override
  String get homeTitle => 'thor recipes';

  @override
  String get homeMeta => 'Home';

  @override
  String get homeDescription =>
      'Common screens written the way they are written in thor. Each one is a file in lib/routes/ and has its test.';

  @override
  String get homeHint => 'Use the menu to see them.';

  @override
  String get menu => 'Menu';

  @override
  String get navigation => 'Navigation';

  @override
  String get language => 'Language';
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
    case 'es':
      return AppLocalizationsEs();
    case 'en':
      return AppLocalizationsEn();
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
      const {'es', 'en'}.contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
