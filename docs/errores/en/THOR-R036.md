# THOR-R036 · A widget that adds up padding received one given as a `Length`

**Where:** `thor_ui` · `InputDecoration.contentPadding` (`TextField`,
`DropdownButtonFormField`), `DropdownMenu(inputDecorationTheme:)`,
`ExpansionTile.tilePadding` and `GridView.padding`.

## What happened

The padding was given with `EdgeInsetsGeometry.allLength`, `symmetricLength` or
`onlyLength` (for example, a CSS variable: `Length.variable(CssVariable('--gap'))`) and
the widget needs the numbers for each side.

## Why

A `Length` is resolved by the browser, so it has no numbers to read: an
`EdgeInsetsGeometry.allLength` isn't even an `EdgeInsets` (the widgets
that add up take `EdgeInsets` and reject it at compile time). These
widgets add something of their own to those sides (the space for an icon, the
selector's arrow) or split them across several boxes; with a `Length` the padding
would come out as zero without warning. That's why it fails with this code instead of painting
wrong.

`SafeArea` and `Padding` do accept an `EdgeInsetsGeometry` with `Length`: they
add it to the safe area or write it as is in the CSS.

## How to fix it

```dart
// WRONG: the padding is a variable; the field cannot add its icon to it
// (it does not even compile: contentPadding takes EdgeInsets)
TextField(
  decoration: InputDecoration(
    contentPadding: EdgeInsetsGeometry.symmetricLength(
      horizontal: Length.variable(CssVariable('--field-x')),
    ),
  ),
)
```

```dart
// RIGHT: numbers in these widgets; the Length goes in a Padding around them
Padding(
  padding: EdgeInsetsGeometry.symmetricLength(
    horizontal: Length.variable(CssVariable('--field-x')),
  ),
  child: TextField(
    decoration: InputDecoration(
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    ),
  ),
)
```

[All codes](README.md)
