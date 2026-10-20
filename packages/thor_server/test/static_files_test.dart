import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('thor_static_');
    File('${dir.path}/app.css').writeAsStringSync('body{}');
    Directory('${dir.path}/img').createSync();
    File('${dir.path}/img/a b.svg').writeAsStringSync('<svg/>');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('an indexed folder serves its files, nested and with spaces', () async {
    final files = StaticFiles(dir.path, index: true);
    expect((await files.lookup('/app.css', null, null))!.status, 200);
    expect((await files.lookup('/img/a%20b.svg', null, null))!.status, 200);
    expect(await files.lookup('/tag/css', null, null), isNull);
    expect(await files.lookup('/img', null, null), isNull);
  });

  test('a trailing slash on the root changes nothing', () async {
    final files = StaticFiles('${dir.path}/', index: true);
    expect((await files.lookup('/app.css', null, null))!.status, 200);
  });

  test('indexed: a file added after the first request is not served', () async {
    final files = StaticFiles(dir.path, index: true);
    expect(await files.lookup('/late.js', null, null), isNull);
    File('${dir.path}/late.js').writeAsStringSync('1');
    expect(await files.lookup('/late.js', null, null), isNull);
  });

  test('not indexed (thor dev): the disk answers every request', () async {
    final files = StaticFiles(dir.path, index: false);
    expect(await files.lookup('/late.js', null, null), isNull);
    File('${dir.path}/late.js').writeAsStringSync('1');
    expect((await files.lookup('/late.js', null, null))!.status, 200);
  });

  test('an indexed file deleted later is a miss, not an error', () async {
    final files = StaticFiles(dir.path, index: true);
    expect((await files.lookup('/app.css', null, null))!.status, 200);
    File('${dir.path}/app.css').deleteSync();
    expect(await files.lookup('/app.css', null, null), isNull);
  });

  group('compressed representations', () {
    setUp(() => File('${dir.path}/big.css').writeAsStringSync('a{b:c}' * 400));

    test('Vary on the plain 200, the gzip 200 and the 304', () async {
      final files = StaticFiles(dir.path, index: true);
      final plain = (await files.lookup('/big.css', null, null))!;
      final zipped = (await files.lookup('/big.css', 'gzip', null))!;
      final etag = plain.headers['etag']!;
      final cached = (await files.lookup('/big.css', 'gzip', etag))!;
      for (final r in [plain, zipped, cached]) {
        expect(r.headers['vary'], 'Accept-Encoding');
      }
      expect(cached.status, 304);
    });

    test('the gzip body has a weak tag, the plain one a strong tag', () async {
      final files = StaticFiles(dir.path, index: true);
      final plain = (await files.lookup('/big.css', null, null))!;
      final zipped = (await files.lookup('/big.css', 'gzip', null))!;
      expect(plain.headers['etag'], startsWith('"'));
      expect(zipped.headers['etag'], 'W/${plain.headers['etag']}');
      // Weak comparison: the tag of either body validates both.
      final again = await files.lookup(
        '/big.css',
        'gzip',
        zipped.headers['etag'],
      );
      expect(again!.status, 304);
    });

    test('no Vary on a file that is never compressed', () async {
      final files = StaticFiles(dir.path, index: true);
      final r = await files.lookup('/app.css', 'gzip', null);
      expect(r!.headers['vary'], isNull);
    });
  });

  test('a missing root serves nothing', () async {
    final files = StaticFiles('${dir.path}/nope', index: true);
    expect(await files.lookup('/app.css', null, null), isNull);
  });

  test('outside the root is never served, indexed or not', () async {
    for (final index in [true, false]) {
      final files = StaticFiles('${dir.path}/img', index: index);
      expect(await files.lookup('/../app.css', null, null), isNull);
    }
  });

  // A path that doesn't decode is no file (the router answers it), never
  // an exception (a 500 before the request reached the handler).
  test('a path with invalid UTF-8 or a broken escape is no file', () async {
    final files = StaticFiles(dir.path, index: false);
    expect(await files.lookup('/%FF', null, null), isNull);
    expect(await files.lookup('/img/%E0%A4', null, null), isNull);
  });
}
