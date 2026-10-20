import '../core/core.dart';

/// Where a `QueryBuilder`'s builder, drawn with no data, leaves the errors
/// that were not a read of the data: the router hands them to the server's
/// `onError` (release has no other voice; `thor dev` prints them itself).
class BuilderErrorScope extends InheritedWidget {
  /// Collects into [errors].
  const BuilderErrorScope({
    super.key,
    required this.errors,
    required super.child,
  });

  /// The errors of this render.
  final List<(Object, StackTrace)> errors;

  /// The list of the render above [context], or `null` outside a routed
  /// page (a test, a static export).
  static List<(Object, StackTrace)>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BuilderErrorScope>()?.errors;

  @override
  bool updateShouldNotify(BuilderErrorScope oldComponent) => false;
}
