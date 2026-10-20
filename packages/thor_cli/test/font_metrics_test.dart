import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:thor_cli/thor_cli.dart';

/// A minimal TrueType font: `head`, `hhea`, `maxp`, `hmtx`, a format 4
/// `cmap` mapping the space and `a`–`z` to glyphs 1–27 with [advance]
/// each, and `OS/2` with [osAverage].
Uint8List ttf({
  int upm = 1000,
  int ascent = 900,
  int descent = -250,
  int lineGap = 50,
  int Function(String char) advance = _fixed,
  bool letters = true,
  int osAverage = 500,
}) {
  const chars = ' abcdefghijklmnopqrstuvwxyz';
  final head = ByteData(54)..setUint16(18, upm);
  final hhea = ByteData(36)
    ..setInt16(4, ascent)
    ..setInt16(6, descent)
    ..setInt16(8, lineGap)
    ..setUint16(34, chars.length + 1);
  final maxp = ByteData(6)..setUint16(4, chars.length + 1);
  final hmtx = ByteData((chars.length + 1) * 4);
  for (var i = 0; i < chars.length; i++) {
    hmtx.setUint16((i + 1) * 4, advance(chars[i]));
  }
  // cmap: one Unicode (3, 1) subtable, format 4, segments: space, a–z, end.
  final segs = letters
      ? [(0x20, 0x20, 1 - 0x20), (0x61, 0x7A, 2 - 0x61), (0xFFFF, 0xFFFF, 1)]
      : [(0xFFFF, 0xFFFF, 1)];
  final sub = ByteData(14 + segs.length * 8 + 2);
  sub
    ..setUint16(0, 4)
    ..setUint16(2, sub.lengthInBytes)
    ..setUint16(6, segs.length * 2);
  for (var s = 0; s < segs.length; s++) {
    final (start, end, delta) = segs[s];
    sub
      ..setUint16(14 + s * 2, end)
      ..setUint16(14 + segs.length * 2 + 2 + s * 2, start)
      ..setInt16(14 + segs.length * 4 + 2 + s * 2, delta);
  }
  final cmap = ByteData(12 + sub.lengthInBytes)
    ..setUint16(2, 1)
    ..setUint16(4, 3)
    ..setUint16(6, 1)
    ..setUint32(8, 12);
  Uint8List.sublistView(cmap).setAll(12, Uint8List.sublistView(sub));
  final os2 = ByteData(4)..setInt16(2, osAverage);
  return sfnt({
    'OS/2': os2,
    'cmap': cmap,
    'head': head,
    'hhea': hhea,
    'hmtx': hmtx,
    'maxp': maxp,
  });
}

int _fixed(String c) => 500;

Uint8List sfnt(Map<String, ByteData> tables) {
  final out = BytesBuilder();
  final header = ByteData(12 + tables.length * 16)
    ..setUint32(0, 0x00010000)
    ..setUint16(4, tables.length);
  var offset = header.lengthInBytes;
  var i = 0;
  for (final MapEntry(:key, :value) in tables.entries) {
    final at = 12 + i++ * 16;
    for (var k = 0; k < 4; k++) {
      header.setUint8(at + k, key.codeUnitAt(k));
    }
    header
      ..setUint32(at + 8, offset)
      ..setUint32(at + 12, value.lengthInBytes);
    offset += value.lengthInBytes;
  }
  out.add(Uint8List.sublistView(header));
  for (final t in tables.values) {
    out.add(Uint8List.sublistView(t));
  }
  return out.toBytes();
}

/// [font] as a WOFF, each table zlib-compressed.
Uint8List woff(Uint8List font) {
  final data = ByteData.sublistView(font);
  final count = data.getUint16(4);
  final dir = ByteData(44 + count * 20)
    ..setUint32(0, 0x774F4646) // wOFF
    ..setUint16(12, count);
  final body = BytesBuilder();
  var offset = dir.lengthInBytes;
  for (var i = 0; i < count; i++) {
    final at = 12 + i * 16;
    final raw = font.sublist(
      data.getUint32(at + 8),
      data.getUint32(at + 8) + data.getUint32(at + 12),
    );
    final packed = ZLibEncoder().convert(raw);
    final r = 44 + i * 20;
    for (var k = 0; k < 4; k++) {
      dir.setUint8(r + k, font[at + k]);
    }
    dir
      ..setUint32(r + 4, offset)
      ..setUint32(r + 8, packed.length)
      ..setUint32(r + 12, raw.length);
    body.add(packed);
    offset += packed.length;
  }
  return Uint8List.fromList([...Uint8List.sublistView(dir), ...body.toBytes()]);
}

Matcher _b013(String what) => throwsA(
  isA<ThorException>().having(
    (e) => e.message,
    'message',
    allOf(contains('THOR-B014'), contains(what)),
  ),
);

