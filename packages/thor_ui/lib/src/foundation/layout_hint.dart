import 'dart:collection';

import '../core/core.dart';
import 'parent_data.dart';
import 'transparent.dart';

/// Flutter's "constraints go down, sizes go up", reduced to what CSS can't
/// infer on its own.
///
/// In Flutter, `Center > Container(maxWidth: 1080) > Column(stretch)` is
/// 1080px wide: the Column asks for the max width and its parents grow to
/// it. In CSS a centered box shrinks to its content instead. Widgets that
/// would take the incoming max width in Flutter report it here, and their
/// parent's `ChildRules.fillWidth` makes them fill it.
///
/// An app component reports what its `build` returns: it needs
/// no hint of its own. One that implements this interface is taken at its
/// word instead.
abstract interface class LayoutHint {
  /// Whether this widget takes the max available width in Flutter semantics.
  bool get fillsWidth;
}

/// Whether [component] takes the max available width in Flutter semantics.
///
/// Remembered per widget during a render ([clearLayoutHints]): a hint
/// often asks its child's, so without it a chain of d boxes costs O(d²) as
/// each level builds.
bool layoutFillsWidth(Widget? component) => component == null
    ? false
    : _fillsWidth[component] ??= switch (component) {
        final LayoutHint c => c.fillsWidth,
        final ParentDataWrapper c => layoutFillsWidth(c.child),
        _ when isTransparent(component) => switch (resolveComponent(
          component,
        )) {
          final built when !identical(built, component) => layoutFillsWidth(
            built,
          ),
          _ => false,
        },
        _ => false,
      };

// Per render: a `Watch`'s hint follows its request's state, so a widget
// shared between requests (a top-level `final`) may answer differently in
// the next render.
// Identity maps, not `Expando`s: a render reads and writes them for most of
// its widgets, and a weak table that starts empty on every page rehashes
// as it grows. Cleared with each page, so they hold nothing longer.
final _fillsWidth = HashMap<Widget, bool>.identity();
final _fillsHeight = HashMap<Widget, bool>.identity();

/// Forgets the remembered hints: the render core calls it before each
/// page (a render is synchronous, so one memo never spans two requests).
void clearLayoutHints() {
  _fillsWidth.clear();
  _fillsHeight.clear();
}

/// Flutter widgets that take the max *height* they are given (a Column
/// with `MainAxisSize.max`, scroll views, `Align`…): in a Row they stretch
/// across its height.
abstract interface class HeightHint {
  /// Whether this widget takes the max available height in Flutter semantics.
  bool get fillsHeight;
}

/// Whether [component] takes the max available height in Flutter semantics
/// (remembered per widget, like [layoutFillsWidth]).
bool layoutFillsHeight(Widget? component) => component == null
    ? false
    : _fillsHeight[component] ??= switch (component) {
        final HeightHint c => c.fillsHeight,
        final ParentDataWrapper c => layoutFillsHeight(c.child),
        _ when isTransparent(component) => switch (resolveComponent(
          component,
        )) {
          final built when !identical(built, component) => layoutFillsHeight(
            built,
          ),
          _ => false,
        },
        _ => false,
      };
