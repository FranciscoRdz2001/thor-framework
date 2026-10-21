/// Screen state as a class (like a `ChangeNotifier` or a Cubit): reactive
/// fields made with `state(...)`, and plain methods. Widgets reference
/// the methods by tear-off (`onPressed: counter.inc`, `Watch(counter.label)`)
/// and thor wires them to the page: the server writes each one's stable id
/// (`CounterState.inc`) into the HTML and the browser finds the method by it.
///
/// ```dart
/// class CounterState extends ThorState {
///   final count = state(0);
///
///   String label() => '${count.value}';
///   bool isZero() => count.value == 0;
///
///   void inc() => count.value++;
///   void reset() => count.value = 0;
/// }
///
/// final counter = CounterState();
/// ```
///
/// Dart can't list a class's members while it runs (no reflection in an
/// AOT server or in dart2js), so `thor_builder` writes that list: one
/// [ThorStateType] per class, registered with [ThorState.register] from the
/// entries thor generates in `.dart_tool/thor/` — never from the app's own
/// files. The names it
/// writes are the ids the page carries, so they survive minification.
library;

import 'dart:convert' show JsonUnsupportedObjectError, jsonEncode;

import 'command.dart';
import 'controllers.dart';
import 'listeners.dart';
import 'notifier.dart';
import 'protocol.dart'
    show keyToken, persistedStateCookiePrefix, templateIntKey;
import 'query.dart';
import 'reactive.dart';

/// A reactive field of a [ThorState] (see [state]). The server
/// writes its value into the page and the browser starts from it.
///
/// It is a Flutter [ValueNotifier]: `value`, [addListener] and
/// [removeListener] work as in Flutter, and `ValueListenableBuilder` takes
/// it. `// web:` a listener runs when the value changes in the browser, in
/// a lite state at the end of the batch that wrote it (like every effect);
/// on the server, where a page is built once, nothing changes and nothing
/// is notified.
final class StateSignal<T> extends Signal<T> implements ValueNotifier<T> {
  StateSignal._(
    super.value,
    this._encode,
    this._decode,
    this.cookie, [
    this.local,
    this.localScope,
  ]) : _initial = value;

  /// The cookie this field persists in (`thor-s.<cookie>`), or null: the
  /// engine writes it when the value changes and the server draws the page
  /// with it (see [state]).
  final String? cookie;

  /// The `localStorage` key this field persists in (`thor-s.<local>`), or
  /// null: the engine writes it when the value changes and applies it when
  /// the state starts in the browser; the server never sees it (see
  /// [state]).
  final String? local;

  /// The field whose value names the instance of [local]: the storage key is
  /// `thor-s.<local>:<scope value>` (see [state]).
  final StateSignal<String>? localScope;

  /// The `localStorage` key this field reads and writes, without the
  /// `thor-s.` prefix: [local], plus `:` and the value of [localScope] when
  /// there is one. Null when the field is not persisted there, or its scope
  /// is empty or longer than [maxLocalScopeLength] (it then lives in memory,
  /// as with blocked storage).
  String? get localKey {
    final base = local;
    final scope = localScope;
    if (base == null || scope == null) return base;
    final value = scope.value;
    if (value.isEmpty || value.length > maxLocalScopeLength) return null;
    return '$base:$value';
  }

  /// The longest [localScope] value used in a storage key.
  static const maxLocalScopeLength = 100;

  /// The longest cookie value read back (longer ones are ignored).
  static const maxCookieLength = 2048;

  @override
  T peek() {
    // First read in a request: the value the browser persisted, if valid.
    if (cookie case final name?
        when SignalScope.isActive && !SignalScope.holds(this)) {
      final (found, persisted) = _persisted(name);
      value = found ? persisted as T : _initial;
    }
    return super.peek();
  }

  (bool, T?) _persisted(String name) {
    final (cookies, read) = SignalScope.cookies ?? (null, null);
    final raw = cookies?['$persistedStateCookiePrefix$name'];
    if (raw == null || read == null || raw.length > maxCookieLength) {
      return (false, null);
    }
    try {
      return (true, fromJson(read(raw)));
      // A cookie is the visitor's to write: a value of another type or
      // shape is ignored, never an error of the page.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      return (false, null);
    }
  }

  // The value the code starts with: the browser starts there too, so the
  // page only carries fields the server changed.
  final T _initial;

  /// Whether the value differs from the one in the code.
  bool get changed => peek() != _initial;

  final Object? Function(T value)? _encode;
  final T Function(Object? json)? _decode;

  /// The value, like `signal.value`.
  T call() => value;

  Listeners? _listeners = Listeners();

  @override
  set value(T next) {
    // In a request's scope nothing listens (and `peek` sets the persisted
    // value through here).
    if (SignalScope.isActive) {
      super.value = next;
      return;
    }
    final before = peek();
    super.value = next;
    if (before != next) notifyListeners();
  }

