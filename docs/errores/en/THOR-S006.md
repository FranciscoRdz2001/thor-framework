# THOR-S006 · A page uses a `ThorState` without `ThorApp`

**Where:** `thor_ui` · warning in debug mode at render time.

## What happened

The page has widgets bound to a `ThorState` but isn't inside a `ThorApp`.

## Why

`ThorApp` is what adds to the document the script that brings the page to life, plus the initial state. Without it the page leaves the server properly painted but **static**: the buttons do nothing.

## How to fix it

```dart
// WRONG
runApp(Document(body: Counter()))
```

```dart
// RIGHT
runApp(Document(body: ThorApp(child: Counter())))

// In an app with routes: WidgetRenderer(app: (page) => ThorApp(child: page))
```

[All codes](README.md)
