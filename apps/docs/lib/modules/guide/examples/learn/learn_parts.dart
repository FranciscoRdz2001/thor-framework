/// The small pieces the stages of the "Aprender" benches share: a labelled
/// tile and a dashed frame that shows the free space around what it holds.
library;

import 'package:thor_ui/thor_ui.dart';

/// A rounded tile with a [label]: the stand-in for "a widget".
class LearnTile extends StatelessWidget {
  /// A tile of [width] x [height] (null: as big as its content).
  const LearnTile({
    super.key,
    required this.label,
    this.width,
    this.height,
    this.filled = true,
    this.hugs = false,
  });

  /// What it says.
  final String label;

  /// Its width, or null.
  final double? width;

  /// Its height, or null.
  final double? height;

  /// Primary when true, the quiet surface when false.
  final bool filled;

  /// Whether the tile is as wide as its label (and so can be aligned inside
  /// its parent) instead of centring the label in the space it is given.
  final bool hugs;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    alignment: hugs ? null : Alignment.center,
    padding: width != null
        ? EdgeInsets.zero
        : const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    decoration: BoxDecoration(
      color: filled ? ThemeColor.primary : ThemeColor.surfaceContainerHigh,
      // The quiet tile keeps a visible line: its fill alone vanishes on a
      // dark stage.
      border: filled
          ? null
          : Border.all(color: ThemeColor.onSurfaceVariant, width: 2),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: filled ? ThemeColor.onPrimary : ThemeColor.onSurface,
      ),
    ),
  );
}

/// A dashed frame of [width] around [child]: the box whose free space the
/// example is about.
class LearnFrame extends StatelessWidget {
  /// A frame around [child].
  const LearnFrame({
    super.key,
    this.width = 320,
    this.height,
    required this.child,
  });

  /// Its widest size: it shrinks to the space the page gives it.
  final double width;

  /// Its height, or null for its content's.
  final double? height;

  /// What it holds.
  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: width),
    child: Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(
          color: ThemeColor.outline,
          style: BorderStyle.dashed,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    ),
  );
}
