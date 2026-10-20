/// Follows docs/guia/es/primera-app.md end to end: `thor create` in a temporary
/// directory outside the repo (with this checkout's packages), the commands
/// and the files the tutorial shows in the order it shows them, `thor test`,
/// `thor build`, and the built server answering the pages the tutorial
/// promises. `tool/thor tutorial-check [--keep]`.
///
/// What it takes from the page:
///  * a ```bash block: each line that starts with `thor` runs in the project
///    (`thor dev` and `thor preview`, which never end, do not: the built
///    server is started and asked instead);
///  * a ```dart block whose first line is a path comment (`// lib/x.dart`):
///    the whole file, written over whatever is there.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'docs_blocks.dart';

/// The project's name, from the tutorial's `thor create`.
const _name = 'store';

Future<void> main(List<String> args) async {
  final keep = args.contains('--keep');
  final root = Directory.current.absolute.path;
  final cli = '$root/packages/thor_cli/bin/thor.dart';
  final blocks = extractBlocks(
    File('docs/guia/es/primera-app.md').readAsStringSync(),
    file: 'docs/guia/es/primera-app.md',
  );

  final tmp = Directory.systemTemp.createTempSync('thor_tutorial_');
  final project = Directory('${tmp.path}/$_name');
  Process? server;
  var failed = false;
  try {
    for (final b in blocks) {
      if (b.lang == 'bash') {
        for (final line in b.code.split('\n').map((l) => l.trim())) {
          final words = line.split(RegExp(r'\s+'));
          if (words.first != 'thor' || words.length < 2) continue;
          if (words[1] == 'dev' || words[1] == 'preview') continue;
          final inProject = words[1] != 'create';
          await _thor(
            cli,
            words.sublist(1),
            inProject ? project.path : tmp.path,
            '${b.file}:${b.line}',
          );
        }
      } else if (b.lang == 'dart' && b.path != null) {
        if (!project.existsSync()) {
          _fail('${b.file}:${b.line}: ${b.path} comes before `thor create`');
        }
        File('${project.path}/${b.path}')
          ..createSync(recursive: true)
          ..writeAsStringSync('${b.code}\n');
        stdout.writeln('  wrote ${b.path} (${b.file}:${b.line})');
      }
    }

    // What `thor build` made, run as `thor preview` would.
    final exe = File('${project.path}/build/server');
    if (!exe.existsSync()) _fail('thor build left no build/server');
    final port = await _freePort();
    stdout.writeln('▸ build/server on :$port');
    server = await Process.start(
      exe.path,
      const [],
      workingDirectory: project.path,
      environment: {'PORT': '$port'},
    );
    final log = StringBuffer();
    server.stdout.transform(utf8.decoder).listen(log.write);
    server.stderr.transform(utf8.decoder).listen(log.write);
    await _waitFor(port, log);

    final base = 'http://127.0.0.1:$port';
    final home = await _get('$base/');
    _expect(home.status == 200, '/ answers 200, got ${home.status}');
    for (final name in ['Cold brew', 'Croissant', 'Hot chocolate']) {
      _expect(home.body.contains(name), '/ lists $name');
    }
    _expect(
      home.body.contains('Your cart is empty'),
      '/ draws the cart summary',
    );
    _expect(
      home.body.contains('CartViewModel.add'),
      '/ wires the cart button to the state',
    );
    _expect(
      home.body.contains('href="/product/2"'),
      '/ links each card to its page',
    );
    final script = RegExp(
      r'data-thor-engine="([^"]+)"',
    ).firstMatch(home.body)?.group(1);
    _expect(script != null, '/ loads the engine with a script');
    final engine = await _get('$base$script');
    _expect(
      engine.status == 200 && engine.body.isNotEmpty,
      '$script is served',
    );

    final product = await _get('$base/product/2');
    _expect(
      product.status == 200,
      '/product/2 answers 200, got ${product.status}',
    );
    _expect(product.body.contains('Croissant'), '/product/2 shows the product');
    _expect(
      product.body.contains('<title>Croissant · Store</title>'),
      '/product/2 has its title',
    );

    final missing = await _get('$base/product/99');
    _expect(
      missing.status == 404,
      '/product/99 answers 404, got ${missing.status}',
    );
    _expect(
      missing.body.contains('That product doesn&#39;t exist.') ||
          missing.body.contains("That product doesn't exist."),
      '/product/99 says why',
    );
    final badId = await _get('$base/product/abc');
    _expect(badId.status == 404, '/product/abc is a 404 before the page');
    stdout.writeln('✓ the tutorial builds, tests and serves');
  } on _Failure catch (e) {
    failed = true;
    stderr.writeln('✗ ${e.message}');
  } finally {
    if (server != null) {
      // The server drains its isolates on SIGTERM; do not wait for it.
      server.kill();
      await server.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          server!.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
    }
    if (keep) {
      stdout.writeln('kept: ${tmp.path}');
    } else {
      tmp.deleteSync(recursive: true);
    }
  }
  exit(failed ? 1 : 0);
}

class _Failure implements Exception {
  _Failure(this.message);
  final String message;
}

Never _fail(String message) => throw _Failure(message);

void _expect(bool ok, String what) {
  if (!ok) _fail('expected: $what');
}

Future<void> _thor(
  String cli,
  List<String> args,
  String dir,
  String where,
) async {
  stdout.writeln('▸ thor ${args.join(' ')}   ($where)');
  final r = await Process.run(
    Platform.resolvedExecutable,
    [cli, ...args],
    workingDirectory: dir,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (r.exitCode != 0) {
    stdout.write(r.stdout);
    stderr.write(r.stderr);
    _fail('thor ${args.join(' ')} exited with ${r.exitCode} ($where)');
  }
}

Future<int> _freePort() async {
  final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = s.port;
  await s.close();
  return port;
}

Future<void> _waitFor(int port, StringBuffer log) async {
  for (var i = 0; i < 100; i++) {
    try {
      final s = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(milliseconds: 200),
      );
      await s.close();
      return;
    } on Object {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
  _fail('the server did not start:\n$log');
}

Future<({int status, String body})> _get(String url) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse(url));
    final res = await req.close();
    return (
      status: res.statusCode,
      body: await res.transform(utf8.decoder).join(),
    );
  } finally {
    client.close(force: true);
  }
}
