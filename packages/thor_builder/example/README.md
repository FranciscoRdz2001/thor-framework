# thor_builder example

`thor_builder` is not called from code: an app lists it under
`dev_dependencies` and the `thor` command runs it.

```yaml
# pubspec.yaml of the app
dev_dependencies:
  thor_builder:
```

Given a state class like this one in `lib/counter_state.dart`:

```dart
import 'package:thor_ui/thor_ui.dart';

class CounterState extends ThorState {
  final count = state(0);

  void inc() => count.value++;
}

final counter = CounterState();
```

`thor dev` and `thor build` run `bin/entries.dart`, which writes, under
`.dart_tool/thor/`, the members of `CounterState` and the entries the
server starts from. The app never imports them:

```bash
thor dev        # generate, serve and rebuild on change
thor build      # release build
```

`build_runner` only generates `lib/l10n/app_localizations.thor.dart` from
the app's `lib/l10n/*.arb` files (add `build_runner` to `dev_dependencies`
for it):

```bash
dart run build_runner build
```
