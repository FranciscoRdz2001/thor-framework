# THOR-P030 · `Form(defaults:)` is not a map and has no `toJson()`

**Where:** `thor_ui` · `Form(defaults:)` (when drawing the form).

## What happened

`defaults` received something that is neither a `Map` nor an object with `toJson()`.

## Why

Fields are filled in by `name`: a name → value map is needed. A model has to say what its fields are, and `toJson()` is the form Thor already asks for in a `query`'s data.

## How to fix it

```dart
// WRONG
Form(defaults: 42, child: …)
Form(defaults: order, child: …)      // Order has no toJson()
```

```dart
// RIGHT
Form(defaults: order, child: …)      // class Order { Map<String, Object?> toJson() => {...}; }
Form(defaults: {'customer': order.customer}, child: …)
```

[All codes](README.md)
