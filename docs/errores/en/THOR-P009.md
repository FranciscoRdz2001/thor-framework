# THOR-P009 · An action returned a value that is not a result

**Where:** `thor_server` · `RouteHandler`, when running a `POST`'s action.

## What happened

The action returned something that is not a `Redirect`, `ActionResult`, `ActionOutcome` or `null` (for example, a number or a model).

## Why

An action answers with a `Redirect`, an `ActionResult`, an `ActionOutcome` or `null` (back to the page). Any other value does not say what to answer: painting the page as a success (`200`) would lose the value, and a rejected form would come out without its messages. A `FormInvalid` is an `ActionOutcome`: returned as is, it answers `422`.

An action declared as `Future<ActionResult?> save(PageRequest r)` does not compile if it returns anything else; the error shows up when the return type allows it (`dynamic`, `Object?`).

## How to fix it

```dart
// WRONG: the data is lost and the page comes out as a success
Future<Object?> save(PageRequest request) async =>
    api.save(await request.form());
```

```dart
// RIGHT: a page method that names the result
Future<ActionResult?> save(PageRequest request) async {
  final saved = await api.save(await request.form());
  return ActionResult.success(saved);
}
// and a form rejected by the backend
if (taken) return values.fail('email is taken', SignUp.email); // 422
```

[All codes](README.md)
