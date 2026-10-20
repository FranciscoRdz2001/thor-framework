# THOR-P011 · The environment is not valid

**Where:** `thor_server` · `EnvSchema.load` (when the server starts).

## What happened

Variables from the app's `EnvSchema` are missing or some do not have the type they declare (a number that is not a number, a URL without `http(s)`, a secret shorter than `minLength`). The message lists **all** of them, not just the first.

## Why

A server that starts half-configured fails later, in a request and far from the cause. Checking everything at startup turns a misconfigured deploy into an immediate error with the full list.

## How to fix it

Define what is missing in the deploy environment or, in development, in the app's `.env` (`thor dev` and `thor preview` read it; the real environment wins). If the variable is optional, give it a `fallback:` or wrap it in `EnvOptional`.

```dart
// WRONG: read anywhere, fails when used
final api = Platform.environment['API_URL']!;
```

```dart
// RIGHT: declared once, checked at startup
static const api = EnvUrl('API_URL');
static const schema = EnvSchema([api]);
// …
env.of(AppEnv.api); // Uri
```

### Declared but missing from the `EnvSchema`

`load()` only reads what the `EnvSchema` lists. A variable that is declared but not put in the list is neither required nor checked, and `env.of(AppEnv.other)` fails on the first request that reads it ("`OTHER` is not in the EnvSchema…"). The editor warns about it earlier with `env_var_not_in_schema`.

```dart
// WRONG: port is declared but not in the list
static const api = EnvUrl('API_URL');
static const port = EnvInt('PORT', fallback: 4300);
static const schema = EnvSchema([api]);
```

```dart
// RIGHT
static const schema = EnvSchema([api, port]);
```

[All codes](README.md)
