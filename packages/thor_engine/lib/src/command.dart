/// Server mutations in a [ThorState]: `final add = commandWith(repo.add);`.
///
/// The function runs on the server only, when the browser calls
/// `add.run(sku)` — never while a page draws. It is never translated for
/// the browser, so it may use any package. After it succeeds, the server
/// runs the page's queries again and sends their new values in the same
/// answer: one round trip for the change and the fresh data.
library;

import 'dart:async';

import 'arg_codec.dart';
import 'query.dart';
import 'server_error.dart';
import 'thor_state.dart';

/// What [ServerCommand] and [ServerCommandWith] share: three signals to
/// draw with ([pending], [error], [result]) and the server side of the
/// call.
///
/// On the server the function runs only when the browser asks (a `POST`
/// to the page's own URL with `x-thor-command`, through that page's
/// middleware); drawing a page never calls it. In the browser the lite
/// engine's `command` part sends the call and applies the answer.
sealed class ServerCommandBase<A, R> {
  ServerCommandBase._(
    this._call,
    this._invalidates,
    this.timeout,
    this.writes,
    this._codec,
  ) {
    // The dart2js engine can't call the server: `thor build` and `thor dev`
    // pick lite for it; a hand-made dart2js build fails here.
    if (_compiledForTheBrowser) {
      throw UnsupportedError(
        'command() needs the lite engine; the dart2js engine does not '
        'support it yet',
      );
    }
  }

  static const _compiledForTheBrowser = bool.fromEnvironment(
    'dart.library.js_interop',
  );

  final FutureOr<R> Function(A arg) _call;

  // How an argument that is not a simple value travels (a class or a
  // record): set by `members`, from what the builder writes.
  final ArgCodec<A> _codec;

  final List<ServerQuery<Object?, Object?>> Function(ThorState state)?
  _invalidates;

  /// How long the browser waits for an answer before it gives up with an
  /// error, or null (no limit). The change may still have happened on the
  /// server. Only the browser applies it.
  final Duration? timeout;

  /// Whether the command changes data the page cache or the browser's
  /// prefetches may hold. False for a read the visitor asks for (load more):
  /// the page cache and the browser's prefetches are kept, and the
  /// invalidated queries still refresh. Only the server reads it.
  final bool writes;

  /// Whether the function takes an argument ([commandWith]).
  bool get hasArg;

  /// Whether a call is waiting or on its way (browser only): true from the
  /// first `run` until the last one of the queue is answered.
  final StateSignal<bool> pending = state(false);

  /// A message for the visitor when the last call failed, or null. The
  /// message of an `HttpError`; a generic one for anything else.
  final StateSignal<String?> error = state<String?>(null);

  /// Why the last call failed ([error] says it to the visitor), or null.
  final StateSignal<ServerErrorKind?> errorKind = state<ServerErrorKind?>(
    null,
    encode: (k) => k?.name,
    decode: (j) =>
        j == null ? null : ServerErrorKind.values.byName(j as String),
  );

  /// What the last successful call returned, or null before one.
  final StateSignal<R?> result = state<R?>(null);

  // A `run` never runs on the server (a page never runs a command while it
  // draws): the browser's engine has the queue.

  /// A call with the argument [json] from the page: throws [ArgumentError]
  /// at once (before anything runs) when [json] is not an [A].
  Future<R> Function() callWith(Object? json) {
    final a = _argFrom(json);
    return () async => _call(a);
  }

  A _argFrom(Object? json) => _codec.argFrom(json, hasArg: hasArg);

  /// [ThorMember.call] of `run`: the page's text argument as an [A].
  Object? _runFromPage(String? a);

  /// The tear-off of `run` (widgets' callbacks are matched against it).
  Function get _run;

