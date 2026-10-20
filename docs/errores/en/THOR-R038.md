# THOR-R038 · A segment with no accessible name

**Where:** `thor_ui` · `SegmentedButton`; `thor_studio` · `StudioSegmentedControl` (debug only).

## What happened

A segment has a `label` that is not a `Text` (an `Icon`, say) and no
`tooltip`, or it is an icon alone with no `tooltip`. A `Text` built by an
app component, a `Semantics(label:)` or an `Icon(semanticLabel:)` does name
it.

## Why

Each segment is a native radio. Its name comes from the text of a `Text`
(or the label of a `Semantics` or an `Icon`) or from the `tooltip`; with neither, a screen reader announces a radio with no
name. So it fails in debug instead of drawing a mute control.

## How to fix it

```dart
// WRONG
ButtonSegment(value: View.list, icon: Icon(Icons.list))
```

```dart
// RIGHT
ButtonSegment(value: View.list, icon: Icon(Icons.list), tooltip: 'List')
```

[All codes](README.md)
