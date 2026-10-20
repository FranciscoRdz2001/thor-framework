import 'package:thor_ui/thor_ui.dart';

/// Applies [style] to its child's element only while [condition] holds, like
/// a `:has()` or `:root` rule of the child's own class.
///
/// ```dart
/// // Hidden until a script marks the page (a button that needs JavaScript).
/// StudioWhen(
///   CssCondition.within(':root:not([data-studio-js])'),
///   const StyleProps(offstage: true),
///   child: button,
/// )
/// ```
///
/// `// web:` Flutter has no selectors. This is the typed way to say "when
/// this ancestor matches" without a CSS string and without a node of its
/// own: the rule joins the element's class like `Widget.when(hover: …)` does.
class StudioWhen extends ParentDataWrapper {
  /// Applies [style] to [child] while [condition] holds.
  const StudioWhen(
    this.condition,
    this.style, {
    super.key,
    required super.child,
  });

  /// When the style applies.
  final CssCondition condition;

  /// What changes.
  final StyleProps style;

  @override
  WrapData get wrapData =>
      WrapData(conditions: [ConditionalCss(condition, style.toCss())]);
}
