// What `thor dev`'s worker keeps between saves (lib/src/entries_cache.dart)
// must never change what the steps write: after any sequence of edits, an
// incremental update leaves the files a cold run on the same sources
// would, and it resolves only what the edit touched.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thor_builder/src/entries_cache.dart';
import 'package:thor_builder/src/step_worker.dart';

String _api(String source) => apiSignature(parseString(content: source).unit);

void main() {
  group('apiSignature', () {
    test('ignores comments, formatting and bodies with written types', () {
      const base = '''
import 'a.dart';

class A extends B {
  A(this.x) : y = 1;
  final int x;
  final int y;
  int count = 0;
  static final List<int> all = [1, 2];

  int twice() { return x * 2; }
  String get name => 'a';
  set name(String v) { print(v); }
  void run() {}
}

String shout(String s) => s.toUpperCase();
final String greeting = 'hi';
''';
      final edited = base
          .replaceFirst('return x * 2;', 'return x * 3; /* changed */')
          .replaceFirst("=> 'a'", "=> 'b'")
          .replaceFirst('print(v);', 'print(v + v);')
          .replaceFirst('void run() {}', 'void run() { all.add(1); }')
          .replaceFirst('s.toUpperCase()', 's.trim()')
          .replaceFirst("'hi'", "'ho'")
          .replaceFirst('int count = 0;', 'int count = 5;')
          .replaceFirst('[1, 2]', '[3]')
          .replaceFirst(
            'A(this.x) : y = 1;',
            'A(this.x) : y = 1 { print(x); }',
          );
      expect(_api(edited), _api(base));
      expect(_api('// hello\n$base'), _api(base));
    });

    test('keeps what other code can see', () {
      const base = '''
class A {
  int twice() => 2;
  var inferred = compute();
  final int x;
  const A(this.x);
}
int compute() => 1;
const limit = 3;
final inferredTop = compute();
f() => 1;
''';
      for (final (from, to) in [
        ('int twice()', 'num twice()'),
        ('compute();\n  final', 'compute2();\n  final'),
        ('final int x;', 'final int x = 1;'),
        ('const limit = 3', 'const limit = 4'),
        ('final inferredTop = compute()', 'final inferredTop = 1.5'),
        ('f() => 1', 'f() => 1.5'),
        ('int compute() => 1;', 'int compute(int a) => 1;'),
      ]) {
        expect(
          _api(base.replaceFirst(from, to)),
          isNot(_api(base)),
          reason: to,
        );
      }
    });

    test('keeps the values of a class with a const constructor', () {
      const base = '''
class A {
  const A();
  final int x = 1;
}
''';
      expect(_api(base.replaceFirst('= 1', '= 2')), isNot(_api(base)));
    });
  });

  group('the worker', () {
    late Directory tmp;
    late String app;

    setUpAll(() async {
      final lib = await Isolate.resolvePackageUri(
        Uri.parse('package:thor_builder/src/step_worker.dart'),
      );
      final builder = p.normalize(
        p.join(p.dirname(lib!.toFilePath()), '..', '..'),
      );
      tmp = Directory.systemTemp.createTempSync('thor_incremental_');
      app = (Directory(
        p.join(tmp.path, 'incremental_app'),
      )..createSync(recursive: true)).resolveSymbolicLinksSync();
      _writeApp(app, p.dirname(p.dirname(builder)));
    });
    tearDownAll(() => tmp.deleteSync(recursive: true));

    void clean() {
      for (final dir in ['.dart_tool/thor', 'build', 'web']) {
        final d = Directory(p.join(app, dir));
        if (d.existsSync()) d.deleteSync(recursive: true);
      }
    }

    /// The steps through [worker], and what they wrote and said.
    Future<Map<String, String>> steps(StepWorker worker) async {
      clean();
      var id = 0;
      Future<String> ask(Map<String, Object?> request) async {
        final answer = await worker.handle({'id': ++id, ...request});
        expect(answer['error'], isNull, reason: '${answer['error']}');
        // The summary line says what it wrote this time; the rest is the
        // findings.
        final said = [
          for (final line in const LineSplitter().convert(
            '${answer['output']}',
          ))
            if (!line.startsWith('.dart_tool/thor:')) line,
        ].join('\n').replaceAll('$app/', '');
        return 'exit ${answer['exit']}\n$said';
      }

      final entries = await ask({'cmd': 'entries'});
      final lite = await ask({
        'cmd': 'lite_state',
        'out': 'build/lite/state.js',
        'readable': true,
      });
      final bundle = lite.startsWith('exit 0')
          ? await ask({
              'cmd': 'lite_bundle',
              'state': 'build/lite/state.js',
              'out': 'web/engine.dart.js',
              'minify': false,
              'dev': true,
            })
          : '';
      return {
        'entries': entries,
        'lite_state': lite,
        'lite_bundle': bundle.replaceAll(RegExp(r'[\d.]+ KB'), 'N KB'),
        ..._outputs(app),
      };
    }

    /// An incremental update against a cold run of the same sources.
    Future<void> sameAsCold(StepWorker worker, String why) async {
      final incremental = await steps(worker);
      final cold = StepWorker(app);
      try {
        expect(incremental, await steps(cold), reason: why);
      } finally {
        await cold.dispose();
      }
    }

    test('a bundle of the same states and parts is not made again', () async {
      final worker = StepWorker(app);
      addTearDown(worker.dispose);
      Future<Map<String, Object?>> bundle() => worker.handle({
        'id': 1,
        'cmd': 'lite_bundle',
        'state': 'build/lite/state.js',
        'out': 'web/engine.dart.js',
        'minify': false,
        'dev': true,
      });
      final state = await worker.handle({
        'id': 1,
        'cmd': 'lite_state',
        'out': 'build/lite/state.js',
        'readable': true,
      });
      expect(state['exit'], 0, reason: '$state');
      final first = await bundle();
      final out = File(p.join(app, 'web', 'engine.dart.js'));
      expect(out.readAsStringSync(), contains('thor'));
      // Marked: a second bundle would write over the mark.
      out.writeAsStringSync('// mark');
      expect(await bundle(), first);
      expect(out.readAsStringSync(), '// mark');
      // Other states: made again.
      File(p.join(app, 'build', 'lite', 'state.js')).writeAsStringSync(
        '${File(p.join(app, 'build', 'lite', 'state.js')).readAsStringSync()}\n',
      );
      await bundle();
      expect(out.readAsStringSync(), isNot('// mark'));
    });

    test(
      'an update after any edit writes what a cold run writes',
      () async {
        final worker = StepWorker(app);
        addTearDown(worker.dispose);
        await worker.warm();
        final first = await steps(worker);
        expect(first['.dart_tool/thor/states.dart'], contains('CounterState'));
        await sameAsCold(worker, 'the first run');

        // A body of the state: only its own library resolves again.
        final before = worker.cache.resolutions;
        _edit(app, 'lib/counter.dart', 'count.value++', 'count.value += 1');
        await steps(worker);
        expect(
          worker.cache.resolutions - before,
          lessThan(10),
          reason: 'a body-only edit re-resolved most of the app',
        );
        await sameAsCold(worker, 'a body of the state');

        // A page whose closure calls the state's method is a misuse...
        File(p.join(app, 'lib', 'closure.dart')).writeAsStringSync(_closure);
        final closure = await steps(worker);
        expect(
          closure['.dart_tool/thor/state_misuses.txt'],
          contains('closure.dart'),
        );
        await sameAsCold(worker, 'a closure');
        // ... until `counter` is not a state any more: the page did not
        // change, the API of what it calls did.
        _edit(
          app,
          'lib/counter.dart',
          'final counter = CounterState();',
          'final counter = Plain();\n\n'
              'class Plain {\n'
              '  void increment() {}\n'
              '  void reset() {}\n'
              '  void twice() {}\n'
              "  String label() => '';\n"
              '}',
        );
        final plain = await steps(worker);
        expect(plain['.dart_tool/thor/state_misuses.txt'], isNull);
        await sameAsCold(worker, 'the API a misuse was found against');
        _edit(
          app,
          'lib/counter.dart',
          'final counter = Plain();',
          'final counter = CounterState();',
        );
        await sameAsCold(worker, 'the state back');
        File(p.join(app, 'lib', 'closure.dart')).deleteSync();

        // A comment, and a body of a helper the state's file calls.
        _edit(app, 'lib/helpers.dart', '// helpers', '// helpers, edited');
        await sameAsCold(worker, 'a comment');
        _edit(app, 'lib/helpers.dart', "'n=\$n'", "'count=\$n'");
        await sameAsCold(worker, 'a body of a dependency');

        // The API of a dependency: a parameter, and a model field.
        _edit(
          app,
          'lib/helpers.dart',
          'String describe(int n) =>',
          "String describe(int n, [String sep = '=']) =>",
        );
        await sameAsCold(worker, 'an API of a dependency');
        _edit(
          app,
          'lib/model.dart',
          'final String text;',
          'final String text;\n  final int size = 1;',
        );
        await sameAsCold(worker, 'a field of the model');

        // A helper that now asks the page for a confirmation: the state's
        // file reaches it.
        _edit(
          app,
          'lib/helpers.dart',
          '// helpers, edited',
          "import 'package:thor_ui/thor_ui.dart';\n\n"
              "void ask() => confirm('sure?');",
        );
        _edit(
          app,
          'lib/counter.dart',
          'void reset() => count.value = 0;',
          'void reset() {\n    count.value = 0;\n    ask();\n  }',
        );
        await sameAsCold(worker, 'a state that reaches a feature');
        expect(
          (await steps(worker))['.dart_tool/thor/states.dart'],
          contains('uses: const {'),
        );

        // The body of the helper stops asking: the state's file (unchanged,
        // and so is the API of what it imports) reaches nothing now.
        _edit(app, 'lib/helpers.dart', "confirm('sure?')", '{}');
        expect(
          (await steps(worker))['.dart_tool/thor/states.dart'],
          isNot(contains('uses: const {')),
        );
        await sameAsCold(worker, 'a body that no longer calls a feature');

        // A new file with a state and a top-level instance, and a page that
        // uses it.
        File(p.join(app, 'lib', 'timer.dart')).writeAsStringSync(_timer);
        File(p.join(app, 'lib', 'more.dart')).writeAsStringSync(_more);
        await sameAsCold(worker, 'a new state');
        expect(
          (await steps(worker))['.dart_tool/thor/states.dart'],
          contains('TimerState'),
        );

        // A misuse that appears in a page body, and goes.
        _edit(
          app,
          'lib/more.dart',
          'onPressed: counter.twice',
          'onPressed: () => counter.twice()',
        );
        final misused = await steps(worker);
        expect(
          misused['.dart_tool/thor/state_misuses.txt'],
          contains('more.dart'),
        );
        await sameAsCold(worker, 'a misuse');
        _edit(
          app,
          'lib/more.dart',
          'onPressed: () => counter.twice()',
          'onPressed: counter.twice',
        );
        await sameAsCold(worker, 'the misuse fixed');

        // A state class removed from its file, then a file deleted.
        File(p.join(app, 'lib', 'timer.dart')).writeAsStringSync(
          "import 'package:thor_ui/thor_ui.dart';\n\nvoid unused() {}\n",
        );
        await sameAsCold(worker, 'a state removed');
        expect(
          (await steps(worker))['.dart_tool/thor/states.dart'],
          isNot(contains('TimerState')),
        );
        File(p.join(app, 'lib', 'more.dart')).deleteSync();
        File(p.join(app, 'lib', 'timer.dart')).deleteSync();
        await sameAsCold(worker, 'files deleted');
      },
      timeout: const Timeout(Duration(minutes: 8)),
    );
  });
}

