import 'dart:io';

import 'package:thor_server/thor_server.dart' show Locale, LocaleRouting;

import '../core/content/library.dart';
import '../core/i18n/docs_locale.dart';
import '../modules/api/api_routes.dart' show apiIndexRoute;

/// How the site's URLs carry the language: always a prefix (`/es/…`), and
/// `/` goes to the reader's language. A `ThorApp` with a single language
/// leaves the URLs as they are; the docs keep the prefix from the first
/// language on, so adding another changes no address.
///
/// It also decides which languages a page advertises as `hreflang`
/// alternates: only the ones that really have the page (a guide with its own
/// file; a page served from the default language as a fallback is a
/// duplicate, not an alternate), and `x-default` is the root, the page that
/// picks a language.
class DocsLocaleRouting extends LocaleRouting {
  /// The routing; [baseUrl] (`https://docs.example.com`) makes the `hreflang`
  /// links absolute.
  DocsLocaleRouting({super.baseUrl})
    : super(
        supportedLocales: AppLocalizations.supportedLocales,
        defaultLocale: const Locale(defaultLocale),
      );

  /// A page's URL spells its path in its language
  /// (`/en/get-started/installation`); the router matches the route's own
  /// (`/empezar/instalacion`). A path the language doesn't spell is kept.
  @override
  ({Locale locale, String path, bool prefixed}) resolve(
    String path, {
    String? cookie,
    String? acceptLanguage,
  }) {
    final resolved = super.resolve(
      path,
      cookie: cookie,
      acceptLanguage: acceptLanguage,
    );
    if (!resolved.prefixed) return resolved;
    return (
      locale: resolved.locale,
      path: routePathOf(resolved.locale.toLanguageTag(), resolved.path),
      prefixed: true,
    );
  }

  /// [path] (the route's own) in [locale], spelled as that language spells
  /// it: every link, switcher and `hreflang` goes through here.
  @override
  String pathFor(Locale locale, String path) =>
      super.pathFor(locale, routePathIn(locale.toLanguageTag(), path));

  @override
  Map<String, String> alternates(String path) {
    final all = super.alternates(path);
    if (all.isEmpty) return all;
    final origin = (baseUrl ?? '').replaceFirst(RegExp(r'/$'), '');
    return {
      for (final MapEntry(:key, :value) in all.entries)
        if (key != 'x-default' && hasPage(key, path)) key: value,
      'x-default': '$origin/',
    };
  }

  /// The old addresses that redirect (`/guia/<slug>`, `/api`) answer in the
  /// visitor's language instead of first sending them to `/es/guia/<slug>`:
  /// one hop to the new page, not two.
  @override
  bool redirectsUnprefixed(String path, Locale visitorLocale) =>
      !(path.startsWith('/guia/') || path == apiIndexRoute.link()) &&
      super.redirectsUnprefixed(path, visitorLocale);

  /// Whether [locale] has its own version of the page at [path] (the
  /// route's own, without the language).
  static bool hasPage(String locale, String path) {
    final dir = docsDir();
    for (final guide in allGuides) {
      if (guide.path == path) {
        return File('$dir/${guide.file(locale)}').existsSync();
      }
    }
    if (locale == sourceLocale) return true;
    // The reference and the error codes are translations next to the
    // generated pages; the rest is the interface alone, translated by the
    // ARB, and the changelogs, written in English.
    final segments = path.split('/');
    return switch (segments.length > 1 ? segments[1] : '') {
      'api' => Directory('$dir/api/$locale').existsSync(),
      'errores' => File(
        '$dir/errores/$locale/${segments.length > 2 ? segments[2] : 'README'}.md',
      ).existsSync(),
      _ => true,
    };
  }
}
