import 'dart:io';

import 'package:path/path.dart' as p;

/// What one `thor dev` run recorded in `.dart_tool/thor/dev-<port>.pids`: its
/// own pid (the owner) and the processes it started.
///
/// A record is per run, not per project: a second `thor dev` in the same
/// app must not stop the processes of the first one, which is alive.
class DevRun {
  /// A record.
  DevRun({
    required this.owner,
    required this.port,
    required this.pids,
    this.at,
    this.version = 1,
  });

  /// Reads the record in the file called [name] (`dev-4300.pids`).
  factory DevRun.parse(String name, String text) {
    int? owner;
    DateTime? at;
    var version = 1;
    final pids = <int>[];
    for (final line in text.split('\n')) {
      final t = line.trim();
      if (t.startsWith('owner ')) {
        owner = int.tryParse(t.substring(6));
      } else if (t.startsWith('at ')) {
        final ms = int.tryParse(t.substring(3));
        if (ms != null) {
          at = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
        }
      } else if (t.startsWith('version ')) {
        version = int.tryParse(t.substring(8)) ?? version;
      } else if (int.tryParse(t) case final pid?) {
        pids.add(pid);
      }
    }
    final port = RegExp(r'^dev-(\d+)\.pids$').firstMatch(name)?.group(1);
    return DevRun(
      owner: owner,
      port: port == null ? null : int.parse(port),
      pids: pids,
      at: at,
      version: version,
    );
  }

  /// The pid of the `thor dev` that wrote it (null in an old record).
  final int? owner;

  /// The port it listened on (null in an old record).
  final int? port;

  /// The processes it started (server first).
  final List<int> pids;

  /// When it was written: every process of the run started before it, so a
  /// process that started after is a reused pid (null in an old record).
  final DateTime? at;

  /// The format of the file; a newer one than this code knows is left alone.
  final int version;

  /// The file's text.
  String format() => [
    'owner $owner',
    'at ${(at ?? DateTime.now()).millisecondsSinceEpoch}',
    ...pids,
  ].join('\n');

  /// Writes the record to [file] all at once (a reader never sees half of it).
  void write(File file) {
    file.parent.createSync(recursive: true);
    final tmp = File('${file.path}.tmp');
    tmp.writeAsStringSync(format());
    tmp.renameSync(file.path);
  }

  /// The file of the run on [port] under [dir] (`.dart_tool/thor`).
  static File fileFor(String dir, int port) =>
      File(p.join(dir, 'dev-$port.pids'));
}

/// What to do with the records found: stop [kill] (the dart children of the
/// runs that are gone), delete the [forget] ones, and tell about the [live].
class ReapPlan {
  /// A plan.
  ReapPlan(this.kill, this.forget, this.live);

  /// Pids to stop.
  final List<int> kill;

  /// Records of runs that are gone.
  final List<DevRun> forget;

  /// Records of runs still alive: not touched.
  final List<DevRun> live;
}

/// Whether [command] is one thor dev starts: a dart executable, or the `sh`
/// that ties a child to it (`thor-dev`). Not any command that mentions dart.
bool isThorProcess(String command) =>
    RegExp(r'^(\S*/)?(dart|dartvm|dartaotruntime)(\s|$)').hasMatch(command) ||
    RegExp(r'^(\S*/)?sh\s+-c\s[\s\S]*\sthor-dev\s').hasMatch(command);

/// How much later than the record a process may have started and still be
/// one of the run (`ps` only has whole seconds).
const _startSlack = Duration(seconds: 2);

/// Decides, from [runs] and the process table ([commandOf]: a pid's command
/// line, or null if there is no such process; [startOf]: when it started).
/// A run is alive if its owner is a live process of ours that started before
/// the record; only the processes of a run that is gone, and that are still
/// ours (pids get reused), are stopped.
ReapPlan planReap(
  List<DevRun> runs, {
  required int selfPid,
  required String? Function(int pid) commandOf,
  DateTime? Function(int pid)? startOf,
}) {
  bool ours(int pid, DevRun run) {
    if (pid <= 1) return false;
    if (!isThorProcess(commandOf(pid) ?? '')) return false;
    final at = run.at;
    final start = startOf?.call(pid);
    if (at != null && start != null && start.isAfter(at.add(_startSlack))) {
      return false;
    }
    return true;
  }

  final kill = <int>[];
  final forget = <DevRun>[];
  final live = <DevRun>[];
  final claimed = <int>{};
  final pending = <DevRun>[];
  for (final run in runs) {
    if (run.version > 1) {
      live.add(run);
      claimed.addAll(run.pids);
    } else if (run.owner == selfPid) {
      forget.add(run);
    } else if (run.owner != null && ours(run.owner!, run)) {
      live.add(run);
      claimed.addAll(run.pids);
    } else {
      pending.add(run);
    }
  }
  for (final run in pending) {
    for (final pid in run.pids) {
      if (pid != selfPid && !claimed.contains(pid) && ours(pid, run)) {
        if (!kill.contains(pid)) kill.add(pid);
      }
    }
    forget.add(run);
  }
  return ReapPlan(kill, forget, live);
}

