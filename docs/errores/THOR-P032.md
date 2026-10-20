# THOR-P032 · Un campo opcional que también es obligatorio

**Dónde:** `thor_ui/router.dart` · `OptionalSchemaField` (en debug).

## Qué pasó

Un `OptionalSchemaField` envuelve un campo con `Validator.required`.

## Por qué

Opcional dice «puede venir vacío» y `required` dice «no puede». No hay valor correcto para el navegador ni para el servidor.

## Cómo se arregla

```dart
// WRONG
static const bio = OptionalSchemaField(TextSchemaField('bio', validators: [Validator.required('Falta')]));
```

```dart
// RIGHT
static const bio = OptionalSchemaField(TextSchemaField('bio'));        // opcional
static const name = TextSchemaField('name', validators: [Validator.required('Falta')]);  // obligatorio
```

[Todos los códigos](README.md)
