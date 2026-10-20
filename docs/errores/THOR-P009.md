# THOR-P009 · Una acción devolvió un valor que no es un resultado

**Dónde:** `thor_server` · `RouteHandler`, al correr la acción de un `POST`.

## Qué pasó

La acción devolvió algo que no es `Redirect`, `ActionResult`, `ActionOutcome` ni `null` (por ejemplo, un número o un modelo).

## Por qué

Una acción responde con un `Redirect`, un `ActionResult`, un `ActionOutcome` o `null` (volver a la página). Otro valor no dice qué responder: pintar la página como éxito (`200`) perdería el valor, y un formulario rechazado saldría sin sus mensajes. Un `FormInvalid` sí es un `ActionOutcome`: devuelto tal cual, responde `422`.

Una acción declarada como `Future<ActionResult?> save(PageRequest r)` no compila si devuelve otra cosa; el error aparece cuando el tipo de retorno lo permite (`dynamic`, `Object?`).

## Cómo se arregla

```dart
// WRONG: el dato se pierde y la página sale como éxito
Future<Object?> save(PageRequest request) async =>
    api.save(await request.form());
```

```dart
// RIGHT: un método de la página que nombra el resultado
Future<ActionResult?> save(PageRequest request) async {
  final saved = await api.save(await request.form());
  return ActionResult.success(saved);
}
// y un formulario rechazado por el backend
if (taken) return values.fail('email is taken', SignUp.email); // 422
```

[Todos los códigos](README.md)
