// Statics (methods, consts) and top-level declarations used by field
// initializers must exist before the initializers run. The translated JS
// runs on the real runtime under node.
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:thor_engine/src/lite_bundle.dart';
import 'package:thor_lints/lite.dart';

Future<String> _translate(String source) async {
  final units = await resolveSources(
    {'app|lib/s.dart': source},
    (resolver) async {
      final lib = await resolver.libraryFor(AssetId.parse('app|lib/s.dart'));
      final result =
          await lib.session.getResolvedLibraryByElement(lib)
              as ResolvedLibraryResult;
      return [for (final u in result.units) LiteUnit('lib/s.dart', u.unit)];
    },
    rootPackage: 'app',
    readAllSourcesFromFilesystem: true,
  );
  return translateLiteStates(units);
}

const _header = '''
import 'dart:async';

import 'package:thor_ui/thor_ui.dart';

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
  test('statics and top-level declarations in field initializers', () async {
    final js = await _translate('''
$_header
const _topConst = 10;
int _topFn(int v) => v * 3;

class ClassState extends ThorState {
  // Declared after the fields that use them, on purpose.
  final viaMethod = state(ClassState._twice(4));
  final viaConst = state(_topConst + 1);
  final viaChain = state(ClassState._outer(1));
  final viaTop = state(_topFn(_topConst));
  final plain = ClassState._twice(5);
  final fromField = state(_topConst * 2);

  static int _twice(int v) => v * 2;
  static int _outer(int v) => _inner(v) + 100;
  static int _inner(int v) => v + _topConst;

  int sum() => viaMethod.value + viaConst.value + viaChain.value + viaTop.value + plain + fromField.value;
  String label() => 'T' + viaMethod.value.toString();
}

class Plain {
  Plain() : a = _bump(1);
  final int a;
  final int b = _bump(2) + k;
  static const k = 5;
  static int _bump(int v) => v + 1;
  static int make(int v) => _bump(v) * k;
}

class PlainState extends ThorState {
  final p = state(Plain());
  final q = state(Plain.make(Plain.k));
  String show() => '\${p.value.a},\${p.value.b},\${q.value}';
}
''');
    final out = _run(js, r'''
const S = thor.use('ClassState');
out.sum = S.sum();
out.label = S.label();
const P = thor.use('PlainState');
out.plain = P.show();
''');
    // 8 + 11 + 111 + 30 + 10 + 20
    expect(out['sum'], 190);
    expect(out['label'], 'T8');
    expect(out['plain'], '2,8,30');
  });

  test('static constants of a state', () async {
    final js = await _translate('''
$_header
enum Unit { px, em }

class GeoState extends ThorState {
  // Read before they are declared, and one constant names a later one.
  final width = state(GeoState.cols * cell);
  final unit = state(defaultUnit);
  static const area = cols * rows;
  static const cols = 4, rows = 3;
  static const double cell = 2.5;
  static const sizes = [1, 2, 3];
  static const defaultUnit = Unit.em;
  static final label = 'grid \${cols}x\$rows';
  static final half = cell / 2;

  String show() =>
      '\${width.value} \${unit.value.name} \$area \${sizes.length} '
      '\${GeoState.sizes.last} \$label \$half';
}
''');
    final out = _run(js, r'''
const S = thor.use('GeoState');
out.show = S.show();
''');
    expect(out['show'], '10 em 12 3 3 grid 4x3 1.25');
  });

  test('static const instances and top-level const instances', () async {
    final js = await _translate('''
$_header
class Tree {
  const Tree({required this.file, this.rows = const [], this.tags = const {}});
  final String file;
  final List<int> rows;
  final Set<String> tags;
  static const none = Tree(file: '');
  static const withRows = Tree(file: 'a', rows: [1, 2]);
  bool get isNone => identical(this, none) || file.isEmpty;
}

const emptyTree = Tree(file: '');

class TreeState extends ThorState {
  final t = state(Tree.none);
  final u = state(emptyTree);
  String show() =>
      '\${t.value.rows.length} \${u.value.rows.length} \${Tree.withRows.rows.length} '
      '\${identical(Tree.none, Tree.none)} \${t.value.isNone}';
}
''');
    expect(js, isNot(contains(r'static none = new')));
    final out = _run(js, r'''
out.show = thor.use('TreeState').show();
''');
    expect(out['show'], '0 0 2 true true');
  });

  test(
    'a const list of instances comes after the instances it holds',
    () async {
      // The hoisted `Object.freeze([$c1, $c2])` names instances that are
      // hoisted too: the "instances after the plain hoisted ones" guess
      // must not put the list first (a TDZ when the state is created).
      final js = await _translate('''
$_header
class EdgeRow {
  const EdgeRow(this.id, this.count, {this.tags = const []});
  final int id;
  final int count;
  final List<String> tags;
}

class Note {
  const Note(this.id, this.text);
  final int id;
  final String text;
}

class EdgeState extends ThorState {
  final notes = state<List<Note>>(const [Note(1, 'a'), Note(2, 'b')]);
  final rows = state<List<EdgeRow>>(const [EdgeRow(1, 0), EdgeRow(2, 0)]);
  String show() =>
      '\${rows.value.length} \${rows.value.last.id} '
      '\${rows.value.first.tags.length} \${notes.value.last.text}';
}
''');
      final out = _run(js, r'''
out.show = thor.use('EdgeState').show();
''');
      expect(out['show'], '2 2 0 b');
    },
  );

  test('a static reads a later class and a top-level const', () async {
    final js = await _translate('''
$_header
class First {
  static const fromLater = Later.value;
  static const fromTop = topName;
  static const limit = 3;
}

class Later {
  static const value = 'later';
}

const topName = 'top';

class OrderState extends ThorState {
  final s = state(First.fromLater);
  String show() => '\${s.value} \${First.fromTop} \${First.limit}';
}
''');
    expect(js, contains('static limit = 3;'));
    final out = _run(js, r'''
out.show = thor.use('OrderState').show();
''');
    expect(out['show'], 'later top 3');
  });

  test('static fields that are not constants say how', () async {
    Future<List<String>> errors(String body) async {
      try {
        await _translate('$_header\n$body');
      } on LiteTranslationException catch (e) {
        return [for (final x in e.errors) x.message];
      }
      fail('expected lite errors');
    }

    final mutable = await errors(r'''
class AState extends ThorState {
  static int count = 0;
  static final now = DateTime.now();
  static final items = <int>[];
}
''');
    expect(mutable, hasLength(3));
    for (final m in mutable) {
      expect(m, contains('Move it to the top level'));
    }
    final outside = await errors(r'''
class AState extends ThorState {
  static const size = 3;
}
class BState extends ThorState {
  final n = state(AState.size);
}
''');
    expect(
      outside.single,
      contains('outside its state: move it to the top level'),
    );
  });
}
