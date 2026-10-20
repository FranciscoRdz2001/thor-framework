/// The site's languages: which one is the default, how a path gets its
/// locale prefix and how the page that is being rendered finds its
/// messages. The messages themselves are the ARB files of `lib/l10n/`.
library;

import 'package:thor_ui/router.dart'
    show LocaleSwitcher, PageRequest, RequestScope;
import 'package:thor_ui/thor_ui.dart';

import '../../l10n/app_localizations.thor.dart';
import '../content/library.dart' show routePathIn;

export '../../l10n/app_localizations.thor.dart' show AppLocalizations;

/// The site's language: where `/` sends a reader whose browser asks for no
/// language the site has, `x-default`, and what a page falls back to when
/// its language has no file for it.
const defaultLocale = 'en';

/// The language of the files of `docs/` that have no language folder: the
/// generated API reference (`docs/api/thor_ui.md`) and the error pages
/// (`docs/errores/THOR-*.md`) are written in it, and a translation lives in
/// `<locale>/` next to them (`docs/errores/en/`). The guide has a folder per
/// language (`docs/guia/<locale>/`), and the template ARB is this one's.
const sourceLocale = 'es';

/// The site's languages (one ARB file each in `lib/l10n/`), as tags.
List<String> get docsLocales => [
  for (final locale in AppLocalizations.supportedLocales)
    locale.toLanguageTag(),
];

/// [path] (the route's own: `/empezar/instalacion`) under [locale], as that
/// language spells it (`/es/empezar/instalacion`,
/// `/en/get-started/installation`: see `routePathIn`). A URL with a scheme
/// (`https://…`), a path that already has a locale and the files at the
/// site's root (`llms.txt`) stay as they are.
String localizePath(String locale, String path) {
  if (!path.startsWith('/') || path.startsWith('//')) return path;
  final first = path.split(RegExp('[/?#]'))[1];
  if (docsLocales.contains(first) || _rootFiles.contains(first)) return path;
  return path == '/' ? '/$locale' : '/$locale${routePathIn(locale, path)}';
}

const _rootFiles = {'llms.txt', 'llms-full.txt', 'og.png', 'favicon.png'};

/// [html] with its links to pages of the site (`<a href="/api/thor_ui">`)
/// under [locale]: the markdown is rendered once and says where a page is;
/// each reader gets it in their language.
String localizeLinks(String locale, String html) => html.replaceAllMapped(
  RegExp(r'(<a\b[^>]*?\shref=")(/[^"]*)"'),
  (m) => '${m[1]}${localizePath(locale, m[2]!)}"',
);

/// The messages in [locale] (a tag of [docsLocales]; the default's when it
/// is not one).
AppLocalizations messagesFor(String? locale) {
  final tag = locale != null && docsLocales.contains(locale)
      ? locale
      : defaultLocale;
  return lookupAppLocalizations(Locale.tryParse(tag)!);
}

/// The messages of the language [request] is in, for what has no
/// `BuildContext` (a page's `meta`, its `load`).
AppLocalizations messagesOf(PageRequest request) =>
    messagesFor(request.locale?.toLanguageTag());

/// The tag of the language [request] is in (the default's when it has none):
/// what picks the files of `docs/` and `lib/l10n/`.
String localeTagOf(PageRequest request) =>
    request.locale?.toLanguageTag() ?? defaultLocale;

/// The name of the language [tag] (`es`) in that language.
String endonymOf(String tag) => LocaleSwitcher.endonym(Locale.tryParse(tag)!);

/// The site's messages and paths, from a widget.
extension DocsContext on BuildContext {
  /// The messages of the page's language (the default's for a widget drawn
  /// outside the app: an example rendered on its own).
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      messagesFor(defaultLocale);

  /// The language of the page, as a tag (`es`).
  String get docsLocale =>
      Localizations.maybeLocaleOf(this)?.toLanguageTag() ?? defaultLocale;

  /// [path] (the route's own: `/api/thor_ui`) in the page's language.
  String localized(String path) =>
      RequestScope.maybeOf(this)?.localizedPath(path) ?? path;
}
