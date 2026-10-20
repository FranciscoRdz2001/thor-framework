/// Where app code builds each element, for the development inspector.
///
/// Structure: the server's widget tree (`PageBuild`, `core/framework.dart`)
/// gives every element the source of the nearest app code that built it
/// (a widget's `build`, a `State.build`, a `Builder` closure or a route's
/// `build` function) and writes it as `data-thor-src="/abs/file.dart:12:3"`.
/// `thor dev`'s proxy adds the script that reads it (Alt+click opens the
/// editor). Only on the Dart VM in JIT with `THOR_DEV=1`: a release build
/// (AOT, `-Dthor.release=true`) compiles the stub and writes nothing.
library;

import 'foundation.dart';
import 'inspect_stub.dart' if (dart.library.mirrors) 'inspect_vm.dart' as impl;

/// The attribute with the source of an element's app code.
const inspectSourceAttribute = 'data-thor-src';

/// The attribute with the place of an element in the widget tree of the app
/// code that builds it: `0.1.0`, the child indexes down from the
/// root of that build; `/` separates the builds nested through app
/// widgets (`0.1/0.0`: the second child of the page's root is an app widget
/// whose own build starts again at `0`).
const inspectAtAttribute = 'data-thor-at';

/// Switches and lookups of the development inspector.
abstract final class ThorInspect {
  /// Whether pages carry [inspectSourceAttribute]: in debug, when
  /// `thor dev` or `thor render` runs the server (`THOR_DEV=1`). Tests set
  /// it.
  static bool enabled = kDebugMode && impl.enabledByDefault();

  /// `file:line:column` of what builds [owner] (a widget or state type, or
  /// a function), or null when it isn't app code (thor's, the SDK's,
  /// generated `.thor.dart`) or sources can't be read here.
  static String? sourceOf(Object owner) => impl.sourceOf(owner);

  /// Forgets the sources [sourceOf] remembers: `thor dev` calls it on
  /// every reload, when a class's `build` may have moved.
  static void clearSources() => impl.clearSources();
}

/// A widget that builds what a function it holds returns (a route's page,
/// a `Builder`): the inspector points at that function, not at the widget.
abstract interface class InspectSourceOwner {
  /// The function whose code builds this widget's content.
  Function get inspectSource;
}
