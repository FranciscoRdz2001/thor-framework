/// App components are transparent: a parent that decides by the
/// type of its child (whether it fills the width, whether its first
/// element is a thor element, a `Text` a box renders itself, a `Flex` a
/// box merges into…) sees what an app component builds, not the class
/// that wraps it. Extracting a widget never changes the layout, as in
/// Flutter.
library;

import '../core/core.dart';
import '../core/framework.dart' show fragmentChildren, previewBuild;
import 'child_rules.dart' show MultipleRoots, ThorBuiltIn, ThorElementWidget;
import 'parent_data.dart' show ParentDataWrapper;

/// Whether [widget] is an app component: a [StatelessWidget] that is not
/// one of thor's own ([ThorBuiltIn]) nor a parent-data wrapper. `Builder`
/// is one too. A `StatefulWidget` or an `InheritedWidget` is not (a state
/// is created once, where it is built).
bool isTransparent(Widget widget) =>
    widget is StatelessWidget &&
    widget is! ThorBuiltIn &&
    widget is! ParentDataWrapper;

/// [widget] as its parent sees it: each app component on top replaced by
/// what it builds (`previewBuild`), as many levels as there are. The
/// widget itself when it isn't one, or when its build can't be known
/// here (nothing is being built, or it throws before its place).
Widget? resolveComponent(Widget? widget) {
  var w = widget;
  // Bounded: a component that builds itself never ends.
  for (var i = 0; i < 64 && w != null && isTransparent(w); i++) {
    final built = previewBuild(w as StatelessWidget);
    if (built == null) return w;
    w = built;
  }
  return w;
}

/// [widget] through app components and the node-less wrappers around
/// what they build (`Padding` is an element, `Expanded` is not): the
/// widget whose element the wrappers decorate.
Widget? resolveLeaf(Widget? widget) {
  var w = resolveComponent(widget);
  for (var i = 0; i < 64 && w is ParentDataWrapper; i++) {
    w = resolveComponent(w.child);
  }
  return w;
}

/// Whether the first element of the app component [widget] (through the
/// components and parent-data wrappers it builds) is a thor element
/// ([ThorElementWidget]): a wrapper around it hands its data to that
/// element, which compiles it into its one class.
bool resolvesToElement(Widget widget) =>
    isTransparent(widget) && resolveLeaf(widget) is ThorElementWidget;

/// Whether [widget] draws other than one root node: a [MultipleRoots]
/// widget, or a fragment of none or of several (a `ResponsiveLayout`'s
/// copies), through app components and parent-data wrappers. A state of the
/// engine (a `Watch` variant) or a list's container with several roots needs
/// a box of its own to be marked and swapped as one element.
bool drawsSeveralRoots(Widget? widget) {
  // A wrapper that renders markup of its own (a `DialogTrigger`'s dialog)
  // makes a fragment when built, which `resolveLeaf` steps through.
  var wrapper = resolveComponent(widget);
  for (var i = 0; i < 64 && wrapper is ParentDataWrapper; i++) {
    if (wrapper.addsSiblings) return true;
    wrapper = resolveComponent(wrapper.child);
  }
  final w = resolveLeaf(widget);
  if (w is MultipleRoots) return true;
  final children = fragmentChildren(w);
  if (children == null) return false;
  return children.length != 1 || drawsSeveralRoots(children.single);
}