/// Every file the steps write, by path in the app.
Map<String, String> _outputs(String app) => {
  for (final dir in ['.dart_tool/thor', 'build/lite', 'web'])
    if (Directory(p.join(app, dir)).existsSync())
      for (final f in Directory(p.join(app, dir)).listSync())
        if (f is File) p.relative(f.path, from: app): f.readAsStringSync(),
};

void _edit(String app, String file, String from, String to) {
  final f = File(p.join(app, file));
  final text = f.readAsStringSync();
  expect(text, contains(from));
  f.writeAsStringSync(text.replaceFirst(from, to));
}

/// A small app whose package config is the checkout's (absolute paths)
/// plus itself.
void _writeApp(String app, String checkout) {
  final config =
      jsonDecode(
            File(
              p.join(checkout, '.dart_tool', 'package_config.json'),
            ).readAsStringSync(),
          )
          as Map<String, Object?>;
  final base = Uri.directory(p.join(checkout, '.dart_tool'));
  final packages = [
    for (final package
        in (config['packages']! as List).cast<Map<String, Object?>>())
      {...package, 'rootUri': '${base.resolve(package['rootUri']! as String)}'},
    {
      'name': 'incremental_app',
      'rootUri': '${Uri.directory(app)}',
      'packageUri': 'lib/',
      'languageVersion': '3.8',
    },
  ];
  File(p.join(app, '.dart_tool', 'package_config.json'))
    ..createSync(recursive: true)
    ..writeAsStringSync(jsonEncode({...config, 'packages': packages}));
  File(p.join(app, 'pubspec.yaml')).writeAsStringSync('''
name: incremental_app
environment:
  sdk: ^3.10.0
''');
  void write(String name, String source) => File(p.join(app, 'lib', name))
    ..createSync(recursive: true)
    ..writeAsStringSync(source);
  write('model.dart', '''
class Label {
  const Label(this.text);

  final String text;

  String shout() => text.toUpperCase();
}
''');
  write('helpers.dart', r'''
// helpers
String describe(int n) => 'n=$n';
''');
  write('counter.dart', r'''
import 'package:thor_ui/thor_ui.dart';

import 'helpers.dart';
import 'model.dart';

class CounterState extends ThorState {
  final count = state(0);

  String label() => '${const Label('x').shout()} ${describe(count.value)}';

  void increment() => count.value++;

  void reset() => count.value = 0;

  void twice() => count.value += 2;
}

final counter = CounterState();
''');
  write('page.dart', '''
import 'package:thor_ui/thor_ui.dart';

import 'counter.dart';

class Buttons extends StatelessWidget {
  const Buttons({super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      FilledButton(onPressed: counter.increment, child: const Text('+')),
      FilledButton(onPressed: counter.reset, child: const Text('0')),
    ],
  );
}
''');
}

const _closure = '''
import 'package:thor_ui/thor_ui.dart';

import 'counter.dart';

// Calls a method of the CounterState in `counter`.
class Closed extends StatelessWidget {
  const Closed({super.key});

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: () => counter.increment(),
    child: const Text('+'),
  );
}
''';

const _timer = r'''
import 'package:thor_ui/thor_ui.dart';

class TimerState extends ThorState {
  final seconds = state(0);

  void tick() => seconds.value++;
}

final timer = TimerState();
''';

const _more = '''
import 'package:thor_ui/thor_ui.dart';

import 'counter.dart';
import 'timer.dart';

class Twice extends StatelessWidget {
  const Twice({super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      FilledButton(onPressed: counter.twice, child: Watch(counter.label)),
      FilledButton(onPressed: timer.tick, child: const Text('tick')),
    ],
  );
}
''';
