import 'package:thor_ui/router.dart';

import '../api.dart';
import '../router.dart';

/// `/sitemap.xml`: the public pages without parameters and the latest
/// articles (the first page of the global feed).
Future<Sitemap> sitemap(PageRequest request) async {
  const private = {'/login', '/register', '/editor', '/settings'};
  final latest = await api.articles();
  return Sitemap([
    for (final path in router.staticPaths)
      if (!private.contains(path)) SitemapUrl(path),
    for (final a in latest.articles)
      SitemapUrl(
        articleRoute.link({'slug': a.slug}),
        lastModified: a.createdAt,
      ),
  ]);
}
