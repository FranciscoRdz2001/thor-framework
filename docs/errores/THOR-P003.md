# THOR-P003 · El secreto de `SignedCookies` es corto

**Dónde:** `thor_server` · `SignedCookies`.

## Qué pasó

El secreto tiene menos de 32 bytes.

## Por qué

Con HMAC-SHA256 un secreto corto se puede adivinar por fuerza bruta y alguien podría firmar cookies (una sesión) a su gusto.

## Cómo se arregla

```dart
// WRONG
SignedCookies('secreto')
```

```dart
// RIGHT
// Generarlo una vez (openssl rand -base64 48) y leerlo del entorno:
SignedCookies(Platform.environment['SESSION_SECRET']!)
```

[Todos los códigos](README.md)
