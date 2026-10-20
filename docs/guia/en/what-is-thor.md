# What is Thor

Thor renders Flutter widgets as semantic HTML and CSS on the server. This page helps you decide whether it fits your app.

:::flutter Flutter: widgets painted on its own canvas · Thor: the same widgets, as HTML and CSS

## One widget, one page

You write a `StatelessWidget` as in Flutter. Thor runs its `build` on the server and sends the browser an HTML element with its CSS class.

:::example start-widget-to-web
:::

## What runs where

Widget code runs on the server; the browser does the layout and updates only what changes.

| Part of the app | Runs on | What it does |
|---|---|---|
| each widget's `build` | server | renders the HTML and CSS, once per request |
| each page's `load` | server | loads the data before rendering |
| layout, scrolling and animations | browser | applied with CSS, without JavaScript |
| ViewModel (`ThorState`) | browser | updates what changes without reloading the page |

JavaScript only reaches pages that use a ViewModel. The details are in [What runs where](how-it-works.md).

## Thor or Flutter web

| Choose Thor if… | Choose Flutter web if… |
|---|---|
| the site must be indexed: a store, a blog, documentation | the app paints every pixel: an editor, a game |
| you need selectable text, links, zoom and native forms | you need the same rendering on mobile, desktop and web |
| the first screen must show content without waiting for JavaScript | the app already exists in Flutter and rewriting it isn't worth it |

To combine both, [Embedded Flutter](embedded-flutter.md) places a Flutter app inside a region of the page.

## Next steps

:::cards
- [Installation](installation.md) — install the `thor` command and create a project
- [Your first app](first-app.md) — a store with a cart, a form and routes, step by step
- [Coming from Flutter](from-flutter.md) — the Thor equivalent of every Flutter API
:::
