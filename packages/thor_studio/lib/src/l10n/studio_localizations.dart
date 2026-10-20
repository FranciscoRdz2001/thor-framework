import 'package:thor_ui/thor_ui.dart';

/// Every string the studio's widgets write themselves, for the locale of the
/// page (Flutter's `MaterialLocalizations`): "Copy", "Previous", "Skip to
/// content", "On this page"…
///
/// ```dart
/// ThorApp(
///   localizationsDelegates: [StudioLocalizations.delegate, AppLocalizations.delegate],
///   supportedLocales: StudioLocalizations.supportedLocales,
///   theme: StudioTheme.light(),
///   child: StudioScaffold(body: …),
/// )
/// final l10n = StudioLocalizations.of(context); // l10n.copy, l10n.previous
/// ```
///
/// A widget's own parameter (`copyLabel:`, `skipLabel:`…) always wins; this
/// supplies what it leaves out. English and Spanish ship; another language is
/// a subclass registered through its own [LocalizationsDelegate].
///
/// `// web:` the delegate is optional. With no delegate in the app,
/// [StudioLocalizations.of] reads the page's locale and answers in Spanish
/// for `es` and in English otherwise, so a page that never asked for the
/// delegate still has labels in its own language.
abstract class StudioLocalizations {
  /// The strings of one language.
  const StudioLocalizations();

  /// Loads [StudioLocalizations] for `en` and `es`.
  static const LocalizationsDelegate<StudioLocalizations> delegate =
      _StudioLocalizationsDelegate();

  /// The languages the studio ships.
  static const supportedLocales = [Locale('en'), Locale('es')];

  /// The strings of the page's locale (see the class for the fallback).
  static StudioLocalizations of(BuildContext context) =>
      maybeOf(context) ?? _forLocale(Localizations.maybeLocaleOf(context));

  /// The strings the app's delegate loaded, or null without one.
  static StudioLocalizations? maybeOf(BuildContext context) =>
      Localizations.of<StudioLocalizations>(context, StudioLocalizations);

  static StudioLocalizations _forLocale(Locale? locale) =>
      locale?.languageCode == 'es'
      ? const StudioLocalizationsEs()
      : const StudioLocalizationsEn();

  /// The copy button of a code block.
  String get copy;

  /// The copy button after it copied.
  String get copied;

  /// The caption of the previous page's card.
  String get previous;

  /// The caption of the next page's card.
  String get next;

  /// The pager's landmark.
  String get pagination;

  /// The skip link: the first Tab stop.
  String get skipToContent;

  /// The top bar's button that opens the sidebar drawer.
  String get openNavigation;

  /// The drawer's close button.
  String get close;

  /// The sidebar's landmark and drawer.
  String get navigation;

  /// The top bar's links landmark.
  String get sections;

  /// The search pill's text.
  String get search;

  /// The table of contents' heading.
  String get onThisPage;

  /// The breadcrumb landmark.
  String get breadcrumb;

  /// The language menu's button.
  String get language;

  /// A heading's anchor link.
  String get linkToSection;

  /// A bench's Demo view.
  String get benchDemo;

  /// A bench's Code view.
  String get benchCode;

  /// A bench's view toggle.
  String get benchView;

  /// The Flutter side of a comparison.
  String get flutterLabel;

  /// The Thor side of a comparison.
  String get thorLabel;

  /// The theme choice's group name (`StudioThemeChoice`).
  String get themeChoice => 'Theme';

  /// The theme choice that follows the operating system.
  String get themeSystem => 'System';

  /// The theme choice for the light theme.
  String get themeLight => 'Light';

  /// The theme choice for the dark theme.
  String get themeDark => 'Dark';
}

/// English.
class StudioLocalizationsEn extends StudioLocalizations {
  /// The English strings.
  const StudioLocalizationsEn();

  @override
  String get copy => 'Copy';
  @override
  String get copied => 'Copied';
  @override
  String get previous => 'Previous';
  @override
  String get next => 'Next';
  @override
  String get pagination => 'Pages';
  @override
  String get skipToContent => 'Skip to content';
  @override
  String get openNavigation => 'Open navigation';
  @override
  String get close => 'Close';
  @override
  String get navigation => 'Documentation';
  @override
  String get sections => 'Sections';
  @override
  String get search => 'Search';
  @override
  String get onThisPage => 'On this page';
  @override
  String get breadcrumb => 'Breadcrumb';
  @override
  String get language => 'Language';
  @override
  String get linkToSection => 'Link to this section';
  @override
  String get benchDemo => 'Demo';
  @override
  String get benchCode => 'Code';
  @override
  String get benchView => 'View';
  @override
  String get flutterLabel => 'Flutter';
  @override
  String get thorLabel => 'Thor';
}

/// Spanish.
class StudioLocalizationsEs extends StudioLocalizations {
  /// The Spanish strings.
  const StudioLocalizationsEs();

  @override
  String get copy => 'Copiar';
  @override
  String get copied => 'Copiado';
  @override
  String get previous => 'Anterior';
  @override
  String get next => 'Siguiente';
  @override
  String get pagination => 'Páginas';
  @override
  String get skipToContent => 'Saltar al contenido';
  @override
  String get openNavigation => 'Abrir navegación';
  @override
  String get close => 'Cerrar';
  @override
  String get navigation => 'Documentación';
  @override
  String get sections => 'Secciones';
  @override
  String get search => 'Buscar';
  @override
  String get onThisPage => 'En esta página';
  @override
  String get breadcrumb => 'Ruta de navegación';
  @override
  String get language => 'Idioma';
  @override
  String get linkToSection => 'Enlace a esta sección';
  @override
  String get benchDemo => 'Demo';
  @override
  String get benchCode => 'Código';
  @override
  String get benchView => 'Vista';
  @override
  String get flutterLabel => 'Flutter';
  @override
  String get thorLabel => 'Thor';
  @override
  String get themeChoice => 'Tema';
  @override
  String get themeSystem => 'Sistema';
  @override
  String get themeLight => 'Claro';
  @override
  String get themeDark => 'Oscuro';
}

class _StudioLocalizationsDelegate
    extends LocalizationsDelegate<StudioLocalizations> {
  const _StudioLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'en' || locale.languageCode == 'es';

  @override
  Future<StudioLocalizations> load(Locale locale) =>
      SynchronousFuture<StudioLocalizations>(
        StudioLocalizations._forLocale(locale),
      );

  @override
  bool shouldReload(_StudioLocalizationsDelegate old) => false;
}
