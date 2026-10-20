# THOR-R004 · `.when()` inside a style sheet

**Where:** `thor_ui` · sheet rules (`css(...).props(...)`).

## What happened

A style sheet rule received `StyleProps` with variants (`.when(...)`).

## Why

A sheet already varies by its selector and its media queries; `.when()` is for the style of **one element** (`Styled(style:)`, widgets), where Thor turns the variants into conditions on the same class. In a sheet the marker would reach the CSS as garbage.

## How to fix it

```dart
// WRONG
css('.card').props(const StyleProps(padding: EdgeInsets.all(8)).when(medium: StyleProps(padding: EdgeInsets.all(16))))
```

```dart
// RIGHT
css('.card').props(const StyleProps(padding: EdgeInsets.all(8))),
WindowSizeClass.medium.media([css('.card').props(const StyleProps(padding: EdgeInsets.all(16)))]),

// or better, on the widget:
Styled(style: const StyleProps(padding: EdgeInsets.all(8)).when(medium: ...), child: ...)
```

[All codes](README.md)
