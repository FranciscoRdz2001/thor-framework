import 'package:thor_server/thor_server.dart' show PageRequest;

import '../core/core.dart';
import 'errors.dart';

/// The request the page is rendering for, visible to every widget below
/// (the current path for an active link, the signed-in user in `locals`).
///
/// ```dart
/// final path = RequestScope.of(context).uri.path;
/// ```
class RequestScope extends InheritedWidget {
  /// Publishes [request] to [child].
  const RequestScope({super.key, required this.request, required super.child});

  /// The request.
  final PageRequest request;

  /// The nearest request above [context].
  static PageRequest of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RequestScope>();
    if (scope == null) {
      throw StateError(
        thorError(
          'THOR-R010',
          'RequestScope.of: no page request above this widget',
        ),
      );
    }
    return scope.request;
  }

  /// The nearest request, or `null` outside a routed page (a test).
  static PageRequest? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RequestScope>()?.request;

  @override
  bool updateShouldNotify(RequestScope oldWidget) =>
      oldWidget.request != request;
}