  @override
  bool get hasListeners => _listeners?.isNotEmpty ?? false;

  /// Calls [listener] on every change. Throws [StateError] after [dispose]
  /// (Flutter asserts; a lite state throws in release too).
  @override
  void addListener(void Function() listener) {
    final all = _listeners;
    if (all == null) {
      throw StateError(
        'A StateSignal was used after dispose(): its state is gone.',
      );
    }
    all.add(listener);
  }

  @override
  void removeListener(void Function() listener) => _listeners?.remove(listener);

  /// Calls the listeners, in the order they were added; one removed by an
  /// earlier listener is skipped, one that throws is reported (as in Flutter).
  @override
  void notifyListeners() => _listeners?.notify();

  /// Drops the listeners; a later [addListener] throws.
  @override
  void dispose() => _listeners = null;

  @override
  String toString() => 'StateSignal<$T>(${peek()})';

  /// The value as JSON-compatible data, or null if it has no encoding.
  Object? toJson() {
    final v = peek();
    if (_encode != null) return _encode(v);
    // A set field (`state(<String>{})`) has no JSON of its own: a list, in
    // insertion order. Only when the field is declared a set: an `Object?`
    // field holding one would come back a list.
    if (v is Set && <T>[] is List<Set<Object?>>) return v.toList();
    return _models.isEmpty ? v : _encodeModels(v);
  }

  /// Writes [json] (from [toJson]) back.
  void restoreJson(Object? json) {
    value = fromJson(json);
  }

  /// Back to where a new state starts: the value [json] says (what the
  /// server wrote for the field) when [fromServer], else the one in the
  /// code. A persisted field (`cookie:`, `local:`) keeps what it has: its
  /// cookie or its stored value says where it starts.
  void startOver({bool fromServer = false, Object? json}) {
    if (cookie != null || local != null) return;
    value = fromServer ? fromJson(json) : _initial;
  }

  /// The value [json] (from [toJson]) stands for; throws when it isn't one.
  T fromJson(Object? json) => _decode != null ? _decode(json) : _typed(json);

  // Decoded JSON lists and maps are `List<dynamic>` / `Map<String,
  // dynamic>`: give them the field's element type (`List<String>`…).
  T _typed(Object? json) {
    if (json is T) return json;
    if (json is List) {
      // A set field (`state(<String>{})`) comes back as a list.
      if (<String>{} is T) return Set<String>.from(json) as T;
      if (<int>{} is T) return Set<int>.from(json) as T;
      if (<double>{} is T) {
        return {for (final v in json) (v as num).toDouble()} as T;
      }
      if (<num>{} is T) return Set<num>.from(json) as T;
      if (<bool>{} is T) return Set<bool>.from(json) as T;
      if (<String>[] is T) return List<String>.from(json) as T;
      if (<int>[] is T) return List<int>.from(json) as T;
      if (<double>[] is T) {
        return [for (final v in json) (v as num).toDouble()] as T;
      }
      if (<num>[] is T) return List<num>.from(json) as T;
      if (<bool>[] is T) return List<bool>.from(json) as T;
    }
    for (final model in _models.values) {
      if (model.read<T>(json) case (true, final value)) return value as T;
    }
    if (json is Map) {
      if (<String, String>{} is T) return Map<String, String>.from(json) as T;
      if (<String, int>{} is T) return Map<String, int>.from(json) as T;
      if (<String, bool>{} is T) return Map<String, bool>.from(json) as T;
      if (<String, num>{} is T) return Map<String, num>.from(json) as T;
    }
    return json as T;
  }
}

final _models = <Type, _JsonModel<Object>>{};

/// Teaches the engine to read and write a class of the app as JSON, so a
/// `state<List<Order>>(...)` (or `state<Order>`, `state<Map<String, Order>>`)
/// needs no `encode:`/`decode:`: the class has `toJson()` and a
/// `factory fromJson(Map<String, Object?> json)`, like a query's result does.
///
/// The build writes the call for every such class a `state(...)` field
/// holds (`registerThorStates()`); an app never makes it. A test of a state
/// class run without the build can register its classes by hand.
void registerJsonModel<M extends Object>(
  M Function(Map<String, Object?> json) fromJson,
  Object? Function(M model) toJson,
) {
  _models[M] = _JsonModel<M>(fromJson, toJson);
}

/// Forgets the registered classes (tests).
void clearJsonModels() => _models.clear();

final class _JsonModel<M extends Object> implements _AnyJsonModel {
  const _JsonModel(this._from, this._to);

  final M Function(Map<String, Object?> json) _from;
  final Object? Function(M model) _to;

  M _one(Object? json) => _from(Map<String, Object?>.from(json! as Map));

