# THOR-P013 · Una página con datos sin `load`

**Dónde:** `thor_ui/router.dart` · la primera petición a esa página.

## Qué pasó

La clase extiende `ThorPage<T>` (o `ThorLayout<T>`) con un tipo de dato, pero no sobrescribe `load`: no hay de dónde sacar `state.data`.

## Por qué

`T` dice qué recibe `build` en `state.data`; solo `load` lo produce. Una página sin datos es `ThorPage<void>`.

## Cómo se arregla

```dart
// WRONG
class ArticlePage extends ThorPage<Article> {
  const ArticlePage();
  @override
  Widget build(BuildContext context, PageState<Article> state) => ...;
}
```

```dart
// RIGHT
class ArticlePage extends ThorPage<Article> {
  const ArticlePage();
  @override
  Future<Article> load(PageRequest request) => api.article(request.param('slug'));
  @override
  Widget build(BuildContext context, PageState<Article> state) => ...;
}
```

[Todos los códigos](README.md)
