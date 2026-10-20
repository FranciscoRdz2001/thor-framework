# El comando thor

`thor` crea el proyecto, lo ejecuta mientras escribes, agrega páginas y ViewModels, ejecuta las pruebas y compila la versión de producción.

:::flutter Flutter: `flutter create`, `flutter run`, `flutter build` · Thor: `thor create`, `thor dev`, `thor build`

## Los comandos

```bash
dart pub global activate --source path <thor>/packages/thor_cli
thor <command> [arguments] [options]
```

`<thor>` es tu copia del repositorio de Thor ([Instalación](instalacion.md)). `thor --help` lista los comandos y `thor help <command>` muestra las opciones de uno.

| Comando | Qué hace |
|---|---|
| [`thor create`](#thor-create) | crea una app lista para ejecutar |
| [`thor dev`](#thor-dev) | ejecuta la app y la actualiza en cada cambio |
| [`thor add`](#thor-add) | agrega una página, un layout, un ViewModel o un componente |
| [`thor test`](#thor-test) | ejecuta las pruebas de la app |
| `thor analyze`, `thor format` | analizan y formatean el proyecto con las reglas de Thor ([Análisis y editor](#análisis-y-editor)) |
| [`thor build`](#thor-build), [`thor export`](#thor-export) | compilan la versión de producción o un sitio estático |
| `thor preview`, `thor deploy init` | sirven la versión compilada y escriben la configuración de un hosting ([Compilar y publicar](#compilar-y-publicar)) |
| [`thor render`](#thor-render), [`thor mcp`](#thor-mcp) | inspeccionan una página sin abrir el navegador, también para agentes de IA |
| [`thor doctor`](#thor-doctor), [`thor fonts`](#thor-fonts) | revisan el entorno y recortan fuentes |

Un proyecto de Thor es un paquete de Dart que depende de `thor_ui`. Sin argumento, cada comando usa el proyecto de la carpeta actual o el más cercano hacia arriba, así que `thor dev` funciona desde `lib/modules/home/`. `dev`, `build`, `export`, `preview`, `deploy init` y `doctor` aceptan la ruta del proyecto (`thor dev ../shop`); `add` y `render` usan `--project` o `--app`. Un comando que falla termina con un código distinto de 0 y explica qué hacer.

## Crear y desarrollar

### `thor create`

```bash
thor create shop
thor create sites/blog --title "My blog"
thor create demo --git <url> --ref master
```

Crea una app con servidor, lista para `thor dev`, resuelve las dependencias y agrega `analysis_options.yaml` con las reglas de Thor y `.github/workflows/ci.yml` ([Estructura del proyecto](estructura.md)).

| Opción | Por defecto | Qué hace |
|---|---|---|
| `--title <text>` | `Hello, Thor` | el título de la página de inicio |
| `--git <url>` | | toma Thor de ese repositorio en lugar de tu copia local |
| `--ref <branch>` | `master` | rama, tag o commit de `--git` |
| `--[no-]pub` | `--pub` | resuelve las dependencias al terminar |

El nombre sigue las reglas de un paquete de Dart: minúsculas, dígitos y `_`, empezando por una letra. Si la carpeta existe y no está vacía, no escribe nada. Sin `--git`, Thor sale de la copia desde la que corre el comando; `THOR_HOME=~/src/thor thor create shop` elige otra.

### `thor dev`

```bash
thor dev
thor dev --port 5000
thor dev --host                           # the phone opens http://192.168.1.20:4300
thor dev --allowed-host my-app.ngrok.app  # behind a tunnel
```

Ejecuta la app y la mantiene actualizada: al guardar un archivo de `lib/`, `bin/`, `web/` o de un paquete local, el servidor se recarga en caliente y el navegador recarga la página. Si un cambio no admite la recarga en caliente, como uno en `bin/`, el proceso se reinicia y la consola indica el motivo. Ctrl-C detiene todo lo que arrancó.

Imprime `✓ http://localhost:…` solo cuando la app ya escucha. Si la primera compilación falla (el código no compila, la app termina), imprime `✗ http://localhost:…  is up but the app is not running: …` y la página muestra el error; guarda un arreglo y se recupera.

| Opción | Por defecto | Qué hace |
|---|---|---|
| `-p`, `--port <n>` | `4300` | el puerto preferido; si está ocupado, el siguiente libre |
| `-w`, `--watch <folder>` | | reinicia también al cambiar esa carpeta; se puede repetir |
| `--host [<address>]` | solo este equipo | escucha en esa dirección; sin valor, en toda la red (`0.0.0.0`) |
| `--allowed-host <name>` | | acepta también ese nombre de host: un túnel o un dominio de desarrollo |
| `--no-reload` | | reinicia el servidor en cada cambio en lugar de recargarlo |

Un error en un `load`, una acción o un `build` cubre la página con el archivo, la línea, la corrección y el enlace a su [código `THOR-*`](../../errores/README.md); al guardar el arreglo, el aviso desaparece. **Alt+clic** (Option en Mac) sobre un elemento abre en el editor el widget de tu app que lo construyó; `THOR_EDITOR=vscode|cursor|zed|idea` elige el editor. Si embebes la app en otra página y quieres mostrar tú los errores, `THOR_OVERLAY=off` no dibuja nada: cada página conserva `window.__thorDevErrors` (los errores del servidor y los no capturados del navegador) y emite el evento `thor:dev-errors` en `window` cuando cambia.

Al recargar, la página conserva los valores de cada ViewModel, los campos de formulario (nunca las contraseñas) y el scroll. Si cambiaste la clase, un campo nuevo toma su valor inicial y uno eliminado o de otro tipo se descarta.

> **Cuidado:** `thor dev` solo responde a `localhost` y a direcciones IP, porque sus páginas de error muestran tu código fuente. `--host` abre el puerto a tu red; un nombre ajeno, como un túnel, necesita `--allowed-host`.

## `thor add`

```bash
thor add page /sales/orders/:id:int
thor add layout Sales --module sales
thor add styles sales --module sales
thor add state Cart --module sales
thor add component StatusChip --module sales
```

Crea el archivo en su lugar y nunca reemplaza uno existente. Todos aceptan `--module <module>` y `--project <path>`.

| Comando | Crea |
|---|---|
| `thor add page /about` | `lib/modules/about/pages/about_page.dart` y su ruta en el grupo del módulo; con `:id:int`, también un `load` que lee el parámetro |
| `thor add layout Sales --module sales`, `thor add styles sales --module sales` | `lib/modules/sales/sales_layout.dart` o `sales_styles.dart`, para `Group(layout:)` o `Group(styles:)` |
| `thor add error`, `thor add not_found` | la página de error o 404, para `Group(error:)` o `Group(notFound:)` |
| `thor add middleware session` | `lib/core/middleware/session.dart`, para `Group(middleware:)` |
| `thor add state Cart --module sales` | `lib/modules/sales/state/cart_view_model.dart`: `CartViewModel` y su instancia `cart` |
| `thor add component StatusChip --module sales` | `lib/modules/sales/widgets/status_chip.dart` y su prueba |

Con `--module`, la página de error, la 404, el middleware y la hoja de estilos también se conectan al `Group` del módulo; si el grupo ya tiene uno, el comando indica la línea que hay que cambiar. La tabla de rutas está en [Rutas y navegación](navegacion.md).

## `thor test`

```bash
thor test test/cart_test.dart -N "adds a line"   # one test by name
thor test -t slow -x network -j 2                # tags, in parallel
thor test --record                               # MockTransport.recorded calls the real backend
```

Ejecuta `dart test` sobre `test/**_test.dart`, o sobre los archivos que indiques, con los ViewModels de la app registrados. Las demás opciones pasan tal cual a `dart test`.

| Opción | Qué hace |
|---|---|
| `-a`, `--app <project>` | el proyecto, si no es el actual |
| `--no-codegen` | no prepara nada antes, útil cuando `thor dev` ya está en marcha |
| `--record` | permite que `MockTransport.recorded` guarde las respuestas reales en `test/fixtures` |

Cómo escribir las pruebas: [Pruebas](pruebas.md).

## Compilar y publicar

| Comando | Qué hace |
|---|---|
| `thor build` | compila la versión de producción |
| `thor export` | exporta una app con servidor como sitio estático |
| `thor preview [project] [--port <n>]` | sirve la versión compilada en `http://localhost:4400`, como lo haría el hosting |
| `thor deploy init <target>` | escribe la configuración de `docker`, `fly`, `railway`, `render`, `cloudflare-pages`, `vercel` o `netlify`; no reemplaza archivos sin `--force` |

Qué publicar y dónde: [Compilar y publicar](publicar.md).

### `thor build`

```bash
thor build [project] [--no-flutter] [--[no-]share-styles]
```

Una app con servidor (con `bin/server.dart`) deja en `build/` el servidor compilado a un ejecutable nativo (`server`), los archivos públicos con las variantes de las imágenes (`public/`) y `run.sh`, que lo arranca con los ajustes de producción. Una app estática renderiza cada página en `build/site/`, una por idioma. Si un ViewModel usa algo que el navegador no puede ejecutar, la compilación se detiene con [THOR-B012](../../errores/THOR-B012.md), el archivo y la línea.

Un ejecutable nativo no resuelve URIs `package:` ni tiene un SDK de Dart al lado. Lo que el servidor lee en ejecución se declara en un pubspec (el de la app o el de un paquete) y `thor build` lo copia a `build/resources/`:

```yaml
thor:
  resources:      # paths relative to lib/: files or folders
    - assets
  sdk: true       # also bundles the Dart SDK libraries (for the analyzer)
```

```dart
final bridge = await thorResource('package:my_pkg/assets/bridge.js'); // a File
final sdk = thorDartSdkPath(); // pass it to AnalysisContextCollection(sdkPath:)
```

`thorResource` es la misma llamada con `thor dev` y en `build/server` (también `THOR_RESOURCES`, una carpeta que reemplaza a `build/resources/`).

| Opción | Qué hace |
|---|---|
| `--no-flutter` | publica la app de Flutter embebida que ya está en `web/flutter/`, sin compilarla ([Flutter embebido](flutter-embebido.md)) |
| `--[no-]share-styles` | reúne los estilos que comparten las páginas en una hoja con caché |

### `thor export`

```bash
thor export --base-url https://docs.example.com
```

Ejecuta el `bin/export.dart` de la app, que elige las páginas y llama a `exportSite`, y escribe el resultado en `build/site/`. Falla si una página no responde 200 o si un enlace interno o un ancla no llevan a ninguna parte. `--base-url` es la URL pública con la que se escriben `sitemap.xml` y `robots.txt`.

## Inspeccionar una página

### `thor render`

```bash
thor render /articles?page=2
thor render /account --cookie session=…         # with a session
thor render --widget lib/ui/card.dart#Card      # a single widget, inside ThorApp
thor render / --report page.json                # everything as data, to a file
```

Ejecuta la app, pide la ruta y la detiene. Informa el estado y el tamaño del HTML y del CSS, los errores con su código `THOR-*`, los avisos de layout con el archivo y la línea, la consola del navegador, el árbol de accesibilidad y capturas en cada ancho (`--widths 390,800,1440`). Las capturas y el árbol del navegador necesitan [Playwright](https://playwright.dev) (`npm install playwright` en la carpeta del proyecto); sin él, informa el resto.

### `thor mcp`

Expone `thor render` y las páginas de error como un servidor [MCP](https://modelcontextprotocol.io), para que un agente de IA vea lo que construyó. Sus herramientas son `render` y `error_code`. Regístralo en tu agente como un servidor MCP por stdio; con la configuración JSON habitual:

```json
{
  "mcpServers": {
    "thor": { "command": "thor", "args": ["mcp", "--app", "."] }
  }
}
```

## Mantenimiento

### `thor doctor`

```bash
thor doctor [project] [--fix] [--fetch]
```

Revisa lo que impediría arrancar la app y explica cómo arreglarlo: la versión de Dart, las dependencias, la tabla de rutas, la carpeta `web/`, la caché de compilación, tu copia de Thor (`--fetch` la compara con el repositorio) y el puerto 4300. `--fix` aplica las correcciones seguras. Termina con 0 si todo está listo.

> **Consejo:** Ejecuta `thor doctor` después de actualizar Thor: avisa si una versión nueva exporta un nombre que tu app ya declara, con la línea `hide` que lo resuelve.

### `thor fonts`

```bash
thor fonts subset <font> --unicodes latin [--out <file>]
thor fonts subset <font> --icons <family>
thor fonts metrics <font> [--fallback <file>] [--json]
```

`subset` recorta una fuente a `woff2` con los caracteres que usas, o con `--icons`, con los íconos de esa familia que usa tu `lib/`; necesita fontTools (`pip install fonttools brotli`). `metrics` calcula los valores de `FontFallback` para que el texto no se desplace mientras carga la fuente ([Tema y estilos](tema-y-estilos.md)).

## Análisis y editor

`thor analyze` ejecuta `dart analyze --fatal-infos` desde la raíz del proyecto o del workspace, que es donde corren las reglas de Thor; `thor format` formatea el proyecto y `thor format --check` falla en CI si hay cambios pendientes. Las mismas reglas aparecen en el editor mientras escribes.

### Reglas de Thor

`thor_lints` es un plugin del analizador que `thor create` activa en `analysis_options.yaml`. Para silenciar una regla en una línea, escribe `// ignore: thor_lints/<rule>` con el motivo en la línea anterior.

Reglas del ViewModel:

| Regla | Qué marca |
|---|---|
| `state_callback_closure`, `state_watch_closure` | un closure donde el navegador necesita un método del ViewModel ([THOR-S011](../../errores/THOR-S011.md)) |
| `state_instance_not_top_level` | un ViewModel creado dentro de un widget ([THOR-S012](../../errores/THOR-S012.md)) |
| `frozen_state_read`, `stateful_set_state` | un `.value` leído en `build` ([THOR-S015](../../errores/THOR-S015.md)) o un `setState` ([THOR-S014](../../errores/THOR-S014.md)), que no cambian nada en el navegador |
| `row_server_read` | un método del ViewModel que lee `row.key` en el servidor dentro del `each` de `Watch.list` |
| `watch_field_with_builder` | un campo pasado tal cual a `Watch` con `builder`, que el compilador tipa como `Object?` |
| `query_builder_reads_data`, `future_builder_nullable_has_data` | `snapshot.data` de un `QueryBuilder` leído en el servidor, o un `FutureBuilder<T?>` que distingue la espera solo con `hasData` |

Reglas de widgets, formularios y accesibilidad:

| Regla | Qué marca |
|---|---|
| `animated_switcher_without_watch` | un `AnimatedSwitcher` sin un `Watch` que cambie su hijo |
| `untyped_form_action` | una acción de formulario escrita como texto o closure en lugar de un método de la página |
| `widget_props_in_styled`, `length_unit_in_const` | en `Styled`, un valor que ya pone un widget de Flutter, como `padding`; o una unidad como `8.px` dentro de un `const` |
| `icon_button_without_name`, `text_field_without_label` | un botón de ícono o un campo de texto sin nombre para el lector de pantalla |
| `env_var_not_in_schema` | una variable de entorno que falta en su `EnvSchema` ([THOR-P011](../../errores/THOR-P011.md)) |

### Asistencias del editor

Con el cursor en el nombre de un widget, `Cmd+.` (o `Ctrl+.`) ofrece las mismas asistencias que Dart da para Flutter, también para los widgets de Thor y los tuyos.

| Asistencia | Resultado |
|---|---|
| Wrap with widget... | `widget(child: …)`, con el nombre listo para escribir |
| Wrap with Padding, Center, Container, SizedBox, Expanded, Semantics, Link… | el widget como `child:` del elegido |
| Wrap with Column / Row | el widget dentro de `children: [...]` |
| Wrap with Watch | `Watch(source, builder: (value) => …)` |
| Remove this widget | lo reemplaza por su `child:` o sus `children:` |
| Swap with child / parent, Move widget up / down | intercambia el widget con su hijo o su padre, o lo mueve en `children:` |

## Siguientes pasos

:::cards
- [Estructura del proyecto](estructura.md) — dónde va cada archivo que crean los comandos
- [Pruebas](pruebas.md) — escribir las pruebas que ejecuta `thor test`
- [Compilar y publicar](publicar.md) — publicar lo que produce `thor build`
:::
