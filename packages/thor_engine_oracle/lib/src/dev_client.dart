/// Development only: the browser half of `dev_state.dart`. `startThor`
/// calls [installDevState] only when [devReload] is on, so release builds
/// never contain it.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:thor_engine/src/thor_state.dart';
import 'package:thor_engine_oracle/src/dev_state.dart';
import 'package:web/web.dart' as web;

export 'package:thor_engine_oracle/src/dev_state.dart';

/// Exposes the snapshot of [states] to the live-reload script (as the
/// global [devStateGlobal]) and restores the snapshot stored for [path]
/// (`location.pathname` by default), once: it is removed as it is read, so
/// a manual reload starts from the server's values again.
///
/// Returns what was restored, or null when there was nothing to restore.
/// Never throws: storage may be missing (sandboxed frames), the snapshot
/// may be corrupt, and the code may have changed since it was taken.
DevRestore? installDevState(
  List<ThorState> states, {
  String? path,
  int limit = devStateLimit,
}) {
  final key = devStateKey + (path ?? web.window.location.pathname);
  globalContext[devStateGlobal] = (() {
    final dropped = <String>[];
    final snapshot = snapshotStates(
      states,
      size: (json) => _stringify(json.jsify()).length,
      limit: limit,
      dropped: dropped,
    );
    if (dropped.isNotEmpty) {
      web.console.warn(
        'thor dev: not kept across the reload (not JSON, or too big): '
                '${dropped.join(', ')}'
            .toJS,
      );
    }
    return _stringify(snapshot.jsify()).toJS;
  }).toJS;

  String? text;
  try {
    final storage = web.window.sessionStorage;
    text = storage.getItem(key);
    if (text == null) return null;
    storage.removeItem(key);
  } on Object {
    return null;
  }
  Object? snapshot;
  try {
    snapshot = (globalContext['JSON']! as JSObject)
        .callMethod<JSAny?>('parse'.toJS, text.toJS)
        .dartify();
  } on Object {
    web.console.warn('thor dev: the saved state was not JSON; ignored'.toJS);
    return null;
  }
  final result = restoreStates(states, snapshot);
  if (result.rolledBack) {
    web.console.warn(
      'thor dev: the page failed with the saved state; it starts from the '
              "server's values"
          .toJS,
    );
  }
  for (final MapEntry(:key, :value) in result.dropped.entries) {
    web.console.info('thor dev: $key not restored: $value'.toJS);
  }
  return result;
}

String _stringify(JSAny? value) =>
    (globalContext['JSON']! as JSObject)
        .callMethod<JSString?>('stringify'.toJS, value)
        ?.toDart ??
    'null';
