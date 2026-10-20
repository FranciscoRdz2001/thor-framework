/// Persisted page states for the dart2js engine: `state(…, cookie:)` and
/// `state(…, local:)`.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:thor_engine/src/protocol.dart';
import 'package:thor_engine/src/reactive.dart';
import 'package:thor_engine/src/thor_state.dart';
import 'package:thor_engine_oracle/client.dart' show EngineFeature;
import 'package:thor_engine_oracle/src/json_interop.dart';
import 'package:web/web.dart' as web;

/// `state(…, cookie:)` and `state(…, local:)`: after hydration each
/// persisted field moves to its cookie (the server drew the page with it
/// already; a static site's page could not) or its `localStorage` value
/// (the server never sees it), and writes it back when it changes. A
/// `local:` field also follows the other tabs (the `storage` event). The
/// generated entry adds it when the app persists a field.
final class PersistedStatesFeature extends EngineFeature {
  /// The feature.
  const PersistedStatesFeature();

  @override
  void Function()? afterHydration(Iterable<ThorMember> members) =>
      _persistStates(members);
}

/// Persisted page states (`state(…, cookie:)`): each moves to its cookie's
/// value (the server drew the page with it already; a static site's page
/// could not) and writes it back when it changes. Returns what stops the
/// writes.
void Function() _persistStates(Iterable<ThorMember> members) {
  final signals = [
    for (final m in members)
      if (m.signal case final s? when s.cookie != null) s,
  ];
  final locals = [
    for (final m in members)
      if (m.signal case final s? when s.local != null) s,
  ];
  if (signals.isEmpty && locals.isEmpty) return () {};
  final jar = <String, String>{};
  for (final part in web.document.cookie.split(';')) {
    final eq = part.indexOf('=');
    if (eq > 0) jar[part.substring(0, eq).trim()] = part.substring(eq + 1);
  }
  final json = globalContext['JSON']! as JSObject;
  final stops = <void Function()>[];
  final queue = _WriteQueue();
  for (final s in signals) {
    final name = '$persistedStateCookiePrefix${s.cookie}';
    final raw = jar[name];
    if (raw != null && raw.length <= StateSignal.maxCookieLength) {
      try {
        final text = _decodeUriComponent(raw);
        s.restoreJson(
          jsonToDart(json.callMethod<JSAny?>('parse'.toJS, text.toJS)),
        );
        // A cookie is the visitor's to write: a value that isn't the
        // field's is ignored (the page keeps the server's).
        // ignore: avoid_catches_without_on_clauses
      } catch (_) {}
    }
    var first = true;
    void write() {
      final encoded = json
          .callMethod<JSString>('stringify'.toJS, dartToJson(s.toJson()))
          .toDart;
      final value = _encodeUriComponent(encoded);
      if (value.length > StateSignal.maxCookieLength) return;
      final secure = web.window.location.protocol == 'https:';
      web.document.cookie =
          '$name=$value; path=/; max-age=31536000; samesite=lax'
          '${secure ? '; secure' : ''}';
    }

    stops.add(
      effect(() {
        s.value; // subscribes; the value is read when it is written
        if (first) {
          first = false;
          return;
        }
        queue.add(write);
      }),
    );
  }
  if (locals.isNotEmpty) stops.add(_persistLocal(locals, queue));
  return () {
    queue.stop();
    for (final stop in stops) {
      stop();
    }
  };
}

/// What a `localStorage` that throws (blocked: a private window, a
/// sandboxed frame, a full quota) keeps for the page instead: the value
/// lives on in memory, never as an error.
final _memory = <String, String>{};

/// The page's `localStorage`, or null when reading it throws (SecurityError).
JSObject? _storage() {
  try {
    final s = globalContext['localStorage'];
    if (s == null || s.isUndefinedOrNull) return null;
    // A blocked storage throws on its first use in some engines.
    return (s as JSObject).has('length') ? s : null;
    // ignore: avoid_catches_without_on_clauses
  } catch (_) {
    return null;
  }
}

String? _readLocal(String key) {
  if (_memory[key] case final v?) return v;
  try {
    return _storage()?.callMethod<JSString?>('getItem'.toJS, key.toJS)?.toDart;
    // ignore: avoid_catches_without_on_clauses
  } catch (_) {
    return null;
  }
}

void _writeLocal(String key, String value) {
  try {
    final s = _storage();
    if (s == null) throw StateError('no localStorage');
    s.callMethod<JSAny?>('setItem'.toJS, key.toJS, value.toJS);
    _memory.remove(key);
    // ignore: avoid_catches_without_on_clauses
  } catch (_) {
    _memory[key] = value;
  }
}

