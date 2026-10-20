// thor dev's worker (bin/worker.dart) against the one-shot commands: after
// each change, a request writes the same files and prints the same lines as
// `dart run` of bin/entries.dart, bin/lite_state.dart and thor_engine's
// bin/lite_bundle.dart.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thor_builder/src/step_worker.dart';

void main() {
  late Directory tmp;
  late String app;
  late String builder;
  late String engine;

  setUpAll(() async {
    final lib = await Isolate.resolvePackageUri(
      Uri.parse('package:thor_builder/src/step_worker.dart'),
    );
    builder = p.normalize(p.join(p.dirname(lib!.toFilePath()), '..', '..'));
    engine = p.join(p.dirname(builder), 'thor_engine');
    tmp = Directory.systemTemp.createTempSync('thor_worker_');
    app = (Directory(
      p.join(tmp.path, 'worker_app'),
    )..createSync(recursive: true)).resolveSymbolicLinksSync();
    _writeApp(app, p.dirname(p.dirname(builder)));
  });
  tearDownAll(() => tmp.deleteSync(recursive: true));

  /// What the one-shot commands write and print, in that order.
  Future<Map<String, String>> oneShot() async {
    Future<String> run(String script, List<String> args) async {
      final r = await Process.run('dart', [
        'run',
        script,
        ...args,
        // Not in the app: `dart run` there would `pub get` it.
      ], workingDirectory: builder);
      return 'exit ${r.exitCode}\n${r.stdout}${r.stderr}';
    }

    final state = p.join(app, 'build', 'lite', 'state.js');
    final entries = await run(p.join(builder, 'bin', 'entries.dart'), [app]);
    final lite = await run(p.join(builder, 'bin', 'lite_state.dart'), [
      app,
      state,
      '--readable',
    ]);
    final bundle = lite.startsWith('exit 0')
        ? await run(p.join(engine, 'bin', 'lite_bundle.dart'), [
            '--no-minify',
            '--dev',
            state,
            app,
            p.join(app, 'web', 'engine.dart.js'),
          ])
        : '';
    return {
      'entries': entries,
      'lite_state': lite,
      'lite_bundle': bundle,
      ..._outputs(app),
    };
  }

  /// The same through [worker].
  Future<Map<String, String>> worked(StepWorker worker) async {
    var id = 0;
    Future<String> ask(Map<String, Object?> request) async {
      final answer = await worker.handle({'id': ++id, ...request});
      expect(answer['id'], id);
      expect(answer['error'], isNull, reason: '${answer['error']}');
      return 'exit ${answer['exit']}\n${answer['output']}';
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
      'lite_bundle': bundle,
      ..._outputs(app),
    };
  }

  void clean() {
    for (final dir in ['.dart_tool/thor', 'build', 'web']) {
      final d = Directory(p.join(app, dir));
      if (d.existsSync()) d.deleteSync(recursive: true);
    }
  }

  /// The one-shot's and the worker's results, each from a clean slate
  /// (the entries rewrite a file only when it changes: `wrote …`).
  Future<Map<String, String>> same(StepWorker worker) async {
    clean();
    final expected = await oneShot();
    clean();
    final actual = await worked(worker);
    // Both name the files they write with their absolute paths.
    String relative(String text) => text.replaceAll('$app/', '');
    expect(
      actual.map((k, v) => MapEntry(k, relative(v))),
      expected.map((k, v) => MapEntry(k, relative(v))),
    );
    return expected;
  }

  test(
    'a request after each change writes what the one-shot commands write',
    () async {
      final worker = StepWorker(app);
      addTearDown(worker.dispose);
      await worker.warm();
      expect((await same(worker))['entries'], contains('THOR-S'));

      // A state's body.
      _edit(app, 'lib/counter.dart', r"'${count.value}'", r"'n${count.value}'");
      expect(
        (await same(worker))['web/engine.dart.js'],
        contains(r'`n${count.value}`'),
      );

      // A new member and a new file that uses the state.
      _edit(
        app,
        'lib/counter.dart',
        '  void reset()',
        '  void twice() => count.value += 2;\n\n  void reset()',
      );
      File(p.join(app, 'lib', 'more.dart')).writeAsStringSync(_more);
      await same(worker);

      // Outside the lite subset: exit 1 and the file and line, nothing
      // written; then fixed.
      _edit(
        app,
        'lib/counter.dart',
        '  void reset()',
        '  void io() => print(DateTime.now().timeZoneName);\n\n  void reset()',
      );
      expect((await same(worker))['lite_state'], startsWith('exit 1'));
      _edit(
        app,
        'lib/counter.dart',
        '  void io() => print(DateTime.now().timeZoneName);\n\n',
        '',
      );
      File(p.join(app, 'lib', 'more.dart')).deleteSync();
      await same(worker);
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test(
    'an identical run leaves the lite outputs untouched',
    () async {
      final worker = StepWorker(app);
      addTearDown(worker.dispose);
      Future<void> run() async {
        for (final request in [
          {'cmd': 'lite_state', 'out': 'build/lite/state.js', 'readable': true},
          {
            'cmd': 'lite_bundle',
            'state': 'build/lite/state.js',
            'out': 'web/engine.dart.js',
            'minify': false,
            'dev': true,
          },
        ]) {
          final answer = await worker.handle({'id': 1, ...request});
          expect(answer['exit'], 0, reason: '$answer');
        }
      }

      final files = [
        File(p.join(app, 'build', 'lite', 'state.js')),
        File(p.join(app, 'web', 'engine.dart.js')),
      ];
      final past = DateTime(2020);
      await run();
      for (final f in files) {
        f.setLastModifiedSync(past);
      }
      await run();
      for (final f in files) {
        expect(f.lastModifiedSync(), past, reason: '${f.path} was rewritten');
      }
      // A real change still writes.
      const member = '  void thrice() => count.value += 3;\n\n';
      _edit(app, 'lib/counter.dart', '  void reset()', '$member  void reset()');
      addTearDown(() => _edit(app, 'lib/counter.dart', member, ''));
      await run();
      for (final f in files) {
        expect(f.lastModifiedSync(), isNot(past), reason: '${f.path} stale');
      }
      expect(files.first.readAsStringSync(), contains('thrice'));
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test('serves JSON lines in order and stops when its input ends', () async {
    final input = StreamController<String>();
    final output = StringBuffer();
    final served = serveSteps(StepWorker(app), input.stream, output);
    input
      ..add(jsonEncode({'id': 1, 'cmd': 'entries'}))
      ..add('not json')
      ..add(jsonEncode({'id': 2, 'cmd': 'nope'}))
      ..add(
        jsonEncode({
          'id': 3,
          'cmd': 'lite_state',
          'out': 'build/lite/state.js',
          'readable': true,
        }),
      );
    await input.close();
    await served;
    final answers = [
      for (final line in const LineSplitter().convert('$output'))
        jsonDecode(line) as Map<String, Object?>,
    ];
    expect(answers, hasLength(4));
    expect(answers[0]['error'], startsWith('not a request'));
    expect([for (final a in answers.skip(1)) a['id']], [1, 2, 3]);
    expect(answers[1]['exit'], 0);
    expect(answers[2]['error'], 'unknown cmd: nope');
    expect(answers[3]['exit'], 0);
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
      'name': 'worker_app',
      'rootUri': '${Uri.directory(app)}',
      'packageUri': 'lib/',
      'languageVersion': '3.8',
    },
  ];
  File(p.join(app, '.dart_tool', 'package_config.json'))
    ..createSync(recursive: true)
    ..writeAsStringSync(jsonEncode({...config, 'packages': packages}));
  File(p.join(app, 'pubspec.yaml')).writeAsStringSync('''
name: worker_app
environment:
  sdk: ^3.10.0
''');
  File(p.join(app, 'lib', 'counter.dart'))
    ..createSync(recursive: true)
    ..writeAsStringSync(r'''
import 'package:thor_ui/thor_ui.dart';

class CounterState extends ThorState {
  final count = state(0);

  String label() => '${count.value}';

  void increment() => count.value++;

  void reset() => count.value = 0;
}

final counter = CounterState();
''');
  File(p.join(app, 'lib', 'page.dart')).writeAsStringSync('''
import 'package:thor_ui/thor_ui.dart';

import 'counter.dart';

class Buttons extends StatelessWidget {
  const Buttons({super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      FilledButton(onPressed: counter.increment, child: const Text('+')),
      // A closure: the browser can't run it (a state misuse).
      FilledButton(onPressed: () => counter.reset(), child: const Text('0')),
    ],
  );
}
''');
}

const _more = '''
import 'package:thor_ui/thor_ui.dart';

import 'counter.dart';

class Twice extends StatelessWidget {
  const Twice({super.key});

  @override
  Widget build(BuildContext context) =>
      FilledButton(onPressed: counter.twice, child: Watch(counter.label));
}
''';
