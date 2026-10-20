/// Which language a request gets: the URL prefix, a cookie, the browser's
/// `Accept-Language`, or the default.
library;

import 'package:thor_style/thor_style.dart' show TextDirection;

/// Flutter's `Locale`: a language, optionally with a script and a region.
///
/// The one language type of the page: `PageRequest.locale`,
/// `LocaleRouting`, `WidgetRenderer(locale:)` and `LocaleSwitcher(labels:)`
/// all take it, never a tag `String`.
///
/// ```dart
/// const Locale('es')            // es
/// const Locale('pt', 'BR')      // pt_BR, tag pt-BR
/// const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
/// ```
class Locale {
  /// A locale for [languageCode] (`es`) and optionally [countryCode] (`MX`).
  const Locale(this.languageCode, [this.countryCode]) : scriptCode = null;

  /// A locale from its subtags (`und` when there is no language).
  const Locale.fromSubtags({
    this.languageCode = 'und',
    this.scriptCode,
    this.countryCode,
  });

  /// The language subtag (`es`, `pt`).
  final String languageCode;

  /// The script subtag (`Hant`, `Arab`), or `null`.
  final String? scriptCode;

  /// The region subtag (`MX`, `BR`), or `null`.
  final String? countryCode;

  /// `// web:` no Flutter counterpart: the locale of a BCP 47 [tag]
  /// (`pt-BR`, `zh-Hant-TW`, `es_MX`), or `null` when it isn't one.
  /// Variants and extensions are dropped.
  static Locale? tryParse(String tag) {
    final parts = tag.split(RegExp('[-_]'));
    if (!RegExp(r'^[A-Za-z]{2,8}$').hasMatch(parts.first)) return null;
    String? script, region;
    for (final part in parts.skip(1)) {
      if (!RegExp(r'^[A-Za-z0-9]{1,8}$').hasMatch(part)) return null;
      if (script == null && region == null && part.length == 4) {
        script = part[0].toUpperCase() + part.substring(1).toLowerCase();
      } else if (region == null &&
          (part.length == 2 || RegExp(r'^\d{3}$').hasMatch(part))) {
        region = part.toUpperCase();
      }
    }
    return Locale.fromSubtags(
      languageCode: parts.first.toLowerCase(),
      scriptCode: script,
      countryCode: region,
    );
  }

  /// The BCP 47 tag: `pt-BR` (what `<html lang>` and `hreflang` carry).
  String toLanguageTag() => [languageCode, ?scriptCode, ?countryCode].join('-');

  /// Whether text in this locale runs right to left (`ar`, `he`, `fa`…):
  /// the `dir` of its pages. `// web:` Flutter reads it from
  /// `WidgetsLocalizations.textDirection`.
  TextDirection get textDirection =>
      isRtlLanguageTag(toLanguageTag()) ? TextDirection.rtl : TextDirection.ltr;

  @override
  bool operator ==(Object other) =>
      other is Locale &&
      other.languageCode == languageCode &&
      other.scriptCode == scriptCode &&
      other.countryCode == countryCode;

  @override
  int get hashCode => Object.hash(languageCode, scriptCode, countryCode);

  /// Like Flutter: subtags joined with `_` (`pt_BR`).
  @override
  String toString() => [languageCode, ?scriptCode, ?countryCode].join('_');
}

/// Where the locale of a page comes from.
enum LocaleStrategy {
  /// Every page lives under its locale (`/es/about`, `/en/about`). The URL
  /// alone decides: pages cache and share like any other, and static hosts
  /// can serve them (`exportSite` writes each locale). A URL without a
  /// prefix redirects (`302`) to the visitor's locale: the cookie, then
  /// `Accept-Language`, then the default.
  prefix,

  /// The default locale has no prefix (`/about`), the others do
  /// (`/es/about`): the default's URLs stay as they were when a site adds
  /// a language. Only the root (`/`) looks at the visitor: a cookie or
  /// `Accept-Language` for another supported locale redirects (`302`) to
  /// its root (`/es`); every other URL without a prefix is the default's
  /// page, never a redirect. The default spelled with its prefix
  /// (`/en/about`) redirects (`308`) to its one URL (`/about`). Exportable:
  /// the default at the site's root, each other locale under its prefix.
  prefixExceptDefault,

