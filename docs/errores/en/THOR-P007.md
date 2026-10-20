# THOR-P007 · A field from another schema in `FormValid.of`

**Where:** `thor_ui/router.dart` · `FormValid.of`.

## What happened

A field was read with `values.of(field)` and that field does not belong to the `FormSchema` that validated the form.

## Why

The value only exists for the fields of the schema that ran `parse`. It usually happens with two similar schemas (sign-in and sign-up) when the action validates with one and reads a field from the other.

## How to fix it

```dart
// WRONG
final form = await AuthForm.signIn.parse(request);
(form as FormValid).of(AuthForm.username); // username is only in signUp
```

```dart
// RIGHT
final form = await AuthForm.signUp.parse(request);
(form as FormValid).of(AuthForm.username);
```

[All codes](README.md)
