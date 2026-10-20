# THOR-B002 · A `ThorState` method is skipped

**Where:** `thor build` / `thor dev` · warning.

## What happened

A public method of the state cannot be called from the browser, so Thor leaves it out (a warning, not an error). The causes: more than three parameters, optional or named parameters, a parameter that is not a simple value in a method with several parameters, or a parameter type the file does not import.

## Why

The browser calls methods with arguments that travel in the HTML as text: only simple values (`int`, `double`, `String`, `bool`, `enum`, `DateTime`, `TimeOfDay`) or a row's item.

## How to fix it

```dart
// WRONG
void addLine(String name, {int qty = 1}) { ... }       // named
void move(Line line, Line target, int at, bool copy) { ... } // four
```

```dart
// RIGHT
void addLine(String name) { ... }
void moveTo(int at, Line line) { ... }   // fixed argument with withArg + item

// What is not for the browser: private (_helper) or static.
```

[All codes](README.md)
