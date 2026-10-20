# SEO

Declare what search engines and social networks read: title, description, link preview, structured data, sitemap and `robots.txt`.

Everything is declared with types in `PageMeta`, next to the page that uses it:

| Field | Writes |
|---|---|
| `title`, `titleTemplate` | `<title>` and the title format of the pages a layout contains |
| `description` | `<meta name="description">` |
| `canonical` | `<link rel="canonical">` |
| `robotsMeta` | `<meta name="robots">`; `RobotsMeta.noindex` on private pages |
| `openGraph` | the `og:*` and `twitter:card` tags |
| `jsonLd` | one `<script type="application/ld+json">` per map |

## Title and description

Every page and every layout can declare `meta`. The layout sets what is shared and the page sets the specifics:

```dart
// in RootLayout
@override
PageMeta meta(PageState<void> state) =>
    const PageMeta(title: 'Conduit', titleTemplate: '%s · Conduit');

// in ArticlePage → "My article · Conduit"
@override
PageMeta meta(PageState<ArticleData> state) => PageMeta(
  title: state.data.article.title,
  description: state.data.article.description,
);
```

Levels are merged field by field: the one closest to the page wins, and `titleTemplate` applies to the titles of the pages below it.

### Title from slow data

If the title depends on slow data, don't hold the whole page with `await`: mark the future with `defer(f, head: true)` and read it in `meta` with `resolvedValue`. The server waits for it before sending the head, so the title and the `404` are always the real ones ([Server and actions](server-and-actions.md#head-and-status-with-deferred-data)).

```dart
PageMeta meta(PageState<ProductData> state) => PageMeta(
  title: resolvedValue(state.data.item)?.name ?? 'Product',
);
```

> **Important:** A `404` that depends on how fast the backend is becomes a "soft 404" that search engines index; that is why `head: true` has no limit. If the data is purely cosmetic, `headBudget:` sets one, and a page that exceeds it is served with `noindex`.

## Link preview when sharing

`PageMeta(openGraph:)` writes the tags that social networks and messaging apps use to build a link's card. The layout can set `siteName` and the default image, and each page its own title:

```dart
PageMeta(
  title: article.title,
  description: article.description,
  openGraph: OpenGraph(
    type: 'article',
    title: article.title,
    description: article.description,
    siteName: 'Conduit',
  ),
)
```

## Structured data

`PageMeta(jsonLd:)` adds one `<script type="application/ld+json">` per map, so a search engine knows what the page is: an article, a product, an organization.

```dart
PageMeta(
  jsonLd: [
    {
      '@context': 'https://schema.org',
      '@type': 'Article',
      'headline': article.title,
      'datePublished': article.createdAt.toUtc().toIso8601String(),
      'author': {'@type': 'Person', 'name': article.author.username},
    },
  ],
)
```

Levels add up (the layout describes the site and the page describes the article) and the content is escaped: a title containing `</script>` doesn't break the page.

## Sitemap and robots.txt

`SitemapRoute` and `RobotsRoute` are two entries at the top level of the route table:

```dart
// lib/seo.dart
Future<Sitemap> sitemap(PageRequest request) async {
  const private = {'/login', '/register', '/editor', '/settings'};
  final latest = await api.articles();
  return Sitemap([
    for (final path in router.staticPaths)
      if (!private.contains(path)) SitemapUrl(path),
    for (final a in latest.articles)
      SitemapUrl(articleRoute.link({'slug': a.slug}), lastModified: a.createdAt),
  ]);
}

Robots robots(PageRequest request) => Robots([
  RobotsRule(disallow: [editorRoute.link(), settingsRoute.link()]),
]);

// lib/router.dart
final ThorRouter router = ThorRouter([
  Group(layout: const RootLayout(), children: [homeRoute]),
  const SitemapRoute(sitemap),
  const RobotsRoute(robots),
]);
```

`router.staticPaths` holds every route without parameters, the starting point of a sitemap; since the table reads itself, declare its type (`final ThorRouter router = …`). Relative paths become absolute with the site URL; behind a proxy, declare the public URL ([Session and security](session-and-security.md#host-and-public-origin)). These routes go through the root middleware and guards, but not through `load`, rendering or the page cache.

> **Note:** `SitemapRoute` and `RobotsRoute` only go at the top level of the table: inside a `Group` they are [THOR-P014](../../errores/en/THOR-P014.md).

On a static site, `thor export --base-url https://…` writes your sitemap and your `robots.txt`, or generates them from the exported pages if the app doesn't declare them.

## Images and fonts

Load speed also matters to a search engine. The page's main image, `Image(priority: true)`, is requested first, and fonts with a measured fallback don't shift the text when they load. The details are in [Content](components-content.md) and [Theme and styles](theme-and-styles.md).

## Next steps

:::cards
- [Build and deploy](build-and-deploy.md) — where the sitemap and the 404 are written
- [Languages](localization.md) — `hreflang` and one page per language
- [Server and actions](server-and-actions.md) — `meta`, caching and deferred data
:::
