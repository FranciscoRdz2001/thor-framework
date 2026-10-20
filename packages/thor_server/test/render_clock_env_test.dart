// `THOR_NOW` (thor_ui's render clock) pins the date every page renders with:
// a release that inherits it by accident shows a frozen "today" to everyone.
// `serve` says so on startup, and a value that is not a date stops it there,
// not on the first page with a date picker.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  Future<({int? exit, String out, String err})> start(
    Map<String, String> env,
  ) async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    final p = await Process.start(
      Platform.resolvedExecutable,
      ['run', 'test/fixtures/setup_server.dart', '$port'],
      environment: {...env, 'THOR_DEV': ''},
    );
    addTearDown(p.kill);
    final out = StringBuffer(), err = StringBuffer();
    final ready = Completer<void>();
    p.stdout.transform(utf8.decoder).listen((s) {
      out.write(s);
      if (s.contains('thor: http') && !ready.isCompleted) ready.complete();
    });
    p.stderr.transform(utf8.decoder).listen(err.write);
    final exit = p.exitCode.then<int?>((c) => c);
    await Future.any([ready.future, exit]).timeout(const Duration(seconds: 60));
    final code = await Future.any([
      exit,
      Future<int?>.delayed(const Duration(milliseconds: 300)),
    ]);
    return (exit: code, out: '$out', err: '$err');
  }

  test('a server started with THOR_NOW says the date is frozen', () async {
    final r = await start({'THOR_NOW': '2026-01-15T12:00:00'});
    expect(r.exit, isNull);
    expect(r.err, contains('THOR_NOW'));
    expect(r.err, contains('2026-01-15T12:00:00'));
  });

  test('a server without it says nothing about the date', () async {
    final r = await start({});
    expect(r.err, isNot(contains('THOR_NOW')));
  });

  test('a THOR_NOW that is not a date stops the server at start', () async {
    final r = await start({'THOR_NOW': 'tomorrow'});
    expect(r.exit, isNot(0));
    expect(r.err, contains('THOR_NOW'));
    expect(r.out, isNot(contains('thor: http')));
  });
}
