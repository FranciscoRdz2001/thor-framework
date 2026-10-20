import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../font_metrics.dart';
import '../run.dart';
import '../workspace.dart';

/// `thor fonts subset`: a font cut down to what the app uses (`woff2`),
/// and the `unicodeRange` to give its `FontFace`.
class FontsCommand extends Command<int> {
  /// The command and its subcommands.
  FontsCommand() {
    addSubcommand(_Subset());
    addSubcommand(_Metrics());
  }

  @override
  String get name => 'fonts';

  @override
  String get description =>
      'Cut fonts down to the glyphs the app uses (woff2), and measure '
      'them for their fallback.';
}

class _Subset extends Command<int> {
  _Subset() {
    argParser
      ..addOption(
        'out',
        abbr: 'o',
        help: 'Where to write it (default: web/fonts/<name>.woff2).',
      )
      ..addOption(
        'unicodes',
        help:
            'Characters to keep (`U+0000-00FF,U+2013`); `latin` is the usual '
            'Latin set.',
      )
      ..addOption(
        'icons',
        help:
            'An icon font: keep only the code points of the '
            "`IconData(0x…, fontFamily: '<this>')` the app's lib/ uses.",
      )
      ..addOption('project', help: 'The project (default: the current one).');
  }

  @override
  String get name => 'subset';

  @override
  String get description =>
      'Subset a font (woff2) to a character set or to the icons the app '
      'uses. Needs fontTools (`pip install fonttools brotli`).';

  @override
  String get invocation =>
      'thor fonts subset <font.ttf|otf|woff2> (--unicodes <set> | --icons '
      '<family>) [--out <file>]';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) usageException('One font file.');
    final font = File(rest.single);
    if (!font.existsSync()) throw ThorException('No font at ${font.path}.');
    final unicodes = argResults!['unicodes'] as String?;
    final icons = argResults!['icons'] as String?;
    if ((unicodes == null) == (icons == null)) {
      usageException('Give --unicodes or --icons (one of them).');
    }
    final project = Project.find(argResults!['project'] as String?);
    List<int> points;
    if (icons != null) {
      if (project == null) {
        throw ThorException('--icons reads a project: run it inside one.');
      }
      points = iconCodePoints(_dartSources(project.path('lib')), icons);
      if (points.isEmpty) {
        throw ThorException(
          "No IconData(…, fontFamily: '$icons') in ${project.path('lib')}.",
        );
      }
    } else {
      points = parseUnicodes(unicodes == 'latin' ? latinUnicodes : unicodes!);
    }
    final range = unicodeRangeOf(points);
    final out =
        argResults!['out'] as String? ??
        p.join(
          project?.path('web/fonts') ?? 'web/fonts',
          '${p.basenameWithoutExtension(font.path)}.woff2',
        );
    Directory(p.dirname(out)).createSync(recursive: true);
    final ProcessResult result;
    try {
      result = await Process.run('pyftsubset', [
        font.path,
        '--unicodes=$range',
        '--flavor=woff2',
        '--layout-features=*',
        '--output-file=$out',
      ]);
    } on ProcessException {
      throw ThorException(
        'thor fonts subset needs fontTools: pip install fonttools brotli',
      );
    }
    if (result.exitCode != 0) {
      throw ThorException('pyftsubset failed:\n${result.stderr}');
    }
    final before = font.lengthSync(), after = File(out).lengthSync();
    Say.ok(
      '${p.relative(out)}: ${points.length} glyphs, '
      '${(before / 1024).toStringAsFixed(1)} → '
      '${(after / 1024).toStringAsFixed(1)} KB',
    );
    Say.info("FontFace(…, url: '/${_webPath(out)}', unicodeRange: '$range')");
    return 0;
  }

  static String _webPath(String out) {
    final parts = p.split(p.normalize(out));
    final web = parts.indexOf('web');
    return (web < 0 ? parts : parts.sublist(web + 1)).join('/');
  }

  static Iterable<String> _dartSources(String dir) sync* {
    final root = Directory(dir);
    if (!root.existsSync()) return;
    for (final f in root.listSync(recursive: true)) {
      if (f is File && f.path.endsWith('.dart')) yield f.readAsStringSync();
    }
  }
}

class _Metrics extends Command<int> {
  _Metrics() {
    argParser
      ..addOption(
        'fallback',
        help:
            'The local font to resize, as a file (default: Arial, the '
            'FontFallback default).',
      )
      ..addFlag('json', negatable: false, help: 'Print the numbers as JSON.');
  }

