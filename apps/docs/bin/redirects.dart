import 'dart:convert';
import 'dart:io';

import 'package:docs/core/content/library.dart';
import 'package:docs/core/content/redirects.dart';
import 'package:docs/core/i18n/docs_locale.dart';

/// Writes the redirects of `deploy/vercel.json` from `redirects.dart`, where
/// the old addresses live: `dart run bin/redirects.dart`. `--check` only
/// says whether the file is up to date (the test runs it).
///
/// Vercel redirects `/guia/<slug>`, the old sections' pages and `/api/…` on
/// the server; the export also writes a small page per old address for
/// hosts with no such rules.
Future<void> main(List<String> args) async {
  final file = File('deploy/vercel.json');
  final text = redirectsConfig(
    jsonDecode(file.readAsStringSync()) as Map<String, Object?>,
  );
  if (args.contains('--check')) {
    stdout.writeln(file.readAsStringSync() == text ? 'up to date' : 'stale');
    exit(file.readAsStringSync() == text ? 0 : 1);
  }
  file.writeAsStringSync(text);
}

/// [config] (`deploy/vercel.json`) with the redirects of `redirects.dart`
/// and the header of the guide's Markdown, as the file's text.
String redirectsConfig(Map<String, Object?> config) {
  final guides = {
    for (final locale in docsLocales)
      for (final g in allGuides) localizePath(locale, g.path),
  };
  String markdown(String target) =>
      guides.contains(target) ? '$target.md' : target;
  String inDefault(String target) => target.startsWith('http')
      ? target
      : localizeAnchor(defaultLocale, localizePath(defaultLocale, target));
  final redirects = <Map<String, Object?>>[
    for (final MapEntry(:key, :value) in legacyGuideTargets.entries) ...[
      {
        'source': '/guia/$key',
        'destination': inDefault(value),
        'permanent': true,
      },
      {
        'source': '/guia/$key.md',
        'destination': markdown(inDefault(value)),
        'permanent': true,
      },
    ],
    // A page that changed section, in every language (and its Markdown).
    for (final locale in docsLocales)
      for (final MapEntry(:key, :value) in legacySectionTargets.entries) ...[
        {
          'source': localizePath(locale, key),
          'destination': localizePath(locale, value),
          'permanent': true,
        },
        {
          'source': '${localizePath(locale, key)}.md',
          'destination': markdown(localizePath(locale, value).split('#').first),
          'permanent': true,
        },
      ],
    // An address that only sends to a page (`/es/api`).
    for (final MapEntry(:key, :value) in localizedIndexRedirects().entries)
      {'source': key, 'destination': value, 'permanent': true},
    // `/api` on its own goes to the first reference page in one hop: the
    // rule below would send it to `/es/api` first.
    for (final MapEntry(:key, :value) in indexRedirects.entries)
      {'source': key, 'destination': inDefault(value), 'permanent': true},
    // The pages that had no language in their address, in the default
    // language: the reference's topics that it spells otherwise first (the
    // rule after them keeps the rest of the path as it is).
    for (final package in apiPackages)
      for (final MapEntry(key: folder, value: spelled)
          in (apiFolderSlugs[defaultLocale] ?? const {}).entries)
        {
          'source': '/api/$package/$folder/:path*',
          'destination':
              '${localizePath(defaultLocale, '/api/$package')}/$spelled/:path*',
          'permanent': true,
        },
    for (final root in unprefixedRoots)
      {
        'source': '/$root/:path*',
        'destination': '${localizePath(defaultLocale, '/$root')}/:path*',
        'permanent': true,
      },
  ];
  return '${const JsonEncoder.withIndent('  ').convert({
    ...config,
    'redirects': redirects,
    'headers': [
      {
        'source': '/(.*)\\.md',
        'headers': [
          {'key': 'Content-Type', 'value': 'text/plain; charset=utf-8'},
        ],
      },
      for (final header in (config['headers'] as List).skip(1)) header,
    ],
  })}\n';
}
