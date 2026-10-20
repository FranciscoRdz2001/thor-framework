/// Flutter's foundation names that don't depend on the widget tree:
/// callback signatures and the build mode.
library;

/// Flutter's `VoidCallback`: a callback with no arguments.
typedef VoidCallback = void Function();

/// Flutter's `ValueChanged`: called with a new value.
typedef ValueChanged<T> = void Function(T value);

/// Flutter's `ValueSetter`: sets a value.
typedef ValueSetter<T> = void Function(T value);

/// Flutter's `ValueGetter`: returns a value.
typedef ValueGetter<T> = T Function();

/// Flutter's `AsyncCallback`.
typedef AsyncCallback = Future<void> Function();

/// Flutter's `AsyncValueSetter`.
typedef AsyncValueSetter<T> = Future<void> Function(T value);

/// Flutter's `AsyncValueGetter`.
typedef AsyncValueGetter<T> = Future<T> Function();

/// Whether this is a release build: compiled with `-Dthor.release=true`,
/// what `thor build` and `thor export` pass (compact HTML, no debug
/// attributes or checks).
const bool kReleaseMode = bool.fromEnvironment('thor.release');

/// Whether this is a debug build (not [kReleaseMode]).
const bool kDebugMode = !kReleaseMode;

/// Whether the code runs in the browser (compiled to JavaScript).
const bool kIsWeb = bool.fromEnvironment('dart.library.js_interop');
