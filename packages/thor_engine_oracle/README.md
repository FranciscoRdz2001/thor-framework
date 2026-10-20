# thor_engine_oracle

**Internal. Not shipped, not published, not part of the public API.**

The Dart client engine of thor (`startThor`, `hydrate` and the `*Feature`
classes), compiled by dart2js. Thor ships a single browser engine, lite;
this package stays only as the oracle that tests compare lite
against: the conformance and parity checks of `tool/e2e.mjs`, the dart2js
build of `test/fixtures/apps/counter` (`tool/thor dart2js`) and the browser
tests in `test/`.

It is reached through one internal switch, never through the pubspec or a
CLI option: `THOR_INTERNAL_ENGINE=dart` makes `thor build`, `thor dev` and
`thor export` compile the generated `.dart_tool/thor/engine.dart` with
dart2js. Only apps inside this workspace can do it (the entry imports this
package).
