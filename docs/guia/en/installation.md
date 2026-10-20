# Installation

Install the `thor` command, create an app and open it in the browser. You need Dart and an editor.

> **Note:** Thor is at version 0.1 and is not yet published on pub.dev. The `thor` command is installed from a local copy of the repository, and every new project uses that copy.

## Requirements

| You need | Check with |
|---|---|
| Dart 3.10 or later (Flutter's works) | `dart --version` |
| git | `git --version` |
| `~/.pub-cache/bin` on your `PATH` | `thor --help`, after installing |

## Install and create an app

Clone the repository, activate the command and create the app. `thor dev` serves it at `http://localhost:4300`, or on the next free port.

:::bench bench-start-install
:::

| `thor create` option | Effect |
|---|---|
| `--git <url>` | takes Thor from a git repository instead of your local copy; it's the option for a project that is shared or deployed |
| `--title 'My store'` | changes the title of the home page |

With `thor dev` running, edit `lib/modules/home/pages/home_page.dart` and save: the open page updates.

## Project files

:::files
my_app/
  .github/workflows/ci.yml   continuous integration: formatting, analysis and tests
  bin/
    server.dart   the server
  lib/
    app.dart   the theme and the app
    env.dart   the environment variables
    router.dart   the route table
    shell/   the page frame and the error page
    core/   what several modules share
    modules/
      home/   the home page, its route and a sample counter
  web/   public files
  test/   tests
  pubspec.yaml
:::

The full layout is in [Project structure](project-structure.md).

## Set up the editor

| What | How |
|---|---|
| Dart | your editor's Dart extension (VS Code, Cursor, IntelliJ, Zed) |
| Thor rules | already on: `thor create` adds them to `analysis_options.yaml` and the editor flags what doesn't work in the browser, with its `THOR-*` code |
| From the browser to the code | with `thor dev`, **Alt+click** (Option on Mac) on an element opens the file that built it; `THOR_EDITOR=cursor` picks the editor |

## Environment variables

`lib/env.dart` declares the variables with their types; the values go in `.env`, at the app root, which `thor create` adds to `.gitignore`.

```ini
# .env
API_URL=https://api.example.com
SESSION_SECRET=a-long-key-of-at-least-32-characters
```

`thor dev` and `thor preview` read `.env`. If a variable is missing, the server doesn't start and lists every missing one ([THOR-P011](../../errores/en/THOR-P011.md)). Types and secret protection are in [Session and security](session-and-security.md).

## Continuous integration

`thor create` writes `.github/workflows/ci.yml`, which installs `thor` and runs formatting, `dart analyze --fatal-infos` and `thor test`. CI can only install Thor from a repository: create the project with `--git <url>` or point the `pubspec.yaml` dependency to a repository.

> **Tip:** `thor analyze` and `thor format --check` run the same checks as CI on your machine.

## Common commands

| Command | What it does |
|---|---|
| `thor dev` | runs the app and updates it on every change |
| `thor test` | runs the tests |
| `thor analyze` | analyzes the project with Thor's rules |
| `thor build` | builds the production version |
| `thor preview` | serves the built version at `http://localhost:4400` |
| `thor doctor --fix` | checks the SDK and the project, and applies the safe fixes |

Every command and its options are in [The thor command](cli.md).

## Next steps

:::cards
- [Your first app](first-app.md) — a store with a cart, a form and routes, from start to finish
- [Coming from Flutter](from-flutter.md) — the Thor equivalent of every Flutter API
- [The thor command](cli.md) — every command and its options
:::
