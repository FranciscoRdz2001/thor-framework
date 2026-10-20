/// An image the page asks the browser to fetch before it finds it in the
/// document: its main image (`Image(priority: true)`, the LCP). The page
/// writes it as `<link rel=preload as=image>` in its `<head>`, and a server
/// renderer reports it for the `Link` header of the response.
final class ImagePreload {
  /// [href] (the fallback URL), the [srcset]/[sizes] the `<img>` or its
  /// `<source>` has, the [type] of that source (`image/avif`) and the
  /// [media] it applies to (a theme's picture).
  const ImagePreload({
    required this.href,
    this.srcset,
    this.sizes,
    this.type,
    this.media,
  });

  /// The URL.
  final String href;

  /// `imagesrcset`.
  final String? srcset;

  /// `imagesizes`.
  final String? sizes;

  /// Its media type, when the browser picks it by type.
  final String? type;

  /// The media query it is for.
  final String? media;

  /// The `<link>` attributes.
  Map<String, String> get attributes => {
    'rel': 'preload',
    'as': 'image',
    'href': href,
    'imagesrcset': ?srcset,
    'imagesizes': ?sizes,
    'type': ?type,
    'media': ?media,
    'fetchpriority': 'high',
  };

  @override
  bool operator ==(Object other) =>
      other is ImagePreload &&
      other.href == href &&
      other.srcset == srcset &&
      other.sizes == sizes &&
      other.type == type &&
      other.media == media;

  @override
  int get hashCode => Object.hash(href, srcset, sizes, type, media);
}
