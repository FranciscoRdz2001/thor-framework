import 'package:thor_ui/thor_ui.dart';

/// What a `StudioScaffold` tells the widgets inside it: which drawer holds
/// the sidebar (so the top bar can open it) and how the open button is
/// named. Read by `StudioTopBar`; not exported.
class StudioScaffoldScope extends InheritedWidget implements InheritedMemoKey {
  /// Publishes the sidebar drawer's [sidebarId] and [menuLabel] to [child].
  const StudioScaffoldScope({
    super.key,
    required this.sidebarId,
    required this.menuLabel,
    required super.child,
  });

  /// The `id` of the sidebar's drawer (`<dialog>`).
  final String sidebarId;

  /// The accessible name of the button that opens it.
  final String menuLabel;

  /// The nearest scaffold's scope above [context], or null (a top bar used
  /// on its own, or a scaffold with no sidebar).
  static StudioScaffoldScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StudioScaffoldScope>();

  @override
  bool updateShouldNotify(covariant StudioScaffoldScope oldComponent) =>
      oldComponent.sidebarId != sidebarId ||
      oldComponent.menuLabel != menuLabel;

  @override
  Object? get memoKey => (sidebarId, menuLabel);
}
