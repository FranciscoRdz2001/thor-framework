# THOR-P035 · A `RegExp` with flags in a `Validator.pattern`

**Where:** `thor_ui` · `Validator.pattern(RegExp(...), ...)` (in debug, when painting the field).

## What happened

You passed `Validator.pattern` a `RegExp` with `caseSensitive: false`, `multiLine: true` or `dotAll: true`, and the browser cannot apply them.

## Why

The rule becomes the `<input>`'s native `pattern` attribute: it is the text of a JavaScript regular expression, without flags. Silently ignoring the flag would make the browser accept or reject differently from what your code says.

## How to fix it

Write the flag into the pattern, or leave the rule to the server.

```dart
// WRONG
Validator.pattern(RegExp(r'^abc$', caseSensitive: false), 'Type abc')
```

```dart
// RIGHT: the flag inside the pattern
Validator.pattern(RegExp(r'^[Aa][Bb][Cc]$'), 'Type abc')

// or a rule only the server checks (with a FormSchema)
Validator.custom((v) => v.toLowerCase() == 'abc' ? null : 'Type abc')
```

The same goes for `\p{..}`, `\P{..}` and `\u{..}` without `unicode: true`: Dart reads them as text, the server and the browser as a Unicode property. Set `unicode: true`.

A `RegExp` without flags means the same as in Flutter (`hasMatch`: a match anywhere in the value). More in [Forms](../../guia/en/forms.md#validate).

[All codes](README.md)
