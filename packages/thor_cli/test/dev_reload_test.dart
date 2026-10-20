import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thor_cli/src/commands/dev.dart' show engineSources;
import 'package:thor_cli/src/dev/declarations.dart';
import 'package:thor_cli/src/dev/local_packages.dart';
import 'package:thor_cli/src/dev/overlay.dart';
import 'package:thor_cli/src/dev_proxy.dart';

void main() {
  group('initializers (what a hot reload keeps)', () {
    test('top-level and class fields, by name, text normalized', () {
      final v = variableInitializers('''
import 'x.dart';

/// Doc.
final routes = <int>[
  1, // one
  2,
];
const limit = 10;
late final lazy = compute();
int count = 0, other = 1;
@deprecated
final old = 'a';
final Map<String, List<int>> typed = {'a': [1]};

class CounterState extends ThorState {
  final count = state(0);
  static final shared = <String>{};
  final int plain;
  CounterState(this.plain) : super();
  String label() => '\${count.value}';
  void inc() { final local = 3; count.value += local; }
}
''');
      expect(v, {
        'routes': '<int>[1, 2]',
        'limit': '10',
        'lazy': 'compute()',
        'count': '0, other = 1',
        'old': "'a'",
        'typed': "{'a': [1]}",
        'type typed': 'Map<String, List<int>>',
        'CounterState.count': 'state(0)',
        'CounterState.shared': '<String>{}',
      });
    });

    test('functions, getters and bodies are not variables', () {
      final v = variableInitializers('''
int f(int x) => x;
int get g => 1;
set s(int v) => null;
Widget build(BuildContext context, PageState<void> state) => const Column(
  children: [Text('a = b')],
);
void main({int port = 8080}) {
  final inside = 1;
  var other = {'k': 1};
}
bool operator ==(Object o) => true;
''');
      expect(v, isEmpty);
    });

    test('strings and comments that look like code change nothing', () {
      final v = variableInitializers(r'''
final a = 'x; final b = 2; }';
// final c = 3;
/* final d = 4; /* nested */ final e = 5; */
final f = """
  multi; { line
""";
final g = r'\'; // raw ends at the quote
final h = 'it${ {'k': 1}['k'] }s';
''');
      expect(v.keys, ['a', 'f', 'g', 'h']);
      expect(v['a'], "'x; final b = 2; }'");
    });

    test('an enum with fields, a mixin, an extension', () {
      final v = variableInitializers('''
enum Plan { free(0), pro(10); const Plan(this.price); final int price; static const all = Plan.values; }
mixin M { final m = 1; }
extension X on int { static const k = 2; }
''');
      expect(v, {'Plan.all': 'Plan.values', 'M.m': '1', 'X.k': '2'});
    });

    test('a changed initializer is reported; a new or removed one is not', () {
      expect(
        changedInitializers(
          {'a': '1', 'b': '2', 'gone': '3'},
          {'a': '1', 'b': '20', 'added': '4'},
        ),
        ['b'],
      );
      expect(changedInitializers(const {}, {'a': '1'}), isEmpty);
    });

    test('a typedef is tracked by its shape (a record gains a field)', () {
      final before = variableInitializers('''
typedef ShellData = ({Cms cms, int count});
typedef Pair = (int, String);
typedef Cb<T> = void Function(T value);
final x = 1;
''');
      final after = variableInitializers('''
typedef ShellData = ({Cms cms, int count, bool open});
typedef Pair = (int, String);
typedef Cb<T> = void Function(T value);
final x = 1;
''');
      expect(before['typedef ShellData'], '({Cms cms, int count})');
      expect(before['typedef Pair'], '(int, String)');
      expect(before.containsKey('typedef Cb'), isTrue);
      expect(changedInitializers(before, after), ['typedef ShellData']);
    });

    test('a typedef moved to a new file in the same save is compared with '
        'the one it left', () {
      final old = variableInitializers('typedef Pair = (int, String);\n');
      final gone = variableInitializers('final x = 1;\n');
      final moved = variableInitializers(
        'typedef Pair = (int, String, bool);\n',
      );
      expect(
        changedAcrossFiles({'a.dart': old}, {'a.dart': gone, 'b.dart': moved}),
        {'typedef Pair': 'b.dart'},
      );
      // The same shape, or a name that is only new: nothing to restart.
      expect(
        changedAcrossFiles({'a.dart': old}, {'a.dart': gone, 'b.dart': old}),
        isEmpty,
      );
      expect(changedAcrossFiles(const {}, {'b.dart': moved}), isEmpty);
    });

    test('a typedef moved to a file that already exists, a class moved, a '
        'rename alone', () {
      final a = variableInitializers('typedef Pair = (int, String);\n');
      final none = variableInitializers('final x = 1;\n');
      final existing = variableInitializers(
        'final y = 2;\ntypedef Pair = (int, String, bool);\n',
      );
      final existingBefore = variableInitializers('final y = 2;\n');
      // Into a file that was there: its own earlier version has no typedef.
      expect(changedInitializers(existingBefore, existing), isEmpty);
      expect(
        changedAcrossFiles(
          {'a.dart': a, 'b.dart': existingBefore},
          {'a.dart': none, 'b.dart': existing},
        ),
        {'typedef Pair': 'b.dart'},
      );
      // A class header (the type arguments a route table keeps) moved with
      // another one; the same header moved is nothing.
      final c1 = variableInitializers('class P extends ThorPage<A> {}\n');
      final c2 = variableInitializers('class P extends ThorPage<B> {}\n');
      expect(
        changedAcrossFiles({'a.dart': c1}, {'a.dart': none, 'c.dart': c2}),
        {'class P': 'c.dart'},
      );
      expect(
        changedAcrossFiles({'a.dart': c1}, {'a.dart': none, 'c.dart': c1}),
        isEmpty,
      );
      // A rename alone (even with a new shape: nothing holds the new name).
      final renamed = variableInitializers('typedef Pair2 = (int, bool);\n');
      expect(changedAcrossFiles({'a.dart': a}, {'a.dart': renamed}), isEmpty);
      // A variable is not tracked across files: it is read afresh by name.
      final v1 = variableInitializers('final k = 1;\n');
      final v2 = variableInitializers('final k = 2;\n');
      expect(
        changedAcrossFiles({'a.dart': v1}, {'a.dart': none, 'b.dart': v2}),
        isEmpty,
      );
    });

    test('a class header with type arguments is tracked (a page changes '
        'its data type, a layout its record)', () {
      final before = variableInitializers('''
class OrderPage extends ThorPage<Order> {
  const OrderPage();
}
class Plain extends Base {}
class ShellLayout extends ThorLayout<({int count})> {}
''');
      expect(
        before.keys,
        containsAll(['class OrderPage', 'class ShellLayout']),
      );
      expect(before.containsKey('class Plain'), isFalse);
      final after = variableInitializers('''
/// New doc.
class OrderPage extends ThorPage<Orders> {
  const OrderPage();
  int extra() => 1;
}
class Plain extends Other {}
class ShellLayout extends ThorLayout<({int count, bool open})> {}
''');
      expect(changedInitializers(before, after), [
        'class OrderPage',
        'class ShellLayout',
      ]);
      // The body of the class, its members and its docs are not the header.
      final same = variableInitializers('''
class OrderPage extends ThorPage<Order> {
  const OrderPage();
  void more() {}
}
class Plain extends Base {}
class ShellLayout extends ThorLayout<({int count})> {}
''');
      expect(changedInitializers(before, same), isEmpty);
    });

    test('the declared type of a variable is tracked, not only its value', () {
      final before = variableInitializers(
        'final Map<String, ({int a})> cache = {};\nfinal plain = 1;',
      );
      final after = variableInitializers(
        'final Map<String, ({int a, int b})> cache = {};\nfinal plain = 1;',
      );
      expect(changedInitializers(before, after), ['type cache']);
    });

    test('formatting only is not a change (spaces, trailing commas, '
        'but not inside strings)', () {
      final a = variableInitializers(
        "typedef T = ({int a, int b});\nfinal l = [1, 2];\nfinal s = 'a  b';",
      );
      final spaced = variableInitializers(
        'typedef T  =  ( {int a,\n int b,} );\nfinal l = [ 1,2, ];\n'
        "final s = 'a  b';",
      );
      expect(changedInitializers(a, spaced), isEmpty);
      final string = variableInitializers(
        "typedef T = ({int a, int b});\nfinal l = [1, 2];\nfinal s = 'a b';",
      );
      expect(changedInitializers(a, string), ['s']);
    });

    test('broken code: no throw, whatever it could read', () {
      expect(
        () => variableInitializers('final a = (;\nclass {'),
        returnsNormally,
      );
      expect(variableInitializers(''), isEmpty);
      // An unterminated string ends at its line; what follows joins the
      // declaration (the compiler reports the error, a restart is fine).
      expect(variableInitializers('final s = "unterminated\nfinal t = 1;'), {
        's': '"unterminated final t = 1',
      });
    });
  });

  group('workspace packages to watch', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('thor_local_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    void write(Map<String, String> roots, Map<String, List<String>>? graph) {
      final tool = Directory(p.join(tmp.path, 'ws', '.dart_tool'))
        ..createSync(recursive: true);
      File(p.join(tool.path, 'package_config.json')).writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            for (final MapEntry(:key, :value) in roots.entries)
              {'name': key, 'rootUri': value, 'packageUri': 'lib/'},
          ],
        }),
      );
      if (graph != null) {
        File(p.join(tool.path, 'package_graph.json')).writeAsStringSync(
          jsonEncode({
            'roots': ['app'],
            'packages': [
              for (final MapEntry(:key, :value) in graph.entries)
                {'name': key, 'dependencies': value},
            ],
          }),
        );
      }
    }

    test('only what the app depends on, transitively; not the cache, the '
        'SDK, the root or unrelated members', () {
      final cache = p.join(tmp.path, 'cache');
      final sdk = p.join(tmp.path, 'sdk');
      final checkout = p.join(tmp.path, 'thor');
      write(
        {
          'ws': '../',
          'app': '../apps/app',
          'other_app': '../apps/other',
          'ui': '../packages/ui',
          'style': '../packages/style',
          'path_dep': Uri.directory(checkout).toString(),
          'collection': Uri.directory(p.join(cache, 'collection')).toString(),
          'sky_engine': Uri.directory(p.join(sdk, 'pkg', 'sky')).toString(),
          'builder': '../packages/builder',
        },
        {
          'app': ['ui', 'collection', 'path_dep'],
          'ui': ['style', 'collection'],
          'style': [],
          'other_app': ['builder'],
          'path_dep': ['sky_engine'],
        },
      );
      final ws = p.join(tmp.path, 'ws');
      expect(
        localDependencies(ws, 'app', pubCache: cache, sdk: sdk),
        [
          p.join(ws, 'packages', 'style'),
          p.join(ws, 'packages', 'ui'),
          checkout,
        ]..sort(),
      );
    });

    test('without a graph: every local package but the app and the root', () {
      write({'ws': '../', 'app': '../app', 'lib_a': '../lib_a'}, null);
      final ws = p.join(tmp.path, 'ws');
      expect(localDependencies(ws, 'app', pubCache: '/nope', sdk: '/nope'), [
        p.join(ws, 'lib_a'),
      ]);
    });

    test('no resolution yet: nothing, no throw', () {
      expect(localDependencies(tmp.path, 'app'), isEmpty);
    });

    test('the engine sources come from dart2js .deps; none if missing', () {
      final deps = File(p.join(tmp.path, 'engine.dart.js.deps'))
        ..writeAsStringSync(
          '${Uri.file(p.join(tmp.path, 'a b.dart'))}\n'
          'org-dartlang-sdk:///lib/core.dart\n',
        );
      expect(engineSources(deps), {p.join(tmp.path, 'a b.dart')});
      expect(engineSources(File(p.join(tmp.path, 'none'))), isEmpty);
    });
  });

  group('overlay sources', () {
    late Directory tmp;
    late SourceMap sources;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('thor_overlay_');
      final app = p.join(tmp.path, 'apps', 'shop');
      File(
          p.join(
            app,
            'lib',
            'modules',
            'product',
            'pages',
            'product page.dart',
          ),
        )
        ..createSync(recursive: true)
        ..writeAsStringSync(
          [for (var i = 1; i <= 20; i++) 'line $i'].join('\n'),
        );
      sources = SourceMap(
        appDir: app,
        root: tmp.path,
        packages: {
          'shop': p.join(app, 'lib'),
          'thor_ui': p.join(tmp.path, 'packages', 'thor_ui', 'lib'),
        },
      );
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    test('VM and stack_trace frames; the app\'s own frame goes first', () {
      final frames = parseStack(
        '#0      List.[] (dart:core-patch/growable_array.dart)\n'
        '#1      PageBuild._build (package:thor_ui/src/core/framework.dart:439:5)\n'
        '<asynchronous suspension>\n'
        '#2      load (package:shop/modules/product/pages/product%20page.dart:12:7)\n'
        'package:shop/modules/product/pages/product%20page.dart 3:1  build\n'
        '#3      Other.x (package:unknown/x.dart:1:1)\n',
        sources,
      );
      expect(frames, hasLength(5));
      expect([for (final f in frames) f.owner], [0, 1, 2, 2, 0]);
      expect(
        frames[2].file,
        p.join(
          sources.appDir,
          'lib',
          'modules',
          'product',
          'pages',
          'product page.dart',
        ),
      );
      final entry = overlayEntry(
        phase: 'load',
        title: 'StateError',
        message: 'm',
        frames: frames,
        sources: sources,
      );
      final at = entry['at']! as Map<String, Object?>;
      expect(at['line'], 12);
      expect(
        at['file'],
        p.join(
          'apps',
          'shop',
          'lib',
          'modules',
          'product',
          'pages',
          'product page.dart',
        ),
      );
      // The overlay builds the editor's link from the path (THOR_EDITOR).
      expect(at['path'], startsWith('/'));
      expect(at['path'], endsWith('page.dart'));
      final code = at['code']! as List;
      expect(code.first, [9, 'line 9']);
      expect(code.last, [15, 'line 15']);
    });

    test('an excerpt at the edges of a file, and of a missing file', () {
      final file = p.join(
        sources.appDir,
        'lib',
        'modules',
        'product',
        'pages',
        'product page.dart',
      );
      expect(sources.excerpt(file, 1).first, [1, 'line 1']);
      expect(sources.excerpt(file, 20).last, [20, 'line 20']);
      expect(sources.excerpt(file, 999).last, [20, 'line 20']);
      expect(sources.excerpt(p.join(tmp.path, 'nope.dart'), 3), isEmpty);
    });

    test('generated code and the SDK are never "your" frame', () {
      expect(
        sources.ownership(p.join(sources.appDir, 'lib', 'x.thor.dart')),
        0,
      );
      expect(sources.file('dart:core'), isNull);
      expect(sources.file('package:nope/a.dart'), isNull);
    });

    test('compile errors: one entry per Error line; else the whole text', () {
      final entries = compileEntries(
        'compile',
        'The code does not compile',
        "lib/modules/item/pages/item_page.dart:3:5: Error: Expected ';' after this.\n"
            '  line 3\n'
            '    ^\n'
            'lib/modules/item/pages/item_page.dart:4:1: Error: Undefined name.\n',
        sources,
      );
      expect(entries, hasLength(2));
      expect((entries.first['at']! as Map)['line'], 3);
      expect(entries.first['message'], "Expected ';' after this.");
      final plain = compileEntries(
        'compile',
        't',
        'Segmentation fault',
        sources,
      );
      expect(plain.single['message'], 'Segmentation fault');
      expect(plain.single.containsKey('at'), isFalse);
    });

    test('the overlay script cannot be closed early by the data', () {
      final script = overlayScript([
        {'phase': 'build', 'title': 't', 'message': '</script><b>x'},
      ]);
      expect(script.indexOf('</script>'), script.length - '</script>'.length);
    });
  });

  group('proxy overlay', () {
    late HttpServer app;
    late DevProxy proxy;
    final client = HttpClient();
    var page = '';

    setUp(() async {
      app = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      app.listen((r) async {
        r.response
          ..statusCode = r.uri.path == '/boom' ? 500 : 200
          ..headers.contentType = ContentType.html
          ..write(page);
        await r.response.close();
      });
      proxy = DevProxy(
        upstream: app.port,
        sources: SourceMap(appDir: '/app', packages: const {}),
      );
      await proxy.start(0);
      proxy.ready();
    });
    tearDown(() async {
      await proxy.close();
      await app.close(force: true);
    });

    Future<String> get(String path) async {
      final req = await client.get('localhost', proxy.port, path);
      return utf8.decodeStream(await req.close());
    }

    const block =
        '<script type="application/json" id="thor-dev-error">'
        r'{"phase":"load","where":"GET /boom","type":"StateError",'
        r'"message":"a \u003c/script> in it","stack":"#0 f (package:x/y.dart:1:2)"}'
        '</script>';

    test('an error block becomes the overlay and leaves the page', () async {
      page = '<html><body><h1>500</h1>$block</body></html>';
      final html = await get('/boom');
      expect(html, isNot(contains('thor-dev-error')));
      expect(html, contains('thor-dev-overlay'));
      expect(html, contains(r'a \u003c/script> in it'));
      expect(
        html.indexOf('thor-dev-overlay'),
        lessThan(html.indexOf('</body>')),
      );
    });

    test('a page without errors has no overlay', () async {
      page = '<html><body><p>ok</p></body></html>';
      expect(await get('/'), isNot(contains('thor-dev-overlay')));
    });

    test('a problem shows on every page until cleared', () async {
      page = '<html><body><p>ok</p></body></html>';
      proxy.problem(
        'engine',
        'The engine did not compile',
        'web/engine.dart:1:1: Error: x',
      );
      expect(await get('/'), contains('The engine did not compile'));
      proxy.clearProblem('engine');
      expect(await get('/'), isNot(contains('thor-dev-overlay')));
    });

    test('a broken block is dropped, never shown raw', () async {
      page =
          '<html><body><script type="application/json" id="thor-dev-error">'
          '{nope</script></body></html>';
      final html = await get('/');
      expect(html, isNot(contains('{nope')));
      expect(html, isNot(contains('thor-dev-overlay')));
    });

    test(
      'a failed start: the error page carries the compile overlay',
      () async {
        proxy.failed(
          "lib/a.dart:2:3: Error: Expected ';'.",
          title: 'The code does not compile',
        );
        final html = await get('/');
        expect(html, contains('<title>The code does not compile</title>'));
        expect(html, contains('thor-dev-overlay'));
        expect(html, contains('"path":"/app/lib/a.dart"'));
        expect(html, contains('"line":2,"column":3'));
      },
    );
  });
}
