# THOR-S013 · A `ValueListenableBuilder` the browser can't rebuild

**Where:** `thor_ui` · the server, when painting the page.

## What happened

`ValueListenableBuilder` received a `StateSignal` that isn't a field of a top-level `ThorState`, or whose value doesn't have a finite set of cases (an `int`, a `String`, or a `bool?` / nullable enum: `null` has no copy to paint).

## Why

The server paints the `builder` once for each possible value (a `bool`, each case of an enum) and the browser shows the one that applies, just like `Watch(..., builder:)`. An `int` or a `String` has infinitely many values: there's nothing to paint ahead of time. The browser finds the field by its name, so it has to be a field of a top-level state ([THOR-S012](THOR-S012.md)).

## How to fix it

```dart
// WRONG
ValueListenableBuilder<String>(
  valueListenable: profile.name,
  builder: (context, name, child) => Text('Hello, $name'),
)
```

```dart
// RIGHT: a String is shown as text
Watch(profile.name)

// a text with more words: a state method that builds it
String greeting() => 'Hello, ${name.value}';
Watch(profile.greeting)

// an int: its values from 0 to n - 1
Watch(rating.stars.call, count: 6, builder: (n) => Text('★' * n))

// a bool? or an enum?: remove the null (state(false), or a `none` case in the enum)
final open = state(false);

// a bool or an enum works as is
ValueListenableBuilder<bool>(
  valueListenable: panel.open,
  builder: (context, open, child) => Text(open ? 'Open' : 'Closed'),
)
```

A standalone `ValueNotifier` (one that isn't a `state(...)` field) is painted once with its value and never reacts in the browser; as a field of a `ThorState`, `thor build` rejects it.

[All codes](README.md)
