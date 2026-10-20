# THOR-R019 · Two `Hero` widgets with the same `tag` on a page

**Where:** `thor_ui` · `Hero` (in debug; in release the second one is skipped).

## What happened

Two `Hero` widgets on the same page have the same `tag`, so their elements would have the same `view-transition-name`.

## Why

In a view transition each name belongs to a single element on the page. If two share it, the browser cancels the whole transition and the navigation is left without animation. In release Thor keeps the name on the first one and removes it from the second, so the transition keeps working.

## How to fix it

Make the `tag` unique within the page, for example with the id of the item it represents.

```dart
// WRONG: every card in the list with the same tag
Hero(tag: 'title', child: Text(article.title))
```

```dart
// RIGHT: one per article, the same in the list and on the article's page
Hero(tag: 'article-${article.slug}', child: Text(article.title))
```

[All codes](README.md)
