/// Responsive images at build time: `web/images/**` → WebP
/// variants per width, content-hashed, next to the original, plus the
/// manifest (`build/images.json`) the renderer reads to write `srcset`,
/// `sizes` and the intrinsic `width`/`height` of `Image.asset`.
///
/// Never in the browser and never per request: the build encodes once
/// (cached in `.dart_tool/thor/images/`); `thor dev` only measures, so a
/// page has the same sizes in dev and in release, without the encoding.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:thor_engine/fingerprint.dart' show contentHash;
import 'package:thor_server/thor_server.dart'
    show ImageEntry, ImageManifest, ImageVariant, imageManifestPath;
import 'package:yaml/yaml.dart';

import 'errors.dart';
import 'run.dart';
import 'workspace.dart';

/// The folder of `web/` whose images the build processes.
const imagesDir = 'images';

/// Extensions the build measures; all but `.gif` also get variants (an
/// animated GIF, WebP or APNG would lose its frames; a JPEG with a turned EXIF
/// orientation keeps only its original).
const _raster = {'.jpg', '.jpeg', '.png', '.webp', '.gif'};

/// An image's intrinsic size, px.
typedef ImageSize = ({int width, int height});

/// The size [bytes] declare (PNG, JPEG, WebP, GIF headers), or `null` when
/// they are none of those or are cut short: the file is never decoded.
ImageSize? readImageSize(Uint8List bytes) {
  int u16be(int i) => bytes[i] << 8 | bytes[i + 1];
  int u16le(int i) => bytes[i] | bytes[i + 1] << 8;
  int u24le(int i) => bytes[i] | bytes[i + 1] << 8 | bytes[i + 2] << 16;
  int u32be(int i) =>
      bytes[i] << 24 | bytes[i + 1] << 16 | bytes[i + 2] << 8 | bytes[i + 3];
  bool at(int i, List<int> magic) {
    if (bytes.length < i + magic.length) return false;
    for (var k = 0; k < magic.length; k++) {
      if (bytes[i + k] != magic[k]) return false;
    }
    return true;
  }

  ImageSize? valid(int w, int h) =>
      w > 0 && h > 0 ? (width: w, height: h) : null;

  // PNG: signature, then IHDR (width, height as big-endian u32).
  if (at(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    if (bytes.length < 24 || !at(12, 'IHDR'.codeUnits)) return null;
    return valid(u32be(16), u32be(20));
  }
  // GIF: logical screen size (little-endian u16).
  if (at(0, 'GIF87a'.codeUnits) || at(0, 'GIF89a'.codeUnits)) {
    if (bytes.length < 10) return null;
    return valid(u16le(6), u16le(8));
  }
  // WebP: RIFF….WEBP, then a VP8 / VP8L / VP8X chunk.
  if (at(0, 'RIFF'.codeUnits) && at(8, 'WEBP'.codeUnits)) {
    if (bytes.length < 30) return null;
    if (at(12, 'VP8 '.codeUnits)) {
      if (!at(23, const [0x9D, 0x01, 0x2A])) return null;
      return valid(u16le(26) & 0x3FFF, u16le(28) & 0x3FFF);
    }
    if (at(12, 'VP8L'.codeUnits)) {
      if (bytes[20] != 0x2F) return null;
      final b = bytes;
      final w = 1 + (b[21] | (b[22] & 0x3F) << 8);
      final h = 1 + ((b[22] >> 6) | b[23] << 2 | (b[24] & 0x0F) << 10);
      return valid(w, h);
    }
    if (at(12, 'VP8X'.codeUnits)) {
      return valid(1 + u24le(24), 1 + u24le(27));
    }
    return null;
  }
  // JPEG: walk the segments to the first start-of-frame.
  if (at(0, const [0xFF, 0xD8])) {
    var i = 2;
    while (i + 9 < bytes.length) {
      if (bytes[i] != 0xFF) return null;
      final marker = bytes[i + 1];
      if (marker == 0xFF) {
        i++; // fill byte
        continue;
      }
      // Standalone markers carry no length.
      if (marker == 0xD8 || (marker >= 0xD0 && marker <= 0xD7)) {
        i += 2;
        continue;
      }
      final length = u16be(i + 2);
      if (length < 2) return null;
      final isFrame =
          marker >= 0xC0 &&
          marker <= 0xCF &&
          marker != 0xC4 &&
          marker != 0xC8 &&
          marker != 0xCC;
      if (isFrame) {
        final w = u16be(i + 7), h = u16be(i + 5);
        // EXIF orientations 5-8 turn the picture a quarter: the displayed
        // width is the stored height.
        return jpegOrientation(bytes) >= 5 ? valid(h, w) : valid(w, h);
      }
      i += 2 + length;
    }
    return null;
  }
  return null;
}

/// The EXIF orientation (1-8) of a JPEG, `1` when it has none or [bytes]
/// are not a JPEG. 1 is upright; 2-4 mirror/rotate 180; 5-8 turn a quarter
/// (width and height swap on display).
int jpegOrientation(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return 1;
  var i = 2;
  while (i + 4 <= bytes.length) {
    if (bytes[i] != 0xFF) return 1;
    final marker = bytes[i + 1];
    if (marker == 0xFF) {
      i++;
      continue;
    }
    if (marker == 0xD8 || (marker >= 0xD0 && marker <= 0xD7)) {
      i += 2;
      continue;
    }
    // Start of scan or end of image: no metadata after it.
    if (marker == 0xDA || marker == 0xD9) return 1;
    final length = bytes[i + 2] << 8 | bytes[i + 3];
    if (length < 2) return 1;
    final end = i + 2 + length;
    if (marker == 0xE1) {
      final o = _exifOrientation(
        bytes,
        i + 4,
        end > bytes.length ? bytes.length : end,
      );
      if (o != null) return o;
    }
    i = end;
  }
  return 1;
}

/// The orientation in the APP1 payload `bytes[start, end)`, or `null` when
/// it is not an Exif block with one.
int? _exifOrientation(Uint8List bytes, int start, int end) {
  const exif = [0x45, 0x78, 0x69, 0x66, 0, 0]; // "Exif\0\0"
  if (end - start < 14) return null;
  for (var k = 0; k < exif.length; k++) {
    if (bytes[start + k] != exif[k]) return null;
  }
  final tiff = start + 6;
  final little = bytes[tiff] == 0x49 && bytes[tiff + 1] == 0x49;
  if (!little && !(bytes[tiff] == 0x4D && bytes[tiff + 1] == 0x4D)) {
    return null;
  }
  int u16(int i) =>
      little ? bytes[i] | bytes[i + 1] << 8 : bytes[i] << 8 | bytes[i + 1];
  int u32(int i) =>
      little ? u16(i) | u16(i + 2) << 16 : u16(i) << 16 | u16(i + 2);
  final ifd = tiff + u32(tiff + 4);
  if (ifd < tiff || ifd + 2 > end) return null;
  final count = u16(ifd);
  for (var n = 0; n < count; n++) {
    final entry = ifd + 2 + n * 12;
    if (entry + 12 > end) return null;
    if (u16(entry) == 0x0112) {
      final v = u16(entry + 8);
      return v >= 1 && v <= 8 ? v : null;
    }
  }
  return null;
}

/// Whether [bytes] are an animated WebP (VP8X with the animation flag) or
/// an APNG (an `acTL` chunk before the first `IDAT`): re-encoding either
/// loses its frames.
bool isAnimatedImage(Uint8List bytes) {
  bool at(int i, List<int> magic) {
    if (bytes.length < i + magic.length) return false;
    for (var k = 0; k < magic.length; k++) {
      if (bytes[i + k] != magic[k]) return false;
    }
    return true;
  }

  if (at(0, 'RIFF'.codeUnits) && at(8, 'WEBP'.codeUnits)) {
    return at(12, 'VP8X'.codeUnits) &&
        bytes.length > 20 &&
        bytes[20] & 0x02 != 0;
  }
  if (at(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    var i = 8;
    while (i + 8 <= bytes.length) {
      final length =
          bytes[i] << 24 |
          bytes[i + 1] << 16 |
          bytes[i + 2] << 8 |
          bytes[i + 3];
      if (at(i + 4, 'acTL'.codeUnits)) return true;
      if (at(i + 4, 'IDAT'.codeUnits)) return false;
      i += 12 + length;
    }
  }
  return false;
}

/// What the pubspec asks for:
///
/// ```yaml
/// thor:
///   images:
///     widths: [640, 1280, 1920]   # the variants' widths, px
///     quality: 80                 # WebP quality, 1–100
///     formats: [webp, avif]       # AVIF too (needs ImageMagick with AVIF)
///     avif_quality: 50            # AVIF quality, 1–100
/// ```
///
/// Declared, a missing encoder fails the build (THOR-B010, THOR-B013 for
/// AVIF); left out, the defaults apply and a missing encoder is a warning
/// (sizes only).
class ImagesConfig {
  /// The config.
  const ImagesConfig({
    this.widths = defaultWidths,
    this.quality = 80,
    this.avif = false,
    this.avifQuality = 50,
    this.declared = false,
  });

  /// Widths when the pubspec names none.
  static const defaultWidths = [640, 1280, 1920];

  /// The variants' widths, ascending (an image narrower than one gets its
  /// own width instead: never upscaled).
  final List<int> widths;

  /// WebP quality.
  final int quality;

  /// AVIF quality (`-quality` of ImageMagick): 50 looks like WebP at 80
  /// and weighs about half.
  final int avifQuality;

  /// Whether AVIF variants are made too (`formats: [webp, avif]`).
  final bool avif;

  /// Whether the pubspec has a `thor.images` section.
  final bool declared;

  /// The config of [project]'s pubspec.
  factory ImagesConfig.of(Project project) {
    final pubspec = loadYaml(
      File(project.path('pubspec.yaml')).readAsStringSync(),
    );
    final thor = pubspec is YamlMap ? pubspec['thor'] : null;
    final images = thor is YamlMap ? thor['images'] : null;
    if (images == null) return const ImagesConfig();
    ThorException bad(String what) =>
        ThorException('thor.images in pubspec.yaml: $what');
    if (images is! YamlMap) {
      throw bad('must be a map (widths, quality, formats)');
    }
    for (final key in images.keys) {
      if (!const {
        'widths',
        'quality',
        'formats',
        'avif_quality',
      }.contains(key)) {
        throw bad(
          'unknown key "$key" (widths, quality, formats, avif_quality)',
        );
      }
    }
    final formats = images['formats'] ?? const ['webp'];
    if (formats is! List ||
        !formats.contains('webp') ||
        formats.any((f) => f != 'webp' && f != 'avif')) {
      throw bad('formats must list webp, and may add avif');
    }
    final rawWidths = images['widths'] ?? defaultWidths;
    if (rawWidths is! List ||
        rawWidths.isEmpty ||
        rawWidths.any((w) => w is! int || w < 16 || w > 8192)) {
      throw bad('widths must be a list of px between 16 and 8192');
    }
    final quality = images['quality'] ?? 80;
    if (quality is! int || quality < 1 || quality > 100) {
      throw bad('quality must be an integer from 1 to 100');
    }
    final avifQuality = images['avif_quality'] ?? 50;
    if (avifQuality is! int || avifQuality < 1 || avifQuality > 100) {
      throw bad('avif_quality must be an integer from 1 to 100');
    }
    return ImagesConfig(
      widths: ({for (final w in rawWidths) w as int}.toList()..sort()),
      quality: quality,
      avif: formats.contains('avif'),
      avifQuality: avifQuality,
      declared: true,
    );
  }
}

/// Runs an encoder: `(executable, args)` → throws on failure.
typedef Encode = Future<void> Function(String executable, List<String> args);

Future<void> _run(String executable, List<String> args) async {
  final r = await Process.run(executable, args);
  if (r.exitCode != 0) {
    throw ThorException(
      '$executable ${args.join(' ')} failed (${r.exitCode})\n${r.stderr}',
    );
  }
}

/// The path of [tool] on `PATH`, or `null`.
String? findTool(String tool) {
  final r = Process.runSync('which', [tool]);
  final out = (r.stdout as String).trim();
  return r.exitCode == 0 && out.isNotEmpty ? out : null;
}

/// An ImageMagick on `PATH` that writes AVIF (`magick -list format` says
/// so), or `null`. ImageMagick, not `avifenc`: it resizes too.
String? findAvifEncoder() {
  final magick = findTool('magick');
  if (magick == null) return null;
  final r = Process.runSync(magick, ['-list', 'format']);
  if (r.exitCode != 0) return null;
  final writes = RegExp(r'^\s*AVIF\*?\s+\S+\s+r?w', multiLine: true);
  return writes.hasMatch(r.stdout as String) ? magick : null;
}

/// The build's image step.
class ImagePipeline {
  /// A pipeline for [project] with [config]; [cwebp] and [magick] are the
  /// encoders' paths (`null`: none installed), [encode] how they run.
  ImagePipeline(
    this.project, {
    ImagesConfig? config,
    String? cwebp,
    String? magick,
    bool findEncoder = true,
    Encode? encode,
  }) : config = config ?? ImagesConfig.of(project),
       cwebp = cwebp ?? (findEncoder ? findTool('cwebp') : null),
       _magick = magick,
       _findEncoder = findEncoder,
       _encode = encode ?? _run;

  /// The project.
  final Project project;

  /// What its pubspec asks for.
  final ImagesConfig config;

  /// The WebP encoder, or `null`.
  final String? cwebp;

  final String? _magick;
  final bool _findEncoder;

  /// The AVIF encoder (an ImageMagick that writes AVIF), or `null`; looked
  /// up only when the config asks for AVIF.
  late final String? magick =
      _magick ?? (_findEncoder && config.avif ? findAvifEncoder() : null);

  final Encode _encode;

  /// The images of `web/images/`, site-relative (`images/hero.jpg`).
  List<String> sources() {
    final dir = Directory(project.path(p.join('web', imagesDir)));
    if (!dir.existsSync()) return const [];
    return [
      for (final f in dir.listSync(recursive: true).whereType<File>())
        if (_raster.contains(p.extension(f.path).toLowerCase()))
          p.posix.joinAll(
            p.split(p.relative(f.path, from: project.path('web'))),
          ),
    ]..sort();
  }

  /// Every image measured, no variants: what `thor dev` serves, so a page
  /// has the same `width`/`height` as in release.
  ImageManifest measure() => ImageManifest({
    for (final name in sources()) name: _entry(name, _size(name)),
  });

  /// Measures every image and writes its WebP variants into [siteDir]
  /// (`build/site` or `build/public`), next to where `web/` is copied.
  Future<ImageManifest> build(String siteDir) async {
    final names = sources();
    if (names.isEmpty) return ImageManifest.empty;
    final encoder = cwebp;
    if (encoder == null) {
      final message = thorError(
        'THOR-B010',
        'no cwebp on PATH: install libwebp (brew install webp, '
            'apt install webp) for the image variants',
      );
      if (config.declared) throw ThorException(message);
      Say.warn('$message; only their sizes this time.');
      return measure();
    }
    final avifEncoder = config.avif ? magick : null;
    if (config.avif && avifEncoder == null) {
      throw ThorException(
        thorError(
          'THOR-B013',
          'thor.images.formats asks for avif and no ImageMagick on PATH '
              'writes AVIF (brew install imagemagick, apt install '
              'imagemagick libheif1)',
        ),
      );
    }
    final cache = Directory(project.path('.dart_tool/thor/images'))
      ..createSync(recursive: true);
    final images = <String, ImageEntry>{};
    for (final name in names) {
      final size = _size(name);
      final source = File(project.path(p.join('web', name)));
      final raw = source.readAsBytesSync();
      if (p.extension(name).toLowerCase() == '.gif' ||
          // web: cwebp ignores EXIF orientation and drops it, so a
          // rotated JPEG would come out sideways; the original (which the
          // browser rotates) is the only honest source.
          jpegOrientation(raw) > 1 ||
          // web: cwebp rejects an animated WebP and keeps one frame of an
          // APNG; both stay as they are.
          isAnimatedImage(raw)) {
        images[name] = _entry(name, size);
        continue;
      }
      final original = raw.length;
      final input = contentHash(raw);
      final variants = <ImageVariant>[];
      for (final width in _targets(size.width)) {
        final cached = File(
          p.join(cache.path, '$input-$width-q${config.quality}.webp'),
        );
        if (!cached.existsSync()) {
          final tmp = File('${cached.path}.tmp');
          await _encode(encoder, [
            '-quiet',
            '-mt',
            '-q',
            '${config.quality}',
            if (width < size.width) ...['-resize', '$width', '0'],
            source.path,
            '-o',
            tmp.path,
          ]);
          tmp.renameSync(cached.path);
        }
        final bytes = cached.readAsBytesSync();
        // At the image's own width, a WebP no smaller than the original
        // (a flat PNG) is dropped: the original is the better file.
        if (width == size.width && bytes.length >= original) continue;
        // Named by what it is made from (the source and the parameters),
        // not by the encoder's bytes: the same HTML on every machine,
        // whatever its cwebp version, and a new name when the source or
        // the parameters change.
        final stem = p.posix.withoutExtension(name);
        final key = contentHash(
          utf8.encode('$input|$width|q${config.quality}|webp'),
        );
        final src = '$stem-$width.$key.webp';
        final out = File(p.join(siteDir, src));
        out.parent.createSync(recursive: true);
        out.writeAsBytesSync(bytes);
        variants.add(ImageVariant(width: width, type: 'image/webp', src: src));
      }
      if (avifEncoder != null) {
        variants.addAll(
          await _avif(avifEncoder, siteDir, name, source, input, size, {
            for (final v in variants)
              v.width: File(p.join(siteDir, v.src)).lengthSync(),
          }, original),
        );
      }
      images[name] = _entry(name, size, variants);
    }
    return ImageManifest(images);
  }

  /// The AVIF variants of [name]: the same widths as its WebP ones, each
  /// kept only when smaller than the WebP of that width ([webp], width →
  /// its size) or, without one, than the original.
  Future<List<ImageVariant>> _avif(
    String encoder,
    String siteDir,
    String name,
    File source,
    String input,
    ImageSize size,
    Map<int, int> webp,
    int original,
  ) async {
    final cache = project.path('.dart_tool/thor/images');
    final out = <ImageVariant>[];
    for (final width in _targets(size.width)) {
      final cached = File(
        p.join(cache, '$input-$width-q${config.avifQuality}.avif'),
      );
      if (!cached.existsSync()) {
        final tmp = '${cached.path}.tmp';
        await _encode(encoder, [
          source.path,
          if (width < size.width) ...['-resize', '${width}x'],
          '-quality',
          '${config.avifQuality}',
          'avif:$tmp',
        ]);
        File(tmp).renameSync(cached.path);
      }
      final bytes = cached.readAsBytesSync();
      if (bytes.length >= (webp[width] ?? original)) continue;
      final stem = p.posix.withoutExtension(name);
      final key = contentHash(
        utf8.encode('$input|$width|q${config.avifQuality}|avif'),
      );
      final src = '$stem-$width.$key.avif';
      File(p.join(siteDir, src))
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(bytes);
      out.add(ImageVariant(width: width, type: 'image/avif', src: src));
    }
    return out;
  }

  /// The widths to make for an image [width] px wide: the configured ones
  /// below it, plus its own width (never upscaled).
  List<int> _targets(int width) => {
    for (final w in config.widths)
      if (w < width) w,
    width,
  }.toList()..sort();

  ImageSize _size(String name) {
    final file = File(project.path(p.join('web', name)));
    final size = readImageSize(file.readAsBytesSync());
    if (size == null) {
      throw ThorException(
        thorError(
          'THOR-B011',
          'web/$name is not a PNG, JPEG, WebP or GIF the build can read '
              '(cut short, or another format with that extension)',
        ),
      );
    }
    return size;
  }

  static ImageEntry _entry(
    String name,
    ImageSize size, [
    List<ImageVariant> variants = const [],
  ]) => ImageEntry(
    width: size.width,
    height: size.height,
    src: name,
    variants: variants,
  );
}

/// Writes [manifest] to [path] (sorted JSON: same images, same bytes).
void writeImageManifest(ImageManifest manifest, String path) {
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(manifest.toJson()),
    );
}

/// Where a build leaves an app's manifest.
String buildManifestPath(Project project) => project.path(imageManifestPath);

/// Where `thor dev` leaves the measured manifest.
String devManifestPath(Project project) =>
    project.path('.dart_tool/thor/images.json');
