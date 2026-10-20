// Adversarial tests for helpers in other files: conditional imports, helpers
// of another package, mutual recursion across files, and the dart2js
// parity of the helpers.
@Timeout(Duration(minutes: 3))
library;

import 'package:analyzer/dart/analysis/results.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:thor_lints/lite.dart';

import 'lite_oracle.dart' show hasNode, runJs;

/// Translates the app files in [files] (path under `lib/` → source) the way
/// `writeLiteStates` does: every file of the app, plus [other] packages'
/// files that are resolved but not translated.
Future<String> translateFiles(
  Map<String, String> files, {
  Map<String, String> other = const {},
  bool shortNames = false,
}) async {
  final units = await resolveSources(
    {
      for (final e in files.entries) 'app|lib/${e.key}': e.value,
      for (final e in other.entries) e.key: e.value,
    },
    (resolver) async {
      final out = <LiteUnit>[];
      for (final f in files.keys) {
        final lib = await resolver.libraryFor(AssetId.parse('app|lib/$f'));
        final result =
            await lib.session.getResolvedLibraryByElement(lib)
                as ResolvedLibraryResult;
        for (final u in result.units) {
          out.add(LiteUnit('lib/$f', u.unit));
        }
      }
      return out;
    },
    rootPackage: 'app',
    readAllSourcesFromFilesystem: true,
  );
  return translateLiteStates(units, shortNames: shortNames);
}

Future<List<LiteError>> errorsOf(
  Map<String, String> files, {
  Map<String, String> other = const {},
}) async {
  try {
    await translateFiles(files, other: other);
  } on LiteTranslationException catch (e) {
    return e.errors;
  }
  fail('expected lite errors');
}

const _state = r'''
import 'package:thor_ui/thor_ui.dart';
import 'helper.dart';


class PState extends ThorState {
  final label = state('');
  String e0() => describe();
  void go() { label.value = describe(); }
}
''';

void main() {
  test('a conditional import is refused when the state uses it', () async {
    final errors = await errorsOf({
      'main.dart': _state,
      'helper.dart': r'''
export 'helper_stub.dart' if (dart.library.js_interop) 'helper_web.dart';
''',
      'helper_stub.dart': "String describe() => 'stub';",
      'helper_web.dart': "String describe() => 'web';",
    });
    expect(errors.first.message, contains('onditional'));
  });

  test('a conditional import nothing uses is fine', () async {
    await translateFiles({
      'main.dart': _state
          .replaceFirst(
            "import 'helper.dart';",
            ''
                "import 'helper.dart';\nimport 'srv.dart';",
          )
          .replaceAll('describe()', "'x'"),
      'helper.dart': "String describe() => 'plain';",
      'srv.dart': r'''
import 'srv_stub.dart' if (dart.library.io) 'srv_io.dart';
String viaServer() => serverName();
''',
      'srv_stub.dart': "String serverName() => 'stub';",
      'srv_io.dart': "String serverName() => 'io';",
    });
  });

  test('a helper of another package says it is outside the subset', () async {
    final errors = await errorsOf(
      {
        'main.dart': _state.replaceFirst(
          "import 'helper.dart';",
          "import 'package:other/h.dart';",
        ),
      },
      other: {'other|lib/h.dart': "String describe() => 'pkg';"},
    );
    expect(errors, isNotEmpty);
    expect(errors.first.message, contains('describe'));
  });

  test('mutual recursion across files translates and runs', () async {
    final js = await translateFiles({
      'main.dart': r'''
import 'package:thor_ui/thor_ui.dart';
import 'a.dart';


class PState extends ThorState {
  final label = state('');
  String e0() => ping(4);
}
''',
      'a.dart': r'''
import 'b.dart';
String ping(int n) => n <= 0 ? 'done' : pong(n - 1);
''',
      'b.dart': r'''
import 'a.dart';
String pong(int n) => n <= 0 ? 'done-b' : ping(n - 1);
''',
    });
    if (!hasNode) return markTestSkipped('node is not installed');
    expect(runJs(js, 'out.v = S.e0();')['v'], 'done');
  });
}