  /// The members this command gives its state's page, as [name] (the
  /// field): `name$pending`, `name$error`, `name$result`, `name$run` and
  /// the command itself (the server finds it by id). Generated code calls
  /// it.
  ///
  /// [argToJson] and [argFromJson] say how an argument that is a class or
  /// a record becomes JSON and back (`(a) => a.toJson()`,
  /// `Edit.fromJson`): the builder passes them when [A] is not a simple
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
    ThorMember.command(name, this),
    ThorMember.state('$name\$pending', pending, variants: const [false, true]),
    ThorMember.state('$name\$error', error),
    ThorMember.state('$name\$errorKind', errorKind),
    ThorMember.state('$name\$result', result),
    ThorMember('$name\$run', _run, arity: hasArg ? 1 : 0, call: _runFromPage),
  ];

  /// The command with page id [id] (`CartState.add`, `CartState#left.add`)
  /// among the states created so far, or null.
  static ServerCommandBase<Object?, Object?>? find(String id) {
    final dot = id.lastIndexOf('.');
    if (dot <= 0) return null;
    final prefix = id.substring(0, dot), name = id.substring(dot + 1);
    for (final s in ThorState.all) {
      if (s.idPrefix != prefix) continue;
      for (final m in s.members) {
        if (m.command != null && m.name == name) return m.command;
      }
    }
    return null;
  }

  /// The ids of the queries command [id] refreshes (`invalidates:`), or null
  /// when it names none: then it refreshes every query the browser has on
  /// the page. A query that is no member of any state is not in the set.
  static Set<String>? invalidatedBy(String id) {
    final dot = id.lastIndexOf('.');
    if (dot <= 0) return null;
    final prefix = id.substring(0, dot), name = id.substring(dot + 1);
    for (final s in ThorState.all) {
      if (s.idPrefix != prefix) continue;
      for (final m in s.members) {
        if (m.command != null && m.name == name) {
          final of = m.command!._invalidates;
          if (of == null) return null;
          final named = of(s);
          return {
            for (final e in ServerQuery.of(ThorState.all).entries)
              if (named.any((q) => identical(q, e.value))) e.key,
          };
        }
      }
    }
    return null;
  }

  /// The ids (`CartState.add`) of the commands of [states].
  static Map<String, ServerCommandBase<Object?, Object?>> of(
    Iterable<ThorState> states,
  ) => {
    for (final s in states)
      for (final m in s.members)
        if (m.command != null) '${s.idPrefix}.${m.name}': ?m.command,
  };
}

/// A command without an argument ([command]): `onPressed: cart.clear.run`.
final class ServerCommand<R> extends ServerCommandBase<Null, R> {
  ServerCommand._(
    FutureOr<R> Function() fn,
    List<ServerQuery<Object?, Object?>> Function(ThorState state)? invalidates,
    Duration? timeout,
    bool writes,
  ) : super._((_) => fn(), invalidates, timeout, writes, ArgCodec<Null>());

  @override
  bool get hasArg => false;

  /// Calls the function on the server (in the browser). A `run` while
  /// another is on its way waits its turn: runs go out one at a time, in
  /// order, none is dropped. When one succeeds, [result] gets its value and
  /// the page's queries their new ones, from the same answer.
  ///
  /// The future completes with what this run returned, or with null when it
  /// failed ([error] says why) — it never throws, so a state method can
  /// `await` it and go on. A `void` command can't tell success from failure
  /// by its value: read [error] after the `await`. On the server there is
  /// nothing to do: a page never runs a command while it draws.
  Future<R?> run() async => null;

  @override
  Function get _run => run;

  @override
  Object? _runFromPage(String? a) {
    unawaited(run());
    return null;
  }
}

/// A command with an argument ([commandWith]):
/// `onPressed: cart.add.run.withArg(sku)`.
final class ServerCommandWith<A, R> extends ServerCommandBase<A, R> {
  ServerCommandWith._(
    FutureOr<R> Function(A arg) fn,
    List<ServerQuery<Object?, Object?>> Function(ThorState state)? invalidates,
    Duration? timeout,
    bool writes,
  ) : super._(fn, invalidates, timeout, writes, ArgCodec<A>());

  @override
  bool get hasArg => true;

