# Error codes

Thor's most common errors and warnings carry a stable code
(`THOR-S001`) and a page here with the cause and how to fix it
(`/errores/THOR-S001`). Those from the browser and the development inspector
carry only the code, and the `thor dev` overlay links them all the same.

A code is never reused and never changes meaning: if an error stops
existing, its page is deleted and the code stays unused.

Letters: **S** state · **R** render · **L** layout (inspector) ·
**P** pages and server · **B** build and code generation.

## State

| Code | What happens |
|---|---|
| [THOR-S001](THOR-S001.md) | A `Watch` or a callback receives a closure |
| [THOR-S002](THOR-S002.md) | A per-row method does not receive the item |
| [THOR-S003](THOR-S003.md) | `Watch` with `builder` over a value that is not finite |
| [THOR-S005](THOR-S005.md) | The browser cannot find a member of a `ThorState` |
| [THOR-S006](THOR-S006.md) | A page uses a `ThorState` without `ThorApp` |
| [THOR-S007](THOR-S007.md) | `Cached` contains widgets bound to a `ThorState` |
| [THOR-S008](THOR-S008.md) | `PageNavigator.go` to a location that is not a page |
| [THOR-S009](THOR-S009.md) | Invalid name of a persisted field (`cookie:` or `local:`) |
| [THOR-S010](THOR-S010.md) | An unregistered `ThorState` (the app ran without Thor) |
| [THOR-S011](THOR-S011.md) | A callback is a closure that uses a `ThorState` |
| [THOR-S012](THOR-S012.md) | A `ThorState` created outside the top level |
| [THOR-S013](THOR-S013.md) | A `ValueListenableBuilder` the browser cannot rebuild |
| [THOR-S014](THOR-S014.md) | `setState` in a `StatefulWidget` |
| [THOR-S015](THOR-S015.md) | A state read while the server paints (it freezes in the browser) |
| [THOR-S016](THOR-S016.md) | An `AnimatedSwitcher` with no states to switch |
| [THOR-S030](THOR-S030.md) | A row key that is neither text nor an integer |
| [THOR-S031](THOR-S031.md) | A page without the dialog or the snackbar a state asks for |
| [THOR-S032](THOR-S032.md) | A row with a lambda but no probe for its class |
| [THOR-S033](THOR-S033.md) | A row lambda that does more than read a property |
| [THOR-S034](THOR-S034.md) | A state method called with `row.key` (or reading row state) while painting: it is evaluated once, with the template's key |
| [THOR-S035](THOR-S035.md) | `row.bind` on an attribute a binding cannot write |
| [THOR-S036](THOR-S036.md) | `row.bind` used as text or transformed |
| [THOR-S037](THOR-S037.md) | A `QueryBuilder` state that reads `snapshot.data` and could not be drawn without data |
| [THOR-S038](THOR-S038.md) | A page with `headBudget` answered 200 and its resource did not exist |
| [THOR-S039](THOR-S039.md) | The browser called a query or command the registry does not declare |
| [THOR-S040](THOR-S040.md) | `Watch.list(virtual: true)` without `itemExtent` |
| [THOR-S041](THOR-S041.md) | A `state(...)` field with a class that does not travel as JSON |
| [THOR-S042](THOR-S042.md) | A `row.length` read outside its row |
| [THOR-S043](THOR-S043.md) | A key met twice in a `Watch.tree` (or a node that is its own descendant) |
| [THOR-S044](THOR-S044.md) | A `postMessage` origin that is not explicit (`'*'`, `'null'`, with a path or default port) |

## Render

| Code | What happens |
|---|---|
| [THOR-R001](THOR-R001.md) | Thor does not know how to build this widget |
| [THOR-R002](THOR-R002.md) | `Cached` is inside a wrapper |
| [THOR-R003](THOR-R003.md) | `Cached` contains the `<head>` or the document |
| [THOR-R004](THOR-R004.md) | `.when()` inside a style sheet |
| [THOR-R005](THOR-R005.md) | Nested `@keyframes` |
| [THOR-R006](THOR-R006.md) | There is no `Localizations` above the widget |
| [THOR-R007](THOR-R007.md) | A translations delegate loads asynchronously |
| [THOR-R008](THOR-R008.md) | `DefaultTabController` is missing |
| [THOR-R009](THOR-R009.md) | The `DefaultTabController` length does not match |
| [THOR-R010](THOR-R010.md) | `RequestScope.of` outside a page |
| [THOR-R011](THOR-R011.md) | A `Table` column width CSS cannot express |
| [THOR-R012](THOR-R012.md) | The shared sheet's specimens are not drawn |
| [THOR-R013](THOR-R013.md) | A `tw()` utility or variant Thor does not know |
| [THOR-R014](THOR-R014.md) | Two `tw()` utilities set the same property |
| [THOR-R015](THOR-R015.md) | `8.px` inside a `const` |
| [THOR-R016](THOR-R016.md) | A `FontFace` `unicodeRange` that is not a range |
| [THOR-R017](THOR-R017.md) | A `const` widget that reads more than its fields (memo in `verify`) |
| [THOR-R018](THOR-R018.md) | A `Style` argument that is not CSS |
| [THOR-R019](THOR-R019.md) | Two `Hero` widgets with the same `tag` on a page |
| [THOR-R020](THOR-R020.md) | A widget tree too deep for the stack |
| [THOR-R021](THOR-R021.md) | A theme color declared twice (`colorTokens` and `tokens`) |
| [THOR-R022](THOR-R022.md) | An element with two ids (`Semantics(identifier:)` over another id) |
| [THOR-R023](THOR-R023.md) | A theme color's channels are not known on the server |
| [THOR-R031](THOR-R031.md) | A `FutureBuilder` received a new future on every pass (create it in `load`) |
| [THOR-R032](THOR-R032.md) | An `Autocomplete`'s `optionsBuilder` returned a `Future` |
| [THOR-R033](THOR-R033.md) | A `FutureBuilder` leaves the skeleton when its future completes with `null` |
| [THOR-R034](THOR-R034.md) | A `ResponsiveLayout` carries the same heavy content (a `FutureBuilder`, a `Watch.list` or a lot of HTML) in two variants |
| [THOR-R035](THOR-R035.md) | A `LazyPiece`'s `id` does not fit in a URL |
| [THOR-R036](THOR-R036.md) | A widget that adds up paddings received one given as a `Length` |
| [THOR-R037](THOR-R037.md) | A value that depends on text direction (`start`/`end`) reached a place that needs the physical side |
| [THOR-R038](THOR-R038.md) | A `SegmentedButton` segment with no `Text` and no `tooltip` has no accessible name |
| [THOR-R040](THOR-R040.md) | A `GestureDetector` or `InkWell` callback the browser cannot provide |

