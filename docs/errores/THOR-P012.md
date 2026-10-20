# THOR-P012 · Un secreto del entorno llegó a una página

**Dónde:** `thor_server` · `RouteHandler` (con `thor dev`) y `exportSite` (siempre).

## Qué pasó

El cuerpo o los encabezados de una respuesta contienen el valor de un `EnvSecret` cargado. Con `thor dev` la respuesta es un `500` que no muestra el valor; al exportar un sitio estático, el export se detiene.

## Por qué

Lo que llega al HTML o al JS lo ve cualquiera y queda en cachés y en el historial del navegador. Un `Secret` ya no se imprime (`toString` da `***`) ni se convierte a JSON, pero `reveal()` sí da el texto: esta revisión atrapa el caso en que ese texto termina en una página.

## Cómo se arregla

Usa el secreto solo en el servidor, donde se necesita (firmar una cookie, un encabezado hacia el backend), y nunca lo pases a un widget, a un `ThorState` ni a `PageMeta`. Si el navegador necesita un valor, que sea una variable pública (`public: true`), no un secreto.

```dart
// WRONG
Text('key: ${env.of(AppEnv.apiKey).reveal()}')
```

```dart
// RIGHT: se queda en el servidor
client.get(url, headers: {'authorization': 'Bearer ${env.of(AppEnv.apiKey).reveal()}'});
```

[Todos los códigos](README.md)