  /// Calls the function on the server with [arg] (in the browser): queued,
  /// in order, and the future completes with the result (null when it
  /// failed). See [ServerCommand.run].
  ///
  /// ```dart
  /// Future<void> buy(String sku) async {
  ///   final units = await add.run(sku);
  ///   if (units != null) highlight.value = sku;
  /// }
  /// ```
  Future<R?> run(A arg) async => null;

  /// Whether a `run` of exactly [arg] is waiting or on its way (browser
  /// only): a row's own spinner while another row's change is not
  /// `pending` for it. Reactive in a state method.
  bool pendingFor(A arg) => false;

  @override
  Function get _run => run;

  @override
  Object? _runFromPage(String? a) {
    unawaited(run(_parse(a)));
    return null;
  }

  A _parse(String? a) {
    if (a == null || (a.isEmpty && null is A)) return null as A;
    if (_holds(<num>[])) return num.parse(a) as A;
    if (_holds(<int>[])) return int.parse(a) as A;
    if (_holds(<double>[])) return double.parse(a) as A;
    if (_holds(<bool>[])) return (a == 'true') as A;
    return a as A;
  }

  // Whether an A can hold the items of [list] (`<int>[]`: A is int, num…).
  bool _holds(Object list) => list is List<A>;
}

/// A change made on the server: `final clear = command(cart.clear);`.
///
/// [fn] runs on the server only, when the browser calls `clear.run` (a
/// button: `onPressed: cartState.clear.run`), never while the page draws.
/// It may use any package. It goes through the middleware of the page that
/// asks, like a form action, and reads the request with
/// `PageRequest.current`. When it succeeds the server runs the page's
/// queries (`query`) again and their new values come back in the same
/// answer. The result travels as JSON like a query's (THOR-B021); `void`
/// is fine.
///
/// [invalidates] names the queries of the state this command changes: only
/// those are asked again (and only if the browser has them on the page).
/// Without it, every query the browser has on the page is asked again.
/// [timeout] (a `Duration` of literals) ends a call that doesn't answer in
/// an error, and the next queued `run` goes.
///
/// [writes] is true by default: the page cache and the browser's
/// prefetches are cleared after the call, like a form action. Pass false for
/// a read the visitor asks for (load more): the page cache and the browser's
/// prefetches are kept, and the invalidated queries still refresh.
///
/// ```dart
/// final clear = command(cart.clear, invalidates: (CartState s) => [s.lines]);
/// ```
ServerCommand<R> command<R, S extends ThorState>(
  FutureOr<R> Function() fn, {
  List<ServerQuery<Object?, Object?>> Function(S state)? invalidates,
  Duration? timeout,
  bool writes = true,
}) => ServerCommand._(fn, _erase(invalidates), timeout, writes);

/// [command] with an argument: `final add = commandWith(cart.add);` and
/// `onPressed: cartState.add.run.withArg(sku)`. The argument is a simple
/// value (`int`, `double`, `num`, `String`, `bool`), a record of them or a
/// class of the app with `toJson()` and a `fromJson` factory, as in
/// [queryWith] (THOR-B021); the server checks it before [fn] runs.
///
/// [invalidates] is the same as in [command]: `commandWith(cart.add,
/// invalidates: (CartState s) => [s.lines, s.total])`. The parameter's type
/// is the state that declares the command; the queries it names may belong
/// to it or to any other state. [timeout] and [writes] are the same as in
/// [command]: `commandWith(store.nextPage, writes: false)` for a load more.
ServerCommandWith<A, R> commandWith<A, R, S extends ThorState>(
  FutureOr<R> Function(A arg) fn, {
  List<ServerQuery<Object?, Object?>> Function(S state)? invalidates,
  Duration? timeout,
  bool writes = true,
}) => ServerCommandWith._(fn, _erase(invalidates), timeout, writes);

List<ServerQuery<Object?, Object?>> Function(ThorState)?
_erase<S extends ThorState>(
  List<ServerQuery<Object?, Object?>> Function(S state)? invalidates,
) => invalidates == null ? null : (state) => invalidates(state as S);