  @override
  bool matches(Object? v) => v is M;

  @override
  Object? encode(Object? v) => _to(v! as M);

  /// `(true, value)` when [json] is a [T] made of this class (the class,
  /// a list or a String-keyed map of it, or null for a nullable one).
  (bool, Object?) read<T>(Object? json) {
    if (json == null) return (null is T && <T>[] is List<M?>, null);
    if (json is Map && <T>[] is List<M?>) return (true, _one(json));
    if (json is List && <T>[] is List<List<M>?>) {
      return (true, <M>[for (final e in json) _one(e)]);
    }
    if (json is Map && <T>[] is List<Map<String, M>?>) {
      return (
        true,
        <String, M>{for (final e in json.entries) '${e.key}': _one(e.value)},
      );
    }
    return (false, null);
  }
}

abstract interface class _AnyJsonModel {
  bool matches(Object? v);
  Object? encode(Object? v);
}

/// [v] with every registered class written as its `toJson()`, inside lists
/// and String-keyed maps.
Object? _encodeModels(Object? v) {
  if (v == null || v is num || v is String || v is bool) return v;
  for (final m in _models.values) {
    if (m.matches(v)) return m.encode(v);
  }
  if (v is List) return [for (final e in v) _encodeModels(e)];
  if (v is Map) {
    return {for (final e in v.entries) e.key: _encodeModels(e.value)};
  }
  return v;
}

/// `StateSignal<bool>.toggle()`: `open.toggle()` instead of
/// `open.value = !open.value`.
extension StateBoolToggle on StateSignal<bool> {
  /// Flips the value.
  void toggle() => value = !value;
}

/// A set field (`final picked = state(<String>{});`) with the operations a
/// selection needs. `// web:` a set changes by a new value, like a list
/// (`todos.value = [...]`): `add`, `remove`, `toggle` and `clear` assign a
/// new set, so `Watch`, `row.watch` and listeners notice, and one already
/// read is never mutated. A change that changes nothing (`add` of a member)
/// assigns nothing. The value stays immutable: nothing is changed in place.
extension StateSetOps<T> on StateSignal<Set<T>> {
  /// Whether [element] is in the set, tracked.
  bool contains(T element) => value.contains(element);

  /// How many elements it has, tracked.
  int get length => value.length;

  /// Whether it is empty, tracked.
  bool get isEmpty => value.isEmpty;

  /// Whether it has any element, tracked.
  bool get isNotEmpty => value.isNotEmpty;

  /// Adds [element] (nothing happens if it is there).
  void add(T element) {
    if (!value.contains(element)) value = {...value, element};
  }

  /// Removes [element] (nothing happens if it is not there).
  void remove(T element) {
    if (value.contains(element)) value = {...value}..remove(element);
  }

  /// Adds [element] if it is not there, removes it if it is.
  void toggle(T element) {
    if (value.contains(element)) {
      remove(element);
    } else {
      add(element);
    }
  }

  /// Empties the set.
  void clear() {
    if (value.isNotEmpty) value = <T>{};
  }
}

