# Qué es Thor

Thor renderiza widgets de Flutter como HTML semántico y CSS en el servidor. Aquí decides si encaja con tu app.

:::flutter Flutter: widgets dibujados en un lienzo propio · Thor: los mismos widgets, como HTML y CSS

## Un widget, una página

Escribes un `StatelessWidget` como en Flutter. Thor ejecuta su `build` en el servidor y envía al navegador un elemento HTML con su clase CSS.

:::example start-widget-to-web
:::

## Qué corre dónde

El código de los widgets corre en el servidor; el navegador hace el layout y actualiza solo lo que cambia.

| Parte de la app | Corre en | Qué hace |
|---|---|---|
| `build` de cada widget | servidor | renderiza el HTML y el CSS, una vez por petición |
| `load` de cada página | servidor | carga los datos antes de renderizar |
| layout, scroll y animaciones | navegador | se aplican con CSS, sin JavaScript |
| ViewModel (`ThorState`) | navegador | actualiza lo que cambia sin recargar la página |

El JavaScript solo llega a las páginas que usan un ViewModel. El detalle está en [Qué corre dónde](como-funciona.md).

## Thor o Flutter web

| Elige Thor si… | Elige Flutter web si… |
|---|---|
| el sitio debe indexarse: una tienda, un blog, documentación | la app dibuja cada píxel: un editor, un juego |
| necesitas texto seleccionable, enlaces, zoom y formularios nativos | necesitas el mismo render en móvil, escritorio y web |
| la primera pantalla debe mostrar contenido sin esperar al JavaScript | la app ya existe en Flutter y no conviene reescribirla |

Para combinar los dos, [Flutter embebido](flutter-embebido.md) coloca una app de Flutter dentro de una región de la página.

## Siguientes pasos

:::cards
- [Instalación](instalacion.md) — instala el comando `thor` y crea un proyecto
- [Tu primera app](primera-app.md) — una tienda con carrito, formulario y rutas, paso a paso
- [Si vienes de Flutter](desde-flutter.md) — la equivalencia de cada API de Flutter en Thor
:::
