import 'dart:convert';
import 'dart:io';

import 'dev_hosts.dart';
import 'errors.dart' show thorErrorsUrl;
import 'results.dart';

/// The contract between an app's server and `thor dev`, active only when
/// `thor dev` starts the server (it sets `THOR_DEV=1`); a release build
/// never turns it on, and nothing here changes a page without it.
///
/// - **Hot reload.** After `thor dev` loads new code into the running
///   server (the VM's hot reload), it calls the `ext.thor.reassemble`
///   service extension: `ThorServer.serve` builds its server again (fresh
///   route table and page cache) and runs the hooks added with
///   [onReassemble] (caches of rendered HTML, the states' registry).
/// - **Errors.** An unexpected exception while answering a page (a `load`,
///   an action, a build) is also written into the error page as a
///   `<script type="application/json" id="thor-dev-error">` block
///   ([errorBlock]); `thor dev`'s proxy turns it into an overlay with the
///   file and line, and removes it. The same error is also one line in
///   `thor dev`'s terminal ([logRequestError]): method, path, type,
///   message and the app's own top frame (what `curl` or an agent reading
///   the terminal sees), whatever `onError` the app set.
/// - **Reach.** The server listens on the loopback only and answers a
///   `Host` that is not `localhost`, an IP address or in `--allowed-host`
///   with a 403 ([hosts], [DevHosts]): DNS rebinding.
/// - **Lifetime.** The server exits when `thor dev` closes its standard
///   input (it stopped, even with `kill -9`): no server left behind.
abstract final class ThorDev {
  /// Whether the server runs under `thor dev`. Tests may set it.
  static bool enabled = Platform.environment['THOR_DEV'] == '1';

  /// The `Host` values the app answers to under `thor dev` (a 403 for
  /// the rest, against DNS rebinding); `--allowed-host` arrives in the
  /// environment.
  static DevHosts hosts = DevHosts.parse(
    Platform.environment[DevHosts.envName],
  );

  /// Where the server listens: [requested] in a release; under `thor dev`
  /// always the IPv4 loopback, whatever the app asked for. Only the
  /// dev proxy (which checks `Host`) is opened to the network, with
  /// `thor dev --host`.
  static Object bindAddress(Object? requested) => enabled
      ? InternetAddress.loopbackIPv4
      : requested ?? InternetAddress.anyIPv6;

  /// The environment variable `thor dev` sets with its own pid.
  static const pidEnvName = 'THOR_DEV_PID';

  /// The pid of the `thor dev` that started this server, or null outside
  /// it. A restart and an exit both reach the server as `SIGTERM`; this
  /// process outlives a restart and is gone on an exit, so a helper that
  /// must survive restarts (but not the end of `thor dev`) anchors to it.
  static int? get devPid => enabled ? pidFrom(Platform.environment) : null;

  /// The pid in [env] (`THOR_DEV_PID`), or null if absent or not a number.
  static int? pidFrom(Map<String, String> env) {
    final pid = int.tryParse(env[pidEnvName] ?? '');
    return pid != null && pid > 0 ? pid : null;
  }

  static final _hooks = <void Function()>[];

  /// Runs [hook] after every hot reload (clears a cache of what the old
  /// code rendered). Adding the same function twice keeps one.
  static void onReassemble(void Function() hook) {
    if (!_hooks.contains(hook)) _hooks.add(hook);
  }

  /// Runs the [onReassemble] hooks (what `ThorServer` does on
  /// `ext.thor.reassemble`).
  static void reassembled() {
    for (final hook in [..._hooks]) {
      hook();
    }
  }

  /// What `ext.thor.reassemble` answers: `setUps` says the hooks ran the
  /// isolate set-ups again (`ThorServer.setUpIsolates`, the states'
  /// registry), so `thor dev` reloads a state's new member instead of
  /// restarting.
  static const reassembledResult = '{"setUps":true}';

  /// The `id` of the error block in a page.
  static const errorId = 'thor-dev-error';

  /// The block that carries an exception to `thor dev`'s overlay: [phase]
  /// (`load`, `action`, `build`, `render`), [where] (method and path, and
  /// the route), [error] and [stack].
  static String errorBlock({
    required String phase,
    required String where,
    required Object error,
    StackTrace? stack,
  }) {
    final json = jsonEncode({
      'phase': phase,
      'where': where,
      'type': error.runtimeType.toString(),
      'message': '$error',
      'stack': '${stack ?? ''}',
    });
    // `</script>` (or `<!--`) inside the JSON would end the block early.
    return '<script type="application/json" id="$errorId">'
        '${json.replaceAll('<', r'\u003c')}</script>';
  }

  /// [html] with [blocks] before its last `</body>` (at the end if it has
  /// none).
  static String withBlocks(String html, Iterable<String> blocks) {
    final text = blocks.join();
    if (text.isEmpty) return html;
    final end = html.toLowerCase().lastIndexOf('</body>');
    return end < 0
        ? '$html$text'
        : '${html.substring(0, end)}$text${html.substring(end)}';
  }

  /// Where [logRequestError] writes (the server's stderr, which `thor dev`
  /// forwards to its terminal). Tests replace it.
  static void Function(String line) errorSink = stderr.writeln;

  /// How long an identical error is written once, not again.
  static const errorDedupe = Duration(seconds: 5);

  /// The clock of the dedupe (tests replace it).
  static DateTime Function() clock = DateTime.now;

  static final _lastLogged = <String, DateTime>{};
  static final _suppressed = <String, int>{};

