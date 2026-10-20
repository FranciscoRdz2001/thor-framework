# Thor

**Flutter's widget API for the web, rendered as semantic HTML and CSS.**
You write `Row`, `Column`, `Container`, `Checkbox` or `AnimatedScale` as in
Flutter; Thor renders them on the server, and the browser does the layout,
the animations and the native controls itself. Interactivity is a state
class written in Dart, translated to a small engine (~8–10 KB gzip) that
hooks into the HTML. Pages without state ship no JavaScript.

```dart
import 'package:thor_ui/thor_ui.dart';

class ProductCard extends StatelessWidget {
  const ProductCard(this.name, this.price, {super.key});
  final String name;
  final double price;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F8FA),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text('\$${price.toStringAsFixed(2)}'),
      ],
    ),
  );
}
```

`Container` and `Column` become a single HTML element with one generated CSS
class: wrappers add no nodes.

## Interactivity

State is a class (a ViewModel); widgets call its methods as in Flutter:

```dart
class CounterViewModel extends ThorState {
  final count = state(0);

  String label() => '${count.value}';
  void increment() => count.value++;
}

final counter = CounterViewModel();

// In a widget:
FilledButton(onPressed: counter.increment, child: Watch(counter.label))
```

Routes are declared in code, as a table of `ThorRoute`s in a `ThorRouter`,
and each page is a `ThorPage<T>` whose `load` runs on the server.

## Get started

Thor is not on pub.dev yet: install the `thor` command from a clone.

```bash
git clone https://github.com/FranciscoRdz2001/thor-framework.git thor
dart pub global activate --source path thor/packages/thor_cli

thor create my_app             # an app with a server, routes and a test
cd my_app && thor dev          # http://localhost:4300, rebuilt on every change
thor build                     # release build
thor preview                   # serves the release build as in production
```

Requirements: Dart 3.10 or later (Flutter's works) and git. `thor doctor`
checks the environment and `thor doctor --fix` repairs what it can.

## Documentation

- **Guide**, in [English](docs/guia/en/what-is-thor.md) and
  [Spanish](docs/guia/es/que-es-thor.md): installation, a first app, state,
  routes, forms, styles, the widget catalog and the CLI. The documentation
  site, [thor-docs.vercel.app](https://thor-docs.vercel.app), publishes it
  with live examples; its source is [`apps/docs`](apps/docs)
  (`cd apps/docs && thor dev --watch ../../docs`).
- **API reference:** [`docs/api/en/thor_ui.md`](docs/api/en/thor_ui.md).
- **Error codes** (`THOR-*`), with what each one means and how to fix it:
  [`docs/errores/`](docs/errores/en/README.md).

## Packages

| Package | What it is |
|---|---|
| [`thor_ui`](packages/thor_ui) | the widgets, themes, animations and native components; the route table (`ThorRouter`, `ThorPage`) and the `server`, `html`, `router` and `testing` facades |
| [`thor_style`](packages/thor_style) | Flutter's value types (`EdgeInsets`, `BoxDecoration`, `TextStyle`, `Color`, `Curve`…) compiled to CSS; pure Dart |
| [`thor_server`](packages/thor_server) | the server, in pure Dart: routes, data loaded before the page renders, form actions, cookies and sessions, page cache and static export |
| [`thor_engine`](packages/thor_engine) | the browser side: signals, `ThorState` and the runtime |
| [`thor_builder`](packages/thor_builder) | the build step: what each `ThorState` needs in the browser, generated outside your code (`.dart_tool/thor/`) |
| [`thor_cli`](packages/thor_cli) | the `thor` command: create, develop, add, build, export, preview and check a project |
| [`thor_test`](packages/thor_test) | test helpers for apps: the HTTP test client and matchers |
| [`thor_lints`](packages/thor_lints) | analyzer rules that flag what doesn't work in the browser |
| [`thor_studio`](packages/thor_studio) | a design system made only of public widgets (the one the docs site uses) |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Security reports go through
[SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE).
