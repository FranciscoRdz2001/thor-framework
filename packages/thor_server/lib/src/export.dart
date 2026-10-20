import 'dart:convert';
import 'dart:io';

import 'env.dart';
import 'errors.dart';
import 'handler.dart';
import 'http_types.dart';
import 'locale.dart';
import 'request.dart';
import 'routes.dart';

/// What [exportSite] wrote, and what it could not.
class ExportReport {
  ExportReport._(this.written, this.failed, this.brokenLinks);

  /// Page path → file written (relative to the output folder).
  final Map<String, String> written;

  /// Page path → the status it answered instead of 200 (not written).
  final Map<String, int> failed;

  /// Page path → its links (`<a href>`) to a page or an anchor that the
  /// site doesn't have.
  final Map<String, List<String>> brokenLinks;

  /// Whether every page was written and every link lands.
  bool get ok => failed.isEmpty && brokenLinks.isEmpty;
}

/// Static site generation: renders [paths] through [handler], like
/// requests, into [outDir]. `/` → `index.html`, `/guide/state` →
/// `guide/state.html` (static hosts serve `/guide/state` from it). With
/// [baseUrl] (`https://docs.example.com`) it also writes `sitemap.xml` and
/// a `robots.txt` pointing to it.
///
/// With [notFoundPath] (a path that doesn't exist) it writes `404.html`,
/// the site's error page.
///
/// A handler with `locales` (`LocaleStrategy.prefix`) writes every path
/// without a locale once per locale (`/about` → `/en/about`,
/// `/es/about`); a path that names one is written as is. `/` becomes a
/// small page that sends the visitor to their language (the browser's,
/// else the default; with no JavaScript, a refresh to the default), since
/// a static host can't read `Accept-Language`. A handler that negotiates
/// the locale (`LocaleStrategy.negotiate`) can't be exported: a
/// [StateError].
///
/// A page that doesn't answer 200 (a redirect, a 404, an error) is not
/// written and is listed in [ExportReport.failed]: a broken link found at
/// build time, not by a visitor. Every internal `<a href>` of the written
/// pages is checked too: it must reach an exported page (or a file of
/// [staticDir], the folder served next to the pages), and its `#anchor`
/// an `id` of that page ([ExportReport.brokenLinks]).
Future<ExportReport> exportSite(
  RouteHandler<Object?> handler, {
  required Iterable<String> paths,
  required String outDir,
  String? baseUrl,
  String host = 'localhost',
  String? notFoundPath,
  String? staticDir,
}) async {
  final written = <String, String>{};
  final failed = <String, int>{};
  final html = <String, String>{};
  final locales = handler.locales;
  if (locales != null && locales.strategy == LocaleStrategy.negotiate) {
    throw StateError(
      thorError(
        'THOR-P002',
        'exportSite: a site that negotiates its locale has one URL for every '
            'language, and a static host cannot choose; use '
            'LocaleStrategy.prefix or prefixExceptDefault',
      ),
    );
  }
  // The pages are asked as the site's own origin when there is a base URL:
  // what they build from the request (absolute `og:url`) is the real one.
  final site = baseUrl?.replaceFirst(RegExp(r'/+$'), '');
  // A site published under a path (`https://example.com/thor`) is still
  // asked at the app's own paths; the path only goes in the absolute URLs.
  final baseUri = site == null ? null : Uri.parse(site);
  final origin = baseUri == null ? 'http://$host' : baseUri.origin;
  final publicPrefix = baseUri?.path ?? '';
  final hostHeader = baseUri == null ? host : baseUri.authority;
  var chooser = false;
  final pages = <String>{};
  for (final path in paths) {
    if (locales == null || locales.resolve(path).prefixed) {
      pages.add(path);
      continue;
    }
    // Without a prefix for the default, `/` is the default's home page.
    if (path == '/' && locales.strategy == LocaleStrategy.prefix) {
      chooser = true;
    }
    for (final locale in locales.supportedLocales) {
      pages.add(locales.pathFor(locale, path));
    }
  }
  if (locales != null && chooser) {
    final body = localeChooserPage(locales);
    await Directory(outDir).create(recursive: true);
    await File('$outDir/index.html').writeAsString(body);
    written['/'] = 'index.html';
    html['/'] = body;
  }
  for (final path in pages) {
    final response = await handler.handle(
      PageRequest(
          method: HttpMethod.get,
          uri: Uri.parse('$origin$path'),
          headers: {HttpHeader.host: hostHeader},
        )
        ..markExport()
        ..publicPathPrefix = publicPrefix,
      stream: false,
    );
    if (response.status != 200) {
      failed[path] = response.status;
      continue;
    }
    // A static file is public forever: a page with a loaded secret in it
    // stops the export (THOR-P012), whatever mode the build runs in.
    if (Secret.leakIn(utf8.decode(response.body, allowMalformed: true)) !=
        null) {
      throw StateError(
        thorError(
          'THOR-P012',
          'exportSite: $path contains the value of a secret from the '
              'environment',
        ),
      );
    }
    // Asked and reported by the encoded path the links use; written where
    // a static host looks for it: the decoded name (`/p/caf%C3%A9` is
    // `p/café.html`; the host decodes the path before it finds the file).
    final file = fileForPath(_decoded(path));
    final target = File('$outDir/$file');
    await target.parent.create(recursive: true);
    await target.writeAsBytes(response.body);
    written[path] = file;
    if (response.headers['content-type']?.contains('html') ?? true) {
      html[path] = response.text;
    }
  }
  // The files the pages link that the renderer makes (the shared
  // stylesheets): next to the pages, at the same paths.
  if (handler.renderer case final RendererAssets assets) {
    for (final path in await assets.assetPaths()) {
      final asset = await assets.asset(path);
      if (asset == null) continue;
      final target = File('$outDir$path');
      await target.parent.create(recursive: true);
      await target.writeAsBytes(asset.body);
    }
  }
  if (notFoundPath != null) {
    // Static hosts serve `404.html` for a missing page: the site's own
    // error page, rendered from a path that doesn't exist.
    final response = await handler.handle(
      PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('$origin$notFoundPath'),
        headers: {HttpHeader.host: hostHeader},
      ),
      stream: false,
    );
    if (response.status == 404) {
      await File('$outDir/404.html').writeAsBytes(response.body);
    } else {
      failed[notFoundPath] = response.status;
    }
  }
  if (baseUrl != null) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final urls = [
      for (final path in written.keys)
        // The locale chooser only redirects: not a page to index.
        if (!(chooser && path == '/'))
          '  <url><loc>${_xml('$base$path')}</loc></url>',
    ];
    // The app's own `sitemap.dart`/`robots.dart` (a ResourceRoute), asked
    // as the site's origin; else the written pages and allow-all.
    Future<List<int>?> own(String file) async {
      final match = handler.router.match('/$file');
      if (match?.entry.page is! ResourceRoute) return null;
      final response = await handler.handle(
        PageRequest(
          method: HttpMethod.get,
          uri: Uri.parse('${Uri.parse(base).origin}/$file'),
          headers: {HttpHeader.host: Uri.parse(base).authority},
        )..publicPathPrefix = Uri.parse(base).path,
        stream: false,
      );
      if (response.status != 200) {
        failed['/$file'] = response.status;
        return null;
      }
      return response.body;
    }

    final sitemap = await own('sitemap.xml');
    await File('$outDir/sitemap.xml').writeAsBytes(
      sitemap ??
          utf8.encode(
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
            '${urls.join('\n')}\n'
            '</urlset>\n',
          ),
    );
    final robots = await own('robots.txt');
    await File('$outDir/robots.txt').writeAsBytes(
      robots ??
          utf8.encode('User-agent: *\nAllow: /\nSitemap: $base/sitemap.xml\n'),
    );
  }
  return ExportReport._(
    written,
    failed,
    _brokenLinks(html, host: host, staticDir: staticDir),
  );
}

