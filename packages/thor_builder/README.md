# thor_builder

Build step of thor apps. Add it to an app's `dev_dependencies`; the `thor`
command (`thor dev`, `thor build`) runs it.

| Output | What it contains |
|---|---|
| `.dart_tool/thor/states.dart` | `bin/entries.dart` (run by `thor`, not by `build_runner`): for every `class Name extends ThorState` of `lib/`, its members: each field made with `state(...)` and each public method, with its name (the id the page uses), how to parse an argument from the page, and the values of finite states (`bool`, enums); the app never imports it |
| `.dart_tool/thor/server.dart`, `export.dart` | the entries `thor` runs: they register the states (in every server isolate) and run `bin/server.dart` or `bin/export.dart` |
| `.dart_tool/thor/engine.dart` | internal: the entry of the dart2js engine thor's own tests compare the lite engine with (`THOR_INTERNAL_ENGINE=dart`); apps never use it |
| `lib/l10n/app_localizations.thor.dart` | the typed messages of `lib/l10n/*.arb` (Flutter's `gen-l10n`; see `docs/guia/en/localization.md`) |

The `.dart_tool/thor/` entries are build output; only
`lib/l10n/app_localizations.thor.dart` goes in the source tree (commit it).
All are formatted like `dart format`. Mistakes are reported against the file that has them, with
what to write: a state outside what the lite engine translates… (nothing
is generated until they are fixed, instead of compile errors in the
generated file). Routes are not generated: they are a table in code
(`ThorRouter`, see `docs/guia/en/navigation.md`).

Rules the state generator applies (see `docs/guia/en/state.md`):

- methods with more than three parameters, optional parameters or private
  names are skipped (with a warning for the first two); getters and
  inherited methods are not members;
- a parameter is "simple" (`int`, `double`, `num`, `String`, `bool`, enum,
  nullable versions) or a list item (any other type: row fields and keys);
- types are written as the library spells them (`m.Line` through
  `import … as m`).

```bash
dart test   # generator tests: real resolution, and the generated code must compile
```