  /// One URL per page for every language: the cookie, then
  /// `Accept-Language`, then the default. Every response says
  /// `Vary: Accept-Language, Cookie` and the page cache keeps one copy per
  /// locale. Not exportable (a static host can't choose).
  negotiate,
}

/// The languages a routed app speaks and how a request picks one
/// (`RouteHandler(locales:)`).
///
/// ```dart
/// RouteHandler(
///   routes: routes,
///   locales: LocaleRouting(supportedLocales: [Locale('en'), Locale('es')]),
///   renderer: WidgetRenderer(...),
/// )
/// ```
///
/// Precedence: the URL prefix (with [LocaleStrategy.prefix]), then the
/// [cookieName] cookie, then `Accept-Language`, then [defaultLocale]. A
/// cookie or header value the app doesn't support is ignored, never an
/// error.
class LocaleRouting {
  /// Routing for [supportedLocales], the first one being the default unless
  /// [defaultLocale] says otherwise.
  ///
  /// [baseUrl] (`https://example.com`) makes the `hreflang` alternates of
  /// every page absolute, as search engines ask; without it they are
  /// root-relative.
  LocaleRouting({
    required List<Locale> supportedLocales,
    Locale? defaultLocale,
    this.strategy = LocaleStrategy.prefix,
    this.cookieName = 'locale',
    this.baseUrl,
  }) : supportedLocales = List.unmodifiable(supportedLocales),
       defaultLocale =
           defaultLocale ??
           (supportedLocales.isEmpty
               ? const Locale('und')
               : supportedLocales.first) {
    if (supportedLocales.isEmpty) {
      throw ArgumentError.value(
        supportedLocales,
        'supportedLocales',
        'must not be empty',
      );
    }
    for (final locale in supportedLocales) {
      // The tag becomes a URL segment and a cookie value.
      if (!_languageTag.hasMatch(locale.toLanguageTag())) {
        throw ArgumentError.value(
          locale,
          'supportedLocales',
          'not a BCP 47 locale',
        );
      }
    }
    if (!this.supportedLocales.contains(this.defaultLocale)) {
      throw ArgumentError.value(
        defaultLocale,
        'defaultLocale',
        'must be one of supportedLocales',
      );
    }
    if (this.supportedLocales.toSet().length != supportedLocales.length) {
      throw ArgumentError.value(
        supportedLocales,
        'supportedLocales',
        'has duplicates',
      );
    }
  }

  /// This routing with [baseUrl] (absolute `hreflang` links), the rest the
  /// same: the generated `localeRouting` with the site's origin.
  LocaleRouting copyWith({String? baseUrl}) => LocaleRouting(
    supportedLocales: supportedLocales,
    defaultLocale: defaultLocale,
    strategy: strategy,
    cookieName: cookieName,
    baseUrl: baseUrl ?? this.baseUrl,
  );

  /// The languages the app speaks.
  final List<Locale> supportedLocales;

  /// The locale when nothing else says (and `x-default`).
  final Locale defaultLocale;

  /// URL prefix or negotiation.
  final LocaleStrategy strategy;

  /// The cookie that remembers the visitor's choice (`locale=es`).
  final String cookieName;

  /// Origin for absolute `hreflang` links, or `null` for root-relative ones.
  final String? baseUrl;

