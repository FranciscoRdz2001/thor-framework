# Project structure

Group the code by business module, with the layers inside each one, and decide which folder may import which.

:::flutter Flutter: folders by layer (`ui/`, `data/`) · Thor: folders by module, with the layers inside

## Folders by module

Each module is a `Group` in the route table, with its layout, its permissions, its data and its components. `router.dart` only composes the modules.

:::example demo-explorer
:::

## Where each file goes

A file goes in the lowest folder that uses it, and moves up when another module needs it.

| If it's… | It goes in |
|---|---|
| A component with no business terms | `core/widgets/` |
| A business component | `modules/sales/widgets/`, or `modules/sales/orders/widgets/` if it belongs to a single feature |
| A backend call | `modules/sales/data/` |
| A ViewModel or a form's rules | `modules/sales/orders/state/` and `modules/sales/orders/forms/` |
| Session and permissions shared by several modules | `core/session/` and `core/auth/`; a rule for a single module, in `modules/sales/middleware/` |
| The header, navigation or footer | `shell/` |

`thor add page`, `thor add state` and `thor add middleware` create each file in its folder ([The thor command](cli.md)).

## Dependencies point down

A file imports from its own module and from `core/`; never from another module, except its routes for linking.

| Who imports | May import |
|---|---|
| `router.dart` and `shell/` | `core/` and the routes (`*_routes.dart`) of each module |
| A page | `core/`, its module and its submodule; from another module, only its routes |
| A component | `core/`, its module and its submodule |
| A Repository | `core/` and its module's models |
| `core/` | only `core/` |

If two modules need the same thing, the code moves up to `core/`.

> **Note:** The general error page goes in `shell/app_error_page.dart`, in the root `Group`, and each module can have its own ([Routes and navigation](navigation.md#error-pages)).

## Next steps

:::cards
- [Interface layer](ui-layer.md) — the View and the two halves of the ViewModel
- [Data layer](data-layer.md) — Repositories, Services and injection
- [Patterns](patterns.md) — commands, errors and optimistic state
:::
