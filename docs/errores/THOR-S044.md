# THOR-S044 · Un origen de `postMessage` que no es explícito

**Dónde:** `thor_engine` · `FrameMessages.postToParent`, `postToFrame` y `listen`.

## Qué pasó

Se pidió enviar a, o escuchar de, un origen que no es `https://host[:puerto]` (o `http://…`): `'*'`, `'null'`, una ruta (`https://a.com/x`), un comodín, un puerto por defecto (`https://a.com:443`), mayúsculas, o una lista `origins` vacía.

## Por qué

`postMessage` con `'*'` entrega el mensaje a quien sea que esté en la ventana de destino, y escuchar sin mirar `origin` obedece a cualquier página que pueda abrir un marco. Thor no ofrece esa puerta: cada origen se escribe entero. El navegador escribe el origen sin puerto por defecto y en minúsculas, así que un origen escrito de otro modo nunca coincidiría con el de un evento.

## Cómo se arregla

```dart
// WRONG: cualquiera puede recibir el mensaje
FrameMessages.postToFrame('canvas', json, targetOrigin: '*');
```

```dart
// RIGHT: el origen exacto del marco
FrameMessages.postToFrame('canvas', json,
    targetOrigin: 'https://preview.example.com');
```

Más en [Interactividad](../guia/es/interactividad.md) (ventanas y marcos).

[Todos los códigos](README.md)
