part of 'style_registry.dart';

/// Sets how the pages below enter from another page of the app (a
/// [PageTransition]), over the app's `PageNavigation(transition:)`. A
/// layout wraps its pages in one, a page wraps itself: the nearest scope
/// wins (a page's over its layout's).
class PageTransitionScope extends StatelessWidget implements ThorBuiltIn {
  /// Gives the page [child] is on [transition].
  const PageTransitionScope({
    super.key,
    required this.transition,
    required this.child,
  });

  /// How the page enters ([PageTransition.none]: no transition).
  final PageTransition transition;

  /// The page (or the layout around it).
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final registry = ThorStyleRegistry.active(context);
    if (registry != null) {
      // Page-level output a replayed fragment wouldn't restore.
      registry._recording?.replayable = false;
      // Built after the scopes above it: the deepest one is the last set.
      registry._transition = transition;
    }
    return child;
  }
}
