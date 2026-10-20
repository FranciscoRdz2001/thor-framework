# THOR-P011 · El entorno no es válido

**Dónde:** `thor_server` · `EnvSchema.load` (al arrancar el servidor).

## Qué pasó

Faltan variables del `EnvSchema` de la app o alguna no tiene el tipo que declara (un número que no es número, una URL sin `http(s)`, un secreto más corto que `minLength`). El mensaje lista **todas**, no solo la primera.

## Por qué

Un servidor que arranca a medias falla después, en una petición y lejos de la causa. Revisar todo al arrancar convierte un deploy mal configurado en un error inmediato con la lista completa.

## Cómo se arregla

Define lo que falta en el entorno del deploy o, en desarrollo, en el `.env` de la app (`thor dev` y `thor preview` lo leen; el entorno real gana). Si la variable es opcional, dale `fallback:` o envuélvela en `EnvOptional`.

```dart
// WRONG: se lee en cualquier parte y falla cuando se usa
final api = Platform.environment['API_URL']!;
```

```dart
// RIGHT: declarada una vez, revisada al arrancar
static const api = EnvUrl('API_URL');
static const schema = EnvSchema([api]);
// …
env.of(AppEnv.api); // Uri
```

### Declarada pero fuera del `EnvSchema`

`load()` solo lee lo que lista el `EnvSchema`. Una variable declarada y no puesta en la lista no se exige ni se revisa, y `env.of(AppEnv.otra)` falla en la primera petición que la lee («`OTHER` is not in the EnvSchema…»). El editor lo avisa antes con `env_var_not_in_schema`.

```dart
// WRONG: port se declara y no está en la lista
static const api = EnvUrl('API_URL');
static const port = EnvInt('PORT', fallback: 4300);
static const schema = EnvSchema([api]);
```

```dart
// RIGHT
static const schema = EnvSchema([api, port]);
```

[Todos los códigos](README.md)
