# THOR-S039 · El navegador llamó a una consulta o comando que el registro no declara

**Dónde:** `thor dev` · terminal del servidor, con el id (`MapState.near`).

## Qué pasó

El navegador hizo un `POST` a una consulta (`queryWith`) o comando (`commandWith`) y el servidor respondió `404` porque el registro generado no lista ese campo.

## Por qué

El servidor solo contesta los ids que el build declaró. Los campos públicos de un `ThorState` entran solos, con argumento simple, record o clase. Si falta, el registro está desactualizado o el campo no es público (`_near`).

## Cómo se arregla

```dart
// WRONG: privado, no entra en el registro
final _near = queryWith(repo.near, arg: (lat: 0.0, lng: 0.0));

// RIGHT
final near = queryWith(repo.near, arg: (lat: 0.0, lng: 0.0));
```

Reconstruye (`thor dev` lo hace al guardar) y revisa el nombre del estado y del campo en el id.

[Todos los códigos](README.md)