/// The command line of [pid], or null if there is no such process.
String? processCommand(int pid) {
  final probe = Process.runSync('ps', ['-o', 'command=', '-p', '$pid']);
  if (probe.exitCode != 0) return null;
  final text = '${probe.stdout}'.trim();
  return text.isEmpty ? null : text;
}

/// When [pid] started, from `ps` (whole seconds), or null if unknown.
DateTime? processStart(int pid) {
  final probe = Process.runSync('ps', ['-o', 'etime=', '-p', '$pid']);
  if (probe.exitCode != 0) return null;
  // [[dd-]hh:]mm:ss
  final m = RegExp(
    r'^\s*(?:(\d+)-)?(?:(\d+):)?(\d+):(\d+)\s*$',
  ).firstMatch('${probe.stdout}');
  if (m == null) return null;
  int n(int g) => int.parse(m.group(g) ?? '0');
  final up = Duration(days: n(1), hours: n(2), minutes: n(3), seconds: n(4));
  return DateTime.now().toUtc().subtract(up);
}

/// Stops what the dead runs of the app left in [dir] (`.dart_tool/thor`),
/// deletes their records and returns the runs that are alive. [say] gets
/// the messages.
List<DevRun> reapStaleRuns(
  Directory dir, {
  required void Function(String message) say,
  int? selfPid,
  String? Function(int pid) commandOf = processCommand,
  DateTime? Function(int pid) startOf = processStart,
}) {
  if (!dir.existsSync()) return const [];
  final files = [
    for (final f in dir.listSync())
      if (f is File && RegExp(r'^dev-\d+\.pids$').hasMatch(p.basename(f.path)))
        f,
  ];
  final runs = <File, DevRun>{};
  for (final f in files) {
    try {
      runs[f] = DevRun.parse(p.basename(f.path), f.readAsStringSync());
    } on FileSystemException {
      // Gone since the listing: another thor dev reaped it.
    }
  }
  final plan = planReap(
    runs.values.toList(),
    selfPid: selfPid ?? pid,
    commandOf: commandOf,
    startOf: startOf,
  );
  var killed = 0;
  for (final target in plan.kill) {
    if (Process.killPid(target)) killed++;
  }
  for (final e in runs.entries) {
    if (!plan.forget.contains(e.value)) continue;
    try {
      e.key.deleteSync();
    } on FileSystemException {
      // Already deleted by another thor dev.
    }
  }
  if (killed > 0) say('stopped $killed process(es) left by a previous run');
  for (final run in plan.live) {
    say(
      'another thor dev of this app is running'
      '${run.port == null ? '' : ' on :${run.port}'} (pid ${run.owner})',
    );
  }
  return plan.live;
}

/// The `thor dev` runs of the app whose `.dart_tool/thor` is [dir] that are
/// alive now. Read only: unlike [reapStaleRuns] it stops and deletes
/// nothing (`thor build` only asks).
List<DevRun> liveDevRuns(
  Directory dir, {
  int? selfPid,
  String? Function(int pid) commandOf = processCommand,
  DateTime? Function(int pid) startOf = processStart,
}) {
  if (!dir.existsSync()) return const [];
  final runs = <DevRun>[];
  for (final f in dir.listSync()) {
    if (f is! File ||
        !RegExp(r'^dev-\d+\.pids$').hasMatch(p.basename(f.path))) {
      continue;
    }
    try {
      runs.add(DevRun.parse(p.basename(f.path), f.readAsStringSync()));
    } on FileSystemException {
      // Removed since the listing.
    }
  }
  return planReap(
    runs,
    selfPid: selfPid ?? pid,
    commandOf: commandOf,
    startOf: startOf,
  ).live;
}

/// `thor build` writes `.dart_tool/thor/` (the entries) while a live
/// `thor dev` of the same app rewrites it on every save and serves from
/// it: [say] that the build may mix their files.
void warnIfDevRunning(
  Directory dir, {
  required void Function(String message) say,
  List<DevRun>? live,
}) {
  for (final run in live ?? liveDevRuns(dir)) {
    say(
      'thor dev is running for this app'
      '${run.port == null ? '' : ' on :${run.port}'} (pid ${run.owner}): it '
      'rewrites .dart_tool/thor/ on every save, so this build may mix its '
      'generated files with the release ones. Stop it first for a clean '
      'build.',
    );
  }
}
