import 'package:thor_ui/thor_ui.dart';

/// What a `StudioBench` tells the panel inside it: the example's name and
/// description, so a `StudioBenchPanel` with no title of its own shows them.
class BenchScope extends InheritedWidget {
  /// Publishes [title] and [description] to the widgets in [child].
  const BenchScope({
    super.key,
    required this.title,
    required this.description,
    required super.child,
  });

  /// The example's name.
  final String? title;

  /// The example's one-sentence description.
  final String? description;

  /// The nearest bench's scope, or null outside a bench.
  static BenchScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BenchScope>();

  @override
  bool updateShouldNotify(BenchScope oldWidget) =>
      title != oldWidget.title || description != oldWidget.description;
}
