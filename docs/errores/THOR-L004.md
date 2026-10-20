# THOR-L004 · Un campo de texto sin nombre accesible

**Dónde:** inspector de desarrollo (modo debug, en el navegador) y el lint `text_field_without_label` del editor.

## Qué pasó

Un `TextField` o `TextFormField` no tiene `labelText`, `hintText` ni un `Semantics(label:)`. Un lector de pantalla lo anuncia solo como «campo de texto», sin decir qué se escribe ahí.

## Por qué

thor da nombre al `<input>` con `aria-label`, tomado de `InputDecoration.labelText` (o de `hintText` si no hay etiqueta). Un `Text('Nombre')` puesto al lado no está enlazado al campo: se ve bien y no nombra nada.

## Cómo se arregla

```dart
// WRONG: la etiqueta es un Text suelto
Row(children: [Text('Correo'), TextField(name: 'email')])
```

```dart
// RIGHT: la etiqueta es del campo
TextField(name: 'email', decoration: InputDecoration(labelText: 'Correo'))

// o, si el diseño no deja ver la etiqueta
Semantics(label: 'Correo', child: TextField(name: 'email'))
```

Si el nombre viene de una variable (`decoration: miDecoracion`) el lint no lo sabe y calla; el inspector sí mira el HTML y avisa si la variable no lo tenía. También cuentan `aria-label`, `aria-labelledby` o `title` en `inputAttributes`.

[Todos los códigos](README.md)
