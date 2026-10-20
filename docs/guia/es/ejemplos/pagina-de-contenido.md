# Página de contenido

Una landing, un blog o una página de documentación que carga rápido, se indexa bien y se lee sin JavaScript.

:::flutter Flutter: `Scaffold`, `ListView` e `Image.network` · Thor: el mismo árbol, exportado como HTML

:::bench recipe-content-page
:::

## La primera pantalla primero

La imagen principal se carga sin diferir (`lazy: false`) y lleva `width` y `height` para que la página no se desplace al cargarla. El resto de las imágenes usa `lazy: true`, el valor por omisión.

```dart
Image.network(
  '/img/hero.jpg',
  width: 1280,
  height: 720,
  lazy: false,
  srcSet: const {640: '/img/hero-640.webp', 1280: '/img/hero-1280.webp'},
  sizes: '(min-width: 768px) 50vw, 100vw',
  semanticLabel: 'The team at the office',
)
```

`srcSet` y `sizes` permiten que el navegador descargue solo el ancho que necesita. Las secciones de más abajo van en un `LazyLayout`, que el navegador no dibuja hasta que se acercan a la pantalla:

```dart
LazyLayout(extentEstimate: 900, child: const ContactSection())
```

> **Importante:** No uses `LazyLayout` en la primera pantalla ni en secciones cuya sombra sale de su caja.

## Tema, fuentes y metadatos

Un `ThemeData` describe la marca, con una fuente propia servida desde tu dominio. Precarga solo la fuente del texto de la primera pantalla.

```dart
final theme = ThemeData(
  fontFamily: 'Figtree',
  fontFamilyFallback: ['system-ui', 'sans-serif'],
  fonts: const [
    FontFace(
      'Figtree',
      url: '/fonts/figtree.woff2',
      weight: FontWeight.w300,
      maxWeight: FontWeight.w900,
      preload: true,
    ),
  ],
);
```

Cada página define su título, su descripción y su imagen para redes sociales con `PageMeta`:

```dart
PageMeta meta(PageState<Post> state) => PageMeta(
  title: state.data.title,
  description: state.data.summary,
  canonical: RouteUrl.external('https://myblog.dev/blog/${state.data.slug}'),
  properties: {'og:image': 'https://myblog.dev/og/${state.data.slug}.jpg'},
);
```

Relacionado: [Tema y estilos](../tema-y-estilos.md) · [SEO](../seo.md) · [Compilar y publicar](../publicar.md)
