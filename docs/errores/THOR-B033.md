# THOR-B033 · Un `ValueNotifier` suelto como campo de un estado

**Dónde:** `thor build` / `thor dev` · aviso.

## Qué pasó

Un `ThorState` tiene un campo `ValueNotifier` o `ChangeNotifier` que no es un `state(...)`. El campo no reacciona en el navegador.

## Por qué

El navegador solo escucha los campos `state(...)`: nadie escucha un notifier propio, así que un `Watch` o un `ValueListenableBuilder` sobre él nunca se actualiza.

## Cómo se arregla

Haz el campo un `state(...)`: un `StateSignal` es un `ValueNotifier` (`addListener` y `ValueListenableBuilder` funcionan sobre él) y reacciona en el navegador.

```dart
// WRONG
final count = ValueNotifier<int>(0);
```

```dart
// RIGHT
final count = state(0);
```

Más en [Estado](../guia/es/estado.md#valuenotifier-y-valuelistenablebuilder).

[Todos los códigos](README.md)