/// A reactive field of a [ThorState]: `final count = state(0);`. Values
/// that are not JSON (numbers, strings, bools, lists and maps of them) need
/// [encode] and [decode] to travel from the server to the page.
///
/// With [cookie] the field persists in the browser (a sidebar collapsed, a
/// band folded): the engine writes the cookie `thor-s.<cookie>` when the
/// value changes, and the server draws the next page with it, so a reload
/// shows it without a flash. A static site (no server) applies it when the
/// engine starts. The cookie is the visitor's to write: keep it to how the
/// page looks, never to what they may do; a value that doesn't decode to
/// the field's type is ignored. [cookie] is 1–40 letters, digits, `_` or
/// `-` (THOR-S009).
///
/// With [local] the field persists in the browser's `localStorage` (key
/// `thor-s.<local>`) instead: a draft, a filter, a preference too big for a
/// cookie or that the server has no use for. The server never sees it and
/// draws the page with the value in the code; the engine applies the stored
/// one when the state starts, so the default can show for a frame (a value
/// the first paint depends on belongs in a [cookie]). Other tabs of the
/// site follow a change (the `storage` event), and where storage is blocked
/// (a private window, a sandboxed frame) the value lives in memory for the
/// page, without an error. The same name rule and the same caution: the
/// value is the visitor's to write. A field persists in one place: [cookie]
/// or [local], not both (THOR-S009).
///
/// [localScope] makes one `local:` field many: a field holding a value the
/// server wrote for the page (`final store = state('')`, set to the store's
/// slug while the page is built) names the instance, and the storage key is
/// `thor-s.<local>:<value>`. The cart of each store, the draft of each
/// document:
///
/// ```dart
/// final store = state('');
/// late final cart = state(<String>[], local: 'cart', localScope: store);
/// ```
///
/// The value is read when the state starts in the browser, so a page of
/// another store starts the field from another key; one that is empty (or
/// longer than 100 characters) keeps the field in memory for the page. The
/// scope must be a field of the same state, declared before it; it needs
/// [local].
///
/// `// web:` not in Flutter's `shared_preferences`, where the key is a
/// string built at runtime; a lite state is compiled ahead of time, so the
/// key is the literal plus a field the page fills.
StateSignal<T> state<T>(
  T initial, {
  Object? Function(T value)? encode,
  T Function(Object? json)? decode,
  String? cookie,
  String? local,
  StateSignal<String>? localScope,
}) {
  // web: Flutter's shared_preferences is async; the browser's localStorage
  // is read synchronously, so the stored value is there when the state
  // starts (one storage for the whole site, like a cookie with `path=/`).
  if (cookie != null && !_cookieName(cookie)) {
    throw ArgumentError.value(
      cookie,
      'cookie',
      'A persisted state cookie is 1–40 letters, digits, _ or - (THOR-S009)',
    );
  }
  if (local != null && !_cookieName(local)) {
    throw ArgumentError.value(
      local,
      'local',
      'A persisted state key is 1–40 letters, digits, _ or - (THOR-S009)',
    );
  }
  if (cookie != null && local != null) {
    throw ArgumentError.value(
      local,
      'local',
      'A field persists in a cookie or in localStorage, not both (THOR-S009)',
    );
  }
  if (localScope != null && local == null) {
    throw ArgumentError.value(
      localScope,
      'localScope',
      'localScope names the instance of a local: field; give local: too',
    );
  }
  return StateSignal._(initial, encode, decode, cookie, local, localScope);
}

/// A value computed from other fields and kept: `late final visible =
/// derived(() => rows.value.where(...).toList());`, read as
/// `visible.value` (or `Watch(visible.call, …)`, `Watch.list(visible.call,
/// …)`). The function runs once per change of the fields it reads, however
/// many `Watch`es or methods read the result, and not at all while they
/// don't change; a method that computes the same list in each `Watch` runs
/// it in each one.
///
/// The function only reads: writing a field in it is THOR-B035. A list or
/// map it returns counts as changed every time it runs (compared by
/// identity, as everywhere in thor).
///
/// `// web:` in the browser it is the engine's computed signal (lazy, and
/// disposed with its state in the lite engine); on the server and in the VM
/// it runs on the first read and is kept until a field is written (a page
/// is built once, so that is once per page).
ReadSignal<T> derived<T>(T Function() compute) => Computed<T>.scoped(compute);

bool _cookieName(String name) {
  if (name.isEmpty || name.length > 40) return false;
  for (final c in name.codeUnits) {
    final ok =
        (c >= 0x30 && c <= 0x39) ||
        (c >= 0x41 && c <= 0x5A) ||
        (c >= 0x61 && c <= 0x7A) ||
        c == 0x5F ||
        c == 0x2D;
    if (!ok) return false;
  }
  return true;
}

/// How a member of a [ThorState] can be used on a page. Generated.
final class ThorMember {
  /// Describes the method or field [name], torn off as [function].
  const ThorMember(
    this.name,
    this.function, {
    this.call,
    this.callWithItem,
    this.callWithArgAndItem,
    this.variants,
    this.signal,
    this.arity = 0,
  }) : query = null,
       command = null;

  /// A reactive field. [variants] makes it a finite state for
  /// `Watch(…, builder:)` (a query's `loading`).
  ThorMember.state(this.name, StateSignal<Object?> this.signal, {this.variants})
    : function = signal.call,
      call = ((_) => signal.value),
      callWithItem = null,
      callWithArgAndItem = null,
      query = null,
      command = null,
      arity = 0;

  /// A [ServerQuery] field: the server finds it by id to answer the
  /// browser. Its signals and `refresh` are members of their own (see
  /// [ServerQuery.members]).
  ThorMember.query(this.name, ServerQuery<Object?, Object?> this.query)
    : function = null,
      call = null,
      callWithItem = null,
      callWithArgAndItem = null,
      variants = null,
      signal = null,
      command = null,
      arity = 0;

  /// A [ServerCommand] or [ServerCommandWith] field: the server finds it by
  /// id to answer the browser. Its signals and `run` are members of their
  /// own (see [ServerCommandBase.members]).
  ThorMember.command(
    this.name,
    ServerCommandBase<Object?, Object?> this.command,
  ) : function = null,
      call = null,
      callWithItem = null,
      callWithArgAndItem = null,
      variants = null,
      signal = null,
      query = null,
      arity = 0;

