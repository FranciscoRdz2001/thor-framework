import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thor_cli/src/images.dart';
import 'package:thor_cli/src/run.dart';
import 'package:thor_cli/src/workspace.dart';

/// A valid PNG of [width]×[height], one flat color (so it encodes fast).
Uint8List png(int width, int height) {
  int crc(List<int> bytes) {
    var c = 0xFFFFFFFF;
    for (final b in bytes) {
      c ^= b;
      for (var k = 0; k < 8; k++) {
        c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
      }
    }
    return c ^ 0xFFFFFFFF;
  }

  List<int> u32(int v) => [v >> 24 & 255, v >> 16 & 255, v >> 8 & 255, v & 255];
  List<int> chunk(String type, List<int> data) {
    final body = [...type.codeUnits, ...data];
    return [...u32(data.length), ...body, ...u32(crc(body))];
  }

  final row = [
    0,
    for (var x = 0; x < width; x++) ...[40, 120, 200],
  ];
  final raw = [for (var y = 0; y < height; y++) ...row];
  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    ...chunk('IHDR', [...u32(width), ...u32(height), 8, 2, 0, 0, 0]),
    ...chunk('IDAT', ZLibEncoder().convert(raw)),
    ...chunk('IEND', const []),
  ]);
}

/// A 4032x3008 JPEG whose EXIF says [orientation].
Uint8List jpegWithOrientation(int orientation, {bool big = false}) {
  List<int> u16(int v) => big ? [v >> 8, v & 255] : [v & 255, v >> 8];
  final tiff = [
    ...(big ? [0x4D, 0x4D] : [0x49, 0x49]),
    ...u16(42),
    ...(big ? [0, 0, 0, 8] : [8, 0, 0, 0]),
    ...u16(1), // one entry
    ...u16(0x0112), ...u16(3), ...(big ? [0, 0, 0, 1] : [1, 0, 0, 0]),
    ...u16(orientation), 0, 0,
    0, 0, 0, 0, // next IFD
  ];
  final app1 = [...'Exif'.codeUnits, 0, 0, ...tiff];
  return Uint8List.fromList([
    0xFF, 0xD8, //
    0xFF, 0xE1, (app1.length + 2) >> 8, (app1.length + 2) & 255, ...app1,
    0xFF, 0xC0, 0x00, 0x11, 0x08, 0x0B, 0xC0, 0x0F, 0xC0, // 4032x3008
    ...List.filled(12, 0),
  ]);
}

