# THOR-B036 · Two states with the same class name

**Where:** `thor dev` / `thor build` / `thor test`.

## What happened

Two classes that extend `ThorState`, in different files, have the same name (`IconVariantsState` in `a.dart` and in `b.dart`).

## Why

In Flutter two classes with the same name in different files are legal: each import decides which one you see. A Thor state is different, because it travels to the browser. The page, the protocol and the browser name a state only by its class name (`IconVariantsState.variant`), and there are no imports in the HTML or in the browser code. With two of the same name, the browser keeps one and the other page calls methods and enums that are not its own.

## How to fix it

Rename one of the two, with the page or function name as a prefix (`CartPagePanelState`, `SettingsPanelState`). The error message suggests one based on the file.

```dart
// WRONG
class IconVariantsState extends ThorState { … } // icons.dart
class IconVariantsState extends ThorState { … } // buttons.dart
```

```dart
// RIGHT
class IconVariantsState extends ThorState { … }       // icons.dart
class ButtonsVariantsState extends ThorState { … }    // buttons.dart
```

[All codes](README.md)