  /// A field holding a [ThorController] (an `AnimationController`, a
  /// [ScrollController], a [TextEditingController], a [FocusNode]): the
  /// engine finds it by id and connects the elements that use it.
  /// [function] is null (there is nothing to match a callback against) and
  /// [call] returns the controller.
  ThorMember.controller(this.name, ThorController controller)
    : function = null,
      call = ((_) => controller),
      callWithItem = null,
      callWithArgAndItem = null,
      variants = null,
      signal = null,
      query = null,
      command = null,
      arity = 0;

  /// The member's name in its class (part of its id).
  final String name;

  /// The tear-off the server matches widgets' callbacks against.
  final Function? function;

  /// Runs the member with an argument from the page (`data-tx`), parsed to
  /// the method's parameter type; null argument for methods without one.
  final Object? Function(String? arg)? call;

  /// Runs a method whose parameter is a list item (row fields and keys).
  final Object? Function(Object? item)? callWithItem;

  /// Runs a method whose first parameter is fixed with `withArg` (its
  /// value from the page, `arg`) and whose second is a list item:
  /// `String cellLabel(int column, Row row)` used as
  /// `row.text(grid.cellLabel.withArg(3))`.
  final Object? Function(String arg, Object? item)? callWithArgAndItem;

  /// The value of this item method for [item], with the fixed argument
  /// [arg] of a `withArg` binding (null: none).
  Object? callItem(Object? item, [String? arg]) =>
      arg == null ? callWithItem!(item) : callWithArgAndItem!(arg, item);

  /// The finite values a variant source can return (`bool` → `[false,
  /// true]`, an enum → its values), in variant order.
  final List<Object?>? variants;

  /// The field's signal (reactive fields only).
  final StateSignal<Object?>? signal;

  /// The query (a [ServerQuery] field only).
  final ServerQuery<Object?, Object?>? query;

  /// The command (a [ServerCommand] or [ServerCommandWith] field only).
  final ServerCommandBase<Object?, Object?>? command;

  /// Number of parameters of the method (0 to 3).
  final int arity;
}

/// What the builder knows about a [ThorState] class: its [name] (the id
/// prefix, which survives minification) and its [members] for an instance.
/// Generated, registered with [ThorState.register].
final class ThorStateType {
  /// The class [name], how to list an instance's [members] and the names
  /// of its `query`/`command` fields ([calls]).
  const ThorStateType(
    this.name,
    this.members, {
    this.calls,
    this.uses = const {},
    this.disposes = false,
  });

  /// The class name as written in the source.
  final String name;

  /// The members of an instance of the class.
  final List<ThorMember> Function(ThorState state) members;

  /// The names of the fields the browser calls on the server (`query`,
  /// `queryWith`, `command`, `commandWith`), from the build: the server
  /// answers no other id, like a server function missing from a build
  /// manifest. Null when the registry doesn't list them (any id may be
  /// one).
  final Set<String>? calls;

  /// The page features the class's code needs markup for: `confirm` and
  /// `toast` (calls in the file that declares it), so a page that uses the
  /// state ships the shared dialog or snack bar and no other page does.
  final Set<String> uses;

  /// Whether the class overrides [ThorState.dispose]: only those states
  /// live as long as the page names them (the generated registry says it;
  /// the others end with the page).
  final bool disposes;
}

/// Base of every screen state: `class CartState extends ThorState`.
abstract class ThorState {
  /// Creates the state. With [key], several instances of one class can live
  /// on the same page (`CounterState(key: 'left')`).
  ThorState({this.key}) {
    _all.add(this);
  }

  /// Distinguishes instances of the same class on one page.
  final String? key;

  /// Runs once when the state wakes in the browser: Flutter's `initState`.
  /// Start a `Timer`, a listener or a subscription here and stop it in
  /// [dispose].
  ///
  /// `// web:` the server never calls it (a page is built once). In the lite
  /// engine a state that overrides it wakes at idle after the page loads, on
  /// the pages whose elements name it (or on every page if it is [global]; a
  /// state without it stays lazy until its first event); with dart2js every
  /// state wakes when the page starts. A throw is reported to the console
  /// and the state keeps working. Writes to fields inside it paint once.
  void onHydrated() {}

  /// Whether the state wakes on every page. By default a state that
  /// overrides [onHydrated] wakes only on a page whose elements name it (a
  /// page that doesn't use it starts no timer and asks for no query); return
  /// `true` for one that must run app-wide. The builder reads it as a
  /// literal: `@override bool get global => true;`.
  ///
  /// `// web:` Flutter keeps a state alive app-wide by holding it above the
  /// route (a provider at the root); the browser loads one page at a time,
  /// so a state lives where the page names it, or everywhere with this.
  bool get global => false;

