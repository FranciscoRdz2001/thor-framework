// Writes `Icons` (packages/thor_ui/lib/src/widgets/icons.dart): every name of
// Flutter's `Icons` class as an SVG icon, from Google's Material icons
// (Apache-2.0).
//
//   dart run tool/gen_icons.dart
//
// The names are Flutter's own: the generator reads `Icons` from
// flutter/flutter at the pinned commit below (every base name in its four
// variants `x`, `x_outlined`, `x_rounded`, `x_sharp`, and which of them Flutter
// flips in right-to-left text) and fetches each shape from
// google/material-design-icons at its pinned commit. Downloads are cached in
// `.dart_tool/gen_icons`, so a second run is offline. The license is copied
// next to the package (packages/thor_ui/third_party).
//
// A name is resolved to a Material folder by, in order:
//  1. its own name (`add_circle`);
//  2. Flutter's spelling of a leading digit (`ten_k` is the folder `10k`) or
//     the few names Material renamed (`_renamed`);
//  3. another Flutter name with the same code point (`copy` is Flutter's
//     alias of `content_copy`): it is emitted as `= content_copy`.
// A name that doesn't resolve (Flutter's brand glyphs such as `Icons.paypal`
// have no SVG in the repository) is left out and listed in the output.
//
// A variant that draws the same shape as its base icon is an alias of it, so
// the page's sprite never holds the same shape twice.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// The commit of flutter/flutter whose `Icons` is the list of names.
const _flutterCommit = '4e5a09292c1c64a38d604c7ec096537f50d69f93';

/// The commit of google/material-design-icons the shapes come from.
const _commit = 'bd8cb85bd4bad964fe6918f79665bb40c3a8efef';

const _flutterUrl =
    'https://raw.githubusercontent.com/flutter/flutter/$_flutterCommit/'
    'packages/flutter/lib/src/material/icons.dart';

const _repo = 'google/material-design-icons';

const _raw = 'https://raw.githubusercontent.com/$_repo/$_commit';

const _variants = {
  '': 'materialicons',
  '_outlined': 'materialiconsoutlined',
  '_rounded': 'materialiconsround',
  '_sharp': 'materialiconssharp',
};

final _client = HttpClient();
const _cacheDir = '.dart_tool/gen_icons';

/// GET [url], through the on-disk cache under [key].
Future<String> _get(String url, String key) async {
  final file = File('$_cacheDir/$key');
  if (file.existsSync()) return file.readAsStringSync();
  for (var attempt = 0; ; attempt++) {
    try {
      final req = await _client.getUrl(Uri.parse(url));
      final token = Platform.environment['GITHUB_TOKEN'];
      if (token != null && url.startsWith('https://api.github.com')) {
        req.headers.set('Authorization', 'Bearer $token');
      }
      final res = await req.close();
      if (res.statusCode != 200) {
        await res.drain<void>();
        throw HttpException('${res.statusCode}', uri: Uri.parse(url));
      }
      final body = await res.transform(utf8.decoder).join();
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(body);
      return body;
    } on Object {
      if (attempt == 3) rethrow;
      await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
    }
  }
}

/// The markup inside `<svg>`, without the transparent 24×24 box every icon
/// starts with (the symbol's viewBox already is that box).
String _body(String svg) {
  final inner = RegExp(
    r'<svg[^>]*>(.*)</svg>',
    dotAll: true,
  ).firstMatch(svg)!.group(1)!;
  return inner
      // A `<title>` in a symbol would show as a tooltip and be read aloud.
      .replaceAll(RegExp(r'<title>.*?</title>', dotAll: true), '')
      .replaceAll(RegExp(r'<path d="M0 0h24v24H0[zV0z]*" fill="none"\s*/>'), '')
      .replaceAll(RegExp(r'>\s+<'), '><')
      .trim();
}

const _units = {
  'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, //
  'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11,
  'twelve': 12, 'thirteen': 13, 'fourteen': 14, 'fifteen': 15,
  'sixteen': 16, 'seventeen': 17, 'eighteen': 18, 'nineteen': 19,
};
const _tens = {
  'twenty': 20,
  'thirty': 30,
  'forty': 40,
  'fifty': 50,
  'sixty': 60,
};

/// The Material folders a Flutter name that starts with a spelled-out
/// number can come from (`twenty_four_mp` is `24mp`, `eighteen_up_rating`
/// is `18_up_rating`, `threed_rotation` is `3d_rotation`).
Iterable<String> _spelled(String name) sync* {
  for (final special in const {
    'threesixty': '360',
    'onetwothree': '123',
    'threed_': '3d_',
  }.entries) {
    if (name.startsWith(special.key)) {
      yield special.value + name.substring(special.key.length);
    }
  }
  final tokens = name.split('_');
  int? number;
  var used = 0;
  if (_tens.containsKey(tokens[0])) {
    number = _tens[tokens[0]];
    used = 1;
    if (tokens.length > 1 &&
        _units.containsKey(tokens[1]) &&
        _units[tokens[1]]! < 10) {
      number = number! + _units[tokens[1]]!;
      used = 2;
    }
  } else if (_units.containsKey(tokens[0])) {
    number = _units[tokens[0]];
    used = 1;
  }
  if (number == null) return;
  final rest = tokens.skip(used).join('_');
  yield '$number$rest';
  yield '${number}_$rest';
}

