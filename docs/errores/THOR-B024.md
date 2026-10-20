# THOR-B024 · Un método de acción con un esquema que thor no puede construir

**Dónde:** `thor dev` / `thor build` / `thor test`.

## Qué pasó

Un método de acción recibe `FormValues<S>` y `S` no es una clase propia de esquema: es `FormSchema` a secas, es privada, o no tiene `static const schema` ni un constructor `const` sin argumentos.

## Por qué

thor revisa el formulario con el esquema **antes** de correr el método (inválido → 422 sin correrlo). El esquema sale del tipo `S` que declara el método, no de lo que pintó la página: el build necesita poder escribir `S.schema` (o `const S()`).

## Cómo se arregla

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

[Todos los códigos](README.md)
