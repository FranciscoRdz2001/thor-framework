# THOR-P020 · A form points to something that is not an action of the page

**Where:** `thor_ui` · `Form(onValid:)`, `Form(onPost:)` and the buttons' `onPost:`/`onValid:`, when painting the page.

## What happened

The form received a function Thor cannot find among the registered actions: a closure, a method of a page that is not in the `ThorRouter`, or the app ran without `thor` (`dart run` directly).

## Why

An action is a public method of the page. Thor registers those methods when preparing the app (`thor dev`, `thor build`, `thor test`); when painting, Thor looks up the tear-off (`send` on the route's instance) and writes `action="?/send"`. A closure has no name the server can call later.

## How to fix it

```dart
// WRONG — a closure
Form(onPost: (request) async => null, child: …)
```

```dart
// RIGHT — a public method of the page, by its tear-off
Future<ActionResult?> favorite(PageRequest request) async { … }

Form(onPost: favorite, child: …)
```

Run the app with `thor dev` / `thor test`. For another page's action, give it its URL: `Form(action: articleRoute.link(…), onPost: const ArticlePage().favorite)`.

[All codes](README.md)
