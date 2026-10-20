/// The image manifest: the contract between the build, which makes each
/// image's variants, and the renderer, which writes `srcset`, `sizes` and
/// the intrinsic `width`/`height` of `Image.asset`.
///
/// ```json
/// {"version": 1, "images": {
///   "images/hero.jpg": {"width": 2400, "height": 1600, "src": "images/hero-1280.3f9a1c2e.webp",
///     "variants": [{"width": 640, "type": "image/webp", "src": "images/hero-640.0b1d2e3f.webp"},
///                  {"width": 1280, "type": "image/webp", "src": "images/hero-1280.3f9a1c2e.webp"}]}}}
/// ```
///
/// Keys are the names an app passes to `Image.asset` (site-relative, no
/// leading slash). `src` is the fallback the `<img>` keeps; `variants`
/// are sorted by type then width. A manifest with no variants (`thor dev`,
/// or a build without an encoder) still gives the sizes, so the page never
/// shifts while an image loads.
///
/// No `dart:io` here: the widget that reads it also compiles for the
/// browser. Loading it from a file is `loadImageManifest` of
/// `package:thor_server/thor_server.dart`.
library;

/// Every image a build knows, by the name `Image.asset` uses.
class ImageManifest {
  /// A manifest with [images].
  const ImageManifest(this.images);

  /// No images: `Image.asset` renders what the app wrote.
  static const empty = ImageManifest({});

  /// Name → its entry.
  final Map<String, ImageEntry> images;

  /// The entry of [name] (with or without a leading `/`), or `null`.
  ImageEntry? operator [](String name) =>
      images[name.startsWith('/') ? name.substring(1) : name];

  /// Whether it knows no image.
  bool get isEmpty => images.isEmpty;

  /// Reads the JSON the build writes. A shape it doesn't know throws a
  /// [FormatException] naming the entry.
  factory ImageManifest.fromJson(Object? json) {
    if (json is! Map || json['version'] != 1 || json['images'] is! Map) {
      throw const FormatException(
        'not an image manifest (expected {"version": 1, "images": {...}})',
      );
    }
    return ImageManifest({
      for (final MapEntry(:key, :value) in (json['images'] as Map).entries)
        key as String: ImageEntry._fromJson(key, value),
    });
  }

  /// The JSON the build writes (keys sorted, so a rebuild of the same
  /// images writes the same bytes).
  Map<String, Object?> toJson() => {
    'version': 1,
    'images': {
      for (final name in images.keys.toList()..sort())
        name: images[name]!.toJson(),
    },
  };
}

/// One image: its intrinsic size and the files the build made from it.
class ImageEntry {
  /// An image [width]×[height] px whose fallback is [src].
  const ImageEntry({
    required this.width,
    required this.height,
    required this.src,
    this.variants = const [],
  });

  /// Intrinsic width, px.
  final int width;

  /// Intrinsic height, px.
  final int height;

  /// The file the `<img>` keeps in `src` (site-relative).
  final String src;

  /// The same picture at other widths or formats.
  final List<ImageVariant> variants;

  /// The media types of [variants], in order (`image/avif` first when the
  /// build made it: the `<source>` the browser tries first).
  List<String> get types {
    final all = {for (final v in variants) v.type}.toList();
    int rank(String t) => t == 'image/avif' ? 0 : 1;
    return all..sort((a, b) => rank(a).compareTo(rank(b)));
  }

  /// The variants of [type], narrowest first.
  List<ImageVariant> ofType(String type) => [
    for (final v in variants)
      if (v.type == type) v,
  ]..sort((a, b) => a.width.compareTo(b.width));

  static ImageEntry _fromJson(String name, Object? json) {
    FormatException bad(String what) =>
        FormatException('image manifest: "$name" $what');
    if (json is! Map) throw bad('is not an object');
    final width = json['width'];
    final height = json['height'];
    final src = json['src'];
    if (width is! int || width <= 0 || height is! int || height <= 0) {
      throw bad('needs a positive integer width and height');
    }
    if (src is! String || src.isEmpty) throw bad('needs a src');
    final raw = json['variants'] ?? const <Object?>[];
    if (raw is! List) throw bad('has variants that are not a list');
    return ImageEntry(
      width: width,
      height: height,
      src: src,
      variants: [for (final v in raw) ImageVariant._fromJson(name, v)],
    );
  }

  /// Its JSON.
  Map<String, Object?> toJson() => {
    'width': width,
    'height': height,
    'src': src,
    if (variants.isNotEmpty) 'variants': [for (final v in variants) v.toJson()],
  };
}

/// A file the build made from an image: [width] px wide, of [type].
class ImageVariant {
  /// A variant at [src].
  const ImageVariant({
    required this.width,
    required this.type,
    required this.src,
  });

  /// Its width, px (its height keeps the image's ratio).
  final int width;

  /// Its media type (`image/webp`, `image/avif`, `image/jpeg`…).
  final String type;

  /// Where it is (site-relative, content-hashed).
  final String src;

  static ImageVariant _fromJson(String name, Object? json) {
    if (json is! Map ||
        json['width'] is! int ||
        (json['width'] as int) <= 0 ||
        json['type'] is! String ||
        json['src'] is! String) {
      throw FormatException(
        'image manifest: "$name" has a variant without width, type and src',
      );
    }
    return ImageVariant(
      width: json['width'] as int,
      type: json['type'] as String,
      src: json['src'] as String,
    );
  }

  /// Its JSON.
  Map<String, Object?> toJson() => {'width': width, 'type': type, 'src': src};
}
