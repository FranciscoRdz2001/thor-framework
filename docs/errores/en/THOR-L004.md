# THOR-L004 · A text field without an accessible name

**Where:** development inspector (debug mode, in the browser) and the editor's `text_field_without_label` lint.

## What happened

A `TextField` or `TextFormField` has no `labelText`, `hintText` or `Semantics(label:)`. A screen reader announces it only as "text field", without saying what goes in it.

## Why

Thor names the `<input>` with `aria-label`, taken from `InputDecoration.labelText` (or from `hintText` if there is no label). A `Text('Name')` placed next to it is not linked to the field: it looks fine and names nothing.

## How to fix it

```dart
// WRONG: the label is a loose Text
Row(children: [Text('Email'), TextField(name: 'email')])
```

```dart
// RIGHT: the label belongs to the field
TextField(name: 'email', decoration: InputDecoration(labelText: 'Email'))

// or, if the design hides the label
Semantics(label: 'Email', child: TextField(name: 'email'))
```

If the name comes from a variable (`decoration: myDecoration`) the lint cannot tell and stays quiet; the inspector does look at the HTML and warns if the variable did not have it. `aria-label`, `aria-labelledby` or `title` in `inputAttributes` also count.

[All codes](README.md)
