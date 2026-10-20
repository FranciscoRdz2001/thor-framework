import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('thor_manifest_'));
  tearDown(() => dir.deleteSync(recursive: true));

  File file(String text) =>
      File('${dir.path}/images.json')..writeAsStringSync(text);

  test('reads the file the build wrote', () {
    final path = file(
      jsonEncode({
        'version': 1,
        'images': {
          'images/a.png': {'width': 4, 'height': 2, 'src': 'images/a.png'},
        },
      }),
    ).path;
    final manifest = loadImageManifest(path: path);
    expect(manifest['images/a.png']?.height, 2);
    expect(manifest['/images/a.png']?.width, 4);
    expect(manifest['images/b.png'], isNull);
  });

  test('a named file that is missing throws: never a silent empty', () {
    expect(
      () => loadImageManifest(path: '${dir.path}/nope.json'),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('a file that does not parse throws, naming it', () {
    final path = file('{"version": 1, "images": {"x": {}}}').path;
    expect(
      () => loadImageManifest(path: path),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains(path),
        ),
      ),
    );
  });

  test('variants: by type, narrowest first, AVIF ahead', () {
    const entry = ImageEntry(
      width: 100,
      height: 100,
      src: 'a.png',
      variants: [
        ImageVariant(width: 80, type: 'image/webp', src: 'b'),
        ImageVariant(width: 40, type: 'image/webp', src: 'c'),
        ImageVariant(width: 40, type: 'image/avif', src: 'd'),
      ],
    );
    expect([for (final v in entry.ofType('image/webp')) v.width], [40, 80]);
    expect(entry.types, ['image/avif', 'image/webp']);
  });
}
