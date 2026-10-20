/// Server state in a [ThorState]: `final info = query(repo.info);`.
///
/// The function runs on the server only — to draw the first page with its
/// data, and when the browser asks again (`refresh`). It is never
/// translated for the browser, so it may use any package. The browser gets
/// its result as JSON and four signals to draw with: [ServerQuery.data],
/// [ServerQuery.loading], [ServerQuery.error] and [ServerQuery.arg].
library;

import 'dart:async';

import 'arg_codec.dart';
import 'async_snapshot.dart';
import 'server_error.dart';
import 'thor_state.dart';

/// A value a [ServerQuery] computes on the server (see [query]).
///
/// On the server, [run] calls the function; the page's render calls it
/// before drawing so the HTML already shows [data]. In the browser the lite
/// engine's `query` part fetches it again on [refresh] (a `POST` to the
/// page's own URL, through that page's middleware).
final class ServerQuery<A, T> {
  ServerQuery._(
    this._call,
    A arg,
    ArgCodec<A> codec, {
    required this.hasArg,
    this.timeout,
    this.ssr = true,
    T? Function(Object? json)? dataDecode,
    bool browserOk = false,
  }) : _codec = codec,
       data = state<T?>(null, decode: dataDecode),
       arg = state<A>(arg, encode: codec.encode, decode: codec.decode) {
    // The dart2js engine can't call the server: `thor build` and `thor dev`
    // pick lite for it; a hand-made dart2js build fails here instead
    // of drawing a query that never answers. A [ServerEventStream] has nothing
    // to ask: its browser side is an `EventSource`.
    if (_compiledForTheBrowser && !browserOk) {
      throw UnsupportedError(
        'query() needs the lite engine; the dart2js engine does not '
        'support it yet',
      );
    }
  }

  static const _compiledForTheBrowser = bool.fromEnvironment(
    'dart.library.js_interop',
  );

  final FutureOr<T> Function(A arg) _call;

  // How an argument that is not a simple value travels (a class or a
  // record): set by `members`, from what the builder writes.
  final ArgCodec<A> _codec;

  /// Whether the function takes an argument ([queryWith]).
  final bool hasArg;

  /// How long the browser waits for an answer before it gives up with an
  /// error, or null (no limit). Only the browser applies it.
  final Duration? timeout;

  /// Whether the server runs the function to draw the page ([query]'s
  /// `ssr:`). False: the page is drawn with the waiting state at once and
  /// the browser asks when it hydrates.
  final bool ssr;

  /// The last value the server answered, or null before the first one.
  final StateSignal<T?> data;

  /// Whether a request for a new value is on its way (browser only: the
  /// server draws with the value already there).
  final StateSignal<bool> loading = state(false);

  /// A message for the visitor when the last call failed, or null. The
  /// message of an `HttpError`; a generic one for anything else (with the
  /// details only under `thor dev`).
  final StateSignal<String?> error = state<String?>(null);

  /// Why the last call failed ([error] says it to the visitor), or null: a
  /// state branches on it (sign in again on [ServerErrorKind.unauthorized]).
  final StateSignal<ServerErrorKind?> errorKind = state<ServerErrorKind?>(
    null,
    encode: (k) => k?.name,
    decode: (j) =>
        j == null ? null : ServerErrorKind.values.byName(j as String),
  );

  /// The argument the function is called with ([queryWith]).
  final StateSignal<A> arg;

  // Set in a request's scope once the server ran the function for it.
  final StateSignal<bool> _ran = state(false);

  /// Asks the server again (in the browser). A call still on its way is
  /// aborted: the newest one wins. On the server there is nothing to do:
  /// every render runs the function.
  void refresh() {}

  /// Sets [arg] to [value] and asks again (in the browser): a `setArg` per
  /// keystroke leaves one request on the wire.
  void setArg(A value) {
    arg.value = value;
    refresh();
  }

  /// Whether the server ran the function in the current request.
  bool get ran => _ran.peek();

  /// The finite state of the query, what a page switches on
  /// (`QueryBuilder`): `0` waiting with nothing to show, `1` waiting with
  /// the last value, `2` done with data, `3` failed, `4` done without data
  /// (the call answered null). A call on its way hides the error of the one
  /// before; a query the server hasn't run yet (the page's first draw,
  /// before it has its data) is waiting.
  int phase() {
    if (loading.value) return data.value == null ? 0 : 1;
    if (error.value != null) return 3;
    if (data.value != null) return 2;
    return ran ? 4 : 0;
  }