  @override
  String get name => 'metrics';

  @override
  String get description =>
      "The FontFallback values that make a local font take a web font's "
      "room (size-adjust and the overrides), from the font's own tables.";

  @override
  String get invocation =>
      'thor fonts metrics <font.ttf|otf|woff|woff2> [--fallback <font file>]';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) usageException('One font file.');
    final path = rest.single;
    if (!File(path).existsSync()) throw ThorException('No font at $path.');
    final fallbackPath = argResults!['fallback'] as String?;
    if (fallbackPath != null && !File(fallbackPath).existsSync()) {
      throw ThorException('No font at $fallbackPath.');
    }
    final m = (await readAnyFontMetrics(path)).fallbackFrom(
      fallbackPath == null
          ? FontMetrics.arial
          : await readAnyFontMetrics(fallbackPath),
    );
    String n(double v) => v.toStringAsFixed(4);
    if (argResults!['json'] as bool) {
      print(
        '{"sizeAdjust": ${n(m.sizeAdjust)}, '
        '"ascentOverride": ${n(m.ascentOverride)}, '
        '"descentOverride": ${n(m.descentOverride)}, '
        '"lineGapOverride": ${n(m.lineGapOverride)}}',
      );
      return 0;
    }
    print(
      'fallback: FontFallback(\n'
      '${fallbackPath == null ? '' : '  local: [/* ${p.basename(fallbackPath)} */],\n'}'
      '  sizeAdjust: ${n(m.sizeAdjust)},\n'
      '  ascentOverride: ${n(m.ascentOverride)},\n'
      '  descentOverride: ${n(m.descentOverride)},\n'
      '  lineGapOverride: ${n(m.lineGapOverride)},\n'
      '),',
    );
    return 0;
  }
}

/// Google Fonts' Latin subset.
const latinUnicodes =
    'U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,'
    'U+0304,U+0308,U+0329,U+2000-206F,U+20AC,U+2122,U+2191,U+2193,U+2212,'
    'U+2215,U+FEFF,U+FFFD';

/// The code points of every `IconData(<n>, fontFamily: '<family>')` in
/// [sources], sorted, once each.
List<int> iconCodePoints(Iterable<String> sources, String family) {
  final call = RegExp(
    r'IconData\(\s*(0x[0-9a-fA-F]+|\d+)\s*,([^)]*)\)',
    multiLine: true,
  );
  final named = RegExp(
    '''fontFamily\\s*:\\s*['"]${RegExp.escape(family)}['"]''',
  );
  final out = <int>{};
  for (final source in sources) {
    for (final m in call.allMatches(source)) {
      if (!named.hasMatch(m[2]!)) continue;
      final raw = m[1]!;
      out.add(
        raw.startsWith('0x')
            ? int.parse(raw.substring(2), radix: 16)
            : int.parse(raw),
      );
    }
  }
  return out.toList()..sort();
}

/// The code points of a `U+0000-00FF,U+2013` list.
List<int> parseUnicodes(String spec) {
  final out = <int>{};
  for (final part in spec.split(',')) {
    final t = part.trim();
    if (t.isEmpty) continue;
    final m = RegExp(
      r'^U\+([0-9A-Fa-f]{1,6})(?:-([0-9A-Fa-f]{1,6}))?$',
    ).firstMatch(t);
    if (m == null) throw ThorException('"$t" is not U+XXXX or U+XXXX-YYYY.');
    final from = int.parse(m[1]!, radix: 16);
    final to = m[2] == null ? from : int.parse(m[2]!, radix: 16);
    if (to < from) throw ThorException('"$t": the range goes backwards.');
    for (var c = from; c <= to; c++) {
      out.add(c);
    }
  }
  return out.toList()..sort();
}

/// [points] as a `unicode-range` (consecutive ones merged).
String unicodeRangeOf(Iterable<int> points) {
  final sorted = points.toSet().toList()..sort();
  final parts = <String>[];
  String hex(int c) => c.toRadixString(16).toUpperCase().padLeft(4, '0');
  for (var i = 0; i < sorted.length; i++) {
    final start = sorted[i];
    var end = start;
    while (i + 1 < sorted.length && sorted[i + 1] == end + 1) {
      end = sorted[++i];
    }
    parts.add(start == end ? 'U+${hex(start)}' : 'U+${hex(start)}-${hex(end)}');
  }
  return parts.join(',');
}
