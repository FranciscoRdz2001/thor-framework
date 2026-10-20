# thor_lints

An analyzer plugin with thor's own lint rules: code the browser can't run
(a closure where the engine needs a state's member), state misuses, raw CSS
strings, missing `thorElement` widgets, what the lite engine can't run in a
`ThorState` (`thor_lite_subset`, the same message as the build) and more.
The editor and `dart analyze` show them where the code is written.

Enable it in the app's `analysis_options.yaml` (`thor create` writes this):

```yaml
plugins:
  thor_lints:
    path: <thor>/packages/thor_lints
```

(`<thor>` is your thor checkout; with `thor create --git` the entry is the
git form of the same package.)

Silence a rule on one line with `// ignore: thor_lints/<rule>` and the reason
on the line above. The rules only run in a `dart analyze` from the root of the
workspace or package that enables the plugin.
