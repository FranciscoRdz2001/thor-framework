# THOR-S008 · `PageNavigator.go` to a location that isn't a page

**Where:** `thor_ui` · `PageNavigator.go`.

## What happened

A state method called `PageNavigator.go` with a location that is neither relative nor `http:`/`https:` (`javascript:`, `data:`, `vbscript:`…).

## Why

`go` loads the next page as a document. A location with another scheme isn't a page: with a value that comes from the user (a parameter, a field) it would be a door to running code in the page. The check ignores control characters and spaces the way the browser does (`java\tscript:` is rejected too).

## How to fix it

```dart
// WRONG: the target comes from the user, unchecked
void open() => PageNavigator.go(link.value);
```

```dart
// RIGHT: an app route (typed) or an http(s) URL
void open(String slug) => PageNavigator.go(Routes.article(slug: slug));
```

If the error can happen (a destination that comes from data), catch it as an `ArgumentError`.

[All codes](README.md)
