# THOR-R032 · An `Autocomplete`'s `optionsBuilder` returned a `Future`

**Where:** `thor_ui` · `Autocomplete(optionsBuilder:)` or
`RawAutocomplete(optionsBuilder:)`.

## What happened

The `optionsBuilder` is `async` or returns a `Future`.

## Why

A page is written once: the server calls `optionsBuilder` while
building, with the field's initial text, and it can't await a future or
call it again while the person types. The browser only filters the
options it received.

## How to fix it

Fixed options: return them right away.

```dart
// WRONG
Autocomplete<String>(optionsBuilder: (v) async => await api.names())
```

```dart
// RIGHT: a fixed list
Autocomplete<String>(optionsBuilder: (v) => names.where((n) => n.contains(v.text)))
```

Options the server looks up as you type (a search box): store them in
a list in a `ThorState` and show it in the `optionsViewBuilder` of a
`RawAutocomplete`.

```dart
RawAutocomplete<String>(
  optionsBuilder: (v) => const [],
  textEditingController: search.box,
  focusNode: search.focus,
  fieldViewBuilder: (context, controller, focus, submit) =>
      TextField(controller: controller, focusNode: focus),
  optionsViewBuilder: (context, onSelected, options) => Watch.list(
    search.names,
    itemKey: search.nameOf,
    each: (row) => Semantics(
      role: SemanticsRole.option,
      child: row.text(search.nameOf),
    ),
  ),
)
```

[All codes](README.md)
