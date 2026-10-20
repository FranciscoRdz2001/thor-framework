import 'package:thor_server/image_manifest.dart' show ImageEntry;
import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/image_manifest_scope.dart';
import '../foundation/image_preload.dart';
import '../foundation/page_navigation.dart' show RoutedPageScope;
import '../foundation/parent_data.dart' show WrapData, WrapWith;
import '../foundation/style_registry.dart'
    show ConditionalCss, CssCondition, ThorStyleRegistry, themeToggleId;
import 'basic.dart' show SizedBox;

/// Flutter's `ImageErrorWidgetBuilder`: the widget shown when the image
/// fails to load.
typedef ImageErrorWidgetBuilder =
    Widget Function(BuildContext context, Object error, StackTrace? stackTrace);

/// Flutter's `ImageLoadingBuilder`: the widget shown while the image loads.
typedef ImageLoadingBuilder =
    Widget Function(
      BuildContext context,
      Widget child,
      ImageChunkEvent? loadingProgress,
    );

/// Flutter's `ImageChunkEvent`: how much of an image has arrived.
class ImageChunkEvent {
  /// Creates a progress report.
  const ImageChunkEvent({
    required this.cumulativeBytesLoaded,
    this.expectedTotalBytes,
  });

  /// The bytes loaded so far.
  final int cumulativeBytesLoaded;

  /// The size of the image, when known (the browser doesn't say).
  final int? expectedTotalBytes;
}

/// What `Image(errorBuilder:)` receives as its `error`: the browser reports
/// that the image failed, not why (a 404, a network error and an invalid
/// file look the same).
class ImageLoadError implements Exception {
  /// An image that failed to load from [url].
  const ImageLoadError(this.url);

  /// The URL (or asset name) of the image.
  final String url;

  @override
  String toString() => 'ImageLoadError: the image at $url failed to load';
}

