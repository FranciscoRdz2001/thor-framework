import 'package:thor_ui/thor_ui.dart';

/// The editor's tags: Enter in the tag field adds one, × removes it, and
/// each posts with the form as a hidden `tag` field. Without JS the field
/// itself posts (`tagInput`, split by the server).
class TagEditor extends ThorState {
  /// The article's tags.
  final tags = state(const <String>[]);

  /// Adds [tag] (trimmed; ignored when empty or repeated).
  void add(String tag) {
    final t = tag.trim();
    if (t.isEmpty || tags.value.contains(t)) return;
    tags.value = [...tags.value, t];
  }

  /// Removes [tag].
  void remove(String tag) => tags.value = [
    for (final t in tags.value)
      if (t != tag) t,
  ];

  /// Row key.
  String tagKey(String tag) => tag;

  /// Row text (and hidden field value).
  String tagName(String tag) => tag;
}

/// The page's tag editor.
final tagEditor = TagEditor();
