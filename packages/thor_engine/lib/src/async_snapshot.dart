/// Flutter's `AsyncSnapshot` for a `ServerQuery`: `lines.snapshot`.
///
/// The names and the shape are Flutter's (`connectionState`, `hasData`,
/// `data`, `hasError`, `error`, `requireData`); the snapshot is only a view
/// over the query's signals, so it adds no state to the page.
library;

import 'server_error.dart';

/// Where an asynchronous computation is (Flutter's `ConnectionState`).
///
/// // web: a query is only [waiting] (a call on its way, or one the server
/// hasn't answered yet) or [done]; [none] and [active] (streams) are for
/// the API's sake and never come out of a query.
enum ConnectionState {
  /// Not connected to any computation.
  none,

  /// A call is on its way.
  waiting,

  /// Connected to an active computation (streams; unused by queries).
  active,

  /// The last call ended, with a value or an error.
  done,
}

/// The latest outcome of a query, as Flutter's `AsyncSnapshot<T>`.
///
/// Like Flutter's, a snapshot has data or an error, never both: the
/// snapshot of a failed call has no [data] (the query's own `data` signal
/// keeps the last good value, for a state that wants to show it stale).
///
/// // web: [error] is the visitor's message (a `String`, what travels from
/// the server) and [errorKind] says why it failed; Flutter's `stackTrace`
/// doesn't exist in the browser.
final class AsyncSnapshot<T> {
  /// A snapshot connected to nothing: no data, no error.
  const AsyncSnapshot.nothing()
    : connectionState = ConnectionState.none,
      _data = null,
      error = null,
      errorKind = null,
      _placeholder = false;

  /// A snapshot waiting for a call, with the [data] of the last one if any.
  const AsyncSnapshot.waiting([T? data])
    : _data = data,
      connectionState = ConnectionState.waiting,
      error = null,
      errorKind = null,
      _placeholder = false;

  /// A snapshot of a finished call with [data] (null for a call that
  /// answered null).
  ///
  /// // web: not in Flutter, where a done snapshot is `withData`; a query
  /// can answer null, which `withData(…, T data)` can't say for a `T` that
  /// isn't nullable.
  const AsyncSnapshot.done([T? data])
    : _data = data,
      connectionState = ConnectionState.done,
      error = null,
      errorKind = null,
      _placeholder = false;

  /// A snapshot in [connectionState] with [data].
  const AsyncSnapshot.withData(this.connectionState, T data)
    : _data = data,
      error = null,
      errorKind = null,
      _placeholder = false;

  /// A snapshot that says it has data it doesn't hold: [hasData] is true
  /// and reading [data] throws. `QueryBuilder` draws its "has data" states with it
  /// when the server has no data to draw them with (a query the browser
  /// runs, or one that failed), so the browser can switch to them once the
  /// data arrives: a builder that only reads [hasData] and binds what
  /// changes (`Watch`, `row.text`) draws them right; one that reads
  /// [data] or [requireData] throws, and that state is not shipped.
  ///
  /// // web: not in Flutter, where a snapshot never says it has data it
  /// doesn't hold. The server draws the structure once, and the browser
  /// fills in the values.
  const AsyncSnapshot.placeholder(this.connectionState)
    : _data = null,
      error = null,
      errorKind = null,
      _placeholder = true;

  /// A snapshot in [connectionState] with an [error] message and its
  /// [errorKind].
  const AsyncSnapshot.withError(
    this.connectionState,
    String this.error, [
    this.errorKind = ServerErrorKind.server,
  ]) : _data = null,
       _placeholder = false;

  /// Where the call is.
  final ConnectionState connectionState;

  /// The last value, or null (also when the value itself is null).
  ///
  /// A placeholder has none to give: reading it throws a [StateError], so a
  /// builder that reads the data (`data!`, `data ?? []`) is not drawn with
  /// the placeholder, rather than drawn with a made-up value.
  T? get data {
    if (_placeholder) {
      throw StateError(
        'Snapshot has no data yet (placeholder): bind values with Watch or '
        'row.text and use hasData to choose the branch (THOR-S037)',
      );
    }
    return _data;
  }

  final T? _data;

  /// The visitor's message for the last call's failure, or null.
  final String? error;

  /// Why the last call failed, or null.
  final ServerErrorKind? errorKind;

  /// Whether there is a non-null [data].
  bool get hasData => _data != null || _placeholder;

  final bool _placeholder;

  /// Whether the last call failed.
  bool get hasError => error != null;

  /// [data], or a [StateError] when there is none (Flutter's `requireData`).
  T get requireData {
    if (hasData) return data as T; // a placeholder throws here
    if (hasError) throw StateError('Snapshot has error: $error');
    throw StateError('Snapshot has neither data nor error');
  }

  @override
  bool operator ==(Object other) =>
      other is AsyncSnapshot<T> &&
      other.connectionState == connectionState &&
      other._data == _data &&
      other.error == error &&
      other.errorKind == errorKind &&
      other._placeholder == _placeholder;

  @override
  int get hashCode =>
      Object.hash(connectionState, _data, error, errorKind, _placeholder);

  @override
  String toString() =>
      'AsyncSnapshot<$T>(${connectionState.name}, data: ${_placeholder ? '<placeholder>' : _data}, error: $error)';
}
