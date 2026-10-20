import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// The service extension an app's server registers under `thor dev`
/// (`ThorDev`, thor_server): after new code is loaded, it builds its
/// server again (fresh routes, empty page cache) and clears what caches
/// rendered HTML.
const reassembleExtension = 'ext.thor.reassemble';

/// The outcome of a hot reload.
sealed class ReloadOutcome {
  const ReloadOutcome();
}

/// The new code runs.
final class Reloaded extends ReloadOutcome {
  /// Reloaded in [elapsed].
  const Reloaded(this.elapsed, {this.setUps = false});

  /// How long the reload and the reassemble took.
  final Duration elapsed;

  /// Whether the server ran its isolate set-ups again (the states'
  /// registry: `ThorServer.setUpIsolates`); an older thor_server doesn't.
  final bool setUps;
}

/// The VM kept the old code; [reason] says why (a compile error, a change
/// it can't apply). A restart may still work (a class changed shape) or
/// fail the same way (a compile error): [compileError] tells them apart.
final class NotReloaded extends ReloadOutcome {
  /// Not reloaded, because of [reason].
  const NotReloaded(this.reason, {this.compileError = false});

  /// What the VM said.
  final String reason;

  /// The code doesn't compile: restarting fails too.
  final bool compileError;
}

/// A connection to the VM service of the app's server (`dart run
/// --enable-vm-service`), for hot reload.
class VmClient {
  VmClient._(this._service);

  final VmService _service;

  /// Connects to the server that writes its VM service address to [info]
  /// (`--write-service-info`), waiting up to [timeout] for the file.
  static Future<VmClient> connect(
    File info, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final clock = Stopwatch()..start();
    while (!info.existsSync() || info.lengthSync() == 0) {
      if (clock.elapsed > timeout) {
        throw TimeoutException('no VM service address in ${info.path}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final json = jsonDecode(info.readAsStringSync()) as Map<String, Object?>;
    final http = Uri.parse(json['uri'] as String);
    final ws = http.replace(
      scheme: 'ws',
      path: '${http.path.endsWith('/') ? http.path : '${http.path}/'}ws',
    );
    return VmClient._(await vmServiceConnectUri(ws.toString()));
  }

  /// Loads the changed code into the running server and asks it to
  /// reassemble ([reassembleExtension]). A server without the extension
  /// (not a `ThorServer`, or an older thor) counts as not reloaded: its
  /// objects may hold the old code.
  Future<ReloadOutcome> reload() async {
    final clock = Stopwatch()..start();
    final isolates = await _isolates();
    if (isolates.isEmpty) return const NotReloaded('the server has no isolate');
    final ReloadReport report;
    try {
      report = await _service.reloadSources(isolates.first.id!);
    } on RPCError catch (e) {
      return NotReloaded('reload failed: ${e.message}');
    }
    if (report.success != true) {
      final notices = [
        for (final n in (report.json?['notices'] as List? ?? const []))
          if (n case {'message': final String message}) message,
      ];
      final reason = notices.isEmpty ? 'the VM refused it' : notices.join('\n');
      return NotReloaded(
        reason,
        compileError: RegExp(r'\bError:').hasMatch(reason),
      );
    }
    var reassembled = 0;
    var setUps = true;
    for (final isolate in await _isolates()) {
      final full = await _service.getIsolate(isolate.id!);
      if (!(full.extensionRPCs ?? const []).contains(reassembleExtension)) {
        continue;
      }
      final answer = await _service.callServiceExtension(
        reassembleExtension,
        isolateId: isolate.id,
      );
      if (answer.json?['setUps'] != true) setUps = false;
      reassembled++;
    }
    if (reassembled == 0) {
      return const NotReloaded(
        'the server has no $reassembleExtension (not a ThorServer)',
      );
    }
    return Reloaded(clock.elapsed, setUps: setUps);
  }

  Future<List<IsolateRef>> _isolates() async {
    final vm = await _service.getVM();
    return [
      for (final i in vm.isolates ?? const <IsolateRef>[])
        if (i.isSystemIsolate != true) i,
    ];
  }

  /// Closes the connection (the server keeps running).
  Future<void> dispose() => _service.dispose();
}

/// The arguments that make `dart run` serve its VM service on a free port
/// of this machine, writing the address to [info]. The address carries the
/// auth code (`http://127.0.0.1:port/<code>/`): without it any page of
/// another site could call the service (it answers every `Origin` and
/// `Host`), and it evaluates code in the app.
List<String> vmServiceArgs(File info) => [
  '--enable-vm-service=0/127.0.0.1',
  '--no-serve-devtools',
  '--write-service-info=${info.uri}',
];

/// The lines the VM prints when its service starts (not the app's).
bool isVmServiceLine(String line) =>
    line.startsWith('The Dart VM service is listening') ||
    line.startsWith('The Dart DevTools debugger') ||
    line.startsWith('Serving DevTools');

/// A compile error's first line in `dart run` output
/// (`lib/x.dart:12:5: Error: …`).
final compileErrorLine = RegExp(r'^(.+\.dart):(\d+):(\d+): Error: ');

/// Whether [pid] is a running process of this user.
bool processAlive(int pid) {
  if (Platform.isWindows) {
    final r = Process.runSync('tasklist', ['/FI', 'PID eq $pid']);
    return '${r.stdout}'.contains(' $pid ');
  }
  return Process.runSync('kill', ['-0', '$pid']).exitCode == 0;
}