  /// Runs once when the state ends: Flutter's `State.dispose`. Stop what
  /// [onHydrated] started.
  ///
  /// `// web:` in the lite engine a state that overrides it lives as long
  /// as elements of the page name it: when the last one leaves (a keyed row
  /// removed, a variant replaced for good) or the page is unloaded (not
  /// when the browser keeps it for the back button), it runs once, the
  /// effects the state made stop, and the same id in the page later is a
  /// new instance. With dart2js (`LifecycleFeature`, which the build adds
  /// for a state that overrides it) it runs when the page stops naming the
  /// state or is unloaded, and the effects its `onHydrated` made stop; the
  /// object stays, so when the page names it later its `state(...)` fields
  /// start from the server's values and `onHydrated` runs again, but its
  /// plain fields keep theirs.
  void dispose() {}

  static final List<ThorState> _all = [];

  /// Every state created so far (the server resolves callbacks among them).
  static List<ThorState> get all => _all;

  static final Map<Type, ThorStateType> _types = {};

  /// Registers the app's state classes (generated code calls it; an app
  /// never does). Registering a class again replaces it: a hot reload
  /// registers the new members, and the instances made before it (a
  /// top-level state lives across a reload) list them from then on.
  static void register(Map<Type, ThorStateType> types) {
    _types.addAll(types);
    _registry++;
  }

  /// Bumped by every [register]: the instances' member lists made before
  /// are stale.
  static var _registry = 0;

  /// Whether [type] was registered.
  static bool isRegistered(Type type) => _types.containsKey(type);

  /// Whether [id] (`CartState.add`, `CartState#left.add`) may name a query
  /// or a command of a registered class: false when no registered class
  /// has that name, or the ones that do list their calls and the field is
  /// not among them. Before any registry, true (nothing to check against).
  static bool declaresCall(String id) {
    if (_types.isEmpty) return true;
    final dot = id.lastIndexOf('.');
    if (dot <= 0) return false;
    final hash = id.indexOf('#');
    final name = id.substring(0, hash < 0 || hash > dot ? dot : hash);
    final field = id.substring(dot + 1);
    for (final t in _types.values) {
      if (t.name != name) continue;
      final calls = t.calls;
      if (calls == null || calls.contains(field)) return true;
    }
    return false;
  }

  ThorStateType get _registered =>
      _types[runtimeType] ??
      (throw StateError(
        '$runtimeType is not registered: its members (the names the page '
        'uses) come from code generation, which only thor runs. Run the '
        'tests with `thor test` instead of `dart test` (same arguments: '
        '`thor test test/x_test.dart -n name`), and the app with `thor dev` '
        '(or `thor build`, `thor preview`) instead of `dart run '
        'bin/server.dart` (THOR-S010)',
      ));

  /// The class name, from the generated registry.
  String get $type => _registered.name;

  /// The page features this state's code needs markup for (`confirm`,
  /// `toast`); see [ThorStateType.uses]. Empty for an unregistered class.
  Set<String> get uses => _types[runtimeType]?.uses ?? const {};

  /// Whether this state's class overrides [dispose], from the generated
  /// registry. True for a class that is not registered (nothing says it
  /// does not).
  bool get disposes => _types[runtimeType]?.disposes ?? true;

  /// The members, from the generated registry.
  List<ThorMember> get $members => _registered.members(this);

  /// The [$members] as of registry [_listedAt] (listing them is not free,
  /// and the server asks on every callback).
  List<ThorMember>? _listed;
  int _listedAt = -1;

  List<ThorMember> get _members {
    if (_listedAt != _registry) {
      _listed = $members;
      _listedAt = _registry;
      _byFunctionOf = null;
    }
    return _listed!;
  }

  /// Id prefix of this instance's members: `CounterState` or
  /// `CounterState#left`. The key goes escaped ([escapeIdKey]) so a `~`
  /// in it can't be taken for the start of an argument (`Row#a%7Eb.label`)
  /// nor a `;` for the end of a handler (`data-t-on`);
  /// the page and the server use this same text everywhere.
  String get idPrefix => key == null ? $type : '${$type}#${escapeIdKey(key!)}';

  /// The members of this instance.
  List<ThorMember> get members => _members;

  /// The id (`CardState.reveal`) of [controller] if a field of a state
  /// holds it (see [ThorMember.controller]), with that state.
  static (ThorState, String)? controllerId(ThorController controller) {
    for (final s in _all) {
      for (final m in s.members) {
        if (m.function == null &&
            m.call != null &&
            identical(m.call!(null), controller)) {
          return (s, '${s.idPrefix}.${m.name}');
        }
      }
    }
    return null;
  }

  /// The member of this state whose tear-off is [function], if any.
  ///
  /// A lookup, not a scan: the server asks for every callback of every
  /// element (a grid's rows ask thousands of times per page), and tear-offs
  /// of one method of one object are equal with equal hash codes.
  ThorMember? memberOf(Function function) => _byFunction[function];

