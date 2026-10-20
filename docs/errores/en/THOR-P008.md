# THOR-P008 · Two fields of a `FormSchema` with the same name

**Where:** `thor_ui/router.dart` · `FormSchema.validate` (in debug).

## What happened

A `FormSchema` has two fields with the same `name`.

## Why

The name is the key in the submitted form: two fields with the same name would read the same value and their messages would overwrite each other.

## How to fix it

```dart
// WRONG
static const schema = FormSchema([email, TextSchemaField('email')]);
```

```dart
// RIGHT
static const schema = FormSchema([email, TextSchemaField('backupEmail')]);
```

[All codes](README.md)
