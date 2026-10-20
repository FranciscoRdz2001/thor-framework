/// `thor fonts metrics`: the numbers a `FontFallback` needs, read from the
/// font's own tables (`head`, `hhea`, `cmap`, `hmtx`), so the local font
/// that shows while the web font loads takes the same room and the text
/// doesn't move when it swaps in.
///
/// The same method as capsize/fontaine: `size-adjust` is the ratio of the
/// fonts' average character widths (glyph advances weighted by how often
/// each letter appears in English text), and the ascent, descent and line
/// gap overrides are the web font's `hhea` values over its em, scaled by
/// that `size-adjust`.
library;

import 'dart:io';
import 'dart:typed_data';

import 'errors.dart';
import 'run.dart';

/// What `FontFallback` takes, as fractions (`1.07` = 107 %).
typedef FallbackMetrics = ({
  double sizeAdjust,
  double ascentOverride,
  double descentOverride,
  double lineGapOverride,
});

/// A font's vertical metrics and average width, in font units.
class FontMetrics {
  /// Metrics of a font with [unitsPerEm].
  const FontMetrics({
    required this.unitsPerEm,
    required this.ascent,
    required this.descent,
    required this.lineGap,
    required this.xWidthAvg,
  });

  /// Font units per em (`head.unitsPerEm`).
  final int unitsPerEm;

  /// `hhea.ascender`.
  final int ascent;

  /// `hhea.descender` (negative: below the baseline).
  final int descent;

  /// `hhea.lineGap`.
  final int lineGap;

  /// The average advance of `a`–`z` and the space, weighted by their
  /// frequency in English.
  final double xWidthAvg;

  /// Arial, the default `FontFallback.local` (what this tool reads from
  /// the system's Arial.ttf: 2048 units per em).
  static const arial = FontMetrics(
    unitsPerEm: 2048,
    ascent: 1854,
    descent: -434,
    lineGap: 67,
    xWidthAvg: 903.45,
  );

  /// The `FontFallback` that makes [fallback] take this font's room.
  FallbackMetrics fallbackFrom(FontMetrics fallback) {
    final sizeAdjust =
        (xWidthAvg / unitsPerEm) / (fallback.xWidthAvg / fallback.unitsPerEm);
    double over(int units) => units.abs() / (unitsPerEm * sizeAdjust);
    return (
      sizeAdjust: sizeAdjust,
      ascentOverride: over(ascent),
      descentOverride: over(descent),
      lineGapOverride: over(lineGap),
    );
  }

  /// Reads [bytes]: a TrueType or OpenType font (`.ttf`, `.otf`) or a
  /// WOFF (`.woff`). A WOFF2 needs a Brotli decoder the Dart SDK doesn't
  /// have: [readAnyFontMetrics] converts it first, else THOR-B014.
  factory FontMetrics.read(Uint8List bytes, {String name = 'font'}) {
    final tables = _tables(bytes, name);
    ThorException bad(String what) => ThorException(
      thorError('THOR-B014', '$name: $what (not a font thor can read)'),
    );
    ByteData table(String tag) {
      final t = tables[tag];
      if (t == null) throw bad('no $tag table');
      return ByteData.sublistView(t);
    }

    final head = table('head');
    final hhea = table('hhea');
    final maxp = table('maxp');
    final hmtx = table('hmtx');
    final unitsPerEm = head.getUint16(18);
    if (unitsPerEm == 0) throw bad('unitsPerEm is 0');
    final numberOfHMetrics = hhea.getUint16(34);
    final numGlyphs = maxp.getUint16(4);
    if (numberOfHMetrics == 0 || hmtx.lengthInBytes < numberOfHMetrics * 4) {
      throw bad('hmtx is shorter than its metrics');
    }
    int advance(int glyph) {
      final i = glyph < numberOfHMetrics ? glyph : numberOfHMetrics - 1;
      return hmtx.getUint16(i * 4);
    }

    final glyphOf = _cmap(table('cmap'));
    var sum = 0.0;
    var weights = 0.0;
    for (final MapEntry(key: char, value: weight)
        in _englishFrequency.entries) {
      final glyph = glyphOf(char.codeUnitAt(0));
      if (glyph == null || glyph == 0 || glyph >= numGlyphs) continue;
      sum += advance(glyph) * weight;
      weights += weight;
    }
    double xWidthAvg;
    if (weights > 0) {
      xWidthAvg = sum / weights;
    } else if (tables['OS/2'] case final os2? when os2.length >= 4) {
      // No Latin letters mapped (an icon font): the table's own average.
      xWidthAvg = ByteData.sublistView(os2).getInt16(2).toDouble();
    } else {
      throw bad('no Latin letters and no OS/2 average width');
    }
    return FontMetrics(
      unitsPerEm: unitsPerEm,
      ascent: hhea.getInt16(4),
      descent: hhea.getInt16(6),
      lineGap: hhea.getInt16(8),
      xWidthAvg: xWidthAvg,
    );
  }
}

