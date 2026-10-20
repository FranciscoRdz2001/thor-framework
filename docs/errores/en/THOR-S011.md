# THOR-S011 · A callback is a closure that uses a `ThorState`

**Where:** `thor_lints` · rule `state_misuse` (in the editor and in `dart analyze`), `thor dev` and `thor build`.

## What happened

A widget received as a callback (`onPressed`, `onChanged`, `onTap`, `onSelected`…) an anonymous function that calls or reads a member of a `ThorState`. In the browser the button does nothing: the element is painted without a handler and no error reports it.

## Why

A widget's code runs only once, on the server. In the browser only a `ThorState`'s own members exist, and the browser finds them **by name** (`counter.increment`). A closure isn't translated and has no name: the browser can't run it. An empty closure (`() {}`, the button that submits a form) or one that doesn't touch any state is valid and isn't flagged.

`thor dev` shows the warning on the page with file and line, and `thor build` fails with it. In the editor, the quick fix replaces the closure with the member when it's a single call.

## How to fix it

```dart
// WRONG
OutlinedButton(onPressed: () { counter.decrement(); }, child: const Text('-'))
IconButton(onPressed: () => todos.remove(id), icon: const Icon(Icons.delete))
TextButton(onPressed: () { counter.reset(); log.clear(); }, child: const Text('Reset'))
```

```dart
// RIGHT
OutlinedButton(onPressed: counter.decrement, child: const Text('-'))
IconButton(onPressed: todos.remove.withArg(id), icon: const Icon(Icons.delete))

// Several actions: a state method.
void resetAll() {
  reset();
  log.clear();
}
TextButton(onPressed: counter.resetAll, child: const Text('Reset'))
```

[All codes](README.md)
