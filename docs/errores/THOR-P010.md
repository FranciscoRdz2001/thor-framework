# THOR-P010 · Una cookie después de la respuesta temprana

**Dónde:** `thor_server` · `RouteHandler` (una ruta con `earlyHints`).

## Qué pasó

Una página con `earlyHints` tardó más que `earlyHintsAfter` en cargar sus datos: el servidor ya mandó el estado y los encabezados (con los `Link` de sus hojas) y, después, un `load` o el `build` puso una cookie.

## Por qué

Las cookies viajan en los encabezados, y los encabezados ya salieron. La cookie no llega al navegador: el servidor lo reporta y la descarta.

## Cómo se arregla

Pon la cookie antes de la respuesta: en un middleware del grupo (`Group(middleware:)`), en un guard o en una acción. O quita `earlyHints` de ese grupo.

```dart
// WRONG: en PanelPage, dentro de Group(earlyHints: true, …)
@override
Future<Panel> load(PageRequest request) async {
  request.response.setCookie('seen', '1');
  return api.panel();
}
```

```dart
// RIGHT: un middleware del grupo, Group(middleware: [markSeen], …)
Future<ThorResponse> markSeen(PageRequest request, Next next) {
  request.response.setCookie('seen', '1');
  return next();
}
```

[Todos los códigos](README.md)
