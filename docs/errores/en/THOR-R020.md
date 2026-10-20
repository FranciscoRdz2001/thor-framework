# THOR-R020 · A widget tree too deep for the stack

**Where:** `thor_ui` · the page render (`PageBuild.buildRoot`).

## What happened

The page nests so many widgets that the build ran out of stack. The
message says how many elements were above the one that failed and both
ends of the chain (the first and last six), so you can see what
repeats.

## Why

Thor's render is recursive: each level of the tree uses a few stack
frames. About 2400 nested `Container` widgets exhaust the stack in release (fewer than
2000 in debug or in `thor test`). Before this code the page answered
500 with thousands of repeated frames in the log; now it fails with this message
and the route shows its error page, like any other exception.

No real interface needs that depth: it's usually a recursion that
nests instead of listing.

## How to fix it

```dart
// WRONG: each element wraps the next; 3000 elements = 3000 levels
Widget chain(List<Item> items) => items.isEmpty
    ? const SizedBox.shrink()
    : Container(child: Column(children: [Text(items.first.name), chain(items.skip(1).toList())]));
```

```dart
// RIGHT: the elements are siblings; the depth does not grow with the list
Column(children: [for (final item in items) Text(item.name)])
```

[All codes](README.md)
