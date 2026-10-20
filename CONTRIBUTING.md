# Contributing to Thor

Thor is open source and developed in this repository. This file says how to
propose a change.

## Before writing code

Open an issue with the real case: the screen or the page that needs it.
Thor follows a few rules that changes are expected to keep:

1. **The API and the types are Flutter's; the execution is the browser's.**
   Layout, animation and overlays are CSS or a native HTML element. Every
   unavoidable difference with Flutter is documented.
2. **One element per concept, one class per element.** A wrapper
   (`Padding`, `Expanded`, `Opacity`) adds no nodes.
3. **Native first:** the browser's element before anything the engine needs.
4. **The browser never generates styles.**

## The flow of a change

```bash
tool/thor setup              # dependencies and the thor command
tool/thor check --changed    # format + analyze + the tests of what changed
tool/thor check              # everything (format, analyze, VM and browser tests)
tool/thor test [--browser]   # only the tests (VM; + Chrome)
tool/thor e2e                # browser checks of the fixture apps
tool/golden.sh check         # HTML/CSS output of the fixture apps
tool/thor docs               # API reference and public API snapshot (docs/api)
```

Requirements: Dart 3.10 or later, Node 20 or later and Chrome (browser tests).

The VS Code extension lives in [`tools/vscode-thor`](tools/vscode-thor):
when an API its snippets use changes, update them and run
`node tools/vscode-thor/test/validate_snippets.mjs`.

If a change touches the public API, update its page in the guide
(`docs/guia/es` and `docs/guia/en`) in the same change, and run
`tool/thor docs`. Removing or renaming something public goes through
`@Deprecated('Use X')` for one minor version first.

## Commits

Title line only, in English, imperative mood (`Add the locale switcher`).
No body and no attribution trailers.
