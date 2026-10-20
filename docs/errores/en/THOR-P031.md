# THOR-P031 · A `Validator.custom` nobody runs

**Where:** `thor_ui` · `TextFormField` (in debug).

## What happened

A `TextFormField` carries a `Validator.custom((v) => …)` but no server schema checks that field.

## Why

A closure does not run in the browser. Its only home is the server, inside a `FormSchema` that checks the submission. Without one, the rule would be skipped silently.

## How to fix it

```dart
// WRONG
TextFormField(name: 'name', validator: Validator.custom((v) => v == 'admin' ? 'Taken' : null))
```

```dart
// RIGHT
bool _free(String v) => v != 'admin';
String? _taken(String v) => _free(v) ? null : 'Taken';

static const name = TextSchemaField('name', validators: [Validator.custom(_taken)]);
// Form(schema: MySchema.schema, onValid: send, child: TextFormField(field: MySchema.name))
```

[All codes](README.md)
