# THOR-L001 · A `Row` or a `Column` overflows

**Where:** development inspector (debug mode, in the browser).

## What happened

The content of a `Row`/`Column` is larger than the flex itself: it is marked with a red outline and a warning in the console.

## Why

It is Flutter's "A RenderFlex overflowed". On the web the content is not clipped: it spills out of the box and pushes or covers whatever is next to it.

## How to fix it

```dart
// WRONG
Row(children: [Icon(Icons.info), Text(longText)])
```

```dart
// RIGHT
Row(children: [Icon(Icons.info), Expanded(child: Text(longText))])
// or Flexible, or Wrap if the children should wrap to the next line.
```

[All codes](README.md)