  /// The visitor's message of the last failure, or `''` (the text a page
  /// binds: `QueryError`).
  String message() => error.value ?? '';

  /// The query's outcome as Flutter's [AsyncSnapshot]: a view over [data],
  /// [loading], [error] and [errorKind] (reading it in a state method
  /// tracks them, like reading the signals).
  AsyncSnapshot<T> get snapshot => snapshotOf(phase(), data.value);

  /// The snapshot of [phase] with [data] (what a page draws for each of its
  /// finite states; `data` is ignored in a failed one and in one done
  /// without data).
  AsyncSnapshot<T> snapshotOf(int phase, T? data) => switch (phase) {
    0 => const AsyncSnapshot.waiting(),
    1 => AsyncSnapshot.waiting(data),
    3 => AsyncSnapshot.withError(
      ConnectionState.done,
      error.value ?? '',
      errorKind.value ?? ServerErrorKind.server,
    ),
    4 => const AsyncSnapshot.done(),
    _ => AsyncSnapshot.done(data),
  };

  /// Calls the function with the current [arg].
  Future<T> run() async => _call(arg.peek());

  /// A call with the argument [json] from the page: throws [ArgumentError]
  /// at once (before anything runs) when [json] is not an [A].
  Future<T> Function() callWith(Object? json) {
    final a = _argFrom(json);
    return () async => _call(a);
  }

  /// Runs the function for the page being drawn: [data], or [error] and
  /// [errorKind] get its outcome ([describe] turns an error into the
  /// visitor's message and its kind).
  Future<void> prefetch(
    (String, ServerErrorKind) Function(Object error) describe,
  ) async {
    _ran.value = true;
    try {
      data.value = await run();
      error.value = null;
      // The function's own error, whatever it is, becomes the page's message.
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      final (message, kind) = describe(e);
      error.value = message;
      errorKind.value = kind;
      rethrow;
    }
  }

  A _argFrom(Object? json) => _codec.argFrom(json, hasArg: hasArg);

  /// The members this query gives its state's page, as [name] (the field):
  /// `name$data`, `name$loading`, `name$error`, `name$errorKind`, `name$arg`,
  /// `name$phase`, `name$message`, `name$refresh`
  /// and the query itself (the server finds it by id). Generated code calls
  /// it.
  ///
  /// [argToJson] and [argFromJson] say how an argument that is a class or
  /// a record becomes JSON and back (`(a) => a.toJson()`,
  /// `Filter.fromJson`): the builder passes them when [A] is not a simple
  /// value.
  List<ThorMember> members(
    String name, {
    Object? Function(A arg)? argToJson,
    A Function(Map<String, Object?> json)? argFromJson,
  }) {
    _codec
      ..toJson = argToJson
      ..fromJson = argFromJson;
    return _members(name);
  }

  List<ThorMember> _members(String name) => [
    ThorMember.query(name, this),
    ThorMember.state('$name\$data', data),
    ThorMember.state('$name\$loading', loading, variants: const [false, true]),
    ThorMember.state('$name\$error', error),
    ThorMember.state('$name\$errorKind', errorKind),
    ThorMember.state('$name\$arg', arg),
    ThorMember(
      '$name\$phase',
      phase,
      call: (_) => phase(),
      variants: const [0, 1, 2, 3, 4],
    ),
    ThorMember('$name\$message', message, call: (_) => message()),
    ThorMember('$name\$refresh', refresh, call: (_) => refresh()),
  ];

  /// The query with page id [id] (`ProfileState.info`,
  /// `ProfileState#left.info`) among the states created so far, or null.
  static ServerQuery<Object?, Object?>? find(String id) {
    final dot = id.lastIndexOf('.');
    if (dot <= 0) return null;
    final prefix = id.substring(0, dot), name = id.substring(dot + 1);
    for (final s in ThorState.all) {
      if (s.idPrefix != prefix) continue;
      for (final m in s.members) {
        if (m.query != null && m.name == name) return m.query;
      }
    }
    return null;
  }

  /// The ids (`ProfileState.info`) of the queries of [states].
  static Map<String, ServerQuery<Object?, Object?>> of(
    Iterable<ThorState> states,
  ) => {
    for (final s in states)
      for (final m in s.members)
        if (m.query != null) '${s.idPrefix}.${m.name}': ?m.query,
  };
}

