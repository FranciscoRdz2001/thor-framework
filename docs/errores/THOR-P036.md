# THOR-P036 · Un `Form` dentro de un `AutofillGroup` que ya es un `<form>`

**Dónde:** `thor_ui` · `Form` (en debug).

## Qué pasó

Un `Form` está debajo de un `AutofillGroup` que no está dentro de ningún formulario, y no es su hijo directo.

## Por qué

Fuera de un formulario, `AutofillGroup` se dibuja como un `<form method="dialog">` para que el navegador agrupe los campos. Un `<form>` dentro de otro no es HTML: el parser ignora el interior y los campos se envían con el formulario equivocado.

## Cómo se arregla

```dart
// WRONG
AutofillGroup(child: Padding(padding: EdgeInsets.all(8), child: Form(child: fields)))
```

```dart
// RIGHT: el Form como hijo directo (el grupo no añade elemento)…
AutofillGroup(child: Form(child: fields))
// …o el grupo dentro del Form
Form(child: AutofillGroup(child: fields))
```

[Todos los códigos](README.md)
