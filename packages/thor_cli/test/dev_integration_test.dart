// `thor dev` end to end: a new app, a save that hot reloads (same server
// process), one that must restart, a compile error and an exception on the
// page (the overlay), and no process left when it stops, even killed.
@TestOn('mac-os || linux')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thor_cli/thor_cli.dart';

/// A running `thor dev`, and what it printed.
class _Dev {
  _Dev(this.process, this.appDir, this.port) {
    for (final stream in [process.stdout, process.stderr]) {
      stream.transform(utf8.decoder).transform(const LineSplitter()).listen((
        line,
      ) {
        log.add(line);
        for (final w in [..._waiters]) {
          if (w.$1.hasMatch(line)) {
            _waiters.remove(w);
            w.$2.complete(line);
          }
        }
      });
    }
  }

  final Process process;
  final String appDir;
  final int port;
  final log = <String>[];
  final _waiters = <(RegExp, Completer<String>)>[];

  static Future<_Dev> start(
    String appDir,
    String checkout,
    int port, [
    List<String> options = const [],
  ]) async {
    final process = await Process.start('dart', [
      'run',
      p.join(checkout, 'packages', 'thor_cli', 'bin', 'thor.dart'),
      'dev',
      '--port',
      '$port',
      ...options,
    ], workingDirectory: appDir);
    final dev = _Dev(process, appDir, port);
    // Even when the test fails or times out: no app server outlives it.
    addTearDown(dev.killAll);
    return dev;
  }

  /// Stops it and everything it started (what its record names).
  Future<void> killAll() async {
    final record = File(p.join(appDir, '.dart_tool', 'thor', 'dev-$port.pids'));
    final started = record.existsSync() ? pids : const <int>[];
    process.kill(ProcessSignal.sigkill);
    for (final pid in started) {
      // Still one of ours (a pid may have been reused).
      final command = Process.runSync('ps', ['-o', 'command=', '-p', '$pid']);
      if ('${command.stdout}'.contains(RegExp('dart|thor-dev'))) {
        Process.runSync('kill', ['-9', '$pid']);
      }
    }
  }

  /// The next line matching [pattern] (from now on).
  Future<String> next(
    Pattern pattern, {
    Duration timeout = const Duration(seconds: 60),
  }) {
    final done = Completer<String>();
    _waiters.add((RegExp(pattern.toString()), done));
    return done.future.timeout(
      timeout,
      onTimeout: () => throw TimeoutException(
        'no "$pattern" in thor dev output:\n${log.join('\n')}',
      ),
    );
  }

  /// The processes it started (server first).
  List<int> get pids => [
    for (final line in File(
      p.join(appDir, '.dart_tool', 'thor', 'dev-$port.pids'),
    ).readAsLinesSync())
      ?int.tryParse(line.trim()),
  ];
}

bool _alive(int pid) => Process.runSync('kill', ['-0', '$pid']).exitCode == 0;

