# What runs where

Thor renders your widgets as HTML and CSS on the server; the browser handles layout and animation, and a small script updates whatever changes.

:::flutter Flutter: Flutter paints every frame on a canvas · Thor: every widget is an HTML element

## The layers

Every layer of [Flutter's architectural overview](https://docs.flutter.dev/resources/architectural-overview) has an equivalent in Thor, with a different owner.

| In Flutter | In Thor | Who does it |
|---|---|---|
| Widgets: `StatelessWidget`, `Row`, `Padding` | the same ones, with the same API | you, in Dart |
| Rendering: `RenderBox`, constraints, layout | one element per widget, with the browser's layout | the browser |
| Animation: `AnimationController`, tickers | CSS transitions | the browser |
| State: `setState`, `ChangeNotifier` | a ViewModel (`ThorState`) and `Watch` | you, in Dart; it runs in the browser |
| Embedder: the platform that calls `runApp` | `ThorServer` and its `RouteHandler` | the server |

That's why no size is measured in Dart, state is a class with named methods, and a page without a ViewModel sends no JavaScript.

## The path of a page

:::steps
### At build time

`thor build` and `thor dev` prepare what the app needs before the first request:

- every ViewModel, ready for the browser; if it uses something the browser can't run, the build stops with the file and line ([THOR-B012](../../errores/en/THOR-B012.md));
- the images in `web/images/` as WebP, and as AVIF if you ask for it, at several widths;
- the shared styles, with a hash of their content;
- the server, compiled to an executable.

The route table isn't generated: it is code (`ThorRouter`) that the server checks at startup.

### On the server

Each request goes through its route, the middleware, the page cache, the action if it's a `POST` and the `load` methods, and ends in rendering. Rendering turns each widget into an HTML element with one class and inlines only the CSS the page doesn't share. The `Link` header announces the stylesheets, fonts and main image while the server waits for the data.

### In the browser

The page arrives complete, as semantic HTML with its CSS, and is visible before any script. The browser does the layout, animates with CSS and opens dialogs, menus and accordions with its native elements. Links and forms work without JavaScript.

### With a ViewModel

If the page uses a ViewModel, a small script loads when the browser is idle and connects it to the HTML already on the page. It doesn't rebuild anything: it updates the text, the variant or the rows that depend on each value.
:::

## How state is connected

The server doesn't send a widget tree: it sends HTML in which every element that depends on a ViewModel is bound to a member of your class, such as `Watch(counter.label)` or `onPressed: counter.increment`. The browser only calls the methods you declared in a `ThorState` and never evaluates code received with the page. Since everything else is native HTML, the page works before the script loads, or if it never arrives.

## Where each task runs

| Task | Where it runs | Why |
|---|---|---|
| Layout, sizes, responsive design | the browser | nothing needs to be measured in Dart |
| Animations | the browser, with CSS transitions | they run without JavaScript |
| Page data | the server (`load`) | the page arrives with its data, with no request waterfalls from the browser |
| Forms | the server (action and schema) and the browser (native validation) | they work without JavaScript; the script only improves the messages |
| Styles | the build and the server | the browser never generates CSS |
| State that changes without reloading | the browser, with the script | it's the only thing that needs JavaScript |

## Next steps

:::cards
- [State](state.md) — `Watch`, lists and what belongs in a ViewModel
- [Theme and styles](theme-and-styles.md) — one class per element and the app theme
- [Embedded Flutter](embedded-flutter.md) — a Flutter view inside a Thor page
:::
