# Content page

A landing page, a blog or a documentation page that loads fast, indexes well and reads without JavaScript.

:::flutter Flutter: `Scaffold`, `ListView` and `Image.network` · Thor: the same tree, exported as HTML

:::bench recipe-content-page
:::

## First screen first

The main image loads without deferring (`lazy: false`) and carries `width` and `height` so the page doesn't shift when it loads. The rest of the images use `lazy: true`, the default value.

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

`srcSet` and `sizes` let the browser download only the width it needs. Sections further down go in a `LazyLayout`, which the browser doesn't paint until they get close to the screen:

```dart
LazyLayout(extentEstimate: 900, child: const ContactSection())
```

> **Important:** Don't use `LazyLayout` on the first screen or in sections whose shadow extends beyond their box.

## Theme, fonts and metadata

A `ThemeData` describes the brand, with a custom font served from your domain. Preload only the font for the first-screen text.

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

Each page defines its title, its description and its social media image with `PageMeta`:

```dart
PageMeta meta(PageState<Post> state) => PageMeta(
  title: state.data.title,
  description: state.data.summary,
  canonical: RouteUrl.external('https://myblog.dev/blog/${state.data.slug}'),
  properties: {'og:image': 'https://myblog.dev/og/${state.data.slug}.jpg'},
);
```

Related: [Theme and styles](../theme-and-styles.md) · [SEO](../seo.md) · [Build and deploy](../build-and-deploy.md)
