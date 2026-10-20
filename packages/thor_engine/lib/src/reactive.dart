/// Fine-grained reactivity: a signal notifies exactly the effects that read
/// it, so an update touches only the DOM nodes bound to it (no tree rebuild,
/// no diff). Same model as the signals of Solid or Preact.
library;

import 'dart:async';

/// Signal values of one server request.
///
/// Signals are usually top-level (`final cart = Signal(...)`), which is right
/// in the browser (one user) and for static generation. A server that renders
/// pages per request would share them between concurrent requests; inside
/// [SignalScope.run], writes go to a scope of their own and reads fall back to
/// the signal's global value, so requests never see each other's state.
///
/// thor's server entry runs every request in a scope. The browser never
/// creates one, so signals there pay nothing for it.
final class SignalScope {
  SignalScope._();

  static final _key = Object();

  // Set once the first scope exists: until then reads skip the zone lookup.
  static bool _used = false;

  final Map<Signal<Object?>, Object?> _values = {};

  // Writes so far: a derived value cached in this scope is stale after one.
  int _writes = 0;
  final Map<Computed<Object?>, (int, Object?)> _derived = {};

  static SignalScope? get _current =>
      _used ? Zone.current[_key] as SignalScope? : null;

  /// Whether the caller runs inside a scope.
  static bool get isActive => _current != null;

  /// Whether the current scope holds a value of its own for [signal].
  static bool holds(Signal<Object?> signal) =>
      _current?._values.containsKey(signal) ?? false;

  static final _cookiesKey = Object();

  /// Runs [body] with the request's persisted page states: [cookies] are
  /// the request's cookies (a `state(…, cookie:)` reads its own there) and
  /// [read] turns a cookie's value into JSON data (percent-decoding, then
  /// `jsonDecode`; given by the server so the browser engine never carries
  /// a JSON parser of its own).
  static R withCookies<R>(
    Map<String, String> cookies,
    Object? Function(String raw) read,
    R Function() body,
  ) => runZoned(body, zoneValues: {_cookiesKey: (cookies, read)});

  /// What [withCookies] gave the caller, if any.
  static (Map<String, String>, Object? Function(String))? get cookies =>
      Zone.current[_cookiesKey]
          as (Map<String, String>, Object? Function(String))?;

  /// Runs [body] with its own signal values (and those of anything it
  /// awaits).
  static R run<R>(R Function() body) {
    _used = true;
    return runZoned(body, zoneValues: {_key: SignalScope._()});
  }
}

/// Anything an effect can depend on.
abstract class _Source {
  final Set<_Effect> _subscribers = {};

  /// Bumped each time the value really changes; an effect compares it with
  /// what it saw on its last run (the way lite's `ver` works).
  int _version = 0;

  void _track() {
    final current = _Effect._current;
    if (current != null) {
      _subscribers.add(current);
      current._sources[this] = _version;
    }
  }

  void _notify() {
    if (_subscribers.isEmpty) return;
    for (final e in _subscribers.toList()) {
      e._schedule();
    }
  }

  /// Brings the value up to date (a [Computed] recomputes if it is dirty).
  void _refresh() {}
}

/// A reactive value (Flutter's `ValueNotifier`, but tracked automatically).
class Signal<T> extends _Source {
  /// Creates a signal holding [_value].
  Signal(this._value);

  T _value;

  /// The value; reading it inside an effect subscribes the effect.
  T get value {
    _track();
    return peek();
  }

  set value(T next) {
    final scope = SignalScope._current;
    if (scope != null) {
      // A request's own value: nothing in this isolate subscribes to it.
      scope._values[this] = next;
      scope._writes++;
      return;
    }
    if (identical(next, _value) || next == _value) return;
    _value = next;
    _version++;
    // One write is a batch of its own: a diamond's effect runs once, after
    // every computed between it and the signal is marked.
    _Effect._begin();
    try {
      _notify();
    } finally {
      _Effect._end();
    }
  }

  /// Reads without subscribing.
  T peek() {
    final scope = SignalScope._current;
    if (scope != null && scope._values.containsKey(this)) {
      return scope._values[this] as T;
    }
    return _value;
  }

  /// `value = update(value)`.
  void update(T Function(T value) update) => value = update(peek());
}