/// Flutter names that Material's repository spells differently.
const _renamed = {
  'door_back_door': 'door_back',
  'door_front_door': 'door_front',
};

/// One `static const IconData` of Flutter's `Icons`.
class _Entry {
  _Entry(this.name, this.codePoint, this.mirror);
  final String name;
  final int codePoint;
  final bool mirror;

  /// `''`, `_outlined`, `_rounded` or `_sharp`.
  String variant = '';

  /// The name without the variant.
  late String base;

  /// The Material folder name, when it has one of its own.
  String? folder;

  /// The entry this one is an alias of, when it has no folder.
  _Entry? aliasOf;
}

Future<Map<String, Object?>> _tree(
  String sha,
  String key, {
  bool all = false,
}) async {
  final url =
      'https://api.github.com/repos/$_repo/git/trees/$sha'
      '${all ? '?recursive=1' : ''}';
  final tree = jsonDecode(await _get(url, key)) as Map<String, Object?>;
  if (tree['truncated'] == true) throw StateError('$key: truncated');
  return tree;
}

List<Map<String, Object?>> _items(Map<String, Object?> tree) =>
    (tree['tree']! as List<Object?>).cast<Map<String, Object?>>();

Future<void> main() async {
  // Flutter's names.
  final flutter = await _get(_flutterUrl, 'flutter_icons.dart');
  final classBody = flutter.substring(
    flutter.indexOf('abstract final class Icons'),
  );
  final entries = [
    for (final m in RegExp(
      r'static const IconData (\w+) = IconData\(\s*(0x[0-9a-fA-F]+),\s*'
      r"fontFamily: 'MaterialIcons',?(\s*matchTextDirection: true,?)?\s*\)",
    ).allMatches(classBody))
      _Entry(m[1]!, int.parse(m[2]!), m[3] != null),
  ];
  // Which shapes the repository has: category/name/variantdir.
  final cats = <String, String>{}; // name → category
  final shapes = <String>{};
  final root = await _tree(_commit, 'tree_root.json');
  final src = _items(root).firstWhere((t) => t['path'] == 'src');
  for (final cat in _items(await _tree('${src['sha']}', 'tree_src.json'))) {
    final tree = await _tree(
      '${cat['sha']}',
      'tree_${cat['path']}.json',
      all: true,
    );
    for (final t in _items(tree)) {
      final path = t['path']! as String;
      if (!path.endsWith('/24px.svg')) continue;
      final parts = path.split('/'); // name/variantdir/24px.svg
      cats[parts[0]] = cat['path']! as String;
      shapes.add('${cat['path']}/${parts[0]}/${parts[1]}');
    }
  }

  final byName = {for (final e in entries) e.name: e};
  for (final e in entries) {
    e.base = e.name;
    for (final v in _variants.keys.where((v) => v.isNotEmpty)) {
      if (!e.name.endsWith(v) || cats.containsKey(e.name)) continue;
      final base = e.name.substring(0, e.name.length - v.length);
      // `class_outlined` is Flutter's spelling of `class_`'s outlined variant.
      final spelled = byName.containsKey(base) ? base : '${base}_';
      if (byName.containsKey(spelled)) {
        e.variant = v;
        e.base = spelled;
      }
    }
  }

  // Resolve each base name to a folder.
  final folders = <String, String>{}; // Flutter base → folder name
  for (final e in entries.where((e) => e.variant.isEmpty)) {
    for (final candidate in [
      e.base,
      ?_renamed[e.base],
      ..._spelled(e.base),
      if (e.base.endsWith('_')) e.base.substring(0, e.base.length - 1),
    ]) {
      if (cats.containsKey(candidate)) {
        folders[e.base] = candidate;
        break;
      }
    }
  }
  // The same code point as a name that resolved: Flutter's alias.
  final byCodePoint = <int, _Entry>{};
  for (final e in entries.where((e) => folders.containsKey(e.base))) {
    byCodePoint.putIfAbsent(e.codePoint, () => e);
  }
  final dropped = <String>{};
  for (final e in entries) {
    final f = folders[e.base];
    if (f != null) {
      e.folder = f;
    } else if (byCodePoint[e.codePoint] case final twin?) {
      e.aliasOf = twin;
    } else {
      dropped.add(e.name);
    }
  }
  entries.removeWhere((e) => dropped.contains(e.name));

  // The shapes.
  final bodies = <String, String>{}; // Flutter name → body
  final jobs = [
    for (final e in entries)
      if (e.folder != null) e,
  ];
  var next = 0;
  final missing = <String>[];
  await Future.wait([
    for (var w = 0; w < 16; w++)
      () async {
        while (next < jobs.length) {
          final e = jobs[next++];
          final dir = _variants[e.variant]!;
          final cat = cats[e.folder]!;
          if (!shapes.contains('$cat/${e.folder}/$dir')) {
            missing.add(e.name);
            continue;
          }
          bodies[e.name] = _body(
            await _get(
              '$_raw/src/$cat/${e.folder}/$dir/24px.svg',
              'svg/$cat/${e.folder}/$dir.svg',
            ),
          );
        }
      }(),
  ]);
  // A variant Material doesn't draw is filled in from the base icon.
  for (final name in missing) {
    final base = byName[name]!.base;
    if (!bodies.containsKey(base)) throw StateError('$name: no base icon');
    bodies[name] = bodies[base]!;
  }

  final variantOrder = _variants.keys.toList();
  final order = [...entries]
    ..sort((a, b) {
      final c = a.base.compareTo(b.base);
      return c != 0
          ? c
          : variantOrder
                .indexOf(a.variant)
                .compareTo(variantOrder.indexOf(b.variant));
    });
  final out = StringBuffer()
    ..writeln('// GENERATED by tool/gen_icons.dart from the `Icons` of Flutter')
    ..writeln(
      '// (flutter/flutter@${_flutterCommit.substring(0, 7)}): do not edit.',
    )
    ..writeln('// Shapes: Material icons (Google, Apache-2.0),')
    ..writeln('// $_repo@${_commit.substring(0, 7)}; the')
    ..writeln(
      '// license is packages/thor_ui/third_party/material-design-icons.',
    )
    ..writeln('// ignore_for_file: constant_identifier_names')
    ..writeln('// web: Flutter names the icons in snake_case, so does `Icons`.')
    ..writeln()
    ..writeln("import 'package:thor_style/thor_style.dart' show IconData;")
    ..writeln()
    ..writeln(
      "/// Flutter's `Icons`: ${order.length} Material icons by name, as SVG",
    )
    ..writeln(
      '/// icons (`Icon(Icons.search)`), each with its `_outlined`, `_rounded`',
    )
    ..writeln('/// and `_sharp` variants.')
    ..writeln('///')
    ..writeln('/// Only the icons a page draws travel in it, once each, in the')
    ..writeln("/// page's sprite. Shapes: Material icons, Apache-2.0.")
    ..writeln('abstract final class Icons {');
  var unique = 0;
  for (final e in order) {
    out.writeln();
    final target = e.aliasOf;
    if (target != null) {
      out
        ..writeln("  /// Flutter's other name for [${target.name}].")
        ..writeln('  static const IconData ${e.name} = ${target.name};');
      continue;
    }
    final body = bodies[e.name]!;
    if (body.contains("'") || body.contains(r'$')) {
      throw StateError('${e.name}: unexpected character in the body');
    }
    if (e.variant.isEmpty) {
      out.writeln('  /// The Material icon "${e.name.replaceAll('_', ' ')}".');
    } else {
      out.writeln(
        '  /// The ${e.variant.substring(1)} variant of [${e.base}].',
      );
    }
    // web: the same shape as the base icon (Material draws them alike).
    if (e.variant.isNotEmpty &&
        bodies[e.base] == body &&
        byName[e.base]!.mirror == e.mirror) {
      out.writeln('  static const IconData ${e.name} = ${e.base};');
      continue;
    }
    unique++;
    out
      ..writeln('  static const IconData ${e.name} = IconData.svg(')
      ..writeln("    'material-${e.name.replaceAll('_', '-')}',")
      ..writeln("    r'$body',")
      ..write(e.mirror ? '    matchTextDirection: true,\n' : '')
      ..writeln('  );');
  }
  out.writeln('}');
  File('packages/thor_ui/lib/src/widgets/icons.dart').writeAsStringSync('$out');

  final license = await _get('$_raw/LICENSE', 'LICENSE');
  Directory(
    'packages/thor_ui/third_party/material-design-icons',
  ).createSync(recursive: true);
  File(
    'packages/thor_ui/third_party/material-design-icons/LICENSE',
  ).writeAsStringSync(license);
  _client.close();
  Process.runSync('dart', [
    'format',
    'packages/thor_ui/lib/src/widgets/icons.dart',
  ]);
  stdout
    ..writeln('${order.length} names, $unique distinct shapes')
    ..writeln('Left out (no SVG upstream): ${dropped.toList()..sort()}');
}
