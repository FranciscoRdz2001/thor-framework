# THOR-P003 · The `SignedCookies` secret is short

**Where:** `thor_server` · `SignedCookies`.

## What happened

The secret is shorter than 32 bytes.

## Why

With HMAC-SHA256 a short secret can be guessed by brute force, and someone could sign cookies (a session) at will.

## How to fix it

```dart
// WRONG
SignedCookies('secret')
```

```dart
// RIGHT
// Generate it once (openssl rand -base64 48) and read it from the environment:
SignedCookies(Platform.environment['SESSION_SECRET']!)
```

[All codes](README.md)
