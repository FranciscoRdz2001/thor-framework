# thor_lints example

`thor_lints` is an analyzer plugin. Enable it in the `analysis_options.yaml`
of the app (or workspace) and run `dart analyze` from that folder:

```yaml
plugins:
  thor_lints:
    diagnostics:
      avoid_raw_css: true # opt-in; the other rules are on by default
```

For example, `avoid_raw_css` flags a CSS string where a typed value exists:

```dart
Container(decoration: const BoxDecoration(color: Color(0xFFF7F8FA))) // ok
Styled(style: StyleProps(raw: {'background': '#f7f8fa'}), child: child) // avoid_raw_css
```

Silence a rule on one line with `// ignore: thor_lints/<rule>` and the reason
on the line above.
