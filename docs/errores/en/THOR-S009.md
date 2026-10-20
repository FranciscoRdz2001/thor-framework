# THOR-S009 · Invalid name of a persisted field (`cookie:` or `local:`)

**Where:** `thor_ui` · `state(…, cookie:)` and `state(…, local:)` (`thor build` checks it too).

## What happened

A persisted field uses a `cookie:` or a `local:` that is empty, longer than 40 characters, has characters other than letters, digits, `_` or `-`, or isn't a string literal. Or it uses both: a field persists in one place.

## Why

The name ends up in the cookie's name or the `localStorage` key (`thor-s.<name>`) and in the code that runs in the browser: a space, a `;` or a `=` would break the cookie, and a computed name can't be checked at compile time. With `cookie:` and `local:` together no value would win.

## How to fix it

```dart
// WRONG
final collapsed = state(false, cookie: 'side menu');
```

```dart
// RIGHT
final collapsed = state(false, cookie: 'sidebar');
final draft = state('', local: 'draft');
```

[All codes](README.md)