/// Flutter's `Image` (`.network` / `.asset`) → `<img>`.
///
/// `// web:` on by default: `loading="lazy"` and `decoding="async"`.
/// Pass [width] and [height] when known to avoid layout shift (CLS).
///
/// An [Image.asset] the build knows (`web/images/`) gets them
/// from the image manifest: its intrinsic `width`/`height` (when the app
/// passes neither; with one, the other keeps the ratio), and a `srcset`
/// of its WebP variants with `sizes`, so the browser downloads the
/// smallest file that fills the slot.
///
/// When there is a choice of files beyond the width (AVIF variants, or a
/// [dark] picture) the image is a `<picture>`: `<source>`s the browser
/// picks from, and the `<img>`. One file is downloaded.
class Image extends StatelessWidget implements ThorElementWidget, ThorBuiltIn {
  /// Creates an image from the URL [src].
  const Image.network(
    this.src, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.lazy = true,
    this.srcSet = const {},
    this.sizes,
    this.priority = false,
    this.dark,
    this.errorBuilder,
    this.loadingBuilder,
  }) : _asset = false;

  /// [name] is resolved relative to the site root, e.g. `images/logo.png`.
  const Image.asset(
    String name, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.lazy = true,
    this.srcSet = const {},
    this.sizes,
    this.priority = false,
    this.dark,
    this.errorBuilder,
    this.loadingBuilder,
  }) : src = name,
       _asset = true;

  /// The image URL.
  final String src;

  /// Same as Flutter's `Image.width`.
  final double? width;

  /// Same as Flutter's `Image.height`.
  final double? height;

  /// Same as Flutter's `Image.fit` (`object-fit`).
  final BoxFit? fit;

  /// Same as Flutter's `Image.alignment` (`object-position`).
  final Alignment alignment;

  /// Accessible name (`alt`); omitted, the image is decorative.
  final String? semanticLabel;

  /// Whether to defer loading until near the viewport (`loading="lazy"`).
  ///
  /// web: only an image with explicit dimensions (its `width` and `height`, the
  /// build manifest's, or a wrapper's) is deferred: one without them loads
  /// eagerly, as the browser warns about a lazy one and its late load shifts
  /// the layout. For unsized images eager and lazy tie on CLS and LCP, because a lazy image with no height
  /// counts as visible and is fetched anyway; eager only delays the `load`
  /// event.
  final bool lazy;

  // web: not in Flutter.
  /// The same picture at other widths (px → URL), so the browser
  /// downloads the smallest one that fills the slot (`srcset`), e.g.
  /// `{640: 'hero-640.webp', 1250: 'hero.webp'}`. [src] stays the fallback.
  final Map<int, String> srcSet;

  // web: not in Flutter.
  /// How wide the image is drawn (`sizes`). Default with a
  /// finite [width]: that width, or the viewport when narrower.
  final String? sizes;

  // web: not in Flutter.
  /// The page's main image (its largest paint, LCP): fetched
  /// first (`fetchpriority="high"`), never deferred ([lazy] ignored), and
  /// preloaded (a `<link rel=preload>` in the `<head>` and the `Link`
  /// header of the response).
  final bool priority;

  // web: not in Flutter.
  /// The same picture for the dark theme (same aspect ratio): a
  /// URL for [Image.network], an asset name for [Image.asset]. Only the
  /// file of the theme showing is downloaded: the system's on load, the
  /// other one if the page's `ThemeToggle` flips it.
  ///
  /// `// web:` in Flutter the app would pick the file from `Theme.of`.
  final String? dark;

  /// What to show when the image fails to load (a 404, a network error).
  ///
  /// ```dart
  /// Image.network(url, errorBuilder: (context, error, stack) => const Icon(Icons.broken_image))
  /// ```
  ///
  /// web: the server can't know the image will fail, so the fallback is
  /// rendered next to the image and CSS hides it; the `<img>` tells its frame
  /// when it fails (an inline `onerror` attribute: no script file, no engine)
  /// and the frame swaps the two. Without JavaScript, or with a strict
  /// Content-Security-Policy that blocks inline handlers, the fallback never
  /// shows and the browser's own broken image (with its `alt`) does.
  /// The `error` is an [ImageLoadError]: the browser doesn't say why it failed
  /// and there is no stack trace.
  final ImageErrorWidgetBuilder? errorBuilder;

  /// What to show while the image loads.
  ///
  /// web: the builder is called once, for the loading state
  /// (`loadingProgress` is never null and `child` is empty: the image is
  /// not repeated), and its widget sits behind the `<img>`, in the same
  /// cell, until the image fires `load` (an inline `onload` attribute). An
  /// opaque image covers it even without JavaScript; a transparent one shows
  /// it through. The builder can't show progress (the browser gives none).
  final ImageLoadingBuilder? loadingBuilder;

  final bool _asset;

  static const _prefersDark = '(prefers-color-scheme: dark)';

  static const _onError =
      "this.closest('[data-ib]').setAttribute('data-broken','')";
  static const _onLoad =
      "this.closest('[data-ib]').setAttribute('data-loaded','')";

  @override
  Widget build(BuildContext context) {
    final image = _image(context);
    if (errorBuilder == null && loadingBuilder == null) return image;
    // The frame both builders' widgets live in, beside the image: the
    // `<img>` says when it failed or loaded (its handlers), and the frame's
    // own CSS swaps what shows.
    final error = errorBuilder;
    final loading = loadingBuilder;
    return thorElement(
      'span',
      debugName: 'ImageFrame',
      css: {
        // A cell every child shares: the placeholder behind the image, the
        // fallback in its place.
        'display': 'grid',
        'max-width': '100%',
        'width': width != null && !width!.isFinite ? '100%' : 'fit-content',
      },
      conditions: [
        const ConditionalCss(CssCondition.children, {
          'grid-area': '1 / 1',
          'min-width': '0',
        }),
        if (error != null) ...const [
          ConditionalCss(
            CssCondition.selector(':not([data-broken]) > [data-fb]'),
            {'display': 'none !important'},
          ),
          ConditionalCss(
            CssCondition.selector('[data-broken] > :not([data-fb])'),
            {'display': 'none !important'},
          ),
        ],
        if (loading != null)
          const ConditionalCss(
            CssCondition.selector('[data-loaded] > [data-ph]'),
            {'display': 'none !important'},
          ),
      ],
      attributes: const {'data-ib': ''},
      children: [
        if (loading != null)
          WrapWith(
            const WrapData(attributes: {'data-ph': ''}),
            child: loading(
              context,
              const SizedBox(),
              const ImageChunkEvent(cumulativeBytesLoaded: 0),
            ),
          ),
        image,
        if (error != null)
          WrapWith(
            const WrapData(attributes: {'data-fb': ''}),
            child: error(context, ImageLoadError(src), null),
          ),
      ],
    );
  }

  Widget _image(BuildContext context) {
    final manifest = _asset ? ImageManifestScope.maybeOf(context) : null;
    // web: a routed page has no `<base href>` (a form's `?/send` and a
    // `#anchor` must resolve against the page's own URL), so an asset's
    // relative name would load from under the page's path
    // (`/servicios/images/x.jpg`): under the router it goes from the root,
    // like the engine's `/engine.dart.js`. A loose page (`Document`, with
    // `<base href="/">`) keeps the name's form.
    final rooted = _asset && RoutedPageScope.isRouted(context);
    final entry = manifest == null ? null : manifest[src];
    final darkEntry = manifest == null || dark == null ? null : manifest[dark!];
    // The manifest's intrinsic size fills what the app didn't write, the
    // missing side keeping the image's ratio.
    final double? w;
    final double? h;
    var intrinsic = false;
    if (entry == null || (width != null && height != null)) {
      (w, h) = (width, height);
    } else if (width != null && width!.isFinite) {
      (w, h) = (width, (width! * entry.height / entry.width).roundToDouble());
    } else if (height != null && height!.isFinite) {
      (w, h) = ((height! * entry.width / entry.height).roundToDouble(), height);
    } else {
      (w, h) = (entry.width.toDouble(), entry.height.toDouble());
      intrinsic = width == null && height == null;
    }
    final set = srcSet.isNotEmpty
        ? srcSet
        : _variants(entry, 'image/webp', rooted);
    final avif = srcSet.isNotEmpty
        ? const <int, String>{}
        : _variants(entry, 'image/avif', rooted);
    final sizesValue =
        sizes ??
        (width != null && width!.isFinite
            ? '(min-width: ${cssPx(width!)}) ${cssPx(width!)}, 100vw'
            : '100vw');
    final scalesDown =
        fit == null && w != null && h != null && w.isFinite && h.isFinite;
    final explicit = _hasExplicitSize(
      context,
      w: w,
      h: h,
      scalesDown: scalesDown,
    );
    final src0 = !_asset
        ? src
        : entry != null
        ? _siteUrl(entry.src, rooted)
        : _assetName(src, rooted);
    final darkWebp = _variants(darkEntry, 'image/webp', rooted);
    // [darkFile]: the dark picture's file; [twin]: a copy hidden until the
    // theme switch shows it (deferred: never downloaded before).
    Map<String, String> imgAttributes({
      bool darkFile = false,
      bool twin = false,
    }) => {
      'src': darkFile ? _darkUrl(darkEntry, rooted) : src0,
      if (darkFile ? darkWebp : set case final s when s.isNotEmpty) ...{
        'srcset': _srcset(s),
        'sizes': sizesValue,
      },
      // Empty alt = decorative image; screen readers skip it.
      'alt': semanticLabel ?? '',
      if (priority && !twin)
        'fetchpriority': 'high'
      else if ((lazy && explicit) || twin)
        'loading': 'lazy',
      'decoding': 'async',
      // Beside the image, a fallback and a placeholder are told how it goes.
      if (!twin) ...{
        // With no errorBuilder a failure still ends the loading: the
        // placeholder goes and the browser's broken image shows.
        if (errorBuilder != null)
          'onerror': _onError
        else if (loadingBuilder != null)
          'onerror': _onLoad,
        if (loadingBuilder != null) 'onload': _onLoad,
      },
      if (w != null && w != double.infinity) 'width': cssNum(w),
      if (h != null && h != double.infinity) 'height': cssNum(h),
    };

    final imgCss = <String, String>{
      'display': 'block',
      // Flutter's parent constraints cap the image's width.
      'max-width': '100%',
      if (width != null) 'width': cssPx(width!),
      // web: with both sizes and no fit, a capped image keeps its aspect
      // ratio (Flutter would letterbox it inside the fixed height).
      if (scalesDown && !intrinsic) ...{
        'height': 'auto',
        'aspect-ratio': '${cssNum(w)} / ${cssNum(h)}',
      } else if (intrinsic) ...{
        // Only the intrinsic size: `height: auto` keeps its ratio, spelled
        // out (with just the attributes the browser sees no dimensions).
        'height': 'auto',
        'aspect-ratio': '${cssNum(w!)} / ${cssNum(h!)}',
      } else if (height != null)
        'height': cssPx(height!),
      ..._fitCss,
    };

    if (dark == null && avif.isEmpty) {
      if (priority) {
        _preload(context, src: src0, srcset: set, sizes: sizesValue);
      }
      return thorElement(
        'img',
        debugName: 'Image',
        css: imgCss,
        attributes: imgAttributes(),
      );
    }

    // A <picture>: the <img> inside keeps the size rules it has alone (a
    // replaced element: a percentage lets it shrink in a narrow parent);
    // the box around it (what wrappers fuse into) only hugs it.
    final boxCss = <String, String>{
      'display': 'block',
      'max-width': '100%',
      'width': width != null && !width!.isFinite ? '100%' : 'fit-content',
    };
    final darkAvif = _variants(darkEntry, 'image/avif', rooted);
    // What the browser picks from, in order (the first that matches): the
    // system's scheme picks the dark files, else the light <img>.
    final picture = thorElement(
      'picture',
      debugName: dark == null ? 'Image' : 'ImagePicture',
      css: dark == null ? boxCss : const {'display': 'block'},
      conditions: [
        // The switch flipped the theme: a twin shows the other file.
        if (dark != null)
          const ConditionalCss(
            CssCondition.within(':root:has(#$themeToggleId:checked)'),
            {'display': 'none'},
          ),
      ],
      children: [
        if (dark != null) ...[
          if (darkAvif.isNotEmpty)
            _source(darkAvif, sizesValue, media: _prefersDark, avif: true),
          _source(
            darkWebp.isEmpty ? {0: _darkUrl(darkEntry, rooted)} : darkWebp,
            sizesValue,
            media: _prefersDark,
          ),
        ],
        if (avif.isNotEmpty) _source(avif, sizesValue, avif: true),
        thorElement(
          'img',
          debugName: 'ImageImg',
          css: imgCss,
          attributes: imgAttributes(),
        ),
      ],
    );
    // The flipped theme's file: a lazy <img>, hidden until the switch
    // shows it. With AVIF files it is a <picture> whose one <source> has no
    // `media`: a `media` that matches makes the preload scanner fetch it
    // before it reads the <img>'s `loading`; without one, Chromium and
    // WebKit fetch nothing until the copy shows, then the AVIF.
    Widget twin({required bool darkFile}) {
      final show = ConditionalCss(
        darkFile ? CssCondition.switchedToDark : CssCondition.switchedToLight,
        const {'display': 'block'},
      );
      final twinAvif = darkFile ? darkAvif : avif;
      if (twinAvif.isEmpty) {
        return thorElement(
          'img',
          debugName: 'ImageTwin',
          css: {...imgCss, 'display': 'none'},
          conditions: [show],
          attributes: imgAttributes(darkFile: darkFile, twin: true),
        );
      }
      return thorElement(
        'picture',
        debugName: 'ImageTwin',
        css: const {'display': 'none'},
        conditions: [show],
        children: [
          _source(twinAvif, sizesValue, avif: true),
          thorElement(
            'img',
            debugName: 'ImageTwinImg',
            css: imgCss,
            attributes: imgAttributes(darkFile: darkFile, twin: true),
          ),
        ],
      );
    }

    if (priority) {
      if (dark == null) {
        _preload(
          context,
          src: src0,
          srcset: avif,
          sizes: sizesValue,
          avif: true,
        );
      } else {
        final darkBest = darkAvif.isNotEmpty ? darkAvif : darkWebp;
        _preload(
          context,
          src: _darkUrl(darkEntry, rooted),
          srcset: darkBest,
          sizes: sizesValue,
          avif: darkAvif.isNotEmpty,
          media: _prefersDark,
        );
        _preload(
          context,
          src: src0,
          srcset: avif.isNotEmpty ? avif : set,
          sizes: sizesValue,
          avif: avif.isNotEmpty,
          media: 'not all and $_prefersDark',
        );
      }
    }
    if (dark == null) return picture;
    return thorElement(
      'span',
      debugName: 'Image',
      css: boxCss,
      children: [picture, twin(darkFile: true), twin(darkFile: false)],
    );
  }

  /// Whether the browser sees explicit dimensions on the `<img>`: both its
  /// width and height, or one of them and an aspect ratio, from the image's
  /// own props, the manifest or the wrappers fused into it. Chromium warns
  /// ("Lazy-loaded images should have explicit dimensions") about a lazy
  /// image without them, and its late load shifts the layout.
  ///
  /// web: a lazy image of unknown size loads eagerly instead, so its
  /// size (`width`/`height`, or `AspectRatio`) is what makes it lazy.
  bool _hasExplicitSize(
    BuildContext context, {
    required double? w,
    required double? h,
    required bool scalesDown,
  }) {
    var hasWidth = width != null || w != null;
    var hasHeight = height != null || h != null;
    var ratio = scalesDown;
    // The wrappers around it become its own class when it is the element
    // (not behind an error/loading frame, not inside a <picture>).
    if (errorBuilder == null && loadingBuilder == null) {
      final pending = ChildRulesScope.maybeOf(context)?.pending;
      if (pending != null) {
        for (final css in [pending.baseCss, pending.classCss, pending.css]) {
          if (_given(css['width'])) hasWidth = true;
          if (_given(css['height'])) hasHeight = true;
          if (_given(css['aspect-ratio'])) ratio = true;
        }
      }
    }
    return (hasWidth && hasHeight) || ((hasWidth || hasHeight) && ratio);
  }

  static bool _given(String? value) => value != null && value != 'auto';

  CssDeclarations get _fitCss => {
    if (fit != null) 'object-fit': fit!.css,
    if (alignment != Alignment.center) 'object-position': alignment.cssPosition,
  };

  Map<int, String> _variants(ImageEntry? entry, String type, bool rooted) =>
      entry == null
      ? const {}
      : {for (final v in entry.ofType(type)) v.width: _siteUrl(v.src, rooted)};

  String _darkUrl(ImageEntry? darkEntry, bool rooted) => darkEntry != null
      ? _siteUrl(darkEntry.src, rooted)
      : _asset
      ? _assetName(dark ?? src, rooted)
      : dark ?? src;

  static String _srcset(Map<int, String> set) => [
    for (final e in set.entries) e.key == 0 ? e.value : '${e.value} ${e.key}w',
  ].join(', ');

  static Widget _source(
    Map<int, String> set,
    String sizes, {
    String? media,
    bool avif = false,
  }) => Widget.element(
    tag: 'source',
    attributes: {
      if (avif) 'type': 'image/avif',
      'media': ?media,
      'srcset': _srcset(set),
      if (!set.containsKey(0)) 'sizes': sizes,
    },
  );

  static void _preload(
    BuildContext context, {
    required String src,
    required Map<int, String> srcset,
    required String sizes,
    bool avif = false,
    String? media,
  }) => ThorStyleRegistry.active(context)?.addImagePreload(
    ImagePreload(
      href: src,
      srcset: srcset.isEmpty ? null : _srcset(srcset),
      sizes: srcset.isEmpty ? null : sizes,
      type: avif && srcset.isNotEmpty ? 'image/avif' : null,
      media: media,
    ),
  );

  // The manifest's paths are site-relative; the app's name keeps its form
  // (`images/x.jpg` or `/images/x.jpg`), except under the router ([rooted]).
  String _siteUrl(String path, bool rooted) =>
      rooted || src.startsWith('/') ? '/$path' : path;

  // An asset's own name (no manifest entry): from the root under the
  // router, as written elsewhere. A URL or a `data:` one is left alone.
  static String _assetName(String name, bool rooted) =>
      rooted &&
          !name.startsWith('/') &&
          !name.contains('://') &&
          !name.startsWith('data:')
      ? '/$name'
      : name;
}
