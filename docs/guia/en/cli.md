# The thor command

`thor` creates the project, runs it while you write, adds pages and ViewModels, runs the tests and builds the production version.

:::flutter Flutter: `flutter create`, `flutter run`, `flutter build` · Thor: `thor create`, `thor dev`, `thor build`

## The commands

```bash
dart pub global activate --source path <thor>/packages/thor_cli
thor <command> [arguments] [options]
```

`<thor>` is your copy of the Thor repository ([Installation](installation.md)). `thor --help` lists the commands and `thor help <command>` shows the options of one.

| Command | What it does |
|---|---|
| [`thor create`](#thor-create) | creates an app ready to run |
| [`thor dev`](#thor-dev) | runs the app and updates it on every change |
| [`thor add`](#thor-add) | adds a page, a layout, a ViewModel or a component |
| [`thor test`](#thor-test) | runs the app's tests |
| `thor analyze`, `thor format` | analyze and format the project with Thor's rules ([Analysis and editor](#analysis-and-editor)) |
| [`thor build`](#thor-build), [`thor export`](#thor-export) | build the production version or a static site |
| `thor preview`, `thor deploy init` | serve the built version and write a hosting's configuration ([Build and deploy](#build-and-deploy)) |
| [`thor render`](#thor-render), [`thor mcp`](#thor-mcp) | inspect a page without opening the browser, also for AI agents |
| [`thor doctor`](#thor-doctor), [`thor fonts`](#thor-fonts) | check the environment and subset fonts |

A Thor project is a Dart package that depends on `thor_ui`. With no argument, each command uses the project in the current folder or the nearest one above it, so `thor dev` works from `lib/modules/home/`. `dev`, `build`, `export`, `preview`, `deploy init` and `doctor` accept the project path (`thor dev ../shop`); `add` and `render` use `--project` or `--app`. A command that fails exits with a non-zero code and explains what to do.

## Create and develop

### `thor create`

```bash
thor create shop
thor create sites/blog --title "My blog"
thor create demo --git <url> --ref master
```

Creates an app with a server, ready for `thor dev`, resolves the dependencies, and adds `analysis_options.yaml` with Thor's rules and `.github/workflows/ci.yml` ([Project structure](project-structure.md)).

| Option | Default | What it does |
|---|---|---|
| `--title <text>` | `Hello, Thor` | the home page title |
| `--git <url>` | | takes Thor from that repository instead of your local copy |
| `--ref <branch>` | `master` | branch, tag or commit of `--git` |
| `--[no-]pub` | `--pub` | resolves the dependencies when done |

The name follows the rules of a Dart package: lowercase letters, digits and `_`, starting with a letter. If the folder exists and is not empty, it writes nothing. Without `--git`, Thor comes from the copy the command runs from; `THOR_HOME=~/src/thor thor create shop` picks another one.

### `thor dev`

```bash
thor dev
thor dev --port 5000
thor dev --host                           # the phone opens http://192.168.1.20:4300
thor dev --allowed-host my-app.ngrok.app  # behind a tunnel
```

Runs the app and keeps it up to date: when you save a file in `lib/`, `bin/`, `web/` or a local package, the server hot-reloads and the browser reloads the page. If a change does not support hot reload, such as one in `bin/`, the process restarts and the console says why. Ctrl-C stops everything it started.

It prints `✓ http://localhost:…` only once the app listens. If the first build fails (the code does not compile, the app exits), it prints `✗ http://localhost:…  is up but the app is not running: …` instead and the page shows the error; save a fix and it recovers.

| Option | Default | What it does |
|---|---|---|
| `-p`, `--port <n>` | `4300` | the preferred port; if it is taken, the next free one |
| `-w`, `--watch <folder>` | | also restarts when that folder changes; can be repeated |
| `--host [<address>]` | this machine only | listens on that address; with no value, on the whole network (`0.0.0.0`) |
| `--allowed-host <name>` | | also accepts that host name: a tunnel or a development domain |
| `--no-reload` | | restarts the server on every change instead of reloading it |

An error in a `load`, an action or a `build` covers the page with the file, the line, the fix and the link to its [`THOR-*` code](../../errores/en/README.md); when you save the fix, the overlay disappears. **Alt+click** (Option on Mac) on an element opens, in the editor, the widget of your app that built it; `THOR_EDITOR=vscode|cursor|zed|idea` picks the editor. If you embed the app in another page and want to show the errors yourself, `THOR_OVERLAY=off` draws nothing: every page keeps `window.__thorDevErrors` (the server's errors and the browser's uncaught ones) and fires a `thor:dev-errors` event on `window` when it changes.

On reload, the page keeps each ViewModel's values, the form fields (never passwords) and the scroll position. If you changed the class, a new field takes its initial value, and a removed field or one of a different type is discarded.

> **Caution:** `thor dev` only responds to `localhost` and IP addresses, because its error pages show your source code. `--host` opens the port to your network; an outside name, such as a tunnel, needs `--allowed-host`.

## `thor add`

```bash
thor add page /sales/orders/:id:int
thor add layout Sales --module sales
thor add styles sales --module sales
thor add state Cart --module sales
thor add component StatusChip --module sales
```

Creates the file in its place and never replaces an existing one. All of them accept `--module <module>` and `--project <path>`.

| Command | Creates |
|---|---|
| `thor add page /about` | `lib/modules/about/pages/about_page.dart` and its route in the module's group; with `:id:int`, also a `load` that reads the parameter |
| `thor add layout Sales --module sales`, `thor add styles sales --module sales` | `lib/modules/sales/sales_layout.dart` or `sales_styles.dart`, for `Group(layout:)` or `Group(styles:)` |
| `thor add error`, `thor add not_found` | the error or 404 page, for `Group(error:)` or `Group(notFound:)` |
| `thor add middleware session` | `lib/core/middleware/session.dart`, for `Group(middleware:)` |
| `thor add state Cart --module sales` | `lib/modules/sales/state/cart_view_model.dart`: `CartViewModel` and its instance `cart` |
| `thor add component StatusChip --module sales` | `lib/modules/sales/widgets/status_chip.dart` and its test |

With `--module`, the error page, the 404, the middleware and the stylesheet are also wired into the module's `Group`; if the group already has one, the command points out the line to change. The route table is in [Routes and navigation](navigation.md).

## `thor test`

```bash
thor test test/cart_test.dart -N "adds a line"   # one test by name
thor test -t slow -x network -j 2                # tags, in parallel
thor test --record                               # MockTransport.recorded calls the real backend
```

Runs `dart test` on `test/**_test.dart`, or on the files you specify, with the app's ViewModels registered. Any other options are passed through to `dart test` as is.

| Option | What it does |
|---|---|
| `-a`, `--app <project>` | the project, if it is not the current one |
| `--no-codegen` | prepares nothing beforehand, useful when `thor dev` is already running |
| `--record` | lets `MockTransport.recorded` save the real responses in `test/fixtures` |

How to write the tests: [Testing](testing.md).

## Build and deploy

| Command | What it does |
|---|---|
| `thor build` | builds the production version |
| `thor export` | exports an app with a server as a static site |
| `thor preview [project] [--port <n>]` | serves the built version at `http://localhost:4400`, as the hosting would |
| `thor deploy init <target>` | writes the configuration for `docker`, `fly`, `railway`, `render`, `cloudflare-pages`, `vercel` or `netlify`; does not replace files without `--force` |

What to deploy and where: [Build and deploy](build-and-deploy.md).

### `thor build`

```bash
thor build [project] [--no-flutter] [--[no-]share-styles]
```

An app with a server (with `bin/server.dart`) leaves in `build/` the server compiled to a native executable (`server`), the public files with the image variants (`public/`) and `run.sh`, which starts it with the production settings. A static app renders each page into `build/site/`, one per language. If a ViewModel uses something the browser cannot run, the build stops with [THOR-B012](../../errores/en/THOR-B012.md), the file and the line.

A native executable resolves no `package:` URIs and has no Dart SDK beside it. What the server reads at run time is declared in a pubspec (the app's or a package's) and `thor build` copies it to `build/resources/`:

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

`thorResource` is the same call under `thor dev` and in `build/server` (also `THOR_RESOURCES`, a folder that replaces `build/resources/`).

| Option | What it does |
|---|---|
| `--no-flutter` | deploys the embedded Flutter app already in `web/flutter/`, without building it ([Embedded Flutter](embedded-flutter.md)) |
| `--[no-]share-styles` | gathers the styles the pages share into one cached stylesheet |

### `thor export`

```bash
thor export --base-url https://docs.example.com
```

Runs the app's `bin/export.dart`, which picks the pages and calls `exportSite`, and writes the result to `build/site/`. It fails if a page does not respond 200 or if an internal link or an anchor leads nowhere. `--base-url` is the public URL used to write `sitemap.xml` and `robots.txt`.

## Inspect a page

### `thor render`

```bash
thor render /articles?page=2
thor render /account --cookie session=…         # with a session
thor render --widget lib/ui/card.dart#Card      # a single widget, inside ThorApp
thor render / --report page.json                # everything as data, to a file
```

Runs the app, requests the route and stops it. It reports the status and the size of the HTML and CSS, errors with their `THOR-*` code, layout warnings with the file and line, the browser console, the accessibility tree and screenshots at each width (`--widths 390,800,1440`). The screenshots and the browser's tree require [Playwright](https://playwright.dev) (`npm install playwright` in the project folder); without it, it reports the rest.

### `thor mcp`

Exposes `thor render` and the error pages as an [MCP](https://modelcontextprotocol.io) server, so an AI agent can see what it built. Its tools are `render` and `error_code`. Register it in your agent as a stdio MCP server; with the usual JSON configuration:

```json
{
  "mcpServers": {
    "thor": { "command": "thor", "args": ["mcp", "--app", "."] }
  }
}
```

## Maintenance

### `thor doctor`

```bash
thor doctor [project] [--fix] [--fetch]
```

Checks what would keep the app from starting and explains how to fix it: the Dart version, the dependencies, the route table, the `web/` folder, the build cache, your copy of Thor (`--fetch` compares it with the repository) and port 4300. `--fix` applies the safe fixes. It exits with 0 if everything is ready.

> **Tip:** Run `thor doctor` after updating Thor: it warns if a new version exports a name your app already declares, with the `hide` line that resolves it.

### `thor fonts`

```bash
thor fonts subset <font> --unicodes latin [--out <file>]
thor fonts subset <font> --icons <family>
thor fonts metrics <font> [--fallback <file>] [--json]
```

`subset` trims a font to `woff2` with the characters you use or, with `--icons`, with the icons of that family your `lib/` uses; it requires fontTools (`pip install fonttools brotli`). `metrics` computes the `FontFallback` values so text does not shift while the font loads ([Theme and styles](theme-and-styles.md)).

## Analysis and editor

`thor analyze` runs `dart analyze --fatal-infos` from the root of the project or workspace, which is where Thor's rules run; `thor format` formats the project and `thor format --check` fails in CI if there are pending changes. In an app (a project with `thor_builder`) it also checks the code the browser runs, the same check the build makes, so a `String.replaceAllMapped` or a `Random` in code a state reaches is reported here and not by the first build; `thor analyze --no-browser-check` skips it. The same rules appear in the editor while you write.

### Thor's rules

`thor_lints` is an analyzer plugin that `thor create` enables in `analysis_options.yaml`. To silence a rule on one line, write `// ignore: thor_lints/<rule>` with the reason on the line above.

ViewModel rules:

| Rule | What it flags |
|---|---|
| `state_callback_closure`, `state_watch_closure` | a closure where the browser needs a ViewModel method ([THOR-S011](../../errores/en/THOR-S011.md)) |
| `state_instance_not_top_level` | a ViewModel created inside a widget ([THOR-S012](../../errores/en/THOR-S012.md)) |
| `frozen_state_read`, `stateful_set_state` | a `.value` read in `build` ([THOR-S015](../../errores/en/THOR-S015.md)) or a `setState` ([THOR-S014](../../errores/en/THOR-S014.md)), which change nothing in the browser |
| `row_server_read` | a ViewModel method that reads `row.key` on the server inside the `each` of `Watch.list` |
| `watch_field_with_builder` | a field passed as is to `Watch` with `builder`, which the compiler types as `Object?` |
| `query_builder_reads_data`, `future_builder_nullable_has_data` | a `QueryBuilder`'s `snapshot.data` read on the server, or a `FutureBuilder<T?>` that tells waiting apart only with `hasData` |

Widget, form and accessibility rules:

| Rule | What it flags |
|---|---|
| `animated_switcher_without_watch` | an `AnimatedSwitcher` without a `Watch` that changes its child |
| `untyped_form_action` | a form action written as text or a closure instead of a page method |
| `widget_props_in_styled`, `length_unit_in_const` | in `Styled`, a value that a Flutter widget already sets, such as `padding`; or a unit like `8.px` inside a `const` |
| `icon_button_without_name`, `text_field_without_label` | an icon button or a text field with no name for the screen reader |
| `env_var_not_in_schema` | an environment variable missing from its `EnvSchema` ([THOR-P011](../../errores/en/THOR-P011.md)) |

### Editor assists

With the cursor on a widget name, `Cmd+.` (or `Ctrl+.`) offers the same assists Dart gives for Flutter, also for Thor's widgets and your own.

| Assist | Result |
|---|---|
| Wrap with widget... | `widget(child: …)`, with the name ready to type |
| Wrap with Padding, Center, Container, SizedBox, Expanded, Semantics, Link… | the widget as the `child:` of the chosen one |
| Wrap with Column / Row | the widget inside `children: [...]` |
| Wrap with Watch | `Watch(source, builder: (value) => …)` |
| Remove this widget | replaces it with its `child:` or its `children:` |
| Swap with child / parent, Move widget up / down | swaps the widget with its child or its parent, or moves it within `children:` |

## Next steps

:::cards
- [Project structure](project-structure.md) — where each file the commands create goes
- [Testing](testing.md) — writing the tests that `thor test` runs
- [Build and deploy](build-and-deploy.md) — deploying what `thor build` produces
:::