  /// The locale of a request for [path] (its prefix), else of [cookie] and
  /// [acceptLanguage], else [defaultLocale]; and the path the router sees
  /// (without the prefix). `prefixed` is false when the URL named no locale
  /// (with [LocaleStrategy.prefix], a candidate for a redirect).
  ({Locale locale, String path, bool prefixed}) resolve(
    String path, {
    String? cookie,
    String? acceptLanguage,
  }) {
    if (strategy != LocaleStrategy.negotiate) {
      final end = path.indexOf('/', 1);
      final first = path.length > 1
          ? path.substring(1, end < 0 ? path.length : end)
          : '';
      // Exact spelling only: `/ES/x` is a path of its own (a 404), not a
      // second URL for the same page.
      for (final locale in supportedLocales) {
        if (locale.toLanguageTag() == first) {
          return (
            locale: locale,
            path: end < 0 ? '/' : path.substring(end),
            prefixed: true,
          );
        }
      }
    }
    return (
      // Without a prefix the page is the default's; only the root asks
      // the visitor (the handler redirects it).
      locale: strategy == LocaleStrategy.prefixExceptDefault && path != '/'
          ? defaultLocale
          : negotiate(cookie: cookie, acceptLanguage: acceptLanguage),
      path: path,
      prefixed: false,
    );
  }

  /// Whether a request for a page without a prefix goes elsewhere: with
  /// [LocaleStrategy.prefix], always (to the visitor's locale); with
  /// [LocaleStrategy.prefixExceptDefault], only the root, and only when
  /// the visitor's locale is not the default.
  bool redirectsUnprefixed(String path, Locale visitorLocale) =>
      switch (strategy) {
        LocaleStrategy.prefix => true,
        LocaleStrategy.prefixExceptDefault =>
          path == '/' && visitorLocale != defaultLocale,
        LocaleStrategy.negotiate => false,
      };

  /// With [LocaleStrategy.prefixExceptDefault], the one URL of a path that
  /// spells the default locale's prefix (`/en/about` → `/about`), else
  /// `null`.
  String? canonicalOfDefaultPrefix(String path) {
    if (strategy != LocaleStrategy.prefixExceptDefault) return null;
    final prefix = '/${defaultLocale.toLanguageTag()}';
    if (path == prefix) return '/';
    if (path.startsWith('$prefix/')) return path.substring(prefix.length);
    return null;
  }

  /// The visitor's locale without a URL: [cookie] if supported, else the
  /// best match of [acceptLanguage], else [defaultLocale].
  Locale negotiate({String? cookie, String? acceptLanguage}) {
    if (cookie != null) {
      final chosen = supportedLocaleOf(cookie);
      if (chosen != null) return chosen;
    }
    if (acceptLanguage != null) {
      final matched = matchLocale(
        parseAcceptLanguage(acceptLanguage),
        supportedLocales,
      );
      if (matched != null) return matched;
    }
    return defaultLocale;
  }

  /// The query parameter a language switcher link carries
  /// (`/about?set-locale=es`): the handler remembers the choice in
  /// [cookieName] and redirects (`303`) to the page in that locale, without
  /// the parameter.
  static const switchParameter = 'set-locale';

  /// The one of [supportedLocales] that the BCP 47 [tag] (a cookie, a
  /// query value) spells, in any case, or `null` when the app doesn't
  /// speak it or it isn't a language tag.
  Locale? supportedLocaleOf(String tag) {
    if (!_languageTag.hasMatch(tag)) return null;
    final locale = Locale.tryParse(tag);
    return locale != null && supportedLocales.contains(locale) ? locale : null;
  }

  /// [path] (as the router sees it: `/about`) in [locale]: `/es/about`
  /// with a prefix (the default's own [path] with
  /// [LocaleStrategy.prefixExceptDefault]); [path] itself with negotiation.
  String pathFor(Locale locale, String path) {
    if (strategy == LocaleStrategy.negotiate) return path;
    if (!supportedLocales.contains(locale)) {
      throw ArgumentError.value(locale, 'locale', 'not supported');
    }
    if (strategy == LocaleStrategy.prefixExceptDefault &&
        locale == defaultLocale) {
      return path.isEmpty ? '/' : path;
    }
    final tag = locale.toLanguageTag();
    return path == '/' || path.isEmpty ? '/$tag' : '/$tag$path';
  }

