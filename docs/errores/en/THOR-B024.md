# THOR-B024 · An action method with a schema Thor cannot build

**Where:** `thor dev` / `thor build` / `thor test`.

## What happened

An action method receives `FormValues<S>` and `S` is not a schema class of your own: it is plain `FormSchema`, it is private, or it has neither a `static const schema` nor a `const` constructor without arguments.

## Why

Thor checks the form against the schema **before** running the method (invalid → 422 without running it). The schema comes from the type `S` the method declares, not from what the page painted: the build needs to be able to write `S.schema` (or `const S()`).

## How to fix it

```dart
// WRONG — the type says nothing about the fields
Future<ActionResult?> send(PageRequest r, FormValues<FormSchema> values) …
```

```dart
// RIGHT — a schema class with its instance
final class ContactForm extends FormSchema {
  const ContactForm._() : super(const [email]);
  static const schema = ContactForm._();
  static const email = TextSchemaField('email');
}

Future<ActionResult?> send(PageRequest r, FormValues<ContactForm> values) …
```

[All codes](README.md)