/// A value computed on the server: `final info = query(repo.info);`.
///
/// [fn] runs on the server only, never in the browser, so it may use any
/// package (a database driver, `uuid`, `intl`…). The page draws with its
/// value (no spinner on the first paint) and the browser asks again with
/// `info.refresh`. The call goes through the middleware of the page that
/// asks, like a form action. The value travels as JSON: a simple value,
/// lists and maps of them, or a class of the app with `toJson()` and a
/// `fromJson` factory (THOR-B021).
///
/// [timeout] (a `Duration` of literals: the browser gets it when it builds)
/// ends a call that doesn't answer in an [ServerQuery.error]; without it
/// the browser waits as long as the connection lives.
///
/// [ssr] `false` is for data the page doesn't need to be drawn with (not for
/// search engines, nothing above the fold): the server doesn't run [fn], so
/// the page doesn't wait for it; it goes out in the waiting state
/// (`QueryBuilder`'s skeleton) and the browser asks for the value as soon as
/// the page hydrates. A literal, like [timeout]: the browser needs it when
/// it builds.
///
/// `// web:` Flutter's `FutureBuilder` always starts in the client; here the
/// server draws first, so the default waits for the data and `ssr: false`
/// is how a page says it won't.
ServerQuery<Null, T> query<T>(
  FutureOr<T> Function() fn, {
  Duration? timeout,
  bool ssr = true,
}) => ServerQuery._(
  (_) => fn(),
  null,
  ArgCodec<Null>(),
  hasArg: false,
  timeout: timeout,
  ssr: ssr,
);

/// [query] with an argument: `queryWith(orders.page, arg: 0)`. [arg] is a
/// simple value (`int`, `double`, `num`, `String`, `bool`), a record of them
/// or a class of the app with `toJson()` and a `fromJson` factory
/// (THOR-B021):
///
/// ```dart
/// final list = queryWith(repo.list, arg: const OrdersFilter(q: '', page: 1));
/// void next() => list.setArg(list.arg.value.copyWith(page: list.arg.value.page + 1));
/// ```
///
/// The state changes it with `setArg` (each call aborts the one before it;
/// an argument equal to the current one, compared as JSON, asks nothing).
/// [ssr] is as in [query]: `false` asks in the browser, with [arg], once the
/// page hydrates.
ServerQuery<A, T> queryWith<A, T>(
  FutureOr<T> Function(A arg) fn, {
  required A arg,
  Duration? timeout,
  bool ssr = true,
}) => ServerQuery._(
  fn,
  arg,
  ArgCodec<A>(),
  hasArg: true,
  timeout: timeout,
  ssr: ssr,
);

/// A [ServerQuery] that stays up to date from the server's events:
/// `final feed = events<List<Quote>>('/quotes/stream', ...)`.
///
/// The page is drawn with `initial`'s value (the server runs it, like a
/// query's function) and the browser opens one native `EventSource` on
/// [url]: each [event] it receives, a JSON text, updates [data] — it
/// replaces it, or, with a [key], merges the items it brings into the list
/// (see [receive]). [connection] says where the stream is, as Flutter's
/// `StreamBuilder` does with [ConnectionState]: `waiting` while it connects
/// or reconnects, `active` while it is open and `done` when it is closed.
///
/// `// web:` Flutter's `StreamBuilder` listens to a `Stream` in the same
/// process; here the stream is the browser's `EventSource`, which brings
/// reconnection (with `Last-Event-ID`, see `PageRequest.lastEventId` in the
/// server) for free. The browser keeps one `EventSource` per [url] on the
/// page, opens it when an element of the page names this state and closes it
/// when none does (and when the page is left).
final class ServerEventStream<T> extends ServerQuery<Null, T> {
  ServerEventStream._(
    this.url,
    this.event,
    this.key,
    this._events,
    FutureOr<T> Function()? initial,
    Duration? timeout,
  ) : hasInitial = initial != null,
      super._(
        (_) {
          if (initial == null) {
            // The browser never asks (its `refresh` is a no-op without
            // `initial`); a hand-made call gets a precise error, not a
            // type error on a null.
            throw StateError('events() without `initial` has no value to ask');
          }
          return initial();
        },
        null,
        ArgCodec<Null>(),
        hasArg: false,
        timeout: timeout,
        // Without `initial` the page goes out waiting for the first event.
        ssr: initial != null,
        dataDecode: _events.decodeData,
        browserOk: true,
      );