final _href = RegExp(r'<a\b[^>]*?\shref="([^"]*)"');
final _id = RegExp(r'\sid="([^"]*)"');

Map<String, List<String>> _brokenLinks(
  Map<String, String> pages, {
  required String host,
  String? staticDir,
}) {
  // Page keys are the paths as asked (encoded, like the links to them):
  // both sides are compared decoded.
  final bodies = {for (final e in pages.entries) _decoded(e.key): e.value};
  final ids = <String, Set<String>>{};
  Set<String> idsOf(String path) => ids[path] ??= {
    for (final m in _id.allMatches(bodies[path]!)) _unescape(m[1]!),
  };
  final broken = <String, List<String>>{};
  for (final MapEntry(key: path, value: body) in pages.entries) {
    final base = Uri.parse('http://$host$path');
    for (final m in _href.allMatches(body)) {
      final href = _unescape(m[1]!);
      final Uri target;
      try {
        target = base.resolve(href);
      } on FormatException {
        (broken[path] ??= []).add(href);
        continue;
      }
      if (target.scheme != 'http' || target.host != host) continue;
      final targetPath = _decoded(target.path);
      final ok = switch (bodies.containsKey(targetPath)) {
        true =>
          !target.hasFragment ||
              target.fragment.isEmpty ||
              idsOf(targetPath).contains(Uri.decodeComponent(target.fragment)),
        false =>
          staticDir != null &&
              !targetPath.split('/').contains('..') &&
              File('$staticDir$targetPath').existsSync(),
      };
      if (!ok) (broken[path] ??= []).add(href);
    }
  }
  return broken;
}

