# THOR-R018 · A `Style` argument that isn't CSS

**Where:** `thor_lints` · rule `style_css_names` (in `dart analyze` and the IDE).

## What happened

`Style` (web layer, `package:thor_ui/web.dart`) received a name that isn't a CSS property (`spacing`, `paddin`, `mainAxisAlignment`) or a Flutter value where a CSS one goes (`padding: EdgeInsets.all(16)`, `gap: 8`).

## Why

`Style` speaks CSS: each parameter is a CSS property in camelCase (like `CSSProperties`) and takes a single typed CSS value. The compiler only says "no named parameter" or "can't be assigned"; the rule names the property or value you need to write.

## How to fix it

```dart
// WRONG
Style(spacing: 8.px, padding: EdgeInsets.all(16), mainAxisAlignment: MainAxisAlignment.center)
```

```dart
// RIGHT
Style(gap: 8.px, padding: 16.px, justifyContent: JustifyContent.center)
// per side: paddingInline, paddingBlock, paddingTop…
```

[All codes](README.md)