/// What can be read as `.value` and tracked: a [Signal] is one of those
/// to its readers, and so is the result of `derived(...)`, which cannot be
/// written.
abstract interface class ReadSignal<T> {
  /// The value; reading it inside an effect subscribes the effect.
  T get value;

  /// The value, like [value] (the tear-off a `Watch` takes: `Watch(x.call)`).
  T call();
}

/// A derived value, recomputed lazily when a dependency changes.
///
/// Like lite's (and Preact's), a recompute that yields an equal value
/// (`identical` or `==`) does not notify: its dependents do not rerun. A
/// `List` or `Map` is compared by identity (Dart's `==`), so a computed that
/// builds a new collection each time always counts as changed, the same as
/// lite's `!==`.
class Computed<T> extends _Source implements ReadSignal<T> {
  /// Creates a value derived from [_compute].
  Computed(this._compute) : _scoped = false;

  /// What `derived(...)` makes: inside a request's scope the value is also
  /// kept (until a signal is written there), so a derivation read by several
  /// `Watch`es of one page runs once on the server too.
  Computed.scoped(this._compute) : _scoped = true;

  final T Function() _compute;
  final bool _scoped;
  late final _Effect _effect = _Effect(_recompute, lazy: true);
  bool _dirty = true;
  bool _computing = false;
  bool _hasValue = false;
  late T _value;

  // A dependency changed: dependents are only marked; whether this really
  // changed is decided when one of them asks (see [_refresh]).
  void _recompute() {
    _dirty = true;
    _notify();
  }

  @override
  void _refresh() {
    if (!_dirty) return;
    if (_computing) {
      throw StateError('thor: cycle: a computed reads itself');
    }
    // Dependencies that did not really change leave the cache valid.
    if (_hasValue && !_effect._sourcesChanged()) {
      _dirty = false;
      return;
    }
    _computing = true;
    var done = false;
    try {
      final next = _effect._runTracked(_compute);
      if (!_hasValue || !(identical(next, _value) || next == _value)) {
        _value = next;
        _version++;
      }
      _hasValue = true;
      _dirty = false;
      done = true;
    } finally {
      _computing = false;
      // A throw leaves no value to trust: the next read computes again (and
      // throws again) instead of serving the one from before the failure.
      if (!done) _hasValue = false;
    }
  }

  /// The computed value; reading it inside an effect subscribes the effect,
  /// and recomputes it first if a dependency changed.
  @override
  T get value {
    // Inside a request scope the cache would mix requests: compute fresh.
    if (SignalScope._current case final scope?) {
      if (!_scoped) return untracked(_compute);
      final kept = scope._derived[this];
      if (kept != null && kept.$1 == scope._writes) return kept.$2 as T;
      final next = untracked(_compute);
      scope._derived[this] = (scope._writes, next);
      return next;
    }
    if (_computing) {
      throw StateError('thor: cycle: a computed reads itself');
    }
    _refresh();
    _track(); // after the refresh: the reader sees the settled version
    return _value;
  }

  @override
  T call() => value;
}

class _Effect {
  _Effect(this._fn, {this.lazy = false});

  static _Effect? _current;
  static int _batchDepth = 0;
  static final List<_Effect> _pending = [];

  /// Rounds of effects re-queuing each other before the flush gives up. The
  /// same limit as lite (a legitimate chain can pass 100; a loop hits 1000
  /// in microseconds).
  static const _maxRounds = 1000;

  final void Function() _fn;

  /// Lazy effects (Computed) only mark themselves dirty.
  final bool lazy;

  /// What this effect read, with the version it saw.
  final Map<_Source, int> _sources = {};
  bool _queued = false;
  bool _disposed = false;

  static void _begin() => _batchDepth++;