  /// The same-origin path of the event stream (`/quotes/stream`).
  final String url;

  /// The name of the events listened to (`ServerEvent.event`); `message`
  /// for the ones the server sends without a name.
  final String event;

  /// The field of each item of a list that identifies it, or null when an
  /// event replaces [data] as a whole.
  final String? key;

  /// Whether the server draws the page with a value (`events`' `initial`).
  final bool hasInitial;

  final _EventsCodec<T> _events;

  /// Where the stream is: [ConnectionState.waiting] (connecting, or
  /// connecting again after the connection dropped), [ConnectionState.active]
  /// (open) and [ConnectionState.done] (closed: the page left, no element
  /// uses the state any more, or the server refused it).
  final StateSignal<ConnectionState> connection = state(
    ConnectionState.waiting,
    encode: (c) => c.name,
    decode: (j) => ConnectionState.values.byName(j as String),
  );

  // Set by the browser's engine: opens the stream again (`reconnect`).
  void Function()? _reopen;

  /// Opens the stream again after it was closed (the server refused it, or
  /// the page came back from the back button): a new connection is a first
  /// one, so the server's first event should bring the whole state. Nothing
  /// happens on the server.
  void reconnect() => _reopen?.call();

  /// Connects the browser's engine: [reopen] is what [reconnect] runs.
  /// Internal: the engine calls it.
  // ignore: use_setters_to_change_properties
  void attach(void Function() reopen) => _reopen = reopen;

  /// Applies one event's [json] (what `JSON.parse` of its data gives) to
  /// [data].
  ///
  /// Without a [key] it is the new value. With one, [data] is a list and the
  /// event brings changes to it, so only the items that changed are new
  /// objects (the others are the ones already there, in their place):
  ///
  /// * a list: the items to add or replace (the one with the same key stays
  ///   where it was; a new key goes to the end);
  /// * an object with any of `upsert` (that list), `remove` (the keys to
  ///   drop) and `replace` (a whole new list, applied first).
  void receive(Object? json) {
    final k = key;
    if (k == null) {
      // The `{replace: value}` envelope a keyed field takes is also this
      // field's value, so one stream can feed keyed and unkeyed states.
      final whole =
          json is Map && json.length == 1 && json.containsKey('replace');
      data.value = _events.decodeAll(whole ? json['replace'] : json);
      return;
    }
    List<Object?> put;
    List<Object?> drop = const [];
    List<Object?>? whole;
    if (json is List) {
      put = json;
    } else if (json is Map) {
      List<Object?> list(String name) => switch (json[name]) {
        null => const [],
        final List<Object?> l => l,
        _ => throw FormatException('"$name" of an event is not a list', json),
      };
      whole = json['replace'] == null ? null : list('replace');
      put = list('upsert');
      drop = list('remove');
    } else {
      throw FormatException(
        'an event of a keyed list is a list or an object',
        json,
      );
    }
    var items = whole == null
        ? [...?(data.peek() as List<Object?>?)]
        : [for (final e in whole) _events.decodeItem(e)];
    var keys = whole == null ? [..._events.keys] : _events.keysOf(whole);
    // The list was set by the page (not by an event or its state): its keys
    // are unknown, so every item counts as new.
    if (keys.length != items.length) {
      keys = List.filled(items.length, null, growable: true);
    }
    final at = <Object?, int>{
      for (var i = 0; i < keys.length; i++)
        if (keys[i] != null) keys[i]: i,
    };
    for (final e in put) {
      final id = _events.keyOf(e);
      final item = _events.decodeItem(e);
      // An item without a key can't be matched: it is appended, never
      // replacing another one.
      final i = id == null ? null : at[id];
      if (i == null) {
        if (id != null) at[id] = items.length;
        items.add(item);
        keys.add(id);
      } else {
        items[i] = item;
      }
    }
    if (drop.isNotEmpty) {
      final gone = {...drop};
      final keep = <int>[
        for (var i = 0; i < keys.length; i++)
          if (!gone.contains(keys[i])) i,
      ];
      items = [for (final i in keep) items[i]];
      keys = [for (final i in keep) keys[i]];
    }
    _events.keys = keys;
    data.value = _events.build(items);
  }

  @override
  AsyncSnapshot<T> snapshotOf(int phase, T? data) => switch (phase) {
    3 || 4 => super.snapshotOf(phase, data),
    2 => AsyncSnapshot.withData(connection.value, data as T),
    _ => AsyncSnapshot.waiting(data),
  };

