# thor_cli

The `thor` command: create a thor app, run it with everything rebuilt on
change, add pages and states, build, export, preview and check it. It
works on any Dart project that depends on `thor_ui`, inside the thor
repository or anywhere else.

## Install

The packages are not on pub.dev yet, so the command comes from a thor
checkout:

```bash
git clone https://github.com/FranciscoRdz2001/thor-framework.git thor
cd thor
tool/thor setup                                   # also activates the command
# or just the command:
dart pub global activate --source path packages/thor_cli
```

`thor` lands in `~/.pub-cache/bin` (add it to your `PATH`). Inside the
repository it also runs as `dart run thor_cli:thor`.

## Commands

The full reference, with every option, is
[docs/guia/en/cli.md](../../docs/guia/en/cli.md).

| Command | What it does |
|---|---|
| `thor create <name>` | A server app: `bin/server.dart`, `lib/app.dart`, `lib/router.dart` (the route table), `lib/shell/`, `lib/core/`, `lib/modules/home/`, `web/`, `test/`, `analysis_options.yaml` with Thor's rules and `.github/workflows/ci.yml`. Then `pub get` (`--no-pub` skips it; `--title` sets the home page title). |
| `thor dev [project]` | Resolves dependencies if needed, copies package public files, generates code, compiles the engine when a page has state, and serves the app on a free port (4300, or the next one) through a proxy, with the server behind it. On every change in `lib/`, `bin/` or `web/` the server reloads and open pages reload themselves and come back as they were: scroll, the form fields you changed, the focus, and every `ThorState` value (the dev engine is compiled with `-Dthor.dev=true`; release engines don't contain any of it). `--port` picks the first port to try; `--watch <folder>` adds folders to watch. |
| `thor add page </url>` | `lib/modules/<module>/pages/<name>_page.dart` and its route in the module's group. A URL with parameters (`/product/:id`, `/item/:id:int`, `/docs/*rest`) gets a `load` that reads each one. |
| `thor add layout\|styles\|error\|not_found\|middleware` | A layout or stylesheet for `Group(layout:)` / `Group(styles:)`, the error or 404 page, or a middleware. |
| `thor add state <Name>` | `lib/modules/<module>/state/<name>_view_model.dart`: a `ThorState` (`<Name>ViewModel`) and its top-level instance. |
| `thor add component <Name>` | A widget in `lib/modules/<module>/widgets/` and its test. |
| `thor test` | Runs the app's tests with its ViewModels registered. |
| `thor analyze`, `thor format` | `dart analyze --fatal-infos` from the project or workspace root (where Thor's rules run) and `dart format`. |
| `thor build [project]` | Release build. Server app: `build/server` (native executable) and `build/public` (`web/` plus the engine compiled with `-O4`). Static app: `build/site`, pre-rendered, with short class names, content-hashed file names and the gzip size of the page. |
| `thor export [project] [--base-url <url>]` | A server app as static files in `build/site`: runs `bin/export.dart` in release mode and shortens class names. The export fails on a page that doesn't answer 200 or an internal link or anchor that leads nowhere. |
| `thor preview [project]` | Serves the release like a host would: `build/site` with clean URLs (`/about` → `about.html`) and `404.html`, or runs `build/server`. Port 4400, or the next free one. |
| `thor deploy init <target>` | Writes a hosting's configuration (`docker`, `fly`, `railway`, `render`, `cloudflare-pages`, `vercel`, `netlify`). |
| `thor render`, `thor mcp` | Render a page without a browser; `mcp` serves the same tools to AI agents over MCP. |
| `thor fonts subset\|metrics` | Trim a font to `woff2`, or compute its `FontFallback` values. |
| `thor doctor [project] [--fix]` | Checks the Dart SDK, the workspace list, resolved dependencies, the route table (`lib/router.dart`), the static entry (`lib/main.server.dart`) and `web/`. `--fix` applies the safe fixes: joins the workspace, runs `pub get`, creates `web/`, syncs package files and clears the build cache. |

`add` takes `--module <module>` and `--project <path>`.

## Which project

A command acts on the project named on the command line (a folder, or
`shop` for `apps/shop` inside the thor repository) or, by default, on the
nearest `pubspec.yaml` above the current folder that depends on `thor_ui`.
When that pubspec says `resolution: workspace`, `pub get` runs at the
workspace root.

## Where `thor create` puts the project

- **Inside the thor repository**, `thor create shop` writes `apps/shop`,
  takes the packages by relative path and adds `apps/shop` to the root
  `workspace:` list.
- **Anywhere else** (or with a path: `thor create ~/work/shop`), the
  project is standalone. It takes the packages from the thor checkout
  (`THOR_HOME`, or the checkout this command runs from) by absolute path.
- **`--git <url> [--ref <branch|tag|commit>]`** takes them from the thor
  git repository instead (the default ref is `master`): a project you can
  share or build on CI without a local checkout.

## What it resolves on its own

- **A stale `build_runner` cache** (a generated file whose source was
  deleted). It is recognized by `build_runner`'s own error, then
  `.dart_tool/build` is deleted and the build retried once.
- **Package public files.** A package declares a folder to publish in its
  pubspec, and the command copies it into the app's `web/` when it is
  missing or changed:

  ```yaml
  thor:
    public:
      fonts: fonts     # the package's fonts/ → the app's web/fonts/
  ```

  That's how `thor_studio`'s fonts and their licenses reach an app.
- **Processes left behind.** `thor dev` records its own pid and its
  children's in `.dart_tool/thor/dev-<port>.pids`. If a run dies without
  cleaning up, the next one stops its children before it starts; a run that
  is still alive (another port) is never touched.

## Known limits

- When a change does not support hot reload, `thor dev` restarts the
  server process: state in the server starts over. Pages reload by themselves, no request fails
  meanwhile, and the browser keeps its `ThorState` values field by field
  (a field renamed, removed or of another type since the last reload
  starts from the server's value; the console says which). Values that
  aren't JSON, and a snapshot over 512 KB, are not kept.
- Installed with `dart pub global activate`, the command runs in a second
  VM behind a small wrapper. Ctrl-C in the terminal reaches the whole
  process group and stops everything; a `kill` sent to the wrapper doesn't
  reach the command (the next `thor dev` cleans up after it).
