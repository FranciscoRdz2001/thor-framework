# SEO

Declara lo que leen un buscador y una red social: título, descripción, vista previa, datos estructurados, sitemap y `robots.txt`.

Todo se declara con tipos en `PageMeta`, junto a la página que lo usa:

| Campo | Escribe |
|---|---|
| `title`, `titleTemplate` | `<title>` y el formato del título de las páginas que contiene un layout |
| `description` | `<meta name="description">` |
| `canonical` | `<link rel="canonical">` |
| `robotsMeta` | `<meta name="robots">`; `RobotsMeta.noindex` en páginas privadas |
| `openGraph` | las etiquetas `og:*` y `twitter:card` |
| `jsonLd` | un `<script type="application/ld+json">` por mapa |

## Título y descripción

Cada página y cada layout pueden declarar `meta`. El layout pone lo común y la página lo concreto:

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

Los niveles se combinan campo por campo: gana el más cercano a la página, y `titleTemplate` se aplica a los títulos de las páginas de abajo.

### Título con datos lentos

Si el título depende de un dato lento, no esperes toda la página con `await`: marca el futuro con `defer(f, head: true)` y léelo en `meta` con `resolvedValue`. El servidor lo espera antes de enviar la cabecera, así que el título y el `404` son siempre los reales ([Servidor y acciones](red-y-servidor.md#cabecera-y-estado-con-datos-diferidos)).

```dart
PageMeta meta(PageState<ProductData> state) => PageMeta(
  title: resolvedValue(state.data.item)?.name ?? 'Product',
);
```

> **Importante:** Un `404` que depende de la velocidad del backend es un «soft 404» que los buscadores indexan; por eso `head: true` no tiene tope. Si el dato es solo cosmético, `headBudget:` pone uno, y la página que lo agota sale con `noindex`.

## Vista previa al compartir

`PageMeta(openGraph:)` escribe las etiquetas con las que las redes sociales y las apps de mensajería arman la tarjeta de un enlace. El layout puede poner `siteName` y la imagen por omisión, y cada página su título:

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

## Datos estructurados

`PageMeta(jsonLd:)` agrega un `<script type="application/ld+json">` por mapa, para que un buscador sepa qué es la página: un artículo, un producto, una organización.

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

Los niveles se suman (el layout describe el sitio y la página, el artículo) y el contenido se escapa: un título con `</script>` no rompe la página.

## Sitemap y robots.txt

`SitemapRoute` y `RobotsRoute` son dos entradas del primer nivel de la tabla de rutas:

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

`router.staticPaths` son todas las rutas sin parámetros, el punto de partida de un sitemap; como la tabla se lee a sí misma, declara su tipo (`final ThorRouter router = …`). Las rutas relativas se vuelven absolutas con la URL del sitio; detrás de un proxy, declara la URL pública ([Sesión y seguridad](sesion-y-seguridad.md#host-y-origen-público)). Estas rutas pasan por el middleware y los guards de la raíz, pero no por `load`, el render ni la caché de página.

> **Nota:** `SitemapRoute` y `RobotsRoute` solo van en el primer nivel de la tabla: dentro de un `Group` son [THOR-P014](../../errores/THOR-P014.md).

En un sitio estático, `thor export --base-url https://…` escribe tu sitemap y tu `robots.txt`, o genera unos con las páginas exportadas si la app no los declara.

## Imágenes y fuentes

La velocidad de carga también cuenta para un buscador. La imagen principal de la página, `Image(priority: true)`, se pide primero, y las fuentes con respaldo medido no desplazan el texto al cargar. Los detalles están en [Contenido](componentes-contenido.md) y [Tema y estilos](tema-y-estilos.md).

## Siguientes pasos

:::cards
- [Compilar y publicar](publicar.md) — dónde se escriben el sitemap y el 404
- [Idiomas](idiomas.md) — `hreflang` y una página por idioma
- [Servidor y acciones](red-y-servidor.md) — `meta`, caché y datos diferidos
:::
