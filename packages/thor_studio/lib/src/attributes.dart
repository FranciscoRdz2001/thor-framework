import 'package:thor_ui/thor_ui.dart';

/// Adds HTML attributes (`aria-*`, `role`, `id`) to its child's element,
/// without a node of its own.
class StudioAttributes extends ParentDataWrapper {
  /// Puts [attributes] on [child]'s element.
  const StudioAttributes(this.attributes, {super.key, required super.child});

  /// The attributes.
  final Map<String, String> attributes;

  @override
  WrapData get wrapData => WrapData(attributes: attributes);
}
