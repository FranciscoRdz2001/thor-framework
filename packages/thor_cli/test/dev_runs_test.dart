// Which processes of an earlier `thor dev` may be stopped: only those whose
// run is gone, never the ones of a run that is alive.
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_cli/src/dev/dev_runs.dart';

void main() {
  // A fake process table: pid -> command line.
  Map<int, String> table(Map<int, String> m) => m;
  String? Function(int) look(Map<int, String> m) =>
      (pid) => m[pid];

  test('parses and writes a run record', () {
    final record = DevRun.parse('dev-4300.pids', 'owner 10\n11\n12\n');
    expect(record.port, 4300);
    expect(record.owner, 10);
    expect(record.pids, [11, 12]);
    expect(DevRun.parse('dev-4300.pids', record.format()).pids, [11, 12]);
  });

  test('a run whose owner is alive is left alone and reported', () {
    final plan = planReap(
      [
        DevRun(owner: 10, port: 4300, pids: [11, 12]),
      ],
      selfPid: 99,
      commandOf: look(table({10: 'dart thor dev', 11: 'dart', 12: 'dart'})),
    );
    expect(plan.kill, isEmpty);
    expect(plan.forget, isEmpty);
    expect(plan.live.single.port, 4300);
    expect(plan.live.single.owner, 10);
  });

  test('a run whose owner is gone is reaped, only its dart children', () {
    final plan = planReap(
      [
        DevRun(owner: 10, port: 4300, pids: [11, 12, 13]),
      ],
      selfPid: 99,
      // 11 is a dart child, 12 is gone, 13 was reused by something else.
      commandOf: look(table({11: 'dart server', 13: '/usr/bin/vim'})),
    );
    expect(plan.live, isEmpty);
    expect(plan.kill, [11]);
    expect(plan.forget, hasLength(1));
  });

  test('an owner pid reused by a non-dart process counts as gone', () {
    final plan = planReap(
      [
        DevRun(owner: 10, port: 4300, pids: [11]),
      ],
      selfPid: 99,
      commandOf: look(table({10: '/usr/bin/vim', 11: 'dart'})),
    );
    expect(plan.live, isEmpty);
    expect(plan.kill, [11]);
  });

  test('a legacy record is reaped as before', () {
    final plan = planReap(
      [
        DevRun(owner: null, port: null, pids: [11]),
      ],
      selfPid: 99,
      commandOf: look(table({11: 'dart'})),
    );
    expect(plan.kill, [11]);
  });

  test('two runs: one alive, one dead', () {
    final plan = planReap(
      [
        DevRun(owner: 10, port: 4300, pids: [11]),
        DevRun(owner: 20, port: 4302, pids: [21]),
      ],
      selfPid: 99,
      commandOf: look(table({10: 'dart', 11: 'dart', 21: 'dart'})),
    );
    expect(plan.kill, [21]);
    expect(plan.live.map((r) => r.port), [4300]);
    expect(plan.forget.map((r) => r.port), [4302]);
  });

  test('never stops this process or its own record', () {
    final plan = planReap(
      [
        DevRun(owner: 99, port: 4300, pids: [99, 11]),
      ],
      selfPid: 99,
      commandOf: look(table({99: 'dart', 11: 'dart'})),
    );
    expect(plan.kill, isEmpty);
    expect(plan.live, isEmpty);
  });

  group('pid reuse', () {
    final at = DateTime.utc(2026, 1, 1, 12);
    DateTime? Function(int) started(Map<int, DateTime> m) =>
        (pid) => m[pid];

    test('vim editing a dart file is not a dart process', () {
      final plan = planReap(
        [
          DevRun(owner: 10, port: 4300, pids: [11], at: at),
        ],
        selfPid: 99,
        commandOf: look({
          10: 'vim lib/main.dart',
          11: 'vim /home/me/.dart_tool/notes.txt',
        }),
      );
      expect(plan.kill, isEmpty);
      expect(plan.live, isEmpty);
    });

    test('a path with dart in it does not make a process ours', () {
      final plan = planReap(
        [
          DevRun(owner: 10, port: 4300, pids: [11]),
        ],
        selfPid: 99,
        commandOf: look({
          10: '/usr/bin/less /opt/dart-sdk/README',
          11: 'node /srv/dartboard/server.js',
        }),
      );
      expect(plan.kill, isEmpty);
    });

    test('a dart process started after the record is a reused pid', () {
      final plan = planReap(
        [
          DevRun(owner: 10, port: 4300, pids: [11, 12], at: at),
        ],
        selfPid: 99,
        commandOf: look({
          10: 'dart run thor_cli:thor dev',
          11: '/sdk/bin/dart run other/bin/server.dart',
          12: '/sdk/bin/dart run mine/bin/server.dart',
        }),
        startOf: started({
          10: at.add(const Duration(hours: 3)),
          11: at.add(const Duration(hours: 3)),
          12: at.subtract(const Duration(seconds: 30)),
        }),
      );
      // The owner pid was reused by a newer dart: the run is gone, but
      // 11 is newer than the record, so only 12 is stopped.
      expect(plan.live, isEmpty);
      expect(plan.kill, [12]);
    });

    test('a live run owner started before its record keeps it alive', () {
      final plan = planReap(
        [
          DevRun(owner: 10, port: 4300, pids: [11], at: at),
        ],
        selfPid: 99,
        commandOf: look({10: 'dart run thor_cli:thor dev', 11: 'dart'}),
        startOf: started({
          10: at.subtract(const Duration(minutes: 5)),
          11: at.subtract(const Duration(minutes: 5)),
        }),
      );
      expect(plan.live, hasLength(1));
      expect(plan.kill, isEmpty);
    });

    test('a pid of a dead run that a live run now owns is not stopped', () {
      final plan = planReap(
        [
          DevRun(owner: 10, port: 4300, pids: [11]),
          DevRun(owner: 20, port: 4302, pids: [21, 11]),
        ],
        selfPid: 99,
        commandOf: look({
          20: 'dart thor dev',
          21: 'dart',
          11: 'dart run server.dart',
        }),
      );
      expect(plan.kill, isNot(contains(11)));
      expect(plan.live.single.port, 4302);
    });

    test('nonsense pids are never signalled', () {
      final plan = planReap(
        [
          DevRun(owner: null, port: null, pids: [0, 1, -1, -5]),
        ],
        selfPid: 99,
        commandOf: (_) => 'dart',
      );
      expect(plan.kill, isEmpty);
    });

    test('the sh that ties a child is ours, a plain sh is not', () {
      final plan = planReap(
        [
          DevRun(owner: 10, port: 4300, pids: [11, 12]),
        ],
        selfPid: 99,
        commandOf: look({
          11: 'sh -c "\$@" </dev/null & thor-dev dart run build_runner watch',
          12: 'sh -c echo dart',
        }),
      );
      expect(plan.kill, [11]);
    });
  });

  group('record files', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('devruns_'));
    tearDown(() => dir.deleteSync(recursive: true));

    List<DevRun> reap(Map<int, String> table) => reapStaleRuns(
      dir,
      say: (_) {},
      selfPid: 99,
      commandOf: (pid) => table[pid],
    );

    test('a record of a newer format is left alone', () {
      final f = File('${dir.path}/dev-4300.pids')
        ..writeAsStringSync('version 9\nowner 10\n11\nfuture-field x\n');
      reap({11: 'dart'});
      expect(f.existsSync(), isTrue);
    });

    test('garbage and empty records do not throw and are dropped', () {
      final a = File('${dir.path}/dev-4300.pids')
        ..writeAsStringSync(
          '\u0000\u0001 owner\nowner x\n999999999999999999999\n',
        );
      final b = File('${dir.path}/dev-4301.pids')..writeAsStringSync('');
      expect(() => reap({}), returnsNormally);
      expect(a.existsSync(), isFalse);
      expect(b.existsSync(), isFalse);
    });

    test('a record deleted while reaping does not throw', () {
      File('${dir.path}/dev-4300.pids').writeAsStringSync('owner 10\n');
      expect(
        () => reapStaleRuns(
          dir,
          say: (_) {},
          selfPid: 99,
          commandOf: (pid) {
            for (final f in dir.listSync()) {
              f.deleteSync();
            }
            return null;
          },
        ),
        returnsNormally,
      );
    });

    test('writing a record leaves no half file for a reader', () {
      final file = DevRun.fileFor(dir.path, 4300);
      DevRun(owner: 10, port: 4300, pids: [11]).write(file);
      expect(dir.listSync().map((e) => e.path.split('/').last), [
        'dev-4300.pids',
      ]);
      expect(DevRun.parse('dev-4300.pids', file.readAsStringSync()).pids, [11]);
    });
  });
}
