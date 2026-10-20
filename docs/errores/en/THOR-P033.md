# THOR-P033 · A signed session without `maxAge`

**Where:** `thor_server` · `SignedCookies(purpose: 'session')` (only with `thor dev`, in the error output).

## What happened

A `SignedCookies` was created with `purpose: 'session'` and without `maxAge`.

## Why

Without `maxAge` the server never rejects a cookie for being old: a stolen session cookie works forever (as long as you do not rotate the secret). The browser deleting it on close does not help, because whoever stole it does not obey the browser.

## How to fix it

Set an expiry (30 days is a starting point) and the same one on the cookie.

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

[All codes](README.md)
