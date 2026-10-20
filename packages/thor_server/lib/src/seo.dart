import 'dart:convert';

import 'handler.dart';
import 'http_types.dart';
import 'request.dart';

/// `sitemap.xml` (the sitemaps.org protocol): what the function of a
/// `SitemapRoute` in the route table returns.
///
/// ```dart
/// Future<Sitemap> sitemap(PageRequest request) async => Sitemap([
///   for (final path in router.staticPaths) SitemapUrl(path),
///   for (final a in await api.articles())
///     SitemapUrl(articleRoute.link({'slug': a.slug}), lastModified: a.updatedAt),
/// ], baseUrl: 'https://conduit.example.com');
/// ```
///
/// A path is made absolute against [baseUrl], else the request's origin
/// (behind a proxy that changes the scheme or host, give [baseUrl]).
class Sitemap {
  /// A sitemap of [urls].
  const Sitemap(this.urls, {this.baseUrl, this.maxAge = 3600});

  /// The pages.
  final List<SitemapUrl> urls;

  /// The site's origin (`https://example.com`); `null`: the request's.
  final String? baseUrl;

  /// How long a cache may keep it, in seconds.
  final int maxAge;

  /// The XML document.
  String toXml(Uri origin) {
    final base = _origin(baseUrl, origin);
    final out = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');
    for (final u in urls) {
      out.write('  <url><loc>${_xml(_absolute(base, u.path))}</loc>');
      if (u.lastModified case final d?) {
        out.write('<lastmod>${d.toUtc().toIso8601String()}</lastmod>');
      }
      if (u.changeFrequency case final f?) {
        out.write('<changefreq>${f.name}</changefreq>');
      }
      if (u.priority case final p?) {
        out.write('<priority>${p.clamp(0, 1).toStringAsFixed(1)}</priority>');
      }
      out.writeln('</url>');
    }
    out.writeln('</urlset>');
    return '$out';
  }

  /// The response for [request].
  ThorResponse response(PageRequest request) => ThorResponse(
    200,
    headers: {
      HttpHeader.contentType: 'application/xml; charset=utf-8',
      HttpHeader.cacheControl: 'public, max-age=$maxAge',
    },
    body: utf8.encode(toXml(request.uri)),
  );
}

/// One page of a [Sitemap].
class SitemapUrl {
  /// [path] (`articleRoute.link({'slug': …})`) or an absolute URL.
  const SitemapUrl(
    this.path, {
    this.lastModified,
    this.changeFrequency,
    this.priority,
  });

  /// The page.
  final String path;

  /// `<lastmod>`.
  final DateTime? lastModified;

  /// `<changefreq>`.
  final ChangeFrequency? changeFrequency;

  /// `<priority>`, 0 to 1.
  final double? priority;
}

/// `<changefreq>` values.
enum ChangeFrequency {
  /// Every visit.
  always,

  /// Hourly.
  hourly,

  /// Daily.
  daily,

  /// Weekly.
  weekly,

  /// Monthly.
  monthly,

  /// Yearly.
  yearly,

  /// Archived.
  never,
}

/// `robots.txt`: what the function of a `RobotsRoute` in the route table
/// (or `ResourceRoute.robots`) returns.
///
/// ```dart
/// Robots robots(PageRequest request) =>
///     const Robots([RobotsRule(disallow: ['/editor', '/settings'])]);
/// ```
///
/// With [sitemap] (default) it points to the site's `/sitemap.xml`.
class Robots {
  /// Robots with [rules] (default: everyone may crawl everything).
  const Robots(
    this.rules, {
    this.sitemap = true,
    this.baseUrl,
    this.maxAge = 86400,
  });

  /// The groups, in order.
  final List<RobotsRule> rules;

  /// Whether to add `Sitemap: <origin>/sitemap.xml`.
  final bool sitemap;

  /// The site's origin; `null`: the request's.
  final String? baseUrl;

  /// How long a cache may keep it, in seconds.
  final int maxAge;

  /// The text.
  String toText(Uri origin) {
    final out = StringBuffer();
    final groups = rules.isEmpty ? const [RobotsRule()] : rules;
    for (final r in groups) {
      out.writeln('User-agent: ${_line(r.userAgent)}');
      for (final a in r.allow) {
        out.writeln('Allow: ${_line(a)}');
      }
      for (final d in r.disallow) {
        out.writeln('Disallow: ${_line(d)}');
      }
      if (r.allow.isEmpty && r.disallow.isEmpty) out.writeln('Allow: /');
      out.writeln();
    }
    if (sitemap) {
      out.writeln('Sitemap: ${_origin(baseUrl, origin)}/sitemap.xml');
    }
    return '$out';
  }

  /// The response for [request].
  ThorResponse response(PageRequest request) => ThorResponse(
    200,
    headers: {
      HttpHeader.contentType: 'text/plain; charset=utf-8',
      HttpHeader.cacheControl: 'public, max-age=$maxAge',
    },
    body: utf8.encode(toText(request.uri)),
  );
}

/// One `User-agent` group of [Robots].
class RobotsRule {
  /// [userAgent] (`*`: everyone) with its paths.
  const RobotsRule({
    this.userAgent = '*',
    this.allow = const [],
    this.disallow = const [],
  });

  /// The crawler.
  final String userAgent;

  /// Paths it may crawl.
  final List<String> allow;

  /// Paths it may not.
  final List<String> disallow;
}

String _origin(String? baseUrl, Uri request) {
  final base = baseUrl ?? request.origin;
  return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
}

String _absolute(String base, String path) =>
    path.startsWith('http://') || path.startsWith('https://')
    ? path
    : '$base${path.startsWith('/') ? '' : '/'}$path';

// A value on one line: a newline would start a directive of its own.
String _line(String value) => value.replaceAll(RegExp(r'[\r\n]'), '');

String _xml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