/// [path] percent-decoded; one that doesn't decode stays as it is.
String _decoded(String path) {
  try {
    return Uri.decodeComponent(path);
  } on ArgumentError {
    return path;
  } on FormatException {
    return path;
  }
}

String _unescape(String s) => s
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');

/// The file a page path is written to: `/` → `index.html`, `/a/b` →
/// `a/b.html`, `/a/` → `a/index.html`.
String fileForPath(String path) {
  if (path.split('/').contains('..')) {
    throw ArgumentError.value(path, 'path', 'must not contain ..');
  }
  final clean = path.startsWith('/') ? path.substring(1) : path;
  if (clean.isEmpty) return 'index.html';
  if (clean.endsWith('/')) return '${clean}index.html';
  return '$clean.html';
}

String _xml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// The `/` of an exported multilingual site: it sends the visitor to the
/// first of their browser's languages the site has (a few bytes of inline
/// script), else, and without JavaScript, to the default locale. Lists
/// every language as a link and as an `hreflang` alternate.
String localeChooserPage(LocaleRouting locales) {
  final target = locales.pathFor(locales.defaultLocale, '/');
  final paths = {
    for (final l in locales.supportedLocales)
      l.toLanguageTag(): locales.pathFor(l, '/'),
  };
  // JSON inside a script: `<` escaped so no tag can close it.
  final json = jsonEncode(paths).replaceAll('<', r'\u003c');
  final out = StringBuffer()
    ..write(
      '<!DOCTYPE html><html lang="${_xml(locales.defaultLocale.toLanguageTag())}">',
    )
    ..write('<head><meta charset="utf-8">')
    ..write('<meta name="viewport" content="width=device-width">')
    ..write('<title>${_xml(locales.defaultLocale.toLanguageTag())}</title>')
    ..write('<meta name="robots" content="noindex">')
    ..write(
      '<link rel="canonical" '
      'href="${_xml(locales.alternates('/')['x-default']!)}">',
    );
  for (final MapEntry(:key, :value) in locales.alternates('/').entries) {
    out.write(
      '<link rel="alternate" hreflang="${_xml(key)}" href="${_xml(value)}">',
    );
  }
  out
    ..write('<script>(function(){var p=$json;')
    ..write('var l=navigator.languages||[navigator.language];')
    ..write('for(var i=0;i<l.length;i++){var t=String(l[i]),s=t.split("-")[0];')
    ..write('var k=p[t]?t:p[s]?s:null;')
    ..write('if(k){location.replace(p[k]);return}}')
    ..write('location.replace(${jsonEncode(target)})})()</script>')
    ..write('<meta http-equiv="refresh" content="0; url=${_xml(target)}">')
    ..write('</head><body><ul>');
  for (final MapEntry(:key, :value) in paths.entries) {
    out.write(
      '<li><a href="${_xml(value)}" hreflang="${_xml(key)}" '
      'lang="${_xml(key)}">${_xml(key)}</a></li>',
    );
  }
  out.write('</ul></body></html>\n');
  return out.toString();
}
