@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// The `thor` shim that `tool/thor setup` installs (tool/cli_shim.sh), run
/// against a fake checkout whose CLI just echoes its arguments, so the tests
/// are fast and never touch the real pub cache.
void main() {
  final repo = Directory.current.path;
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('thor-shim-'));
  tearDown(() => tmp.deleteSync(recursive: true));

  /// A fake checkout in [name] (may contain spaces or unicode) and its shim.
  ({String root, String shim}) install(String name) {
    final root = '${tmp.path}/$name';
    Directory('$root/packages/thor_cli/bin').createSync(recursive: true);
    Directory('$root/packages/thor_ui/lib').createSync(recursive: true);
    File('$root/pubspec.lock').writeAsStringSync('');
    File('$root/packages/thor_ui/lib/a.dart').writeAsStringSync('');
    File('$root/packages/thor_cli/bin/thor.dart').writeAsStringSync(r'''
import 'dart:io';
Future<void> main(List<String> args) async {
  if (args.isNotEmpty && args.first == '--') exit(64); // like the real CLI
  if (args.length == 1 && args.first == 'help') return;
  if (args.length == 1 && args.first == 'which') { stdout.writeln(Platform.script.path); return; }
  if (args.isNotEmpty && args.first == 'exit') exit(int.parse(args[1]));
  if (args.isNotEmpty && args.first == 'cat') {
    stdout.write(await stdin.transform(const SystemEncoding().decoder).join());
    return;
  }
  if (args.isNotEmpty && args.first == 'sleep') {
    stdout.writeln('pid ${pid}');
    await stdout.flush();
    await Future<void>.delayed(const Duration(seconds: 30));
    return;
  }
  stdout.writeln(args.length);
  for (final a in args) { stdout.writeln('<$a>'); }
  stdout.writeln('cwd=${Directory.current.path}');
}
''');
    final shim = '${tmp.path}/shim-${name.hashCode}';
    final r = Process.runSync('bash', [
      'tool/thor',
      'shim',
      root,
      shim,
    ], workingDirectory: repo);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    return (root: root, shim: shim);
  }

  Future<ProcessResult> run(
    String shim,
    List<String> args, {
    Map<String, String>? env,
    String? cwd,
  }) => Process.run(
    shim,
    args,
    workingDirectory: cwd ?? tmp.path,
    environment: env,
  );

  test('arguments pass through intact', () async {
    final s = install('plain');
    final args = [
      'a b',
      "it's",
      r'$HOME',
      '*',
      '--',
      '',
      '"q"',
      '-n',
      'x\ny',
      r'$(echo hi)',
      '`id`',
    ];
    final r = await run(s.shim, args);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final out = const LineSplitter().convert(r.stdout as String);
    expect(out.first, '${args.length}');
    expect(r.stdout as String, contains('<x\ny>'));
    expect(
      out,
      containsAll(['<a b>', "<it's>", r'<$HOME>', '<*>', '<-->', '<>']),
    );
  });

  test('checkout path with spaces, quote, dollar and unicode', () async {
    for (final name in ['sp ace', "o'brien", r'dollar$x', 'ñandú ü', 'a&b']) {
      final s = install(name);
      final r = await run(s.shim, ['hi']);
      expect(r.exitCode, 0, reason: '$name: ${r.stderr}');
      expect(r.stdout, contains('<hi>'), reason: name);
      // cwd is the caller's, not the checkout
      expect(r.stdout, contains('cwd=${tmp.resolveSymbolicLinksSync()}'));
    }
  });

  test('exit codes propagate', () async {
    final s = install('codes');
    for (final code in [0, 1, 2, 64, 255]) {
      final r = await run(s.shim, ['exit', '$code']);
      expect(r.exitCode, code);
    }
  });

  test('stdin passes through', () async {
    final s = install('stdin');
    final p = await Process.start(s.shim, ['cat'], workingDirectory: tmp.path);
    p.stdin.write('hola\nmundo');
    await p.stdin.close();
    expect(await p.stdout.transform(utf8.decoder).join(), 'hola\nmundo');
    expect(await p.exitCode, 0);
  });

  test('a signal reaches the dart process and leaves no orphan', () async {
    final s = install('sig');
    await run(s.shim, ['x']); // build the snapshot first
    final p = await Process.start(s.shim, [
      'sleep',
    ], workingDirectory: tmp.path);
    final line = await p.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .first;
    final dartPid = int.parse(line.split(' ').last);
    // exec: the shim process IS the dart process.
    expect(p.pid, dartPid);
    p.kill(ProcessSignal.sigterm);
    await p.exitCode.timeout(const Duration(seconds: 5));
  });

  test('the first run already uses the fresh snapshot', () async {
    final s = install('first');
    final r = await run(s.shim, ['which']);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    expect((r.stdout as String).trim(), endsWith('thor.jit'));
    expect(
      File('${s.root}/.dart_tool/thor/thor.jit.stamp').existsSync(),
      isTrue,
    );
  });

  test('a stale snapshot is rebuilt once, then reused', () async {
    final s = install('stale');
    final snap = File('${s.root}/.dart_tool/thor/thor.jit');
    var r = await run(s.shim, ['x']);
    expect(r.stderr, contains('rebuilding'));
    expect(snap.existsSync(), isTrue);
    r = await run(s.shim, ['x']);
    expect(r.stderr, isNot(contains('rebuilding')));
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    File('${s.root}/packages/thor_ui/lib/a.dart').writeAsStringSync('//');
    r = await run(s.shim, ['x']);
    expect(r.stderr, contains('rebuilding'));
    r = await run(s.shim, ['x']);
    expect(r.stderr, isNot(contains('rebuilding')));
  });

  test('concurrent runs on a stale snapshot all succeed', () async {
    final s = install('race');
    final results = await Future.wait([
      for (var i = 0; i < 8; i++) run(s.shim, ['n$i']),
    ]);
    for (final (i, r) in results.indexed) {
      expect(r.exitCode, 0, reason: '$i: ${r.stderr}');
      expect(r.stdout, contains('<n$i>'));
    }
    // and no temp leftovers
    final left = Directory(
      '${s.root}/.dart_tool/thor',
    ).listSync().map((e) => e.path.split('/').last).toList();
    expect(left, unorderedEquals(['thor.jit', 'thor.jit.stamp']));
  });

  test('a snapshot made by another Dart is rebuilt, not run', () async {
    final s = install('sdk');
    await run(s.shim, ['x']);
    // Simulate an SDK change: the stamp says another dart built it.
    final stamp = File('${s.root}/.dart_tool/thor/thor.jit.stamp');
    expect(stamp.existsSync(), isTrue);
    stamp.writeAsStringSync('Dart SDK version: 1.0.0\n');
    final r = await run(s.shim, ['hello']);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    expect(r.stdout, contains('<hello>'));
    expect(r.stderr, contains('rebuilding'));
  });

  test('a corrupt snapshot is rebuilt', () async {
    final s = install('corrupt');
    await run(s.shim, ['x']);
    final snap = File('${s.root}/.dart_tool/thor/thor.jit');
    snap.writeAsBytesSync(snap.readAsBytesSync().sublist(0, 100));
    final r = await run(s.shim, ['hello']);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    expect(r.stdout, contains('<hello>'));
  });

  test(
    'a read-only .dart_tool falls back to the source',
    () async {
      final s = install('ro');
      final dir = Directory('${s.root}/.dart_tool');
      dir.createSync();
      Process.runSync('chmod', ['555', dir.path]);
      addTearDown(() => Process.runSync('chmod', ['755', dir.path]));
      final r = await run(s.shim, ['hello']);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(r.stdout, contains('<hello>'));
    },
    skip: Platform.environment['USER'] == 'root' ? 'root ignores modes' : null,
  );

  test('a moved or deleted checkout says so', () async {
    final s = install('gone');
    Directory(s.root).deleteSync(recursive: true);
    final r = await run(s.shim, ['hello']);
    expect(r.exitCode, isNot(0));
    expect(r.stderr, contains(s.root));
    expect(r.stderr, contains('setup'));
  });

  test('without dart on PATH it says so', () async {
    final s = install('nodart');
    final r = await run(
      s.shim,
      ['hello'],
      env: {'PATH': '/usr/bin:/bin', 'HOME': tmp.path},
    );
    expect(r.exitCode, 127);
    expect(r.stderr, contains('dart'));
  });

  test('a failing rebuild falls back to the source', () async {
    final s = install('brokenbuild');
    // Syntax error only in an unused part of thor.dart? Use a compile error
    // in the entry: jit build fails, source run fails too -> nonzero, and
    // no snapshot is left behind that the next run would trust.
    File(
      '${s.root}/packages/thor_cli/bin/thor.dart',
    ).writeAsStringSync('void main( {');
    final r = await run(s.shim, ['hello']);
    expect(r.exitCode, isNot(0));
    expect(File('${s.root}/.dart_tool/thor/thor.jit').existsSync(), isFalse);
  });
}