  /// Leaves a batch; the outermost one runs what was queued. An effect that
  /// throws does not skip the rest (the first error is rethrown at the end),
  /// and a loop of effects feeding each other stops after [_maxRounds].
  static void _end() {
    if (_batchDepth > 1) {
      _batchDepth--;
      return;
    }
    Object? error;
    StackTrace? trace;
    var failed = false;
    var mark = _pending.length, round = 0;
    try {
      for (var i = 0; i < _pending.length; i++) {
        if (i == mark) {
          mark = _pending.length;
          if (++round > _maxRounds) {
            if (!failed) {
              error = StateError(
                'thor: cycle: effects keep triggering each other',
              );
              failed = true;
              trace = StackTrace.current;
            }
            break;
          }
        }
        final e = _pending[i].._queued = false;
        if (e._disposed || !e._sourcesChanged()) continue;
        try {
          e.run();
          // ignore: avoid_catches_without_on_clauses
        } catch (x, st) {
          if (!failed) {
            failed = true;
            error = x;
            trace = st;
          } else {
            // Only one error can be rethrown: the others go to the zone's
            // handler (the console in a page) instead of vanishing.
            Zone.current.handleUncaughtError(x, st);
          }
        }
      }
    } finally {
      for (final e in _pending) {
        e._queued = false;
      }
      _pending.clear();
      _batchDepth = 0;
    }
    if (failed) Error.throwWithStackTrace(error!, trace!);
  }

  /// Whether a source changed since the last run (computeds refresh first,
  /// so one that recomputed to an equal value counts as unchanged).
  bool _sourcesChanged() {
    for (final entry in _sources.entries.toList()) {
      entry.key._refresh();
      if (entry.key._version != entry.value) return true;
    }
    return _sources.isEmpty;
  }

  R _runTracked<R>(R Function() fn) {
    for (final s in _sources.keys) {
      s._subscribers.remove(this);
    }
    _sources.clear();
    final previous = _current;
    _current = this;
    try {
      return fn();
    } finally {
      _current = previous;
    }
  }

  void run() {
    if (!_disposed) _runTracked(_fn);
  }

  void _schedule() {
    if (_disposed) return;
    if (lazy) return _fn();
    if (!_queued) {
      _queued = true;
      _pending.add(this);
    }
  }

  void dispose() {
    _disposed = true;
    for (final s in _sources.keys) {
      s._subscribers.remove(this);
    }
    _sources.clear();
  }
}

/// Runs [fn] now and again whenever a signal it read changes.
/// Returns a function that stops it.
void Function() effect(void Function() fn) {
  final e = _Effect(fn);
  _owned?.add(e.dispose);
  _Effect._begin();
  try {
    e.run();
  } finally {
    _Effect._end();
  }
  return e.dispose;
}

List<void Function()>? _owned;

/// Runs [fn] and returns what stops the effects it created (not the ones
/// those create when they run again). The owner of a piece of code stops
/// its effects with it: a state that ends stops what its `onHydrated`
/// started, as the lite engine's `fx` does.
List<void Function()> collectEffects(void Function() fn) {
  final outer = _owned;
  final mine = _owned = [];
  try {
    fn();
  } finally {
    _owned = outer;
  }
  return mine;
}

/// Groups several writes: each dependent effect runs once, at the end.
void batch(void Function() fn) {
  _Effect._begin();
  try {
    fn();
  } finally {
    _Effect._end();
  }
}

/// Reads signals inside [fn] without subscribing the current effect.
T untracked<T>(T Function() fn) {
  final previous = _Effect._current;
  _Effect._current = null;
  try {
    return fn();
  } finally {
    _Effect._current = previous;
  }
}

/// What the rows of a list read outside their items (another state's field:
/// the set of starred ids a row state looks at).
///
/// The rows render under this tracker, apart from the effect that reads the
/// items, so the two kinds of reads are known apart. [changed] tells that a
/// read outside the items moved: the list then renders every row again
/// though its item is the same. A list whose rows read only their item
/// leaves it without sources: no subscription at all.
final class RowReads {
  /// A tracker; [rerun] renders the whole list when a read moves.
  RowReads(void Function() rerun) : _effect = _Effect(rerun);

  final _Effect _effect;

  /// Whether a read outside the items moved since the rows last rendered.
  bool get changed => _effect._sources.isNotEmpty && _effect._sourcesChanged();

  /// Runs [render] (the whole list) and keeps only what it reads.
  void rebuild(void Function() render) => _effect._runTracked(render);

  /// Runs [render] (some rows) and adds what it reads to what is kept.
  void add(void Function() render) {
    final previous = _Effect._current;
    _Effect._current = _effect;
    try {
      render();
    } finally {
      _Effect._current = previous;
    }
  }

  /// Stops it.
  void dispose() => _effect.dispose();
}