  /// The members of the query (see [ServerQuery.members]) and
  /// `name$connection`. [decode], [item] and [list] say how the JSON becomes
  /// a [T] (a class with `fromJson`, a list of them): the builder passes them
  /// when it isn't a plain JSON value.
  @override
  List<ThorMember> members(
    String name, {
    Object? Function(Null arg)? argToJson,
    Null Function(Map<String, Object?> json)? argFromJson,
    T Function(Object? json)? decode,
    Object? Function(Object? json)? item,
    T Function(List<Object?> items)? list,
  }) {
    _events
      ..whole = decode
      ..item = item
      ..list = list
      ..key = key;
    return [
      ..._members(name),
      ThorMember.state(
        '$name\$connection',
        connection,
        variants: ConnectionState.values,
      ),
    ];
  }
}

/// [query]'s function, kept up to date by the server's events: an
/// `EventSource` the browser opens on [url].
///
/// ```dart
/// final quotes = events<List<Quote>>(
///   '/quotes/stream',         // a ThorRoute.stream of the same app
///   event: 'tick',            // ServerEvent(event: 'tick'); default 'message'
///   initial: market.snapshot, // the first value: server only, like query's fn
///   key: 'symbol',            // each event is a list of changed items
/// );
/// ```
///
/// [url] is a path of the app (`/quotes/stream`, one `/` at the start): the
/// browser never opens a stream on another site. [event], [key] and
/// [timeout] are literals, as the browser needs them when it builds.
/// [initial] runs on the server only (any package) and draws the page; leave
/// it out and the page goes out waiting for the first event. Without a [key]
/// each event is the new value of `data` (a JSON value, or a class with
/// `toJson` / `fromJson`); with one, see [ServerEventStream.receive].
ServerEventStream<T> events<T>(
  String url, {
  String event = 'message',
  FutureOr<T> Function()? initial,
  String? key,
  Duration? timeout,
}) {
  if (!url.startsWith('/') ||
      url.startsWith('//') ||
      RegExp(r'[\s\\\x00-\x1f]').hasMatch(url)) {
    throw ArgumentError.value(
      url,
      'url',
      'an events() url is a path of the app (`/quotes/stream`): the browser '
          'does not open a stream on another origin',
    );
  }
  if (event.isEmpty || RegExp(r'[\r\n\x00]').hasMatch(event)) {
    throw ArgumentError.value(event, 'event', 'not an event name');
  }
  if (key != null && !RegExp(r'^[A-Za-z_$][\w$-]*$').hasMatch(key)) {
    throw ArgumentError.value(key, 'key', 'a key is a field name');
  }
  final codec = _EventsCodec<T>()..key = key;
  return ServerEventStream<T>._(url, event, key, codec, initial, timeout);
}

/// How an event stream's JSON becomes a [T] (see [ServerEventStream.members]),
/// and the keys of the list it keeps up to date.
final class _EventsCodec<T> {
  /// JSON → [T] (a class, a list of classes), when the builder says.
  T Function(Object? json)? whole;

  /// JSON → one item of a list.
  Object? Function(Object? json)? item;

  /// The items → a [T] with the list's element type.
  T Function(List<Object?> items)? list;

  /// The key field of the list's items, or null.
  String? key;

  /// The keys of the items of the list [ServerEventStream.data] holds (parallel
  /// to it), as the JSON they came from said.
  List<Object?> keys = const [];

  // Only for the types `StateSignal` decodes by itself (`List<String>`…).
  late final StateSignal<T?> _plain = state<T?>(null);

  Object? keyOf(Object? json) => json is Map ? json[key] : null;

  List<Object?> keysOf(Object? json) => [
    if (json is List)
      for (final e in json) keyOf(e),
  ];

  Object? decodeItem(Object? json) => (item ?? (j) => j)(json);

  T build(List<Object?> items) => list != null ? list!(items) : items as T;

  /// What the data signal restores from the page's state.
  T? decodeData(Object? json) {
    if (json == null) return null;
    if (key != null) keys = keysOf(json);
    return decodeAll(json);
  }

  /// [json] as a [T]: the value of an event without a key.
  T decodeAll(Object? json) {
    if (whole case final decode?) return decode(json);
    if (item != null && list != null && json is List) {
      return list!([for (final e in json) item!(e)]);
    }
    return _plain.fromJson(json) as T;
  }
}