  Map<Function, ThorMember>? _byFunctionOf;

  Map<Function, ThorMember> get _byFunction {
    final members = _members;
    return _byFunctionOf ??= {
      // The first member with a tear-off wins, as a scan would find.
      for (final m in members.reversed) ?m.function: m,
    };
  }

  /// Finds [function] among the members of every state: the state and the
  /// member, or null for any other function (a closure, a plain callback).
  static (ThorState, ThorMember)? resolve(Function function) {
    for (final s in _all) {
      final m = s.memberOf(function);
      if (m != null) return (s, m);
    }
    return null;
  }
}

/// A member torn off with an argument: `cart.add.withArg(3)`.
final class BoundCall {
  BoundCall._(this.function, this.arg);

  /// The member's tear-off.
  final Function function;

  /// The argument (a number, string, bool or enum value).
  final Object? arg;

  static final _bound = Expando<BoundCall>('thor.withArg');

  /// The binding behind [f], if [f] came from `withArg`.
  static BoundCall? of(Function f) => _bound[f];
}

/// `onPressed: cart.add.withArg(index)` or
/// `Watch(cart.isSelected.withArg(i), builder: …)`: a one-parameter method
/// with a fixed argument. The server writes the argument into the page; the
/// browser parses it back to the parameter's type.
extension WithArg<A, R> on R Function(A) {
  /// This method, called with [arg].
  R Function() withArg(A arg) {
    R f() => this(arg);
    BoundCall._bound[f] = BoundCall._(this, arg);
    return f;
  }
}

/// `FilterChip(onSelected: content.setChip.withArg(i))`: a two-parameter
/// method with its first argument fixed; the widget or the control gives
/// the second (`void setChip(int i, bool selected)`).
extension WithFirstArg<A, B, R> on R Function(A, B) {
  /// This method with its first argument fixed to [arg].
  R Function(B value) withArg(A arg) {
    R f(B value) => this(arg, value);
    BoundCall._bound[f] = BoundCall._(this, arg);
    return f;
  }
}

/// The [count] parts of a multi-argument value from the page
/// (`<first>~<second>…`, see `bindingId`). The last part keeps any `~` of
/// its own (a text typed by the user) as it is; the others come back from
/// their escapes ([escapeArgPart]); missing parts are empty.
List<String> splitArgs(String? arg, int count) {
  var rest = arg ?? '';
  final parts = <String>[];
  for (var i = 0; i < count - 1; i++) {
    final at = rest.indexOf('~');
    if (at < 0) {
      parts.add(unescapeArgPart(rest));
      rest = '';
    } else {
      parts.add(unescapeArgPart(rest.substring(0, at)));
      rest = rest.substring(at + 1);
    }
  }
  return parts..add(rest);
}

/// [key] as it goes in an id (`Row#a%7Eb%3Bc.label`): [escapeArgPart]'s `%`
/// and `~`, and `;`, which separates the ids of `data-t-on` and its kin.
String escapeIdKey(String key) => escapeArgPart(key).replaceAll(';', '%3B');

/// [part] as a non-last part of a multi-argument value: `%` is `%25` and
/// `~` is `%7E`, so no text can move the separator.
String escapeArgPart(String part) {
  if (!part.contains('~') && !part.contains('%')) return part;
  final out = StringBuffer();
  for (final unit in part.runes) {
    out.write(switch (unit) {
      0x25 => '%25',
      0x7E => '%7E',
      _ => String.fromCharCode(unit),
    });
  }
  return '$out';
}

/// [value] (an attribute of a row template) with the row's [key] in place of
/// [keyToken]. A key followed by `~` is a non-last part of a multi-argument
/// value (`row.key` bound with `bind(row.key, x)`), and one in the id of a
/// keyed state (`Row#{{key}}.label`) is part of an id: both go escaped, like
/// the server escapes the keys of the rows it draws; any other stays as it is.
/// [id] is whether [value] is a protocol attribute (`data-t*`, where ids
/// live); in any other (an `href="#{{key}}.notes"`) the `#` form is text.
String fillKey(String value, String key, {bool id = true}) =>
    value.replaceAllMapped(
      RegExp(
        '${id ? '#${RegExp.escape(keyToken)}(?=\\.[A-Za-z_\$])|' : ''}'
        '${RegExp.escape(keyToken)}(~)?',
      ),
      (m) => m[0]!.startsWith('#')
          ? '#${escapeIdKey(key)}'
          : m[1] == null
          ? key
          : '${escapeArgPart(key)}~',
    );