Future<void> _gone(List<int> pids) async {
  final clock = Stopwatch()..start();
  while (pids.any(_alive)) {
    if (clock.elapsed > const Duration(seconds: 15)) {
      fail('still running: ${pids.where(_alive).toList()}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

void main() {
  late Directory tmp;
  late String checkout;
  late String app;
  final client = HttpClient();

  setUpAll(() async {
    final library = await Isolate.resolvePackageUri(
      Uri.parse('package:thor_cli/thor_cli.dart'),
    );
    checkout = p.normalize(
      p.join(p.dirname(library!.toFilePath()), '..', '..', '..'),
    );
    tmp = Directory.systemTemp.createTempSync('thor_dev_');
    app = p.join(tmp.path, 'shop');
    writeApp(app, 'shop', source: LocalSource(checkout));
    final pub = await Process.run('dart', [
      'pub',
      'get',
      '--offline',
    ], workingDirectory: app);
    expect(pub.exitCode, 0, reason: '${pub.stdout}${pub.stderr}');
  });
  // A stopped `thor dev` may still be flushing a file into the app for a
  // moment (a code generation output): retry instead of failing the run.
  tearDownAll(() async {
    for (var attempt = 0; ; attempt++) {
      try {
        tmp.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        if (attempt == 20) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
  });

  Future<(int, String)> get(int port, String path) async {
    final request = await client.get('localhost', port, path);
    final response = await request.close();
    return (response.statusCode, await utf8.decodeStream(response));
  }

  void edit(String file, String from, String to) {
    final f = File(p.join(app, file));
    final text = f.readAsStringSync();
    expect(text, contains(from));
    f.writeAsStringSync(text.replaceFirst(from, to));
  }

  test('listens on the loopback only, and refuses a foreign Host', () async {
    final port = await _anyPort();
    final dev = await _Dev.start(app, checkout, port);
    try {
      await dev.next(
        'http://localhost:$port',
        timeout: const Duration(minutes: 3),
      );
      // The app behind the proxy: its own port, the one the proxy uses.
      final upstream = port + 1000;
      Future<int> status(
        int at,
        String host, [
        Object address = '127.0.0.1',
      ]) async {
        final request = await client.get(address as String, at, '/');
        final i = host.lastIndexOf(':');
        request.headers.host = i < 0 ? host : host.substring(0, i);
        if (i >= 0) request.headers.port = int.parse(host.substring(i + 1));
        final response = await request.close();
        await response.drain<void>();
        return response.statusCode;
      }

      expect(await status(port, 'localhost:$port'), 200);
      expect(await status(port, '127.0.0.1:$port'), 200);
      expect(await status(port, 'evil.example'), 403);
      // The app too, reached directly (DNS rebinding to its port).
      expect(await status(upstream, 'localhost:$upstream'), 200);
      expect(await status(upstream, 'evil.example'), 403);

      // Neither answers on a non-loopback address of this machine.
      final lan = [
        for (final i in await NetworkInterface.list(
          type: InternetAddressType.IPv4,
        ))
          for (final a in i.addresses)
            if (!a.isLoopback && !a.isLinkLocal) a,
      ];
      for (final address in lan.take(1)) {
        for (final at in [port, upstream]) {
          await expectLater(
            Socket.connect(address, at, timeout: const Duration(seconds: 2)),
            throwsA(isA<SocketException>()),
            reason: '${address.address}:$at',
          );
        }
      }
    } finally {
      dev.process.kill();
      await dev.process.exitCode;
    }
  });

  test('a second thor dev of the app leaves the first one running', () async {
    final first = await _anyPort();
    final a = await _Dev.start(app, checkout, first);
    await a.next(
      'http://localhost:$first',
      timeout: const Duration(minutes: 3),
    );
    expect((await get(first, '/')).$1, 200);
    final firstPids = a.pids;

    final second = first + 2;
    final b = await _Dev.start(app, checkout, second);
    await b.next(
      'http://localhost:$second',
      timeout: const Duration(minutes: 3),
    );
    expect(
      b.log.join('\n'),
      contains('another thor dev of this app is running on :$first'),
    );
    expect(b.log.join('\n'), isNot(contains('left by a previous run')));
    // Both answer, and nothing of the first was stopped.
    expect((await get(first, '/')).$1, 200);
    expect((await get(second, '/')).$1, 200);
    expect(firstPids.every(_alive), isTrue);
    expect(a.pids, firstPids, reason: 'no restart');

    // Stopped by hand: each run cleans its own record only.
    b.process.kill();
    await b.process.exitCode;
    expect((await get(first, '/')).$1, 200);
    expect(
      File(p.join(app, '.dart_tool', 'thor', 'dev-$second.pids')).existsSync(),
      isFalse,
    );
    a.process.kill();
    await a.process.exitCode;
    await _gone(firstPids);
  });

  test(
    'bad --host and --allowed-host fail with a message, no trace',
    () async {
      for (final (options, message) in [
        (['--allowed-host', '*.example.test'], 'not a host name'),
        (['--allowed-host', 'https://dev.example'], 'not a host name'),
        (['--host', 'nonexistent.invalid'], 'not an address or a known name'),
        (['--host='], 'not an address or a known name'),
        // An address this machine doesn't have.
        (['--host', '8.8.8.8'], 'Cannot listen on 8.8.8.8'),
      ]) {
        final dev = await _Dev.start(app, checkout, await _anyPort(), options);
        // Fails fast: before any code generation, so load can't stretch it.
        final code = await dev.process.exitCode.timeout(
          const Duration(seconds: 45),
          onTimeout: () {
            dev.process.kill(ProcessSignal.sigkill);
            throw TimeoutException(
              'thor dev $options did not exit:\n${dev.log.join('\n')}',
            );
          },
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final out = dev.log.join('\n');
        expect(code, isNot(0), reason: '$options');
        expect(out, contains(message), reason: '$options\n$out');
        expect(out, isNot(contains('#0')), reason: 'a stack trace: $options');
        expect(
          out,
          isNot(contains('Code generation')),
          reason: 'the options are checked before any work: $options\n$out',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test('--host opens the proxy to the network, the app stays local', () async {
    final port = await _anyPort();
    final dev = await _Dev.start(app, checkout, port, ['--host']);
    try {
      await dev.next(
        'http://localhost:$port',
        timeout: const Duration(minutes: 3),
      );
      final lan = [
        for (final i in await NetworkInterface.list(
          type: InternetAddressType.IPv4,
        ))
          for (final a in i.addresses)
            if (!a.isLoopback && !a.isLinkLocal) a,
      ];
      if (lan.isEmpty) return;
      final socket = await Socket.connect(lan.first, port);
      socket.destroy();
      await expectLater(
        Socket.connect(
          lan.first,
          port + 1000,
          timeout: const Duration(seconds: 2),
        ),
        throwsA(isA<SocketException>()),
      );
      // By its address the page is served; by a name nobody allowed, not.
      final request = await client.get(lan.first.address, port, '/');
      expect((await request.close()).statusCode, 200);
      final foreign = await client.get(lan.first.address, port, '/');
      foreign.headers.host = 'evil.example';
      expect((await foreign.close()).statusCode, 403);
    } finally {
      dev.process.kill();
      await dev.process.exitCode;
    }
  });

  test(
    'hot reload, restart, overlay, and nothing left when it stops',
    () async {
      final port = await _anyPort();
      final dev = await _Dev.start(app, checkout, port);
      await dev.next(
        'http://localhost:$port',
        timeout: const Duration(minutes: 3),
      );
      expect((await get(port, '/')).$2, contains('Hello, Thor'));
      final server = dev.pids.first;

      // A function body: the same process runs the new code.
      var done = dev.next('reloaded in|restart');
      edit(
        'lib/modules/home/pages/home_page.dart',
        "'Hello, Thor',",
        "'Hola, recarga',",
      );
      expect(await done, contains('reloaded in'));
      expect((await get(port, '/')).$2, contains('Hola, recarga'));
      expect(dev.pids.first, server);

      // A state's body: the builder worker's analysis is warm, the engine
      // is rebuilt with the new code in well under the ~5 s of a cold
      // `dart run` per step.
      const state = 'lib/modules/home/state/counter_view_model.dart';
      var clock = Stopwatch()..start();
      done = dev.next('reloaded in|restart');
      edit(state, r"'${count.value}'", r"'n${count.value}'");
      expect(await done, contains('reloaded in'));
      expect(clock.elapsed, lessThan(const Duration(milliseconds: 2500)));
      expect((await get(port, '/engine.dart.js')).$2, contains(r'`n${'));
      expect(dev.pids.first, server);

      // The worker gone: the steps run with `dart run`, said once, and
      // the engine still has the new code.
      final worker = dev.pids[1];
      Process.killPid(worker, ProcessSignal.sigkill);
      await _gone([worker]);
      final notice = dev.next('builder worker stopped');
      done = dev.next('reloaded in|restart');
      edit(state, r"'n${count.value}'", r"'m${count.value}'");
      await notice;
      expect(await done, contains('reloaded in'));
      expect((await get(port, '/engine.dart.js')).$2, contains(r'`m${'));

      // A new member of a state, used by a button: the server registers
      // it again after a hot reload (no restart), and renders it.
      final logged = dev.log.length;
      edit(
        state,
        '  /// One more.',
        '  void twice() => count.value *= 2;\n\n  /// One more.',
      );
      edit(
        'lib/modules/home/widgets/counter_card.dart',
        'onPressed: counter.reset,',
        'onPressed: counter.twice,',
      );
      clock = Stopwatch()..start();
      while (!(await get(port, '/')).$2.contains('CounterViewModel.twice')) {
        expect(clock.elapsed, lessThan(const Duration(seconds: 20)));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect((await get(port, '/engine.dart.js')).$2, contains('twice'));
      expect(dev.pids.first, server);
      expect(dev.log.skip(logged), isNot(contains(contains('restart'))));

      // A deleted file: the saves after it don't wait for a code
      // generation the app doesn't run (it cost 5 s on every save).
      final scratch = File(p.join(app, 'lib', 'scratch.dart'))
        ..writeAsStringSync('// scratch\n');
      await dev.next('reloaded in|restart');
      done = dev.next('reloaded in|restart');
      scratch.deleteSync();
      await done;
      clock = Stopwatch()..start();
      done = dev.next('reloaded in|restart');
      edit(
        'lib/modules/home/pages/home_page.dart',
        "'Hola, recarga',",
        "'Hola, otra vez',",
      );
      expect(await done, contains('reloaded in'));
      expect(clock.elapsed, lessThan(const Duration(seconds: 3)));
      edit(
        'lib/modules/home/pages/home_page.dart',
        "'Hola, otra vez',",
        "'Hola, recarga',",
      );
      await dev.next('reloaded in|restart');

      // A new top-level variable reloads; changing its value restarts
      // (the old value would stay).
      done = dev.next('reloaded in|restart');
      File(
        p.join(app, 'lib', 'modules', 'home', 'pages', 'home_page.dart'),
      ).writeAsStringSync('\nfinal extra = 1;\n', mode: FileMode.append);
      expect(await done, contains('reloaded in'));
      done = dev.next('restarting');
      edit(
        'lib/modules/home/pages/home_page.dart',
        'final extra = 1;',
        'final extra = 2;',
      );
      expect(await done, contains('extra'));
      await dev.next('restarted in');
      final restarted = dev.pids.first;
      expect(restarted, isNot(server));
      expect(_alive(server), isFalse);

      // A compile error: the overlay, with the file; fixed, the page.
      done = dev.next('Error:');
      edit(
        'lib/modules/home/pages/home_page.dart',
        "'Hola, recarga',",
        "'Hola, recarga' 1,",
      );
      await done;
      var (status, html) = await get(port, '/');
      expect(status, 500);
      expect(html, contains('<title>The code does not compile</title>'));
      expect(html, contains('thor-dev-overlay'));
      expect(html, contains('pages/home_page.dart'));
      done = dev.next('reloaded in');
      edit(
        'lib/modules/home/pages/home_page.dart',
        "'Hola, recarga' 1,",
        "'Hola, recarga',",
      );
      await done;
      expect((await get(port, '/')).$1, 200);

      // An exception on the page: the overlay points at the line.
      done = dev.next('reloaded in');
      final page = File(
        p.join(app, 'lib', 'modules', 'home', 'pages', 'home_page.dart'),
      );
      page.writeAsStringSync(
        page
            .readAsStringSync()
            // `const` can't hold the throwing expression: dropped too.
            .replaceFirst('=> const Column(', '=> Column(')
            .replaceFirst(
              "Text(\n        'Edit",
              "Text(\n        <String>[][0] + 'Edit",
            ),
      );
      await done;
      (status, html) = await get(port, '/');
      expect(status, 500);
      expect(html, contains('thor-dev-overlay'));
      expect(html, isNot(contains('thor-dev-error')));
      expect(html, contains(r'"phase":"build"'));
      expect(html, contains('lib/modules/home/pages/home_page.dart'));
      expect(restarted, dev.pids.first);

      // Stopped: every process it started is gone.
      final pids = dev.pids;
      dev.process.kill();
      expect(await dev.process.exitCode, 0);
      await _gone(pids);
    },
    timeout: const Timeout(Duration(minutes: 6)),
  );

  test(
    'killed with -9: the server and code generation stop by themselves',
    () async {
      final port = await _anyPort();
      final dev = await _Dev.start(app, checkout, port);
      await dev.next(
        'http://localhost:$port',
        timeout: const Duration(minutes: 3),
      );
      // The server and the builder worker; a new app has no build_runner
      // to watch.
      final pids = dev.pids;
      expect(pids, hasLength(2));
      dev.process.kill(ProcessSignal.sigkill);
      await dev.process.exitCode;
      await _gone(pids);
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
  test(
    'a typedef moved to a new file with a new shape restarts the server',
    () async {
      final moved = p.join(tmp.path, 'moved');
      writeApp(moved, 'moved', source: LocalSource(checkout));
      expect(
        (await Process.run('dart', [
          'pub',
          'get',
          '--offline',
        ], workingDirectory: moved)).exitCode,
        0,
      );
      final home = File(
        p.join(moved, 'lib', 'modules', 'home', 'pages', 'home_page.dart'),
      );
      final port = await _anyPort();
      final dev = await _Dev.start(moved, checkout, port);
      await dev.next(
        'http://localhost:$port',
        timeout: const Duration(minutes: 3),
      );
      final server = dev.pids.first;
      // A typedef in a file of its own: a reload takes it.
      var done = dev.next('reloaded in|restart');
      home.writeAsStringSync(
        '\ntypedef Pair = (int, String);\n',
        mode: FileMode.append,
      );
      expect(await done, contains('reloaded in'));
      // One save: it leaves this file and arrives in a new one, with
      // another shape. The new file has no earlier version to compare.
      done = dev.next('reloaded in|restart');
      home.writeAsStringSync(
        home.readAsStringSync().replaceFirst(
          'typedef Pair = (int, String);',
          '',
        ),
      );
      File(
        p.join(moved, 'lib', 'pair.dart'),
      ).writeAsStringSync('typedef Pair = (int, String, bool);\n');
      expect(await done, contains('typedef Pair'));
      await dev.next('restarted in');
      expect(dev.pids.first, isNot(server));
      // A rename alone (the same shape under a new name) is a new name:
      // nothing built holds it, a reload is enough.
      final pair = File(p.join(moved, 'lib', 'pair.dart'));
      done = dev.next('reloaded in|restart');
      pair.writeAsStringSync('typedef Pair2 = (int, String, bool);\n');
      expect(await done, contains('reloaded in'));
      // Back under its name in a file that already exists, with a new shape:
      // the file has no typedef of that name before, the one it left does.
      done = dev.next('reloaded in|restart');
      pair.writeAsStringSync('typedef Pair = (int, String, bool);\n');
      expect(await done, contains('reloaded in'));
      done = dev.next('reloaded in|restart');
      pair.writeAsStringSync('');
      home.writeAsStringSync(
        '\ntypedef Pair = (int, String, bool, int);\n',
        mode: FileMode.append,
      );
      expect(await done, contains('typedef Pair'));
      await dev.next('restarted in');
      final pids = dev.pids;
      dev.process.kill();
      expect(await dev.process.exitCode, 0);
      await _gone(pids);
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );

  test(
    'code the browser can not run shows on every page, and goes when fixed',
    () async {
      // An app of its own: the other tests leave theirs edited.
      final diag = p.join(tmp.path, 'diag');
      writeApp(diag, 'diag', source: LocalSource(checkout));
      expect(
        (await Process.run('dart', [
          'pub',
          'get',
          '--offline',
        ], workingDirectory: diag)).exitCode,
        0,
      );
      String read(String file) => File(p.join(diag, file)).readAsStringSync();
      void write(String file, String text) =>
          File(p.join(diag, file)).writeAsStringSync(text);
      const card = 'lib/modules/home/widgets/counter_card.dart';
      const shell = 'lib/shell/app_shell.dart';
      const closure = 'onPressed: () {\n counter.increment();\n },';

      final port = await _anyPort();
      final dev = await _Dev.start(diag, checkout, port);
      await dev.next(
        'http://localhost:$port',
        timeout: const Duration(minutes: 3),
      );

      // Waits for [wanted] of a page: an overlay entry is written into the
      // page by the proxy, so this is what the browser would get.
      Future<String> until(
        String path,
        bool Function(String html) wanted,
      ) async {
        final clock = Stopwatch()..start();
        while (true) {
          final (_, html) = await get(port, path);
          if (wanted(html)) return html;
          if (clock.elapsed > const Duration(seconds: 30)) {
            fail(
              'the page $path never got there:\n$html\n${dev.log.join('\n')}',
            );
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }

      // Nothing wrong: no overlay in the page at all.
      var html = (await get(port, '/')).$2;
      expect(html, isNot(contains('__thorDevErrors')));

      // A closure as a button's callback: the button would do nothing.
      // The page says it, with the file, the fix and the code's page.
      write(
        card,
        read(card).replaceFirst('onPressed: counter.increment,', closure),
      );
      html = await until('/', (h) => h.contains('THOR-S011'));
      expect(html, contains('"severity":"error"'));
      expect(html, contains('"fix":"Pass `counter.increment`."'));
      expect(html, contains('/errores/THOR-S011'));
      expect(
        html,
        contains('"file":"lib/modules/home/widgets/counter_card.dart"'),
      );
      expect(html, contains('"phase":"diagnostics"'));
      expect(dev.log.where((l) => l.contains('THOR-S011')), isNotEmpty);

      // A second one, in the layout every page shares: two files, and the
      // error page (a 404) shows them too.
      write(
        shell,
        "import 'package:diag/modules/home/state/counter_view_model.dart';\n"
        '${read(shell).replaceFirst('          Semantics(\n            role: SemanticsRole.contentInfo,', "          TextButton(\n            onPressed: () { counter.reset(); },\n            child: const Text('reset'),\n          ),\n          Semantics(\n            role: SemanticsRole.contentInfo,")}',
      );
      for (final path in ['/', '/nope']) {
        html = await until(
          path,
          (h) =>
              h.contains('"file":"lib/shell/app_shell.dart"') &&
              h.contains('"file":"lib/modules/home/widgets/counter_card.dart"'),
        );
        expect('"severity":"error"'.allMatches(html), hasLength(2));
      }

      // Fixed, one at a time: the shell's goes, the card's stays; then
      // none is left and the page is clean again.
      write(
        shell,
        read(shell).replaceFirst(
          'onPressed: () { counter.reset(); },',
          'onPressed: counter.reset,',
        ),
      );
      html = await until(
        '/',
        (h) => !h.contains('"file":"lib/shell/app_shell.dart"'),
      );
      expect(
        html,
        contains('"file":"lib/modules/home/widgets/counter_card.dart"'),
      );
      write(
        card,
        read(card).replaceFirst(closure, 'onPressed: counter.increment,'),
      );
      html = await until('/', (h) => !h.contains('__thorDevErrors'));
      expect(html, isNot(contains('THOR-S011')));

      // A lint of another tool: a warning is a badge, not a stop.
      File(
        p.join(diag, '.dart_tool', 'thor', 'diagnostics.txt'),
      ).writeAsStringSync(
        'lib/modules/home/pages/home_page.dart:3:1: Warning: '
        '<b>x</b> (THOR-S013 · https://thor-docs.vercel.app/errores/THOR-S013) '
        'Use `Watch`.\n',
      );
      // It shows with the next save (nothing watches that file).
      write(
        'lib/modules/home/pages/home_page.dart',
        '${read('lib/modules/home/pages/home_page.dart')}\n// touch\n',
      );
      html = await until('/', (h) => h.contains('THOR-S013'));
      expect(html, contains('"severity":"warning"'));
      expect(html, isNot(contains('"severity":"error"')));
      expect((await get(port, '/')).$1, 200, reason: 'a warning does not stop');

      final pids = dev.pids;
      dev.process.kill();
      expect(await dev.process.exitCode, 0);
      await _gone(pids);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test('a page with a deferred future streams through the proxy (first byte '
      'early, the late piece later), with the overlay script once', () async {
    final stream = p.join(tmp.path, 'stream');
    writeApp(stream, 'stream', source: LocalSource(checkout));
    expect(
      (await Process.run('dart', [
        'pub',
        'get',
        '--offline',
      ], workingDirectory: stream)).exitCode,
      0,
    );
    File(
      p.join(stream, 'lib', 'modules', 'home', 'pages', 'home_page.dart'),
    ).writeAsStringSync('''
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

class Slow {
  const Slow(this.value);
  final Future<String> value;
}

class HomePage extends ThorPage<Slow> {
  const HomePage();

  @override
  Future<Slow> load(PageRequest request) async => Slow(
    defer(
      Future<String>.delayed(const Duration(seconds: 1), () => 'late value'),
    ),
  );

  @override
  Widget build(BuildContext context, PageState<Slow> state) =>
      FutureBuilder<String>(
        future: state.data.value,
        builder: (context, snapshot) =>
            Text(snapshot.hasData ? snapshot.data! : 'waiting'),
      );
}
''');
    final port = await _anyPort();
    final dev = await _Dev.start(stream, checkout, port);
    try {
      await dev.next(
        'http://localhost:$port',
        timeout: const Duration(minutes: 3),
      );
      // A first request warms the page up (compiled code, caches).
      await get(port, '/');
      final request = await client.get('localhost', port, '/');
      request.headers.set(HttpHeaders.acceptHeader, 'text/html');
      final clock = Stopwatch()..start();
      final response = await request.close();
      final chunks = <({int ms, String text})>[];
      await for (final c in response) {
        chunks.add((ms: clock.elapsedMilliseconds, text: utf8.decode(c)));
      }
      final html = chunks.map((c) => c.text).join();
      // Order, not a clock: the shell comes before the late piece.
      expect(chunks.length, greaterThan(1));
      expect(chunks.first.ms, lessThan(chunks.last.ms), reason: 'first byte');
      expect(chunks.first.text, isNot(contains('late value')));
      expect(chunks.last.ms, greaterThan(900), reason: 'the late piece');
      expect(html, contains('late value'));
      expect(RegExp('thor-live-reload').allMatches(html), hasLength(1));
      expect(html.trimRight(), endsWith('</html>'));
    } finally {
      final pids = dev.pids;
      dev.process.kill();
      await dev.process.exitCode;
      await _gone(pids);
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  test(
    'a new image in web/images/ gets its size with a hot reload',
    () async {
      // An app of its own: the other tests leave theirs edited.
      final gallery = p.join(tmp.path, 'gallery');
      writeApp(gallery, 'gallery', source: LocalSource(checkout));
      expect(
        (await Process.run('dart', [
          'pub',
          'get',
          '--offline',
        ], workingDirectory: gallery)).exitCode,
        0,
      );
      // Watched from the start (a folder made later isn't).
      Directory(p.join(gallery, 'web', 'images')).createSync(recursive: true);
      final page = File(
        p.join(gallery, 'lib', 'modules', 'home', 'pages', 'home_page.dart'),
      );
      page.writeAsStringSync(
        page.readAsStringSync().replaceFirst(
          "Text(\n        'Edit",
          "Image.asset('images/nueva.png'),\n      Text(\n        'Edit",
        ),
      );
      final port = await _anyPort();
      final dev = await _Dev.start(gallery, checkout, port);
      await dev.next(
        'http://localhost:$port',
        timeout: const Duration(minutes: 3),
      );
      final (_, before) = await get(port, '/');
      // A routed page (the template is ThorApp.router): from the site root.
      expect(before, contains('src="/images/nueva.png"'));
      expect(before, isNot(contains('width="3"')));
      final server = dev.pids.first;

      final done = dev.next('reloaded in|restart');
      File(
        p.join(gallery, 'web', 'images', 'nueva.png'),
      ).writeAsBytesSync(base64Decode(_png3x2));
      expect(await done, contains('reloaded in'));
      final (_, after) = await get(port, '/');
      expect(after, contains('width="3" height="2"'));
      expect(dev.pids.first, server, reason: 'no restart');

      final pids = dev.pids;
      dev.process.kill();
      expect(await dev.process.exitCode, 0);
      await _gone(pids);
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test(
    'a package added while it runs is watched, and its edits show',
    () async {
      // An app of its own, and a local package it doesn't use yet.
      final site = p.join(tmp.path, 'site');
      writeApp(site, 'site', source: LocalSource(checkout));
      final brand = p.join(tmp.path, 'brand');
      File(p.join(brand, 'pubspec.yaml'))
        ..createSync(recursive: true)
        ..writeAsStringSync(
          'name: brand\npublish_to: none\nenvironment:\n  sdk: ^3.8.0\n',
        );
      final brandLib = File(p.join(brand, 'lib', 'brand.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync("const brandName = 'uno';\n");
      Future<void> pubGet() async {
        final pub = await Process.run('dart', [
          'pub',
          'get',
          '--offline',
        ], workingDirectory: site);
        expect(pub.exitCode, 0, reason: '${pub.stdout}${pub.stderr}');
      }

      await pubGet();
      final port = await _anyPort();
      final dev = await _Dev.start(site, checkout, port);
      await dev.next(
        'http://localhost:$port',
        timeout: const Duration(minutes: 3),
      );

      // Added with `pub get` while it runs: watched, and a restart.
      final pubspec = File(p.join(site, 'pubspec.yaml'));
      pubspec.writeAsStringSync(
        pubspec.readAsStringSync().replaceFirst(
          'dependencies:\n',
          'dependencies:\n  brand:\n    path: ../brand\n',
        ),
      );
      var done = dev.next('restarted in');
      await pubGet();
      await done;
      expect(dev.log, contains(contains('watching 1 new package')));
      expect(dev.log, contains(contains('the dependencies changed')));

      // The app uses it…
      final page = File(
        p.join(site, 'lib', 'modules', 'home', 'pages', 'home_page.dart'),
      );
      done = dev.next('reloaded in|restarted in');
      page.writeAsStringSync(
        "import 'package:brand/brand.dart';\n${page.readAsStringSync().replaceFirst("'Hello, Thor',", 'brandName,')}",
      );
      await done;
      expect((await get(port, '/')).$2, contains('uno'));

      // …and an edit inside the package reaches the page: before, the
      // server kept the package as it first compiled it.
      done = dev.next('reloaded in|restarted in');
      brandLib.writeAsStringSync("const brandName = 'dos';\n");
      await done;
      final clock = Stopwatch()..start();
      while (!(await get(port, '/')).$2.contains('dos')) {
        expect(clock.elapsed, lessThan(const Duration(seconds: 20)));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      final pids = dev.pids;
      dev.process.kill();
      expect(await dev.process.exitCode, 0);
      await _gone(pids);
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

/// A 3 × 2 PNG.
const _png3x2 =
    'iVBORw0KGgoAAAANSUhEUgAAAAMAAAACCAIAAAASFvFNAAAAEElEQVR4nGP4z8AAQQxwFg'
    'BB0gX7h/C5SAAAAABJRU5ErkJggg==';

/// A port the OS picks, so two checkouts running this test at once never
/// race for the same one. `thor dev` also binds port + 1000 (with its own
/// fallback), so the pick stays below 64535.
Future<int> _anyPort() async {
  while (true) {
    final socket = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    final port = socket.port;
    await socket.close();
    if (port < 64535) return port;
  }
}