/// The font file at [path].
FontMetrics readFontMetrics(String path) =>
    FontMetrics.read(File(path).readAsBytesSync(), name: path);

/// Runs a process (`Process.run`; tests pass their own).
typedef ProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

/// [readFontMetrics], and a WOFF2 too: fontTools (the one `thor fonts
/// subset` uses) writes it back as a TrueType/OpenType file, which Dart
/// reads. Dart has no Brotli decoder of its own (THOR-B014).
Future<FontMetrics> readAnyFontMetrics(
  String path, {
  ProcessRunner run = Process.run,
}) async {
  final bytes = File(path).readAsBytesSync();
  if (bytes.length < 4 || String.fromCharCodes(bytes.sublist(0, 4)) != 'wOF2') {
    return FontMetrics.read(bytes, name: path);
  }
  final tmp = Directory.systemTemp.createTempSync('thor_woff2_');
  try {
    final out = '${tmp.path}/font.otf';
    ProcessResult? result;
    try {
      result = await run('python3', ['-c', _woff2ToSfnt, path, out]);
    } on ProcessException {
      result = null;
    }
    if (result == null || result.exitCode != 0 || !File(out).existsSync()) {
      throw ThorException(
        thorError(
          'THOR-B014',
          '$path is a WOFF2: reading it needs fontTools with Brotli '
              '(pip install fonttools brotli), or pass the .ttf/.otf/.woff '
              'it was made from',
        ),
      );
    }
    return FontMetrics.read(File(out).readAsBytesSync(), name: path);
  } finally {
    tmp.deleteSync(recursive: true);
  }
}

const _woff2ToSfnt =
    'import sys\n'
    'from fontTools.ttLib import TTFont\n'
    'f = TTFont(sys.argv[1])\n'
    'f.flavor = None\n'
    'f.save(sys.argv[2])\n';

Map<String, Uint8List> _tables(Uint8List bytes, String name) {
  if (bytes.length < 12) {
    throw ThorException(
      thorError('THOR-B014', '$name: too short to be a font'),
    );
  }
  final data = ByteData.sublistView(bytes);
  final tag = String.fromCharCodes(bytes.sublist(0, 4));
  final out = <String, Uint8List>{};
  Uint8List slice(int offset, int length) {
    if (offset < 0 || length < 0 || offset + length > bytes.length) {
      throw ThorException(
        thorError('THOR-B014', '$name: a table runs past the end of the file'),
      );
    }
    return Uint8List.sublistView(bytes, offset, offset + length);
  }

  if (tag == 'wOF2') {
    throw ThorException(
      thorError(
        'THOR-B014',
        '$name is a WOFF2: its tables are Brotli-compressed, which Dart '
            "can't read. Pass the .ttf/.otf/.woff it was made from",
      ),
    );
  }
  if (tag == 'wOFF') {
    final count = data.getUint16(12);
    for (var i = 0; i < count; i++) {
      final at = 44 + i * 20;
      if (at + 20 > bytes.length) break;
      final t = String.fromCharCodes(bytes.sublist(at, at + 4));
      final offset = data.getUint32(at + 4);
      final compressed = data.getUint32(at + 8);
      final original = data.getUint32(at + 12);
      final raw = slice(offset, compressed);
      out[t] = compressed < original
          ? Uint8List.fromList(ZLibDecoder().convert(raw))
          : raw;
    }
    return out;
  }
  if (tag != '\x00\x01\x00\x00' && tag != 'OTTO' && tag != 'true') {
    throw ThorException(
      thorError('THOR-B014', '$name: not a TrueType, OpenType or WOFF font'),
    );
  }
  final count = data.getUint16(4);
  for (var i = 0; i < count; i++) {
    final at = 12 + i * 16;
    if (at + 16 > bytes.length) break;
    final t = String.fromCharCodes(bytes.sublist(at, at + 4));
    out[t] = slice(data.getUint32(at + 8), data.getUint32(at + 12));
  }
  return out;
}

