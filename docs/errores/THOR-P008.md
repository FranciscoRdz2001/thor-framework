# THOR-P008 · Dos campos de un `FormSchema` con el mismo nombre

**Dónde:** `thor_ui/router.dart` · `FormSchema.validate` (en debug).

## Qué pasó

Un `FormSchema` tiene dos campos con el mismo `name`.

## Por qué

El nombre es la llave del formulario enviado: dos campos con el mismo nombre leerían el mismo valor y sus mensajes se pisarían.

## Cómo se arregla

```dart
// WRONG
static const schema = FormSchema([email, TextSchemaField('email')]);
```

```dart
// RIGHT
static const schema = FormSchema([email, TextSchemaField('backupEmail')]);
```

[Todos los códigos](README.md)
