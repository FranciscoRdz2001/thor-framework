import 'package:thor_ui/thor_ui.dart';

/// Gives its child's element a tag, attributes and state rules: the pieces
/// of HTML thor has no widget for (`<details>`, `<summary>`, a `:target-current`
/// rule). Like `StudioAttributes` it adds no node of its own. Not exported.
class StudioMarkup extends ParentDataWrapper {
  /// Wraps [child] with the given [tag], [attributes] and [conditions].
  const StudioMarkup({
    super.key,
    this.tag,
    this.baseCss = const {},
    this.css = const {},
    this.attributes = const {},
    this.conditions = const [],
    required super.child,
  });

  /// Replaces the child element's tag.
  final String? tag;

  /// Defaults under the child's own styles.
  final CssDeclarations baseCss;

  /// Declarations that win over the child's own.
  final CssDeclarations css;

  /// Attributes of the child's element.
  final Map<String, String> attributes;

  /// State and feature rules of the child's element.
  final List<ConditionalCss> conditions;

  @override
  WrapData get wrapData => WrapData(
    tag: tag,
    baseCss: baseCss,
    css: css,
    attributes: attributes,
    conditions: conditions,
  );
}
