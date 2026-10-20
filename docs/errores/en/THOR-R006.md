# THOR-R006 · There is no `Localizations` above the widget

**Where:** `thor_ui` · `Localizations.localeOf`.

## What happened

A widget asked for the locale and there is no `Localizations` among its ancestors.

## Why

`ThorApp` provides one; a widget rendered outside `ThorApp` (a test, a `Document` without an app) doesn't have it.

## How to fix it

```dart
// WRONG
runApp(Document(body: const Greeting()))
```

```dart
// RIGHT
runApp(Document(body: ThorApp(child: const Greeting())))
// In tests: wrap in ThorApp or use Localizations.maybeLocaleOf.
```

[All codes](README.md)