/// What [escapeArgPart] made [part] from (any other `%` stays).
String unescapeArgPart(String part) {
  if (!part.contains('%')) return part;
  final out = StringBuffer();
  var i = 0;
  while (i < part.length) {
    if (part.startsWith('%25', i)) {
      out.write('%');
      i += 3;
    } else if (part.startsWith('%7E', i)) {
      out.write('~');
      i += 3;
    } else {
      out.write(part[i++]);
    }
  }
  return '$out';
}

/// The value of several arguments (`withArgs(a, b)`, a page action's
/// `bind(a, b)`): each one as [encodeArg] writes it, every part but the last
/// escaped, joined by `~` (what [splitArgs] takes apart). One argument is
/// just its text.
String encodeArgs(List<Object?> args) {
  if (args.length == 1) return encodeArg(args.single);
  return [
    for (var i = 0; i < args.length; i++)
      i == args.length - 1
          ? encodeArg(args[i])
          : escapeArgPart(encodeArg(args[i])),
  ].join('~');
}

/// All the arguments of a `withArgs` binding: [BoundCall.arg] holds it, and
/// [encodeArg] writes it as [encodeArgs].
final class MultiArgs {
  /// The arguments, in order.
  const MultiArgs(this.values);

  /// The arguments.
  final List<Object?> values;
}

/// [arg] as the page writes a binding's fixed value into `data-tx`: a
/// [MultiArgs] as [encodeArgs]; with [splits] (the method takes several
/// parameters and the browser splits the value with [splitArgs]) a single
/// fixed argument is the first part, so its `~` and `%` are escaped.
String encodeFixedArg(Object? arg, {bool splits = false}) => arg is MultiArgs
    ? encodeArgs(arg.values)
    : splits
    ? escapeArgPart(encodeArg(arg))
    : encodeArg(arg);

/// `Gesture(onDragEnd: board.moved.withArg(id))`: a three-parameter method
/// with its first argument fixed; the gesture gives the other two
/// (`void moved(int id, double dx, double dy)`).
extension WithFirstOfThreeArgs<A, B, C, R> on R Function(A, B, C) {
  /// This method with its first argument fixed to [arg].
  R Function(B b, C c) withArg(A arg) {
    R f(B b, C c) => this(arg, b, c);
    BoundCall._bound[f] = BoundCall._(this, arg);
    return f;
  }
}

/// `onPressed: grid.cell.withArgs(row.id, 'name')`: a two-parameter method
/// with both arguments fixed. The values keep their types (`int`, `bool`,
/// an enum, `String`…): the page writes them as text and the browser parses
/// each back to its parameter's type.
extension WithBothArgs<A, B, R> on R Function(A, B) {
  /// This method, called with [a] and [b].
  R Function() withArgs(A a, B b) {
    R f() => this(a, b);
    BoundCall._bound[f] = BoundCall._(this, MultiArgs([a, b]));
    return f;
  }
}

/// `onPressed: board.move.withArgs(id, Column.done, true)`: a
/// three-parameter method with every argument fixed.
extension WithThreeArgs<A, B, C, R> on R Function(A, B, C) {
  /// This method, called with [a], [b] and [c].
  R Function() withArgs(A a, B b, C c) {
    R f() => this(a, b, c);
    BoundCall._bound[f] = BoundCall._(this, MultiArgs([a, b, c]));
    return f;
  }
}

/// The text form of an argument written into the page (enum → its name).
String encodeArg(Object? arg) => switch (arg) {
  null => '',
  final Enum e => e.name,
  final MultiArgs m => encodeArgs(m.values),
  // A typed row key inside a list's row template.
  final int i when i == templateIntKey => keyToken,
  _ => '$arg',
};

/// Makes the reactive values of [states] and their JSON for the page.
Map<String, Object?> stateJson(Iterable<ThorState> states) => {
  for (final s in states)
    for (final m in s.members)
      if (m.signal case final signal? when signal.changed)
        '${s.idPrefix}.${m.name}': signal.toJson(),
};

/// [json] (a [stateJson] map) as the JSON text the page carries. A value
/// that is not JSON (a class of the app with no `toJson()`, an enum) is
/// THOR-S041 naming its field, not a bare `jsonEncode` failure.
String encodeStateJson(Object? json) {
  try {
    return jsonEncode(json);
  } on JsonUnsupportedObjectError catch (e) {
    var field = '';
    if (json is Map<String, Object?>) {
      for (final entry in json.entries) {
        try {
          jsonEncode(entry.value);
        } on JsonUnsupportedObjectError {
          field = '${entry.key} ';
          break;
        }
      }
    }
    throw StateError(
      'The state field ${field}holds a ${e.unsupportedObject.runtimeType}, '
      'which does not travel to the browser as JSON. Give the class '
      '`toJson()` and `factory fromJson(Map<String, Object?> json)` (the '
      'field then needs nothing else), or give the `state(...)` `encode:` '
      'and `decode:` (THOR-S041)',
    );
  }
}
