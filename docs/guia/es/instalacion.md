# Instalación

Instala el comando `thor`, crea una app y ábrela en el navegador. Necesitas Dart y un editor.

> **Nota:** Thor está en la versión 0.1 y todavía no se publica en pub.dev. El comando `thor` se instala desde una copia local del repositorio, y cada proyecto nuevo usa esa copia.

## Requisitos

| Necesitas | Comprueba con |
|---|---|
| Dart 3.10 o superior (el de Flutter sirve) | `dart --version` |
| git | `git --version` |
| `~/.pub-cache/bin` en tu `PATH` | `thor --help`, después de instalar |

## Instalar y crear una app

Clona el repositorio, activa el comando y crea la app. `thor dev` la sirve en `http://localhost:4300`, o en el siguiente puerto libre.

:::bench bench-start-install
:::

| Opción de `thor create` | Efecto |
|---|---|
| `--git <url>` | toma Thor de un repositorio de git en lugar de tu copia local; es la opción para un proyecto que se comparte o se publica |
| `--title 'My store'` | cambia el título de la página de inicio |

Con `thor dev` en marcha, edita `lib/modules/home/pages/home_page.dart` y guarda: la página abierta se actualiza.

## Archivos del proyecto

:::files
my_app/
  .github/workflows/ci.yml   integración continua: formato, análisis y pruebas
  bin/
    server.dart   el servidor
  lib/
    app.dart   el tema y la app
    env.dart   las variables de entorno
    router.dart   la tabla de rutas
    shell/   el marco de las páginas y la página de error
    core/   lo que comparten varios módulos
    modules/
      home/   la página de inicio, su ruta y un contador de ejemplo
  web/   archivos públicos
  test/   pruebas
  pubspec.yaml
:::

La organización completa está en [Estructura del proyecto](estructura.md).

## Configurar el editor

| Qué | Cómo |
|---|---|
| Dart | la extensión de Dart de tu editor (VS Code, Cursor, IntelliJ, Zed) |
| Reglas de Thor | ya activas: `thor create` las agrega a `analysis_options.yaml` y el editor marca lo que no funciona en el navegador, con su código `THOR-*` |
| Del navegador al código | con `thor dev`, **Alt+clic** (Option en Mac) sobre un elemento abre el archivo que lo construyó; `THOR_EDITOR=cursor` elige el editor |

## Variables de entorno

`lib/env.dart` declara las variables con su tipo; los valores van en `.env`, en la raíz de la app, que `thor create` agrega a `.gitignore`.

```ini
# .env
API_URL=https://api.example.com
SESSION_SECRET=a-long-key-of-at-least-32-characters
```

`thor dev` y `thor preview` leen `.env`. Si falta una variable, el servidor no arranca y lista todas las que faltan ([THOR-P011](../../errores/THOR-P011.md)). Los tipos y la protección de secretos están en [Sesión y seguridad](sesion-y-seguridad.md).

## Integración continua

`thor create` escribe `.github/workflows/ci.yml`, que instala `thor` y ejecuta el formato, `dart analyze --fatal-infos` y `thor test`. CI solo puede instalar Thor desde un repositorio: crea el proyecto con `--git <url>` o apunta la dependencia de `pubspec.yaml` a un repositorio.

> **Consejo:** `thor analyze` y `thor format --check` ejecutan en tu equipo las mismas comprobaciones que CI.

## Comandos frecuentes

| Comando | Qué hace |
|---|---|
| `thor dev` | ejecuta la app y la actualiza en cada cambio |
| `thor test` | ejecuta las pruebas |
| `thor analyze` | analiza el proyecto con las reglas de Thor |
| `thor build` | compila la versión de producción |
| `thor preview` | sirve la versión compilada en `http://localhost:4400` |
| `thor doctor --fix` | revisa el SDK y el proyecto, y aplica las correcciones seguras |

Cada comando y sus opciones están en [El comando thor](cli.md).

## Siguientes pasos

:::cards
- [Tu primera app](primera-app.md) — una tienda con carrito, formulario y rutas, de principio a fin
- [Si vienes de Flutter](desde-flutter.md) — la equivalencia de cada API de Flutter en Thor
- [El comando thor](cli.md) — cada comando y sus opciones
:::
