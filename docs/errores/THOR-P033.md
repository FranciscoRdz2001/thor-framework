# THOR-P033 · Una sesión firmada sin `maxAge`

**Dónde:** `thor_server` · `SignedCookies(purpose: 'session')` (solo con `thor dev`, en la salida de errores).

## Qué pasó

Se creó un `SignedCookies` con `purpose: 'session'` y sin `maxAge`.

## Por qué

Sin `maxAge` el servidor nunca rechaza una cookie por vieja: una cookie de sesión robada sirve para siempre (mientras no rotes el secreto). Que el navegador la borre al cerrar no ayuda, porque quien la robó no obedece al navegador.

## Cómo se arregla

Pon una caducidad (30 días es un punto de partida) y la misma en la cookie.

```dart
// WRONG
SignedCookies(secret, purpose: 'session')
```

```dart
// RIGHT
const lifetime = Duration(days: 30);
final session = SignedCookies(secret, purpose: 'session', maxAge: lifetime);
// request.response.setCookie('session', session.sign(value), maxAge: lifetime);
```

[Todos los códigos](README.md)