## Layout (development inspector)

| Code | What happens |
|---|---|
| [THOR-L001](THOR-L001.md) | A `Row` or a `Column` overflows |
| [THOR-L002](THOR-L002.md) | `Expanded`/`Flexible` outside a flex |
| [THOR-L003](THOR-L003.md) | Zero-width `LayoutScope` |
| [THOR-L004](THOR-L004.md) | A text field without an accessible name |

## Pages and server

| Code | What happens |
|---|---|
| [THOR-P001](THOR-P001.md) | Two routes catch the same URLs |
| [THOR-P002](THOR-P002.md) | Exporting a site that negotiates the language |
| [THOR-P003](THOR-P003.md) | The `SignedCookies` secret is short |
| [THOR-P004](THOR-P004.md) | `next()` twice in a middleware |
| [THOR-P005](THOR-P005.md) | A value is missing from `request.context` |
| [THOR-P006](THOR-P006.md) | `request.parent<T>()` without a layout that loads `T` |
| [THOR-P007](THOR-P007.md) | A field from another schema in `FormValid.of` |
| [THOR-P008](THOR-P008.md) | Two fields of a `FormSchema` with the same name |
| [THOR-P009](THOR-P009.md) | An action returned a value that is not a result |
| [THOR-P010](THOR-P010.md) | A cookie after the early response (`earlyHints`) |
| [THOR-P011](THOR-P011.md) | The environment is not valid |
| [THOR-P012](THOR-P012.md) | An environment secret reached a page |
| [THOR-P013](THOR-P013.md) | A page with data but no `load` |
| [THOR-P014](THOR-P014.md) | A malformed route or link |
| [THOR-P015](THOR-P015.md) | `request.param` for a parameter the route does not have |
| [THOR-P016](THOR-P016.md) | A middleware in the list failed |
| [THOR-P019](THOR-P019.md) | `PageRequest.current` outside a query or a command |
| [THOR-P020](THOR-P020.md) | A form points to something that is not an action of the page |
| [THOR-P030](THOR-P030.md) | `Form(defaults:)` is neither a map nor an object with `toJson()` |
| [THOR-P031](THOR-P031.md) | A `Validator.custom` on a `TextFormField` that no server schema checks |
| [THOR-P032](THOR-P032.md) | An `OptionalSchemaField` with `Validator.required` |
| [THOR-P033](THOR-P033.md) | A signed session without `maxAge` |
| [THOR-P034](THOR-P034.md) | A `query` or a `command` threw an exception that is not an `HttpError` (the page only shows the generic message) |
| [THOR-P035](THOR-P035.md) | A `RegExp` with flags (`caseSensitive: false`…) in a `Validator.pattern` |
| [THOR-P036](THOR-P036.md) | A `Form` inside an `AutofillGroup` that is already a `<form>` |
| [THOR-P037](THOR-P037.md) | `PageRequest.loaded<D>()` with no loaded data |

## Build and code generation

| Code | What happens |
|---|---|
| [THOR-B002](THOR-B002.md) | A `ThorState` method is skipped |
| [THOR-B010](THOR-B010.md) | `cwebp` is missing for the image variants |
| [THOR-B011](THOR-B011.md) | An image in `web/images/` the build cannot read |
| [THOR-B012](THOR-B012.md) | A state uses something that cannot run in the browser |
| [THOR-B013](THOR-B013.md) | An AVIF encoder is missing for the images |
| [THOR-B014](THOR-B014.md) | A font `thor fonts metrics` cannot read |
| [THOR-B016](THOR-B016.md) | A language is missing messages |
| [THOR-B017](THOR-B017.md) | A deploy target that does not apply to this app |
| [THOR-B018](THOR-B018.md) | A state class the registry cannot name |
| [THOR-B021](THOR-B021.md) | A query or a command whose value or argument does not travel as JSON |
| [THOR-B023](THOR-B023.md) | A page with actions the registry cannot name |
| [THOR-B024](THOR-B024.md) | An action method with a schema Thor cannot build |
| [THOR-B030](THOR-B030.md) | A row lambda the build cannot give to the browser |
| [THOR-B033](THOR-B033.md) | A standalone `ValueNotifier` as a state field |
| [THOR-B035](THOR-B035.md) | A `derived(...)` that writes a field |
| [THOR-B036](THOR-B036.md) | Two states with the same class name |