  /// `hreflang` → URL of [path] in every locale, `x-default` last (the
  /// default locale's URL). Empty with negotiation (one URL for all).
  /// `// web:` the keys are the BCP 47 tags `hreflang` carries.
  Map<String, String> alternates(String path) {
    if (strategy == LocaleStrategy.negotiate) return const {};
    final base = baseUrl == null
        ? ''
        : baseUrl!.endsWith('/')
        ? baseUrl!.substring(0, baseUrl!.length - 1)
        : baseUrl!;
    return {
      for (final l in supportedLocales)
        l.toLanguageTag(): '$base${pathFor(l, path)}',
      'x-default': '$base${pathFor(defaultLocale, path)}',
    };
  }
}

final _languageTag = RegExp(r'^[A-Za-z]{2,8}([-_][A-Za-z0-9]{1,8})*$');

/// The locales of an `Accept-Language` header, most preferred first
/// (RFC 9110 §12.5.4: by `q`, ties in header order).
///
/// Malformed entries (a bad tag, a `q` out of range or unparsable) are
/// skipped, not fatal; `q=0` means "not this one" and `*` adds nothing a
/// default doesn't. A header longer than 4 KB or its entries past the
/// 32nd are ignored (a visitor controls it).
List<Locale> parseAcceptLanguage(String header) {
  if (header.length > 4096) return const [];
  final entries = <({Locale locale, double q, int index})>[];
  final parts = header.split(',');
  for (var i = 0; i < parts.length && i < 32; i++) {
    final fields = parts[i].split(';');
    final tag = fields.first.trim();
    if (tag == '*' || !_languageTag.hasMatch(tag)) continue;
    var q = 1.0;
    var valid = true;
    for (final param in fields.skip(1)) {
      final eq = param.indexOf('=');
      if (eq < 0) {
        valid = false;
        break;
      }
      if (param.substring(0, eq).trim().toLowerCase() != 'q') continue;
      final value = param.substring(eq + 1).trim();
      if (!_qValue.hasMatch(value)) {
        valid = false;
        break;
      }
      q = double.parse(value);
    }
    final locale = Locale.tryParse(tag);
    if (!valid || q <= 0 || locale == null) continue;
    entries.add((locale: locale, q: q, index: i));
  }
  entries.sort(
    (a, b) => a.q != b.q ? b.q.compareTo(a.q) : a.index.compareTo(b.index),
  );
  return [for (final e in entries) e.locale];
}

final _qValue = RegExp(r'^(0(\.\d{0,3})?|1(\.0{0,3})?)$');

/// The first of [supported] that a locale of [preferred] (in order)
/// accepts: the same locale, else the same language (`es-MX` → `es`,
/// `pt` → `pt-BR`), else `null`.
Locale? matchLocale(Iterable<Locale> preferred, List<Locale> supported) {
  for (final locale in preferred) {
    final exact = supported.indexOf(locale);
    if (exact >= 0) return supported[exact];
    final lang = locale.languageCode;
    // The bare language first (`es` for `es-MX`), then any region of it.
    for (final s in supported) {
      if (s.languageCode == lang &&
          s.scriptCode == null &&
          s.countryCode == null) {
        return s;
      }
    }
    for (final s in supported) {
      if (s.languageCode == lang) return s;
    }
  }
  return null;
}

/// Whether text in [tag] runs right to left (`ar`, `he`, `fa`, `ur`… or an
/// Arabic, Hebrew, Syriac or Thaana script subtag): the `dir="rtl"` of
/// its pages.
bool isRtlLanguageTag(String tag) {
  final parts = tag.split(RegExp('[-_]'));
  for (final part in parts.skip(1)) {
    if (part.length == 4) {
      return const {
        'arab',
        'hebr',
        'syrc',
        'thaa',
        'nkoo',
        'adlm',
        'rohg',
      }.contains(part.toLowerCase());
    }
  }
  return const {
    'ar',
    'arc',
    'ckb',
    'dv',
    'fa',
    'he',
    'iw',
    'ks',
    'ps',
    'sd',
    'ug',
    'ur',
    'yi',
  }.contains(parts.first.toLowerCase());
}
