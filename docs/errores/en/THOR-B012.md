# THOR-B012 · A state uses something that cannot run in the browser

**Where:** `thor build` / `thor dev`, and in the editor (`dart analyze` with `thor_lints`: the `thor_lite_subset` rule, with the same message and fix).

## What happened

A `ThorState` in the app, or code it uses, has a construct that cannot run in the browser (a package such as `intl` or `uuid`, `==` on records, generators…). So do the data classes that travel to the browser (the type of an `events<T>`, `query<T>` or `state<T>`: its `fromJson`, `toJson` and the methods the state calls), even in another file: the editor marks it in the class's own file. The message lists each one with its file and line; the build stops without writing anything.

## Why

A state's methods run in the browser. Whatever cannot run the same way there is an error, not different behavior.

## How to fix it

**1. Move it to the server.** A `query(fn)` computes a value and a `command(fn)` changes it; `fn` runs on the server, so it can use any package:

```dart
// WRONG: intl and uuid inside the browser state
class LedgerState extends ThorState {
  final cents = state(0);
  String total() => NumberFormat.currency(locale: 'es_MX').format(cents.value / 100);
  void add(int c) { cents.value += c; lastId.value = const Uuid().v4(); }
}
```

```dart
// RIGHT: the work on the server
class LedgerState extends ThorState {
  final total = query(ledgerRepo.totalLabel);   // NumberFormat on the server
  final add = commandWith(ledgerRepo.add);      // Uuid on the server
}
```

After a `command`, the page's `query` fields come back in the same response. Details in [State](../../guia/en/state.md#server-data).

**2. Rewrite it with Dart basics** (numbers, text, lists, maps, dates, `enum` and your own classes). The state's `static const` and `static final` fields and `FormatException.message` work too.

## Each construct and its fix

What the build recognizes and the "fix:" it suggests (anything not listed gets the general one: move it to the server or rewrite it):

| Construct | What to do |
|---|---|
| `Future.wait(cleanUp:)` | drop `cleanUp:` and release what each future did in a `try`/`finally` after the `await`, or move the work to a server `query()`/`command()` |
| `Timer.run` | `Timer(Duration.zero, callback)` |
| `.wait` (of a record or a list of futures: `(a, b).wait`) | `await Future.wait([a, b])` and read the list: a failure is the first error itself, not a `ParallelWaitError` |
| `.timeout` | cut it on the server, or a `Timer` with the deadline |
| `Completer.sync` | `Completer()`: its listeners run in a microtask, not inside `complete()` |
| `Stream`, `StreamController`, `.listen`, `await for` | no streams: `Timer.periodic`, or read the data with a `query()` |
| `sync*` (and `async*`: generators) | return a `List` built with a loop; a long sequence goes in a `query()` |
| `mixin` (a `mixin class`, one from a package, or with `static` members) | a `mixin` declared in the app with no `static` members; or composition: a field of the helper class or a top-level function |
| `operator +` (and every custom operator except `==`: `[]`, `<`…) | write a method (`a.plus(b)`) |
| `compare by value` (a `Set` or `Map` key of `DateTime`, `Duration` or `TimeOfDay`) | a `String` or `int` key (`item.id`, `date.millisecondsSinceEpoch`). `==` between two collections (`List`, `Set`, `Map`) is translated: it is identity, as in Dart |
| `is Map<String, dynamic>` (and `is List<T>`, `is Set<T>`, `case List<int> l`, map or list patterns with types over something that is not statically `Map`/`List`) | JS keeps no types: test `is Map` / `is List` without arguments and then `as List<T>` or a per-element cast, or a `fromJson` factory |
| `.whereType` (of a type with arguments: `whereType<List<int>>()`) | `l.where((x) => x is List).map((x) => x as List<int>)` |
| `lastIndexOf(RegExp)` (and a `RegExp` in `endsWith`, `trim`…) | walk `RegExp.allMatches` and keep the last one, or a `String` pattern |
| `extension type` | a class with a `final` field, or the underlying type |
| `late` (local and top-level variables, and fields of the state or a class, except `late final x = …` with its initializer in a state or a class, which is translated: it is computed on first read) | give it a value where it is declared (`final x = …`), or make it nullable and check with `!` |
| `super` (except `super.dispose()` and `super.onHydrated()`, which do nothing) | remove the call; cancel `Timer`s in `dispose()` |
| `ValueNotifier` (a state field that is a standalone `ValueNotifier` or `ChangeNotifier`) | make it a `state(...)` field: a `StateSignal` is already a `ValueNotifier` and does react in the browser |
| `interpolate a Map` | print the entries with `m.entries.map(...).join(', ')` |
| `interpolate a record` | interpolate each field (`${r.$1}, ${r.$2}`) |
| `interpolate a List<Object>` (or a `Set`/`Iterable` of `Object`/`dynamic`) | type it (`List<String>`) or `items.map((i) => i.name).join(', ')` |
| `interpolate a list of objects` (a `List`, `Set` or `Iterable` of a class without `toString()`) | `join` of a field, or a `toString()` in the element's class |
| `interpolate a class` | give it a `toString()` or interpolate its fields |
| `getRange`, `removeRange` | `sublist(a, b)`; to remove, rebuild the list with `sublist` |
| `runtimeType` | test with `is`, or a `kind` of your own |
| `index on dynamic` | cast first: `(d as Map)['k']` |
| `extends` (a class that is not the app's) | extend a class of the app, or compose |
| `*.g.dart` (an error in generated code: `.g.dart`, `.freezed.dart`, `.gr.dart`) | the file is generated and not edited: keep that builder's output out of a `ThorState` (a hand-written class, or move it to a `query()`) |
| `integer above 2^53` | send it as a `String`, or compute it in a `query()` |

## If the error names `events(url, …)`

An `events` field is translated with a literal URL, `event:` and `key:`, and the URL is an app route (`/stream`, a single leading `/`: never another origin). Anything else is this error with the reason: pass literals, remove the option `events` does not have (`retry:`…), use `key:` only with `List<…>` and declare the field `final`. Details in [Live data](../../guia/en/live-data.md#server-events).

[All codes](README.md)
