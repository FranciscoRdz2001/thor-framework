/// Flutter's listenable builders (the listenables themselves live in
/// `thor_engine`: a `StateSignal` is a `ValueNotifier`).
///
/// `// web:` the server builds a page once, so a [ListenableBuilder] builds
/// with the current value; state that changes in the browser is a
/// `ThorState`. A `ValueListenableBuilder` on a `StateSignal` rebuilds in the
/// browser, like a `Watch`.
library;

import 'package:thor_engine/thor_engine.dart' show Listenable;

import 'framework.dart';

export 'package:thor_engine/thor_engine.dart'
    show ChangeNotifier, Listenable, ValueListenable, ValueNotifier;

/// Builds [builder] with [listenable]'s current state (see the library).
class ListenableBuilder extends StatelessWidget {
  /// Builds [builder] with [listenable] and [child].
  const ListenableBuilder({
    super.key,
    required this.listenable,
    required this.builder,
    this.child,
  });

  /// What the build reads.
  final Listenable listenable;

  /// What to build; [child] is passed through untouched.
  final Widget Function(BuildContext context, Widget? child) builder;

  /// A part of the result that doesn't depend on [listenable].
  final Widget? child;

  @override
  Widget build(BuildContext context) => builder(context, child);
}