/// `state(…, local:)`: each field moves to its stored value, writes it back
/// (through [queue], coalesced with the cookies) when it changes, and takes
/// the value another tab stores. Returns what stops it.
void Function() _persistLocal(
  List<StateSignal<Object?>> signals,
  _WriteQueue queue,
) {
  final json = globalContext['JSON']! as JSObject;
  final byKey = <String, List<StateSignal<Object?>>>{};
  final stops = <void Function()>[];
  // The value each field just took from the storage: it is there already,
  // so its change writes nothing (no echo between tabs).
  final taken = <StateSignal<Object?>, Object?>{};
  // A stored value that isn't the field's (the visitor's to write) is
  // ignored: the page keeps the value it has.
  void apply(StateSignal<Object?> s, String text) {
    final Object? value;
    try {
      value = s.fromJson(
        jsonToDart(json.callMethod<JSAny?>('parse'.toJS, text.toJS)),
      );
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      return;
    }
    taken[s] = value;
    s.value = value;
  }

  for (final s in signals) {
    final key = '$persistedStateLocalPrefix${s.local}';
    (byKey[key] ??= []).add(s);
    if (_readLocal(key) case final text?) apply(s, text);
    var first = true;
    void write() {
      final text = json
          .callMethod<JSString>('stringify'.toJS, dartToJson(s.toJson()))
          .toDart;
      if (text != _readLocal(key)) _writeLocal(key, text);
    }

    stops.add(
      effect(() {
        final value = s.value; // subscribes; written later with its value
        final fromStorage = taken.containsKey(s);
        final stored = taken.remove(s);
        if (first) {
          first = false;
          return;
        }
        if (fromStorage && identical(stored, value)) return;
        queue.add(write);
      }),
    );
  }
  // Another tab of the site stored a value: take it. A removed key (or a
  // cleared storage) leaves the page as it is.
  final onStorage = ((web.StorageEvent e) {
    final key = e.key, text = e.newValue;
    if (key == null || text == null) return;
    final area = e.storageArea as JSAny?;
    final local = _storage();
    if (area != null && local != null && !area.strictEquals(local).toDart) {
      return;
    }
    final fields = byKey[key];
    if (fields == null) return;
    _memory.remove(key);
    for (final s in fields) {
      apply(s, text);
    }
  }).toJS;
  web.window.addEventListener('storage', onStorage);
  return () {
    web.window.removeEventListener('storage', onStorage);
    for (final stop in stops) {
      stop();
    }
  };
}

/// Cookie writes of one engine, coalesced. A `Slider` drag changes a field
/// dozens of times a second and every `document.cookie = …` is synchronous
/// work (and a header on the next request): a field written many times
/// between two frames is written once, with the value it has then. The
/// last value is never lost: the write also runs when the page is hidden
/// (`visibilitychange`, which fires first on mobile and for a closing tab)
/// and on `pagehide`, since a hidden tab gets no frames.
// web: Flutter's own persistence (shared_preferences) is async and has no
// write per change either; the browser's equivalent is one write per frame.
final class _WriteQueue {
  _WriteQueue() {
    web.window.addEventListener('pagehide', _flush);
    web.document.addEventListener('visibilitychange', _onVisibility);
  }

  final Set<void Function()> _writers = {};
  bool _scheduled = false;
  late final JSFunction _flush = ((JSAny? _) => flush()).toJS;
  late final JSFunction _onVisibility = ((JSAny? _) {
    if (web.document.visibilityState == 'hidden') flush();
  }).toJS;
  late final JSFunction _frame = ((JSAny? _) {
    _scheduled = false;
    flush();
  }).toJS;

  void add(void Function() write) {
    _writers.add(write);
    // No frames while hidden: write now.
    if (web.document.visibilityState == 'hidden') return flush();
    if (_scheduled) return;
    _scheduled = true;
    web.window.requestAnimationFrame(_frame);
  }

  void flush() {
    final writers = _writers.toList();
    _writers.clear();
    for (final write in writers) {
      // A write that throws (cookies blocked) must not lose the others.
      try {
        write();
        // ignore: avoid_catches_without_on_clauses
      } catch (e, st) {
        Zone.current.handleUncaughtError(e, st);
      }
    }
  }

  /// Writes what is pending and lets go of the page's events.
  void stop() {
    flush();
    web.window.removeEventListener('pagehide', _flush);
    web.document.removeEventListener('visibilitychange', _onVisibility);
  }
}

String _decodeUriComponent(String s) => globalContext
    .callMethod<JSString>('decodeURIComponent'.toJS, s.toJS)
    .toDart;

String _encodeUriComponent(String s) => globalContext
    .callMethod<JSString>('encodeURIComponent'.toJS, s.toJS)
    .toDart;
