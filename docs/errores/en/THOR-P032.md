# THOR-P032 · An optional field that is also required

**Where:** `thor_ui/router.dart` · `OptionalSchemaField` (in debug).

## What happened

An `OptionalSchemaField` wraps a field with `Validator.required`.

## Why

Optional says "it can come empty" and `required` says "it cannot". There is no correct value for the browser or for the server.

## How to fix it

```dart
// WRONG
static const bio = OptionalSchemaField(TextSchemaField('bio', validators: [Validator.required('Required')]));
```

```dart
// RIGHT
static const bio = OptionalSchemaField(TextSchemaField('bio'));        // optional
static const name = TextSchemaField('name', validators: [Validator.required('Required')]);  // required
```

[All codes](README.md)
