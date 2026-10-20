# Flutter embebido

`FlutterView` coloca una app de Flutter web en una región de una página de Thor, como una gráfica, un editor o un juego, y el resto de la página sigue siendo HTML indexable.

:::flutter Flutter: `HtmlElementView` dentro de una app · Thor: `FlutterView` dentro de una página

```dart
FlutterView(
  src: '/flutter/', // the folder of the Flutter build
  initialData: {'view': 'chart', 'values': [12, 19, 7]},
  aspectRatio: 16 / 9, // or height: 320
  semanticLabel: 'Sales per month',
  placeholder: const Center(child: Text('Sales: Jan 12 · Feb 19 · Mar 7')),
  onMessage: sales.tapped, // a method of a view model
)
```

## Carga de la vista

El servidor renderiza una caja con su tamaño final y el `placeholder` dentro. Sin JavaScript, el `placeholder` es el contenido: pon ahí la versión en HTML de lo que dibuja Flutter, como los números de la gráfica.

Con la primera vista, un cargador de menos de 1 KB descarga el build de Flutter. Una sola app de Flutter atiende todas las vistas de la página, y cada `FlutterView` es una vista nueva con su `initialData`. El `placeholder` se retira cuando la vista dibuja su primer cuadro, sin cambiar el tamaño de la caja; si el build no carga, se queda.

| `loading` | La vista se monta |
| --- | --- |
| `visible` (por omisión) | cuando está a 200 px de la pantalla |
| `idle` | cuando el navegador queda libre después de cargar la página |
| `interaction` | con el primer toque, foco o tecla dentro; ese toque no llega a Flutter |
| `eager` | al cargar la página, solo si la vista es el motivo de la página |

## Tamaño

Una vista de Flutter no se mide por su contenido: indica `height` o `aspectRatio`. El ancho es `width` o todo el disponible, nunca más que el padre. Sin alto, o con un tamaño `0`, negativo o infinito, la página falla al renderizar.

## El proyecto de Flutter