void main() {
  group('readImageSize', () {
    test('PNG', () {
      expect(readImageSize(png(33, 7)), (width: 33, height: 7));
    });

    test('GIF', () {
      final gif = Uint8List.fromList([...'GIF89a'.codeUnits, 0x2C, 1, 0x10, 0]);
      expect(readImageSize(gif), (width: 300, height: 16));
    });

    test('JPEG: skips the segments before the frame', () {
      final jpeg = Uint8List.fromList([
        0xFF, 0xD8, //
        0xFF, 0xE0, 0x00, 0x04, 0x00, 0x00, // APP0, 2 bytes of data
        0xFF, 0xC0, 0x00, 0x11, 0x08, 0x02, 0x58, 0x03, 0x20, // SOF0 800×600
        ...List.filled(12, 0),
      ]);
      expect(readImageSize(jpeg), (width: 800, height: 600));
    });

    test('JPEG: EXIF orientation 5-8 swaps width and height', () {
      expect(readImageSize(jpegWithOrientation(1)), (
        width: 4032,
        height: 3008,
      ));
      expect(readImageSize(jpegWithOrientation(3)), (
        width: 4032,
        height: 3008,
      ));
      expect(readImageSize(jpegWithOrientation(6)), (
        width: 3008,
        height: 4032,
      ));
      expect(readImageSize(jpegWithOrientation(8, big: true)), (
        width: 3008,
        height: 4032,
      ));
      expect(jpegOrientation(jpegWithOrientation(6)), 6);
    });

    test('WebP: VP8, VP8L and VP8X', () {
      Uint8List riff(String chunk, List<int> data) => Uint8List.fromList([
        ...'RIFF'.codeUnits,
        0,
        0,
        0,
        0,
        ...'WEBP'.codeUnits,
        ...chunk.codeUnits,
        0,
        0,
        0,
        0,
        ...data,
        ...List.filled(8, 0),
      ]);
      // VP8: keyframe tag, start code, 14-bit width and height.
      expect(
        readImageSize(
          riff('VP8 ', [0, 0, 0, 0x9D, 0x01, 0x2A, 0x40, 0x01, 0xF0, 0x00]),
        ),
        (width: 320, height: 240),
      );
      // VP8L: signature 0x2F, then (width-1, height-1) in 14 bits each.
      const w = 100 - 1, h = 50 - 1;
      const bits = w | h << 14;
      expect(
        readImageSize(
          riff('VP8L', [
            0x2F,
            bits & 255,
            bits >> 8 & 255,
            bits >> 16 & 255,
            bits >> 24 & 255,
          ]),
        ),
        (width: 100, height: 50),
      );
      // VP8X: flags, then (width-1, height-1) in 24 bits each.
      expect(
        readImageSize(riff('VP8X', [0, 0, 0, 0, 0xFF, 0x03, 0, 0xFF, 0x01, 0])),
        (width: 1024, height: 512),
      );
    });

    test('cut short or another format: null, never a throw', () {
      expect(readImageSize(Uint8List.fromList([0x89, 0x50])), isNull);
      expect(readImageSize(png(10, 10).sublist(0, 20)), isNull);
      expect(readImageSize(Uint8List.fromList([0xFF, 0xD8, 0xFF])), isNull);
      expect(readImageSize(utf8.encode('<svg></svg>')), isNull);
      expect(readImageSize(Uint8List(0)), isNull);
    });
  });

  group('the pipeline', () {
    late Directory dir;
    late Project project;
    late List<List<String>> encoded;

    void image(String name, List<int> bytes) =>
        File(p.join(dir.path, 'web', 'images', name))
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes);
    void pubspec([String thor = '']) => File(
      p.join(dir.path, 'pubspec.yaml'),
    ).writeAsStringSync('name: app\n$thor');

    /// An encoder that writes [size] bytes where cwebp would.
    Encode fake([int size = 10]) => (exe, args) async {
      encoded.add(args);
      File(args.last).writeAsBytesSync(List.filled(size, 1));
    };

    setUp(() {
      dir = Directory.systemTemp.createTempSync('thor_images_');
      pubspec();
      project = Project(dir.path);
      encoded = [];
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('widths below the image, plus its own; never upscaled', () async {
      image('hero.png', png(1000, 500));
      final site = p.join(dir.path, 'build', 'site');
      final manifest = await ImagePipeline(
        project,
        cwebp: 'cwebp',
        encode: fake(),
      ).build(site);
      final entry = manifest['images/hero.png']!;
      expect((entry.width, entry.height), (1000, 500));
      // 640 < 1000; 1280 and 1920 would upscale: the image's 1000 instead.
      expect([for (final v in entry.variants) v.width], [640, 1000]);
      expect(entry.src, 'images/hero.png');
      for (final v in entry.variants) {
        expect(v.src, matches(RegExp(r'^images/hero-\d+\.[0-9a-f]{8}\.webp$')));
        expect(File(p.join(site, v.src)).existsSync(), isTrue);
      }
      // Resized below its width, encoded as is at its width.
      expect(encoded.first, containsAllInOrder(['-resize', '640', '0']));
      expect(encoded.last, isNot(contains('-resize')));
    });

    test('a variant is named by its source and parameters, not by the '
        'encoder\'s bytes (the same HTML with any cwebp)', () async {
      image('hero.png', png(700, 100));
      Future<List<String>> names(int size, String out) async {
        final m = await ImagePipeline(
          project,
          cwebp: 'cwebp',
          encode: fake(size),
        ).build(p.join(dir.path, out));
        return [for (final v in m['images/hero.png']!.variants) v.src];
      }

      final first = await names(10, 'a');
      Directory(p.join(dir.path, '.dart_tool')).deleteSync(recursive: true);
      expect(await names(20, 'b'), first);
      // Another quality: other files, other names.
      pubspec('thor:\n  images:\n    quality: 50\n');
      final other = await ImagePipeline(
        Project(dir.path),
        cwebp: 'cwebp',
        encode: fake(),
      ).build(p.join(dir.path, 'c'));
      expect([
        for (final v in other['images/hero.png']!.variants) v.src,
      ], isNot(first));
    });

    test('an image narrower than every width gets only its own', () async {
      image('icon.png', png(120, 120));
      final manifest = await ImagePipeline(
        project,
        cwebp: 'cwebp',
        encode: fake(),
      ).build(p.join(dir.path, 'out'));
      expect(
        [for (final v in manifest['images/icon.png']!.variants) v.width],
        [120],
      );
    });

    test('a WebP no smaller than the original is dropped', () async {
      final original = png(64, 64);
      image('flat.png', original);
      final manifest = await ImagePipeline(
        project,
        cwebp: 'cwebp',
        encode: fake(original.length + 1),
      ).build(p.join(dir.path, 'out'));
      expect(manifest['images/flat.png']!.variants, isEmpty);
    });

    test('a GIF is measured, never encoded (its frames)', () async {
      image('anim.gif', [...'GIF89a'.codeUnits, 10, 0, 20, 0]);
      final manifest = await ImagePipeline(
        project,
        cwebp: 'cwebp',
        encode: fake(),
      ).build(p.join(dir.path, 'out'));
      expect(manifest['images/anim.gif']!.width, 10);
      expect(encoded, isEmpty);
    });

    test('a JPEG turned by EXIF is measured upright, never encoded', () async {
      image('phone.jpg', jpegWithOrientation(6));
      final manifest = await ImagePipeline(
        project,
        cwebp: 'cwebp',
        encode: fake(),
      ).build(p.join(dir.path, 'out'));
      expect(manifest['images/phone.jpg']!.width, 3008);
      expect(manifest['images/phone.jpg']!.height, 4032);
      expect(manifest['images/phone.jpg']!.variants, isEmpty);
      expect(encoded, isEmpty);
    });

    test('an animated WebP or APNG is measured, never encoded', () async {
      // VP8X with the animation flag (0x02), 100x50.
      image('anim.webp', [
        ...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits,
        ...'VP8X'.codeUnits, 10, 0, 0, 0, 0x02, 0, 0, 0, //
        99, 0, 0, 49, 0, 0, ...List.filled(8, 0),
      ]);
      // A PNG with an acTL chunk before IDAT.
      final plain = png(64, 32);
      final actl = <int>[
        0, 0, 0, 8, ...'acTL'.codeUnits, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, //
      ];
      image('anim.png', [
        ...plain.sublist(0, 33),
        ...actl,
        ...plain.sublist(33),
      ]);
      final manifest = await ImagePipeline(
        project,
        cwebp: 'cwebp',
        encode: fake(),
      ).build(p.join(dir.path, 'out'));
      expect(manifest['images/anim.webp']!.width, 100);
      expect(manifest['images/anim.webp']!.variants, isEmpty);
      expect(manifest['images/anim.png']!.variants, isEmpty);
      expect(encoded, isEmpty);
    });

    test('the cache: a second build encodes nothing', () async {
      image('hero.png', png(700, 100));
      final pipeline = ImagePipeline(project, cwebp: 'cwebp', encode: fake());
      await pipeline.build(p.join(dir.path, 'a'));
      final first = encoded.length;
      await pipeline.build(p.join(dir.path, 'b'));
      expect(first, 2);
      expect(encoded.length, first);
    });

    test('an image it cannot read stops the build: THOR-B011', () async {
      image('broken.jpg', [0xFF, 0xD8, 0xFF, 0xE0]);
      expect(
        () => ImagePipeline(
          project,
          cwebp: 'cwebp',
          encode: fake(),
        ).build(p.join(dir.path, 'out')),
        throwsA(
          isA<ThorException>().having(
            (e) => e.message,
            'message',
            allOf(contains('web/images/broken.jpg'), contains('THOR-B011')),
          ),
        ),
      );
    });

    test('no encoder, nothing declared: a warning and only sizes', () async {
      image('hero.png', png(900, 300));
      final manifest = await ImagePipeline(
        project,
        findEncoder: false,
      ).build(p.join(dir.path, 'out'));
      expect(manifest['images/hero.png']!.width, 900);
      expect(manifest['images/hero.png']!.variants, isEmpty);
    });

    test('no encoder, images declared: the build stops (THOR-B010)', () {
      pubspec('thor:\n  images:\n    widths: [320]\n');
      image('hero.png', png(900, 300));
      expect(
        () => ImagePipeline(
          Project(dir.path),
          findEncoder: false,
        ).build(p.join(dir.path, 'out')),
        throwsA(
          isA<ThorException>().having(
            (e) => e.message,
            'message',
            contains('THOR-B010'),
          ),
        ),
      );
    });

    /// cwebp writes [webp] bytes, ImageMagick (`avif:<path>`) [avif].
    Encode both({int webp = 10, int avif = 5}) => (exe, args) async {
      encoded.add([exe, ...args]);
      final out = args.last.startsWith('avif:')
          ? args.last.substring(5)
          : args.last;
      File(out).writeAsBytesSync(List.filled(exe == 'magick' ? avif : webp, 1));
    };

    test('formats [webp, avif]: an AVIF of every WebP width', () async {
      pubspec('thor:\n  images:\n    formats: [webp, avif]\n');
      image('hero.png', png(1000, 500));
      final site = p.join(dir.path, 'build', 'site');
      final entry = (await ImagePipeline(
        Project(dir.path),
        cwebp: 'cwebp',
        magick: 'magick',
        encode: both(),
      ).build(site))['images/hero.png']!;
      expect(
        [for (final v in entry.ofType('image/webp')) v.width],
        [640, 1000],
      );
      final avif = entry.ofType('image/avif');
      expect([for (final v in avif) v.width], [640, 1000]);
      for (final v in avif) {
        expect(v.src, matches(RegExp(r'^images/hero-\d+\.[0-9a-f]{8}\.avif$')));
        expect(File(p.join(site, v.src)).lengthSync(), 5);
      }
      final magick = encoded.where((e) => e.first == 'magick').toList();
      expect(magick.first, containsAllInOrder(['-resize', '640x']));
      expect(magick.first, containsAllInOrder(['-quality', '50']));
      expect(magick.last, isNot(contains('-resize')));
    });

    test('an AVIF no smaller than the WebP of its width is dropped', () async {
      pubspec('thor:\n  images:\n    formats: [webp, avif]\n');
      image('hero.png', png(1000, 500));
      final entry = (await ImagePipeline(
        Project(dir.path),
        cwebp: 'cwebp',
        magick: 'magick',
        encode: both(webp: 10, avif: 10),
      ).build(p.join(dir.path, 'out')))['images/hero.png']!;
      expect(entry.ofType('image/avif'), isEmpty);
      expect(entry.ofType('image/webp'), hasLength(2));
    });

    test('AVIF asked, no encoder that writes it: THOR-B013', () {
      pubspec('thor:\n  images:\n    formats: [webp, avif]\n');
      image('hero.png', png(900, 300));
      expect(
        () => ImagePipeline(
          Project(dir.path),
          cwebp: 'cwebp',
          findEncoder: false,
          encode: both(),
        ).build(p.join(dir.path, 'out')),
        throwsA(
          isA<ThorException>().having(
            (e) => e.message,
            'message',
            contains('THOR-B013'),
          ),
        ),
      );
    });

    test('dev measures only, whatever the encoder', () {
      image('hero.png', png(900, 300));
      final manifest = ImagePipeline(project, findEncoder: false).measure();
      expect(manifest['images/hero.png']!.height, 300);
      expect(encoded, isEmpty);
    });

    test('images outside web/images and other files are not its', () async {
      File(p.join(dir.path, 'web', 'og.png'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(png(10, 10));
      image('notes.txt', utf8.encode('hi'));
      expect(ImagePipeline(project, findEncoder: false).sources(), isEmpty);
    });

    test('the manifest file: sorted, the same bytes on a rebuild', () async {
      image('b.png', png(20, 10));
      image('a.png', png(10, 20));
      final path = p.join(dir.path, 'build', 'images.json');
      final pipeline = ImagePipeline(project, findEncoder: false);
      writeImageManifest(pipeline.measure(), path);
      final first = File(path).readAsStringSync();
      writeImageManifest(pipeline.measure(), path);
      expect(File(path).readAsStringSync(), first);
      expect(first.indexOf('images/a.png'), lessThan(first.indexOf('b.png')));
    });
  });

  group('the pubspec config', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('thor_images_'));
    tearDown(() => dir.deleteSync(recursive: true));

    ImagesConfig config(String thor) {
      File(
        p.join(dir.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: app\nthor:\n$thor');
      return ImagesConfig.of(Project(dir.path));
    }

    test('defaults when left out', () {
      File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('name: app\n');
      final c = ImagesConfig.of(Project(dir.path));
      expect(c.declared, isFalse);
      expect(c.widths, ImagesConfig.defaultWidths);
    });

    test('formats: AVIF only when asked, its own quality', () {
      expect(config('  images:\n    widths: [320]\n').avif, isFalse);
      final c = config(
        '  images:\n    formats: [webp, avif]\n    avif_quality: 45\n',
      );
      expect(c.avif, isTrue);
      expect(c.avifQuality, 45);
      expect(config('  images:\n    formats: [webp, avif]\n').avifQuality, 50);
    });

    test('widths sorted and deduplicated, quality kept', () {
      final c = config(
        '  images:\n    widths: [1280, 320, 1280]\n    quality: 70\n',
      );
      expect(c.widths, [320, 1280]);
      expect(c.quality, 70);
      expect(c.declared, isTrue);
    });

    for (final (yaml, what) in [
      ('  images: yes\n', 'must be a map'),
      ('  images:\n    widths: []\n', 'widths'),
      ('  images:\n    widths: [8]\n', 'widths'),
      ('  images:\n    widths: [a]\n', 'widths'),
      ('  images:\n    quality: 0\n', 'quality'),
      ('  images:\n    formats: [avif]\n', 'formats must list webp'),
      ('  images:\n    formats: [webp, jxl]\n', 'formats must list webp'),
      ('  images:\n    avif_quality: 101\n', 'avif_quality'),
      ('  images:\n    sizes: [1]\n', 'unknown key'),
    ]) {
      test('rejects ${yaml.trim().replaceAll('\n', ' ')}', () {
        expect(
          () => config(yaml),
          throwsA(
            isA<ThorException>().having(
              (e) => e.message,
              'message',
              contains(what),
            ),
          ),
        );
      });
    }
  });

  final cwebp = findTool('cwebp');
  test(
    'with the real cwebp: smaller WebP variants that read back',
    () async {
      final dir = Directory.systemTemp.createTempSync('thor_images_');
      addTearDown(() => dir.deleteSync(recursive: true));
      File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync('name: app\n');
      final source = png(1400, 700);
      File(p.join(dir.path, 'web', 'images', 'wide.png'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(source);
      final site = p.join(dir.path, 'site');
      final manifest = await ImagePipeline(Project(dir.path)).build(site);
      final entry = manifest['images/wide.png']!;
      expect([for (final v in entry.variants) v.width], [640, 1280, 1400]);
      for (final v in entry.variants) {
        final bytes = File(p.join(site, v.src)).readAsBytesSync();
        expect(readImageSize(bytes)?.width, v.width);
        expect(bytes.length, lessThan(source.length));
      }
    },
    skip: cwebp == null ? 'cwebp is not installed' : false,
  );

  final magick = findAvifEncoder();
  test(
    'with a real ImageMagick: AVIF variants smaller than the WebP ones',
    () async {
      final dir = Directory.systemTemp.createTempSync('thor_images_');
      addTearDown(() => dir.deleteSync(recursive: true));
      File(p.join(dir.path, 'pubspec.yaml')).writeAsStringSync(
        'name: app\nthor:\n  images:\n    widths: [640]\n'
        '    formats: [webp, avif]\n',
      );
      File(p.join(dir.path, 'web', 'images', 'wide.png'))
        ..createSync(recursive: true)
        ..writeAsBytesSync(png(1400, 700));
      final site = p.join(dir.path, 'site');
      final entry = (await ImagePipeline(
        Project(dir.path),
      ).build(site))['images/wide.png']!;
      final webp = {
        for (final v in entry.ofType('image/webp'))
          v.width: File(p.join(site, v.src)).lengthSync(),
      };
      expect(entry.ofType('image/avif'), isNotEmpty);
      for (final v in entry.ofType('image/avif')) {
        final bytes = File(p.join(site, v.src)).readAsBytesSync();
        // ISO BMFF: a `ftyp` box of brand avif.
        expect(String.fromCharCodes(bytes.sublist(4, 12)), 'ftypavif');
        expect(bytes.length, lessThan(webp[v.width]!));
      }
    },
    skip: cwebp == null || magick == null
        ? 'cwebp or an ImageMagick with AVIF is not installed'
        : false,
  );
}