  /// Writes one line for an exception a request reported, so the terminal
  /// of `thor dev` shows what the page's overlay shows:
  /// `[thor] 500 GET /p: StateError: message (at lib/page.dart:12)`.
  ///
  /// [stack] is reduced to the first frame of the app (not `dart:` nor
  /// thor's own packages), not printed whole. The same error on the same
  /// request within [errorDedupe] is written once; the next line then says
  /// how many repeats it hid. Only under `thor dev`.
  static void logRequestError({
    required String method,
    required String path,
    required Object error,
    StackTrace? stack,
  }) {
    if (!enabled) return;
    final frame = appFrame(stack);
    final type = '${error.runtimeType}';
    String raw;
    try {
      raw = '$error';
    } catch (e) {
      raw = '<toString threw ${e.runtimeType}>';
    }
    // Only the first line, with no control characters: a message built from
    // a query parameter must not add lines or colors to the terminal.
    var text = terminalSafe(raw.split(_lineBreak).first, 300);
    method = terminalSafe(method, 16);
    path = terminalSafe(path, 200);
    // `FormatException: bad` already names its type.
    if (text.startsWith('$type: ')) text = text.substring(type.length + 2);
    final status = error is HttpError ? error.status : 500;
    final key = '$status $method $path $type $text $frame';
    final now = clock();
    final last = _lastLogged[key];
    if (last != null && now.difference(last) < errorDedupe) {
      _suppressed[key] = (_suppressed[key] ?? 0) + 1;
      return;
    }
    if (_lastLogged.length > 200) {
      _lastLogged.removeWhere((_, t) => now.difference(t) >= errorDedupe);
      _suppressed.removeWhere((k, _) => !_lastLogged.containsKey(k));
    }
    _lastLogged[key] = now;
    final hidden = _suppressed.remove(key);
    errorSink(
      '[thor] $status $method $path: $type: $text'
      '${frame == null ? '' : ' (at $frame)'}'
      '${hidden == null ? '' : ' [+$hidden repeats]'}',
    );
  }

  /// Under `thor dev`: a `defer(head: true, headBudget:)` future ran out of
  /// budget and then failed with a status (`NotFound`, `HttpError`,
  /// `Redirect`), so the page already answered 200 (THOR-S038). Written once
  /// per page within [errorDedupe].
  static void warnLateHeadStatus({
    required String method,
    required String path,
  }) {
    if (!enabled) return;
    method = terminalSafe(method, 16);
    path = terminalSafe(path, 200);
    final key = 'THOR-S038 $method $path';
    final now = clock();
    final last = _lastLogged[key];
    if (last != null && now.difference(last) < errorDedupe) return;
    _lastLogged[key] = now;
    errorSink(
      '[thor] THOR-S038 $method $path: this page can answer 200 for a '
      'missing resource when the backend is slow; drop headBudget or await '
      'it in load (${thorErrorsUrl}THOR-S038)',
    );
  }

  /// Under `thor dev`: a browser call named an id (`MapState.near`) the
  /// generated registry does not list as a query or command, so the server
  /// answered `404` (THOR-S039). Written once per id within [errorDedupe].
  static void warnUndeclaredCall(String id) {
    if (!enabled) return;
    id = terminalSafe(id, 200);
    final key = 'THOR-S039 $id';
    final now = clock();
    final last = _lastLogged[key];
    if (last != null && now.difference(last) < errorDedupe) return;
    _lastLogged[key] = now;
    errorSink(
      '[thor] THOR-S039 $id: the state or its query/command field is not in '
      'the generated registry, so the call was answered 404; rebuild, and '
      'check the field is public and declared in that state '
      '(${thorErrorsUrl}THOR-S039)',
    );
  }

  static final _lineBreak = RegExp('[\\n\\r\\u0085\\u2028\\u2029]');
  static final _control = RegExp(
    '[\\u0000-\\u001f\\u007f-\\u009f\\u2028\\u2029]',
  );

  /// [text] with every control character (ESC, `\r`, tabs, C1) written as
  /// `\xNN` and cut to [max] characters, safe for a terminal line.
  static String terminalSafe(String text, int max) {
    var out = text.replaceAllMapped(
      _control,
      (m) => '\\x${m[0]!.codeUnitAt(0).toRadixString(16).padLeft(2, '0')}',
    );
    if (out.length > max) out = '${out.substring(0, max)}...';
    return out;
  }

  /// Forgets what [logRequestError] remembers (tests).
  static void forgetLoggedErrors() {
    _lastLogged.clear();
    _suppressed.clear();
  }

  static final _frame = RegExp(r'\((package:[^)\s]+|file:[^)\s]+)\)');
  static final _own = RegExp(
    r'^package:(thor_(server|ui|style|engine|builder|cli|lints|test)|test|'
    r'shelf|async|stack_trace)/',
  );

  /// The first frame of [stack] that is the app's own, as
  /// `path/file.dart:line:col` (a `file:` frame relative to the working
  /// directory), or the first frame there is, or `null`.
  static String? appFrame(StackTrace? stack) {
    if (stack == null) return null;
    String? first;
    for (final m in _frame.allMatches('$stack')) {
      final loc = m[1]!;
      first ??= loc;
      if (_own.hasMatch(loc)) continue;
      return _short(loc);
    }
    return first == null ? null : _short(first);
  }

  static String _short(String loc) {
    if (!loc.startsWith('file:')) return loc;
    final cwd = Directory.current.uri.toString();
    return loc.startsWith(cwd)
        ? loc.substring(cwd.length)
        : Uri.parse(loc).path;
  }

  static var _watching = false;

  /// Exits when standard input closes (`thor dev` is gone). Once per
  /// process; only under `thor dev`.
  static void exitWithParent() {
    if (!enabled || _watching) return;
    _watching = true;
    stdin.listen((_) {}, onDone: () => exit(0), onError: (_) => exit(0));
  }
}
