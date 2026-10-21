// A ViewModel that reads fixed data of the app (a top-level `const` list
// declared in another library): a search box, "load more" and a selected row
// run on the real runtime under node, with no copy of the data in the state.
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:thor_engine/src/lite_bundle.dart';
import 'package:thor_lints/lite.dart';

Future<String> _translate(Map<String, String> sources) async {
  final units = await resolveSources(
    sources,
    (resolver) async {
      final out = <LiteUnit>[];
      for (final path in sources.keys) {
        final name = path.substring('app|'.length);
        final lib = await resolver.libraryFor(AssetId.parse(path));
        final result =
            await lib.session.getResolvedLibraryByElement(lib)
                as ResolvedLibraryResult;
        out.addAll([for (final u in result.units) LiteUnit(name, u.unit)]);
      }
      return out;
    },
    rootPackage: 'app',
    readAllSourcesFromFilesystem: true,
  );
  return translateLiteStates(units);
}

const _data = '''
class Shop {
  const Shop(this.id, this.name, this.city);
  final String id;
  final String name;
  final String city;
}

const shops = [
  Shop('a', 'Alpha', 'Lima'),
  Shop('b', 'Beta', 'Quito'),
  Shop('c', 'Gamma', 'Lima'),
  Shop('d', 'Delta', 'Bogota'),
  Shop('e', 'Alpine', 'Quito'),
];
''';

const _state = '''
import 'package:thor_ui/thor_ui.dart';

import 'data.dart';

class ShopsViewModel extends ThorState {
  final query = state('');
  final shown = state(2);
  final selected = state('');

  late final matches = derived(
    () => [
      for (final s in shops)
        if (s.name.toLowerCase().contains(query.value.toLowerCase())) s,
    ],
  );

  List<Shop> rows() => matches.value.take(shown.value).toList();
  String keyOf(Shop s) => s.id;
  String nameOf(Shop s) => s.name;
  bool hasMore() => matches.value.length > shown.value;
  String summary() => '\${rows().length} of \${matches.value.length}';

  Shop? get current {
    for (final s in shops) {
      if (s.id == selected.value) return s;
    }
    return null;
  }

  String currentName() => current?.name ?? '';
  String currentCity() => current?.city ?? '';

  void search(String text) {
    query.value = text;
    shown.value = 2;
  }

  void more() => shown.value += 2;
  void select(String id) => selected.value = id;
}
''';

const _page = r'''
globalThis.window = globalThis;
const winL = {};
globalThis.addEventListener = (t, f) => { (winL[t] ||= []).push(f); };
const pagehide = () => (winL.pagehide || []).forEach((f) => f({ persisted: false }));
globalThis.MutationObserver = class { observe() {} };
globalThis.reportError = (x) => (globalThis.errs ||= []).push(x.message);
const root = { innerHTML: '', addEventListener() {}, querySelectorAll: () => [] };
globalThis.document = {
  documentElement: root, cookie: '', querySelectorAll: () => [], querySelector: () => null,
  getElementById: () => null, dispatchEvent() {}, createElement: () => ({}),
};
globalThis.CustomEvent = class {};
''';

Map<String, Object?> _run(String js, String script) {
  final runtime = File('../thor_engine/lib/lite/runtime.js').readAsStringSync();
  // The runtime parts the state names (`// thor-lite parts: …`).
  final names =
      RegExp(
        r'^// thor-lite parts: (.*)$',
        multiLine: true,
      ).firstMatch(js)?.group(1)!.split(' ') ??
      const <String>[];
  final bundle = liteBundle(
    runtime: runtime,
    parts: {
      for (final p in names)
        p: File('../thor_engine/lib/lite/parts/$p.js').readAsStringSync(),
    },
    stateJs: js,
    minify: false,
  );
  final program =
      '$_page$bundle\n(async () => {\nawait new Promise((r) => setTimeout(r, 0));\n'
      'const out = {};\n$script\nconsole.log(JSON.stringify(out));\nprocess.exit(0);\n})();';
  final r = Process.runSync('node', ['-e', program]);
  if (r.exitCode != 0) fail('node failed:\n${r.stderr}\n$js');
  return jsonDecode((r.stdout as String).trim()) as Map<String, Object?>;
}

void main() {
  test('search, load more and a selected row read the app data', () async {
    final js = await _translate({
      'app|lib/data.dart': _data,
      'app|lib/shops.dart': _state,
    });
    final out = _run(js, r'''
const S = thor.use('ShopsViewModel');
const keys = () => S.rows().map(S.keyOf).join(',');
out.first = [keys(), S.hasMore(), S.summary()];
S.more();
out.more = [keys(), S.hasMore(), S.summary()];
S.more();
out.all = [keys(), S.hasMore()];
S.search('al');
out.search = [keys(), S.hasMore(), S.summary()];
S.search('zzz');
out.none = [keys(), S.hasMore(), S.summary()];
out.before = [S.currentName(), S.currentCity()];
S.select('c');
out.after = [S.currentName(), S.currentCity()];
const seen = [];
thor.effect(() => seen.push(S.currentName()));
S.select('d');
out.seen = seen;
''');
    expect(out['first'], ['a,b', true, '2 of 5']);
    expect(out['more'], ['a,b,c,d', true, '4 of 5']);
    expect(out['all'], ['a,b,c,d,e', false]);
    expect(out['search'], ['a,e', false, '2 of 2']);
    expect(out['none'], ['', false, '0 of 0']);
    expect(out['before'], ['', '']);
    expect(out['after'], ['Gamma', 'Lima']);
    expect(out['seen'], ['Gamma', 'Delta']);
  });
}
