# THOR-P031 · Un `Validator.custom` que nadie corre

**Dónde:** `thor_ui` · `TextFormField` (en debug).

## Qué pasó

Un `TextFormField` lleva un `Validator.custom((v) => …)` pero ningún esquema del servidor revisa ese campo.

## Por qué

Un closure no corre en el navegador. Su única casa es el servidor, dentro de un `FormSchema` que revisa el envío. Sin él la regla se saltaría sin avisar.

## Cómo se arregla

```dart
// WRONG
TextFormField(name: 'name', validator: Validator.custom((v) => v == 'admin' ? 'Ocupado' : null))
```

```dart
// RIGHT
bool _free(String v) => v != 'admin';
String? _taken(String v) => _free(v) ? null : 'Ocupado';

static const name = TextSchemaField('name', validators: [Validator.custom(_taken)]);
// Form(schema: MySchema.schema, onValid: send, child: TextFormField(field: MySchema.name))
```

[Todos los códigos](README.md)
