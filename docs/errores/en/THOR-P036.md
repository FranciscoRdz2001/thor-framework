# THOR-P036 · A `Form` inside an `AutofillGroup` that is already a `<form>`

**Where:** `thor_ui` · `Form` (in debug).

## What happened

A `Form` is below an `AutofillGroup` that is not inside any form, and it is not its direct child.

## Why

Outside a form, `AutofillGroup` is drawn as a `<form method="dialog">` so the browser groups the fields. A `<form>` inside another is not valid HTML: the parser ignores the inner one and the fields are submitted with the wrong form.

## How to fix it

```dart
// WRONG
AutofillGroup(child: Padding(padding: EdgeInsets.all(8), child: Form(child: fields)))
```

```dart
// RIGHT: the Form as a direct child (the group adds no element)…
AutofillGroup(child: Form(child: fields))
// …or the group inside the Form
Form(child: AutofillGroup(child: fields))
```

[All codes](README.md)
