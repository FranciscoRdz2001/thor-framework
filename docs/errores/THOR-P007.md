# THOR-P007 · Un campo de otro esquema en `FormValid.of`

**Dónde:** `thor_ui/router.dart` · `FormValid.of`.

## Qué pasó

Se leyó un campo con `values.of(field)` y ese campo no es del `FormSchema` que validó el formulario.

## Por qué

El valor solo existe para los campos del esquema que hizo `parse`. Suele pasar con dos esquemas parecidos (login y registro) cuando la acción valida con uno y lee un campo del otro.

## Cómo se arregla

```dart
// WRONG
final form = await AuthForm.signIn.parse(request);
(form as FormValid).of(AuthForm.username); // username solo está en signUp
```

```dart
// RIGHT
final form = await AuthForm.signUp.parse(request);
(form as FormValid).of(AuthForm.username);
```

[Todos los códigos](README.md)
