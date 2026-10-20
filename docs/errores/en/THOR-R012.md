# THOR-R012 · The shared sheet's specimens fail to render

**Where:** `thor_ui` · `WidgetRenderer(shareStyles: true, specimens:)`.

## What happened

When building the shared sheet (`/_thor/base.<hash>.css`), the server renders
the `specimens` once inside `app` with an empty request, and one of
them threw an exception. Pages keep working, but with all their
styles inline (no shared sheet).

## Why

The sheet has to come **from the code**, not from traffic: each server
isolate builds it on its own and all of them must arrive at the same file. That's
why the specimens are rendered without data from any request: no session,
no `request.context`, no route parameters. A widget that reads any of
that (or an `app` that reads it) can't be a specimen.

## How to fix it

```dart
// WRONG: the specimen needs a request's session
specimens: [UserMenu()], // RequestScope.of(context).context.get(session)
```

```dart
// RIGHT: the component with fixed values, as the pages use it
specimens: [
  Column(children: [
    ShadButton(onPressed: () {}, child: Text('Save')),
    ShadButton.outline(onPressed: () {}, child: Text('Cancel')),
  ]),
],
```

A specimen has to sit in the same context as in the pages (inside
a `Column`, a flex child carries its flex values in the class): otherwise
the class comes out different and the page keeps sending it inline.

[All codes](README.md)
