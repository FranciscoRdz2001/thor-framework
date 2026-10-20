# Qué corre dónde

Thor renderiza tus widgets como HTML y CSS en el servidor; el navegador hace el layout y la animación, y un script pequeño actualiza lo que cambia.

:::flutter Flutter: Flutter dibuja cada cuadro en un lienzo · Thor: cada widget es un elemento HTML

## Las capas

Cada capa del [resumen de arquitectura de Flutter](https://docs.flutter.dev/resources/architectural-overview) tiene un equivalente en Thor, con otro responsable.

| En Flutter | En Thor | Quién lo hace |
|---|---|---|
| Widgets: `StatelessWidget`, `Row`, `Padding` | los mismos, con la misma API | tú, en Dart |
| Rendering: `RenderBox`, restricciones, layout | un elemento por widget, con el layout del navegador | el navegador |
| Animación: `AnimationController`, tickers | transiciones de CSS | el navegador |
| Estado: `setState`, `ChangeNotifier` | un ViewModel (`ThorState`) y `Watch` | tú, en Dart; se ejecuta en el navegador |
| Embedder: la plataforma que llama a `runApp` | `ThorServer` y su `RouteHandler` | el servidor |

Por eso ningún tamaño se mide en Dart, el estado es una clase con métodos con nombre y una página sin ViewModel no envía JavaScript.

## El camino de una página

:::steps
### Al compilar

`thor build` y `thor dev` preparan lo que la app necesita antes de la primera petición:

- cada ViewModel, listo para el navegador; si usa algo que el navegador no puede ejecutar, la compilación se detiene con el archivo y la línea ([THOR-B012](../../errores/THOR-B012.md));
- las imágenes de `web/images/` en WebP, y en AVIF si lo pides, a varios anchos;
- los estilos compartidos, con un hash de su contenido;
- el servidor, compilado a un ejecutable.

La tabla de rutas no se genera: es código (`ThorRouter`) que el servidor comprueba al arrancar.

### En el servidor

Cada petición pasa por su ruta, el middleware, la caché de página, la acción si es un `POST` y los `load`, y termina en el render. El render convierte cada widget en un elemento HTML con una clase y escribe en línea solo el CSS que la página no comparte. La cabecera `Link` anuncia las hojas de estilo, las fuentes y la imagen principal mientras el servidor espera los datos.

### En el navegador

La página llega completa, como HTML semántico con su CSS, y se ve antes de cualquier script. El navegador hace el layout, anima con CSS y abre diálogos, menús y acordeones con sus elementos nativos. Los enlaces y los formularios funcionan sin JavaScript.

### Con un ViewModel

Si la página usa un ViewModel, un script pequeño carga cuando el navegador queda libre y lo conecta al HTML que ya está en la página. No reconstruye nada: actualiza el texto, la variante o las filas que dependen de cada valor.
:::

## Cómo se conecta el estado

El servidor no envía un árbol de widgets: envía HTML en el que cada elemento que depende de un ViewModel queda ligado a un miembro de tu clase, como `Watch(counter.label)` u `onPressed: counter.increment`. El navegador solo llama a los métodos que declaraste en un `ThorState` y nunca evalúa código recibido con la página. Como el resto es HTML nativo, la página funciona antes de que cargue el script, o si no llega.

## Dónde corre cada tarea

| Tarea | Dónde corre | Por qué |
|---|---|---|
| Layout, tamaños, diseño responsivo | el navegador | no hace falta medir nada en Dart |
| Animaciones | el navegador, con transiciones de CSS | se ejecutan sin JavaScript |
| Datos de la página | el servidor (`load`) | la página llega con sus datos, sin peticiones en cascada desde el navegador |
| Formularios | el servidor (acción y esquema) y el navegador (validación nativa) | funcionan sin JavaScript; el script solo mejora los mensajes |
| Estilos | la compilación y el servidor | el navegador nunca genera CSS |
| Estado que cambia sin recargar | el navegador, con el script | es lo único que necesita JavaScript |

## Siguientes pasos

:::cards
- [Estado](estado.md) — `Watch`, listas y lo que cabe en un ViewModel
- [Tema y estilos](tema-y-estilos.md) — una clase por elemento y el tema de la app
- [Flutter embebido](flutter-embebido.md) — una vista de Flutter dentro de una página de Thor
:::