/// Code point → glyph, from the best Unicode subtable of `cmap`
/// (format 12, else format 4).
int? Function(int) _cmap(ByteData cmap) {
  final count = cmap.getUint16(2);
  int? format4;
  int? format12;
  for (var i = 0; i < count; i++) {
    final at = 4 + i * 8;
    final platform = cmap.getUint16(at);
    final encoding = cmap.getUint16(at + 2);
    final offset = cmap.getUint32(at + 4);
    if (offset + 2 > cmap.lengthInBytes) continue;
    final unicode = platform == 0 || (platform == 3 && encoding != 0);
    if (!unicode) continue;
    switch (cmap.getUint16(offset)) {
      case 4:
        format4 ??= offset;
      case 12:
        format12 ??= offset;
    }
  }
  if (format12 case final at?) {
    final groups = cmap.getUint32(at + 12);
    return (c) {
      for (var g = 0; g < groups; g++) {
        final r = at + 16 + g * 12;
        final start = cmap.getUint32(r);
        final end = cmap.getUint32(r + 4);
        if (c >= start && c <= end) return cmap.getUint32(r + 8) + c - start;
      }
      return null;
    };
  }
  if (format4 case final at?) {
    final segments = cmap.getUint16(at + 6) ~/ 2;
    final ends = at + 14;
    final starts = ends + segments * 2 + 2;
    final deltas = starts + segments * 2;
    final ranges = deltas + segments * 2;
    return (c) {
      for (var s = 0; s < segments; s++) {
        final end = cmap.getUint16(ends + s * 2);
        if (c > end) continue;
        final start = cmap.getUint16(starts + s * 2);
        if (c < start) return null;
        final delta = cmap.getInt16(deltas + s * 2);
        final rangeAt = ranges + s * 2;
        final range = cmap.getUint16(rangeAt);
        if (range == 0) return (c + delta) & 0xFFFF;
        final glyphAt = rangeAt + range + (c - start) * 2;
        if (glyphAt + 2 > cmap.lengthInBytes) return null;
        final glyph = cmap.getUint16(glyphAt);
        return glyph == 0 ? null : (glyph + delta) & 0xFFFF;
      }
      return null;
    };
  }
  return (c) => null;
}

// How often each character appears in English text (letters and the
// space), the weights of the average width.
const _englishFrequency = {
  'a': 0.0668, 'b': 0.0122, 'c': 0.0228, 'd': 0.0348, 'e': 0.1039, //
  'f': 0.0182, 'g': 0.0165, 'h': 0.0499, 'i': 0.057, 'j': 0.0013, //
  'k': 0.0063, 'l': 0.0329, 'm': 0.0197, 'n': 0.0552, 'o': 0.0614, //
  'p': 0.0158, 'q': 0.0008, 'r': 0.049, 's': 0.0518, 't': 0.0741, //
  'u': 0.0226, 'v': 0.008, 'w': 0.0193, 'x': 0.0012, 'y': 0.0162, //
  'z': 0.0006, ' ': 0.1818,
};
