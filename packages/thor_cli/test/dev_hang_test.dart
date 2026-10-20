// A stage of `thor dev` that hangs must not block the update queue for
// good, and `thor dev` and `thor build` must not share their intermediates.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_cli/src/dev/builder_worker.dart';
import 'package:thor_cli/src/dev/dev_runs.dart';
import 'package:thor_cli/src/dev/stage_timeouts.dart';

/// A worker process that reads requests and never answers them, or answers
/// them all (an `{id, exit: 0, output}` line).
class _FakeWorker implements Process {
  _FakeWorker({required this.answers});
  final bool answers;
  // ignore: close_sinks
  final _out = StreamController<List<int>>();
  // ignore: close_sinks
  final _in = StreamController<List<int>>();
  final _exit = Completer<int>();
  var killed = false;
  final requests = <Map<String, Object?>>[];

  @override
  // ignore: close_sinks
  late final IOSink stdin = IOSink(_in.sink)..encoding = utf8;

  _FakeWorker start() {
    _in.stream.transform(utf8.decoder).transform(const LineSplitter()).listen((
      line,
    ) {
      final request = jsonDecode(line) as Map<String, Object?>;
      requests.add(request);
      if (answers) {
        _out.add(
          utf8.encode(
            '${jsonEncode({'id': request['id'], 'exit': 0, 'output': 'ok'})}\n',
          ),
        );
      }
    });
    return this;
  }

  @override
  Stream<List<int>> get stdout => _out.stream;
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  Future<int> get exitCode => _exit.future;
  @override
  int get pid => 4242;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    if (!_exit.isCompleted) _exit.complete(-15);
    return true;
  }
}

void main() {
  group('guardStage', () {
    test('passes the result through', () async {
      expect(
        await guardStage('x', const Duration(seconds: 1), Future.value(3)),
        3,
      );
    });

    test('times out with the stage and the limit', () async {
      final never = Completer<void>();
      await expectLater(
        guardStage(
          'hot reload',
          const Duration(milliseconds: 20),
          never.future,
        ),
        throwsA(
          isA<StageTimeout>()
              .having((e) => e.stage, 'stage', 'hot reload')
              .having((e) => e.message, 'message', contains('hot reload')),
        ),
      );
    });

    test('the default limits are in one place', () {
      expect(DevTimeouts.defaults.reload, const Duration(seconds: 60));
      expect(DevTimeouts.defaults.workerRequest, const Duration(seconds: 120));
      expect(DevTimeouts.defaults.serverListening, const Duration(seconds: 60));
    });
  });

  group('builder worker', () {
    test('a request nobody answers falls back, kills it and tells', () async {
      final fake = _FakeWorker(answers: false).start();
      final notices = <String>[];
      final stuck = <StageTimeout>[];
      final worker = WorkerSteps.over(
        fake,
        notice: notices.add,
        requestTimeout: const Duration(milliseconds: 50),
        onStuck: stuck.add,
      );
      // The fallback (`dart run thor_builder:entries` in a folder that is
      // not an app) fails like any step: what matters is that it ran.
      Object? error;
      try {
        await worker.entries(Directory.systemTemp.path, allFeatures: false);
      } on Object catch (e) {
        error = e;
      }
      expect(error, isNotNull, reason: 'the fallback ran (and failed here)');
      expect(fake.requests, hasLength(1));
      expect(fake.killed, isTrue);
      expect(worker.alive, isFalse);
      expect(stuck, hasLength(1));
      expect(stuck.single.stage, contains('builder worker request'));
      expect(notices.single, contains('no answer'));
    });

    test('an answering worker is untouched', () async {
      final fake = _FakeWorker(answers: true).start();
      final stuck = <StageTimeout>[];
      final worker = WorkerSteps.over(
        fake,
        notice: (_) {},
        requestTimeout: const Duration(seconds: 5),
        onStuck: stuck.add,
      );
      expect(await worker.entries('.', allFeatures: false), 'ok');
      expect(await worker.entries('.', allFeatures: false), 'ok');
      expect(stuck, isEmpty);
      expect(fake.killed, isFalse);
      expect(worker.alive, isTrue);
    });
  });

  group('thor build next to a live thor dev', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('thor_dev_live'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('warns for a live run, not for a dead one', () {
      DevRun(
        owner: 10,
        port: 4300,
        pids: [11],
      ).write(DevRun.fileFor(dir.path, 4300));
      DevRun(
        owner: 20,
        port: 4301,
        pids: [21],
      ).write(DevRun.fileFor(dir.path, 4301));
      final live = liveDevRuns(
        dir,
        selfPid: 99,
        commandOf: (pid) => pid == 10 ? 'dart thor dev' : null,
      );
      expect(live.single.port, 4300);

      final said = <String>[];
      warnIfDevRunning(dir, say: said.add, live: live);
      expect(said.single, contains(':4300'));
      expect(said.single, contains('thor dev is running'));
      // Read only: the record of the dead run is still there.
      expect(DevRun.fileFor(dir.path, 4301).existsSync(), isTrue);
    });

    test('silent without runs or without the folder', () {
      final said = <String>[];
      warnIfDevRunning(dir, say: said.add);
      warnIfDevRunning(Directory('${dir.path}/none'), say: said.add);
      expect(said, isEmpty);
    });
  });

  test('dev and build write their lite state to different files', () {
    final dev = File('lib/src/commands/dev.dart').readAsStringSync();
    final build = File('lib/src/commands/build.dart').readAsStringSync();
    expect(dev, contains('.dart_tool/thor/lite/state.js'));
    expect(dev, isNot(contains("'build/lite/state.js'")));
    expect(build, contains("'build/lite/state.js'"));
  });
}