void main() {
  test('the average width weighs each letter by how often English uses it', () {
    // Only `e` is wide: the average moves by e's weight, not by 1/27.
    final m = FontMetrics.read(ttf(advance: (c) => c == 'e' ? 1500 : 500));
    expect(m.unitsPerEm, 1000);
    expect((m.ascent, m.descent, m.lineGap), (900, -250, 50));
    // e: 0.1039 of 1.0 (the weights' sum).
    expect(m.xWidthAvg, closeTo(500 + 1000 * 0.1039, 1));
  });

  test('against itself: size-adjust 1 and the plain overrides', () {
    final m = FontMetrics.read(ttf());
    final f = m.fallbackFrom(m);
    expect(f.sizeAdjust, closeTo(1, 1e-9));
    expect(f.ascentOverride, closeTo(0.9, 1e-9));
    expect(f.descentOverride, closeTo(0.25, 1e-9));
    expect(f.lineGapOverride, closeTo(0.05, 1e-9));
  });

  test('a wider web font grows the fallback and shrinks the overrides', () {
    final wide = FontMetrics.read(ttf(advance: (c) => 600));
    final narrow = FontMetrics.read(ttf(advance: (c) => 500));
    final f = wide.fallbackFrom(narrow);
    expect(f.sizeAdjust, closeTo(1.2, 1e-9));
    expect(f.ascentOverride, closeTo(0.9 / 1.2, 1e-9));
  });

  test('a WOFF reads like its TrueType', () {
    final font = ttf(advance: (c) => c == 'a' ? 700 : 450);
    final a = FontMetrics.read(font);
    final b = FontMetrics.read(woff(font));
    expect(b.xWidthAvg, a.xWidthAvg);
    expect((b.unitsPerEm, b.ascent), (a.unitsPerEm, a.ascent));
  });

  test('no Latin letters (an icon font): the OS/2 average', () {
    final m = FontMetrics.read(ttf(letters: false, osAverage: 812));
    expect(m.xWidthAvg, 812);
  });

  test('a WOFF2: THOR-B014, pass the file it was made from', () {
    expect(
      () => FontMetrics.read(
        Uint8List.fromList([...'wOF2'.codeUnits, ...List.filled(40, 0)]),
      ),
      _b013('WOFF2'),
    );
  });

  test('not a font, or cut short: THOR-B014, never a range error', () {
    expect(() => FontMetrics.read(Uint8List(4)), _b013('too short'));
    expect(
      () => FontMetrics.read(Uint8List.fromList('GIF89a......'.codeUnits)),
      _b013('not a TrueType'),
    );
    final cut = ttf();
    expect(
      () => FontMetrics.read(cut.sublist(0, cut.length - 40)),
      _b013('past the end'),
    );
  });

  group('a WOFF2, through fontTools', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('thor_fm_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    String write(String name, List<int> bytes) =>
        (File('${tmp.path}/$name')..writeAsBytesSync(bytes)).path;

    final woff2 = Uint8List.fromList([
      ...'wOF2'.codeUnits,
      ...List.filled(60, 0),
    ]);

    test(
      'converted to an sfnt, then read like the .ttf it came from',
      () async {
        final font = ttf(advance: (c) => c == 'a' ? 700 : 450);
        final path = write('f.woff2', woff2);
        final calls = <List<String>>[];
        final m = await readAnyFontMetrics(
          path,
          run: (exe, args) async {
            calls.add([exe, ...args]);
            File(args.last).writeAsBytesSync(font);
            return ProcessResult(0, 0, '', '');
          },
        );
        expect(calls.single.first, 'python3');
        expect(calls.single, contains(path));
        final direct = FontMetrics.read(font);
        expect(m.xWidthAvg, direct.xWidthAvg);
        expect(m.ascent, direct.ascent);
      },
    );

    test('without fontTools: THOR-B014 says what to install', () async {
      final path = write('f.woff2', woff2);
      await expectLater(
        readAnyFontMetrics(
          path,
          run: (exe, args) async => ProcessResult(
            0,
            1,
            '',
            "ModuleNotFoundError: No module named 'fontTools'",
          ),
        ),
        _b013('pip install fonttools brotli'),
      );
      await expectLater(
        readAnyFontMetrics(
          path,
          run: (exe, args) => throw const ProcessException('python3', []),
        ),
        _b013('pip install fonttools brotli'),
      );
    });

    test('a .ttf never runs anything', () async {
      final path = write('f.ttf', ttf());
      final m = await readAnyFontMetrics(
        path,
        run: (exe, args) => fail('ran $exe'),
      );
      expect(m.unitsPerEm, FontMetrics.read(ttf()).unitsPerEm);
    });
  });

  const arial = '/System/Library/Fonts/Supplemental/Arial.ttf';
  test(
    "the system's Arial matches the built-in reference",
    () {
      final f = readFontMetrics(arial).fallbackFrom(FontMetrics.arial);
      expect(f.sizeAdjust, closeTo(1, 0.001));
    },
    skip: File(arial).existsSync() ? false : 'no Arial.ttf on this system',
  );
}