El proyecto de Flutter usa `runThorEmbed` en lugar de `runApp` y construye un widget por vista. `runThorEmbed` está en `thor_embed.dart`, un archivo que solo depende de `package:web`: cópialo en la carpeta `lib/` del proyecto desde [El archivo de arranque](#el-archivo-de-arranque).

```dart no-check
void main() {
  runThorEmbed((context, embed) => MaterialApp(
    home: switch (embed.map['view']) {
      'chart' => BarChart(embed: embed),
      _ => const SizedBox(),
    },
  ));
  SemanticsBinding.instance.ensureSemantics(); // accessibility from the start
}
```

`runThorEmbed` crea una `View` por cada vista de la página, expone su `initialData` en `embed.data` (o `embed.map`) y avisa a la página después del primer cuadro.

### Mensajes a la página

`embed.send({'bar': 'apr'})` llega a `FlutterView(onMessage:)` como un `String` con el JSON. Con un método de un ViewModel (`ThorState`), el mensaje puede cambiar el resto de la página:

```dart
class SalesViewModel extends ThorState {
  final last = state('');

  void tapped(String json) => last.value = json;
}
```

> **Importante:** Trata el mensaje como datos de otro programa: un JSON inesperado no debe romper la página. Los mensajes que llegan antes de que arranque el ViewModel se pierden, y de la página hacia Flutter solo viaja `initialData`.

### El archivo de arranque

```dart no-check
// lib/thor_embed.dart
/// The Flutter side of thor's `FlutterView`: one Flutter app that draws a
/// widget in every host element a thor page adds as a view.
///
/// Copy this file into your Flutter project (it only needs `package:web`).
/// The page's loader adds one view per `FlutterView` with the JSON of its
/// `initialData`; this file reads it back, tells the page when the view
/// painted its first frame (the placeholder goes away then) and sends
/// messages to the page (`FlutterView(onMessage:)`).
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui' show FlutterView;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Event the host element receives after the view's first frame.
const readyEvent = 'thor-flutter-ready';

/// Event (bubbling, `detail` = a JSON string) with a message for the page.
const messageEvent = 'thor-flutter-message';

/// What a view knows about its place in the page.
class ThorEmbed {
  ThorEmbed._(this.viewId, this.data, this._host);

  /// The Flutter view's id.
  final int viewId;

  /// The `initialData` of the page's `FlutterView` (decoded JSON), or null.
  final Object? data;

  final web.Element? _host;

  /// [data] as a map (empty when it is not one).
  Map<String, Object?> get map =>
      data is Map ? (data! as Map).cast<String, Object?>() : const {};

  /// Sends [message] (JSON-encodable) to the page: `FlutterView(onMessage:)`
  /// receives it as a JSON string once the page's engine is running.
  void send(Object? message) {
    _host?.dispatchEvent(
      web.CustomEvent(
        messageEvent,
        web.CustomEventInit(detail: jsonEncode(message).toJS, bubbles: true),
      ),
    );
  }

  /// The [ThorEmbed] of the view [context] is in.
  static ThorEmbed of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_EmbedScope>()!.embed;
}

/// Runs [builder] in every view the page adds (use it instead of `runApp`).
void runThorEmbed(
  Widget Function(BuildContext context, ThorEmbed embed) builder,
) {
  runWidget(_MultiView(builder: builder));
}

class _MultiView extends StatefulWidget {
  const _MultiView({required this.builder});

  final Widget Function(BuildContext context, ThorEmbed embed) builder;

  @override
  State<_MultiView> createState() => _MultiViewState();
}

class _MultiViewState extends State<_MultiView> with WidgetsBindingObserver {
  Map<Object, Widget> _views = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _update();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Views are added and removed from JS; Flutter reports it as a change of
  // metrics.
  @override
  void didChangeMetrics() => setState(_update);

  void _update() {
    _views = {
      for (final FlutterView view
          in WidgetsBinding.instance.platformDispatcher.views)
        view.viewId: _views[view.viewId] ?? _create(view),
    };
  }

  Widget _create(FlutterView view) {
    final id = view.viewId;
    final host = ui_web.views.getHostElement(id) as web.Element?;
    final embed = ThorEmbed._(
      id,
      ui_web.views.getInitialData(id).dartify(),
      host,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The frame is on screen after the next animation frame.
      web.window.requestAnimationFrame(
        ((JSNumber _) => host?.dispatchEvent(web.Event(readyEvent))).toJS,
      );
    });
    return View(
      view: view,
      child: _EmbedScope(
        embed: embed,
        child: Builder(builder: (context) => widget.builder(context, embed)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      ViewCollection(views: _views.values.toList(growable: false));
}

class _EmbedScope extends InheritedWidget {
  const _EmbedScope({required this.embed, required super.child});

  final ThorEmbed embed;

  @override
  bool updateShouldNotify(_EmbedScope old) => false;
}
```

## Compilar

Declara el proyecto de Flutter en el `pubspec.yaml` de la app:

```yaml
thor:
  flutter:
    project: flutter_widgets # the folder of the Flutter project
    public: flutter          # published at /flutter/ (the default)
    cdn: false               # true: CanvasKit from gstatic.com
```

`thor build` ejecuta `flutter build web --release` en ese proyecto y deja el resultado en `web/flutter/`, que se publica con los demás archivos públicos. Busca Flutter en `FLUTTER_ROOT` o en el `PATH`; `thor build --no-flutter` reutiliza el build existente.

- `thor dev` sirve `web/`: después de un `thor build`, las vistas funcionan en desarrollo; sin build, se ven los `placeholder`.
- Si el proyecto no tiene `web/flutter_bootstrap.js`, `thor build` escribe el de Thor; con `flutter run`, ese bootstrap dibuja una vista sola para desarrollar el widget por separado.
- El proyecto de Flutter no forma parte del workspace de Dart de la app, porque necesita el SDK de Flutter.

Flutter web descarga la app compilada y CanvasKit, varios megabytes por usuario la primera vez. Por eso `visible` es el valor por omisión y el resto de la página no espera.

## Seguridad

- `initialData` se escapa al renderizar y llega igual a Flutter. Un valor que no se puede codificar como JSON, como un `DateTime`, falla al renderizar.
- Con Content Security Policy, autoriza el cargador por su hash `sha256-…` y agrega `'wasm-unsafe-eval'` a `script-src`; con `cdn: true` o las fuentes por omisión de Flutter, también `https://www.gstatic.com` y `https://fonts.gstatic.com` ([Sesión y seguridad](sesion-y-seguridad.md#content-security-policy)).
- Una página ejecuta una sola app de Flutter: dos `FlutterView` con `src` distintos fallan al renderizar.

## Accesibilidad

`semanticLabel` convierte la caja en una región con ese nombre, marcada como ocupada mientras carga. Dentro, el árbol de semántica de Flutter expone botones y textos reales; `SemanticsBinding.instance.ensureSemantics()` lo activa desde el inicio. El `placeholder` es lo que lee un lector de pantalla sin JavaScript: debe decir lo mismo que la vista.

## Límites

- `FlutterView` necesita `ThorApp`: sin él, la caja se renderiza pero la vista no carga.
- Las vistas no se retiran: cada navegación carga una página nueva.
- Los archivos de Flutter no llevan un hash en el nombre: configura su caché en el hosting o publica cada versión en su propia carpeta (`src: '/flutter-v2/'`).

## Siguientes pasos

:::cards
- [Estado](estado.md) — el ViewModel que recibe los mensajes de Flutter
- [Compilar y publicar](publicar.md) — caché y cabeceras en el hosting
- [Qué corre dónde](como-funciona.md) — lo que Thor envía al navegador
:::
