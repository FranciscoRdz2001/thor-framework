# Thor for VS Code

A small extension for writing Thor apps in VS Code: snippets for the current APIs and commands that run `thor add` in the integrated terminal. Nothing to compile: it is a `package.json`, a snippets file and one JavaScript file.

The widget actions (wrap, remove, swap, move) do not come from this extension but from the `thor_lints` analyzer plugin; they are described at the end.

## Installation

Requires the official Dart extension (`Dart-Code.dart-code`).

Option 1, package and install a `.vsix`:

```bash
cd tools/vscode-thor
npx @vscode/vsce package
code --install-extension vscode-thor-0.1.0.vsix
```

Option 2, link the folder (handy while you change the extension):

```bash
ln -s "$(pwd)/tools/vscode-thor" ~/.vscode/extensions/thor.vscode-thor-0.1.0
```

Either way, reload the VS Code window (`Developer: Reload Window`).

## Snippets

Type the prefix in a `.dart` file and accept it with `Tab`. They assume an app's usual imports: `package:thor_ui/thor_ui.dart` and, for pages, routes and forms, `package:thor_ui/router.dart`.

| Prefix | Writes |
|---|---|
| `tstless` | a `StatelessWidget` that implements `ThorElementWidget` (its `build` returns one Thor element, as `missing_thor_element_widget` asks) |
| `tpage` | a page without data: `ThorPage<void>` with `meta` and `build` |
| `tpaged` | a page with data: its data class and a `ThorPage<T>` whose `load` reads the URL |
| `tlayout` | a `ThorLayout<void>`, the frame a `Group` puts around its pages |
| `terror` | an `ErrorPage` for errors and URLs without a page |
| `tstate` | a ViewModel (`class CounterViewModel extends ThorState`) with a `state(...)` field and methods, and its top-level instance |
| `twatch` | `Watch(viewModel.method)` |
| `twatchb` | `Watch(viewModel.method, builder: (value) => ...)` |
| `troute` | `final xRoute = ThorRoute('/x', const XPage());` |
| `tgroup` | a module's `Group(children: [...])` |
| `tform` | a `FormSchema` class with its fields and its `schema` |
| `tfield` | one schema field (`TextSchemaField`, `IntSchemaField` or `CheckboxSchemaField`) |
| `tmw` | a middleware: `Future<ThorResponse> name(PageRequest request, Next next)` |

## Commands

In the command palette (`Cmd+Shift+P`): **Thor: Add page**, **Thor: Add component** and **Thor: Add state**. Each asks for the URL or the name and runs `thor add page|component|state` from the folder of the open file; Thor finds the project in that folder or above it. Requires `thor` on the `PATH` (`dart pub global activate --source path <thor>/packages/thor_cli`).

## Widget actions (assists)

With the cursor on the name of a Thor widget (your app's own widgets included), the quick actions menu (`Cmd+.`) offers the same assists as Flutter:

| Assist | Result |
|---|---|
| Wrap with widget... | `widget(child: <widget>)`, with the name selected so you can type it |
| Wrap with Padding | `Padding(padding: const EdgeInsets.all(8), child: <widget>)` |
| Wrap with Center, Container, SizedBox, Expanded, Flexible, Semantics | `Name(child: <widget>)` |
| Wrap with Align | `Align(alignment: Alignment.center, child: <widget>)` |
| Wrap with Link | `Link(href: '', child: <widget>)` |
| Wrap with Column / Row | `Column(children: [<widget>])` |
| Wrap with Watch | `Watch(source, builder: (value) => <widget>)`, with `source` selected so you can type the ViewModel's member |
| Remove this widget | the widget is replaced by its `child:` (or by its `children:` inside a list) |
| Swap with child / Swap with parent | swaps the widget with its `child:` or with the widget it is the `child:` of |
| Move widget up / Move widget down | moves the widget one position within `children:` |

These assists come from the `thor_lints` plugin, not from this extension: Dart's built-in assists only work on `package:flutter` widgets. The plugin is enabled in the project's `analysis_options.yaml`, which `thor create` already writes:

```yaml
plugins:
  thor_lints:
    path: <thor>/packages/thor_lints
```

## Tests

`node test/validate_snippets.mjs` creates an app with the local CLI (`thor create`), expands every snippet with its default values (every option of each choice) and checks that `dart analyze --fatal-infos` reports nothing. It works offline (`dart pub get --offline`). `--keep` keeps the generated app.

## License

MIT, like the rest of Thor (see [LICENSE](LICENSE)).
