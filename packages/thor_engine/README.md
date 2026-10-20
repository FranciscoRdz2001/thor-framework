# thor_engine

The client engine of thor: **signals + a runtime that attaches to
server-rendered HTML**. It never builds a component tree in the browser, so
static markup costs nothing and an update touches only the nodes bound to
what changed.

Apps don't use it directly: they write a `ThorState` class and thor_ui's
`Watch` / widget callbacks (guide: [State](../../docs/guia/en/state.md),
[How it works](../../docs/guia/en/how-it-works.md)).
API reference: what apps use of it comes through `thor_ui`
([docs/api/en/thor_ui.md](../../docs/api/en/thor_ui.md), "State in the
browser"); the rest is for the build step. Tests:
[docs/guia/en/testing.md](../../docs/guia/en/testing.md).

## Libraries

| Import | Where | Contents |
|---|---|---|
| `package:thor_engine/thor_engine.dart` | server and client | `Signal`, `Computed`, `effect`, `batch`, `untracked`, `SignalScope`; `ThorState`, `state()`, `withArg`, `ThorMember`; the HTML protocol; low-level bindings |
| `dart run thor_engine:lite_bundle …` | build step | the lite engine (the one browser engine thor ships): the hand-written JS runtime (`lib/lite/`) plus the states translated from Dart |
| `dart run thor_engine:optimize <file.html>…` | build step | export optimizer: short class names (and variants → compact patches for markup thor_ui didn't render; thor_ui writes patches itself) |
| `dart run thor_engine:share_styles <site>` | build step (`thor build`) | the site's shared stylesheets, then short class names on every page |
| `dart run thor_engine:fingerprint <site>` | build step (`thor build`) | content-hash cache busting: every local file a page references gets a hashed name |
| `package:thor_engine/lite.dart` | build step | the lite bundle (runtime + optional parts + the app's states in JS) and its minifier |
| `package:thor_engine/optimize.dart`, `shared_styles.dart`, `fingerprint.dart`, `css_text.dart` | build step | the libraries behind the executables above, and plain-text helpers for thor's stylesheets |
| `package:thor_engine/sanitize.dart` | server | allowlist HTML sanitizer for untrusted markup |

## How a page comes alive

1. The server renders widgets; `Watch(counter.label)` and
   `onPressed: counter.inc` write markers with readable ids
   (`data-tt="CounterState.label"`, `data-t-on="click:CounterState.inc"`),
   and the fields the server changed go into `<script id="thor-state">`.
2. The loader starts `engine.dart.js` on idle after `load`, or at the first
   interaction (queued taps are replayed).
3. The lite runtime restores the fields, finds every marker, resolves its id
   against the states `thor_builder` translated from Dart and attaches one
   effect per marker plus one delegated listener per event type.

Reactivity is fine-grained with dynamic dependency tracking (signals).
Lists reconcile by key, moving only rows outside the
longest increasing subsequence.

## Server requests

`SignalScope.run(body)` gives `body` (and what it awaits) its own signal
values: writes stay in the scope, reads fall back to the global value.
thor's `initializeThor` runs every server request in one, so top-level
states are safe with concurrent requests. The browser never creates a scope
and pays nothing for it.

## Low level (no generator)

The protocol is plain HTML markers (`data-tt`, `data-t-on`…), and the types
that describe it (`TextBinding`, `VariantBinding`, `ListBinding`,
`StateBinding`, `Action`) are in the library. The lite runtime reads the same
markers as the internal dart2js oracle, `packages/thor_engine_oracle`, which
tests compare it against (never shipped).

## Tests

```bash
dart test                                 # reactive core, ThorState, optimizer, lite runtime (VM, node)
```
