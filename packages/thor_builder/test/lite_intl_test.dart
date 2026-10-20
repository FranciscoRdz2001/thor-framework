// The lite engine's `intl` part and thor's Locale in lite, against the
// Dart they stand for: package:intl compiled with dart2js (the part is
// generated from intl's own plural rules by tool/gen_lite_intl.dart), and
// the Locale of thor_ui run by the VM.
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:thor_lints/lite.dart';

final _node = () {
  try {
    return Process.runSync('node', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}();

/// A directory inside the workspace, so a probe resolves its packages.
Directory _probeDir() {
  final d = Directory('.dart_tool/lite_probe')..createSync(recursive: true);
  return d.createTempSync('p');
}

const _part = '../thor_engine/lib/lite/parts/intl.js';

// Numbers, precisions and locales (every locale with rules, and forms that
// only a fallback of verifiedLocale finds).
const _numbers =
    '[0, 1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13, 14, 19, 20, 21, 22, 25, 100, '
    '101, 102, 103, 111, 1000, 1000000, 2000000, 0.0, 0.5, 1.0, 1.5, 2.5, '
    '1.25, 10.75, 0.1, -1, -2.5, 3.0]';
const _extraLocales =
    "['pt-br', 'es_MX', 'sr_Latn_RS', 'iw', 'he', 'nb', 'no', 'xx', 'C', "
    "'in', 'en_US', 'zh_Hant_TW', 'EN', 'de-AT', 'fil', 'invalid', null]";

void main() {
  test(
    'plural rules and canonicalizedLocale: the same as package:intl on the web',
    () {
      if (!_node) return markTestSkipped('node is not installed');
      final dir = _probeDir();
      final probe = File('${dir.path}/probe.dart')
        ..writeAsStringSync('''
import 'dart:convert';
// ignore: implementation_imports
import 'package:intl/src/plural_rules.dart' show pluralRules;
import 'package:intl/intl.dart';

void main() {
  final locales = <String?>[...pluralRules.keys, ...$_extraLocales];
  final out = <Object?>[];
  for (final l in locales) {
    out.add(l == null ? null : Intl.canonicalizedLocale(l));
    for (final num n in $_numbers) {
      for (final p in [null, 0, 2]) {
        for (final e in [true, false]) {
          out.add(Intl.pluralLogic(n, locale: l, zero: 'zero', one: 'one', two: 'two', few: 'few', many: 'many', other: 'other', precision: p, useExplicitNumberCases: e));
          out.add(Intl.pluralLogic(n, locale: l, one: 'one', few: 'few', other: 'other', precision: p, useExplicitNumberCases: e));
        }
      }
    }
  }
  print(jsonEncode([locales, out]));
}
''');
      final compiled = Process.runSync(Platform.resolvedExecutable, [
        'compile',
        'js',
        '-O1',
        '--no-source-maps',
        '-o',
        '${dir.path}/probe.js',
        probe.path,
      ]);
      if (compiled.exitCode != 0) fail('dart2js failed:\n${compiled.stdout}');
      final web = Process.runSync('node', [
        '-e',
        "globalThis.self = globalThis; require('${dir.absolute.path}/probe.js');",
      ]);
      dir.deleteSync(recursive: true);
      if (web.exitCode != 0) fail('the dart2js probe failed:\n${web.stderr}');
      final [locales as List<Object?>, expected as List<Object?>] =
          jsonDecode(web.stdout as String) as List<Object?>;

      final lite = Process.runSync('node', [
        '-e',
        '''
globalThis.thor = {};
require('${File(_part).absolute.path}');
const I = thor.intl;
const locales = ${jsonEncode(locales)};
const out = [];
for (const l of locales) {
  out.push(l == null ? null : I.canon(l));
  for (const n of $_numbers) {
    for (const p of [null, 0, 2]) {
      for (const e of [true, false]) {
        out.push(I.plural(n, 'zero', 'one', 'two', 'few', 'many', 'other', l, p, e));
        out.push(I.plural(n, null, 'one', null, 'few', null, 'other', l, p, e));
      }
    }
  }
}
console.log(JSON.stringify(out));
''',
      ]);
      if (lite.exitCode != 0) fail('the part failed:\n${lite.stderr}');
      final got = jsonDecode(lite.stdout as String) as List<Object?>;
      expect(got.length, expected.length);
      // Report the first differences with what produced them.
      final diffs = <String>[];
      const per = 1 + 37 * 3 * 2 * 2;
      for (var k = 0; k < got.length && diffs.length < 10; k++) {
        if (got[k] != expected[k]) {
          diffs.add(
            '${locales[k ~/ per]} #${k % per}: ${got[k]} vs ${expected[k]}',
          );
        }
      }
      expect(diffs, isEmpty);
    },
  );

  test(
    'Locale and messages that call Intl.pluralLogic run as in Dart',
    () async {
      const lib = r'''
import 'package:intl/intl.dart' as intl;
import 'package:thor_ui/thor_ui.dart';

String describe(Locale? l) => l == null
    ? 'null'
    : '$l|${l.toLanguageTag()}|${l.languageCode}|${l.scriptCode}|${l.countryCode}';

class Messages {
  Messages(String locale) : localeName = intl.Intl.canonicalizedLocale(locale);
  final String localeName;

  String items(int count) => count == 0
      ? 'none'
      : intl.Intl.pluralLogic(
          count,
          locale: localeName,
          one: '$count item',
          other: '$count items',
          useExplicitNumberCases: false,
        );
}

String t0() => [
  for (final tag in ['en', 'es-mx', 'sr_latn_rs', 'zh-Hant-TW', 'en-419', 'e', 'en--us', 'x1', 'EN_us', 'de-AT-1996'])
    describe(Locale.tryParse(tag)),
].join(' / ');

String t1() {
  const a = Locale('es', 'MX');
  final b = Locale.tryParse('es_mx');
  const c = Locale.fromSubtags(languageCode: 'es', countryCode: 'MX');
  const d = Locale.fromSubtags();
  return '${a == b} ${a == c} ${a == const Locale('es')} ${describe(d)} ${[a, c].map(describe).join(',')}';
}

String t2() => [
  for (final l in ['en', 'es', 'pt_BR', 'ru', 'ar', 'xx'])
    for (final n in [0, 1, 2, 5, 11, 21, 1000000]) Messages(l).items(n),
].join('|');
''';
      final units = await resolveSources(
        {
          'app|lib/s.dart':
              '''
$lib
class PState extends ThorState {
  String e0() => t0();
  String e1() => t1();
  String e2() => t2();
}
''',
        },
        (resolver) async {
          final l = await resolver.libraryFor(AssetId.parse('app|lib/s.dart'));
          final result =
              await l.session.getResolvedLibraryByElement(l)
                  as ResolvedLibraryResult;
          return [for (final u in result.units) LiteUnit('lib/s.dart', u.unit)];
        },
        rootPackage: 'app',
        readAllSourcesFromFilesystem: true,
      );
      final js = translateLiteStates(units, shortNames: true);
      expect(js, contains('// thor-lite parts: intl'));
      if (!_node) return markTestSkipped('node is not installed');
      final run = Process.runSync('node', [
        '-e',
        '''
const defs = {};
globalThis.thor = { def: (n, f) => { defs[n] = f; } };
require('${File(_part).absolute.path}');
$js
const S = defs.PState({ key: null, state: (_, v) => ({ value: v }), use: () => null });
console.log(JSON.stringify([S.e0(), S.e1(), S.e2()]));
''',
      ]);
      if (run.exitCode != 0) fail('node failed:\n${run.stderr}\n$js');
      final got = jsonDecode(run.stdout as String) as List<Object?>;

      // The reference: the same library run by the VM (thor_ui's Locale).
      final dir = _probeDir();
      File('${dir.path}/probe.dart').writeAsStringSync('''
import 'dart:convert';
${lib.replaceFirst("import 'package:thor_ui/thor_ui.dart';", "import 'package:thor_ui/thor_ui.dart' show Locale;")}
void main() => print(jsonEncode([t0(), t1(), t2()]));
''');
      final vm = Process.runSync(Platform.resolvedExecutable, [
        'run',
        '${dir.path}/probe.dart',
      ]);
      dir.deleteSync(recursive: true);
      if (vm.exitCode != 0) fail('the VM probe failed:\n${vm.stderr}');
      final expected = jsonDecode(vm.stdout as String) as List<Object?>;
      for (var i = 0; i < expected.length; i++) {
        expect(got[i], expected[i], reason: 't$i');
      }
    },
  );
}
