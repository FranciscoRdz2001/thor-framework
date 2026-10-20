/// Development only: the browser keeps the values of every `ThorState`
/// across the reloads of `thor dev`.
///
/// Before `thor dev` reloads a page, its live-reload script asks the engine
/// for a [snapshotStates] and stores it in `sessionStorage` (per tab, per
/// path); the reloaded page's engine takes it back once with
/// [restoreStates], after hydrating the server's values. The code may have
/// changed in between, so the restore is field by field: what still fits
/// comes back, the rest keeps the server's value, and nothing throws.
///
/// Pure Dart (tested in the VM); the browser half lives in `client.dart`,
/// compiled in only with `-Dthor.dev=true` ([devReload]).
library;

import 'package:thor_engine/src/reactive.dart';
import 'package:thor_engine/src/thor_state.dart';

/// Whether this build is `thor dev`'s engine (`-Dthor.dev=true`). Release
/// builds leave it false, so dart2js drops every use.
const devReload = bool.fromEnvironment('thor.dev');

/// The `sessionStorage` key prefix (plus `location.pathname`) of a page's
/// snapshot. Keep in sync with thor_cli's live-reload script.
const devStateKey = 'thor:state:';

/// The global function the live-reload script calls for the snapshot.
const devStateGlobal = '__thorDevState';

/// Largest snapshot kept, in JSON characters (`sessionStorage` holds about
/// 5 MB per origin, shared with the app's own data).
const devStateLimit = 512 * 1024;

/// Version of the snapshot format; another version is ignored.
const devStateVersion = 1;

/// A snapshot of every reactive field of [states] that survives JSON:
/// `{"v": 1, "s": {"CounterState.count": 3, …}}`.
///
/// A field is left out (and named in [dropped]) when its value is not JSON
/// (a custom class without `encode`, a `Set`, a map with non-string keys,
/// NaN) or its `encode` throws. When the JSON would pass [limit] characters
/// ([size] measures one value's JSON), the largest fields are left out
/// until it fits.
Map<String, Object?> snapshotStates(
  Iterable<ThorState> states, {
  required int Function(Object? json) size,
  int limit = devStateLimit,
  List<String>? dropped,
}) {
  final values = <String, Object?>{};
  final sizes = <String, int>{};
  for (final s in states) {
    for (final m in s.members) {
      final signal = m.signal;
      if (signal == null) continue;
      final id = '${s.idPrefix}.${m.name}';
      Object? json;
      try {
        json = signal.toJson();
      } on Object {
        dropped?.add(id);
        continue;
      }
      if (!isJson(json)) {
        dropped?.add(id);
        continue;
      }
      values[id] = json;
      // The key, its quotes, the colon and the comma.
      sizes[id] = size(json) + id.length + 4;
    }
  }
  var total = sizes.values.fold(0, (a, b) => a + b);
  if (total > limit) {
    final largest = sizes.keys.toList()
      ..sort((a, b) => sizes[b]!.compareTo(sizes[a]!));
    for (final id in largest) {
      if (total <= limit) break;
      values.remove(id);
      total -= sizes[id]!;
      dropped?.add(id);
    }
  }
  return {'v': devStateVersion, 's': values};
}

/// Whether [value] is plain JSON: null, a bool, a string, a finite number,
/// or a list / string-keyed map of those.
bool isJson(Object? value) => switch (value) {
  null || bool() || String() => true,
  final num n => n.isFinite,
  final List<Object?> l => l.every(isJson),
  final Map<Object?, Object?> m => m.entries.every(
    (e) => e.key is String && isJson(e.value),
  ),
  _ => false,
};

/// What [restoreStates] did.
final class DevRestore {
  DevRestore._(this.restored, this.dropped, {this.rolledBack = false});

  /// Ids of the fields that got their value back.
  final List<String> restored;

  /// Ids of the snapshot's fields that did not fit the code anymore (a
  /// removed or renamed field or class, another type, a value its `decode`
  /// rejects), with the reason.
  final Map<String, String> dropped;

  /// Whether the restored values made the page's code throw, so every
  /// field went back to the server's value.
  final bool rolledBack;
}

/// Writes a [snapshotStates] back into [states], field by field.
///
/// A field is restored only if its id still exists, is still a reactive
/// field, its JSON has the kind of the current value (number, string,
/// bool, list, map; anything fits a null) and its type or `decode` accepts
/// it. If the page's effects throw with the restored values (a method that
/// relied on a shape that changed), every restored field goes back to the
/// value it had. Never throws.
DevRestore restoreStates(Iterable<ThorState> states, Object? snapshot) {
  final dropped = <String, String>{};
  if (snapshot is! Map ||
      snapshot['v'] != devStateVersion ||
      snapshot['s'] is! Map) {
    return DevRestore._(const [], const {});
  }
  final values = snapshot['s'] as Map;
  final signals = <String, StateSignal<Object?>?>{
    for (final s in states)
      for (final m in s.members) '${s.idPrefix}.${m.name}': m.signal,
  };
  final previous = <StateSignal<Object?>, Object?>{};
  final restored = <String>[];
  try {
    batch(() {
      for (final MapEntry(:key, :value) in values.entries) {
        final id = '$key';
        if (!signals.containsKey(id)) {
          dropped[id] = 'no longer on the page';
          continue;
        }
        final signal = signals[id];
        if (signal == null) {
          dropped[id] = 'no longer a state field';
          continue;
        }
        final before = signal.peek();
        final Object? current;
        try {
          current = signal.toJson();
        } on Object {
          dropped[id] = 'its value does not encode';
          continue;
        }
        final was = _kind(value), now = _kind(current);
        if (now != null && was != null && was != now) {
          dropped[id] = 'was $was, now $now';
          continue;
        }
        try {
          signal.restoreJson(value);
        } on Object catch (e) {
          dropped[id] = 'does not fit its type ($e)';
          continue;
        }
        previous[signal] = before;
        restored.add(id);
      }
    });
  } on Object {
    // An effect threw with the restored values: back to the server's.
    try {
      batch(() {
        for (final MapEntry(:key, :value) in previous.entries) {
          key.value = value;
        }
      });
    } on Object {
      // The server's values threw too: nothing more to undo.
    }
    return DevRestore._(const [], {
      ...dropped,
      for (final id in restored) id: 'the page failed with it',
    }, rolledBack: true);
  }
  return DevRestore._(restored, dropped);
}

String? _kind(Object? json) => switch (json) {
  null => null,
  bool() => 'bool',
  num() => 'number',
  String() => 'string',
  List() => 'list',
  Map() => 'map',
  _ => 'other',
};
