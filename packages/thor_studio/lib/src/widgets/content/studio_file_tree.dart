import 'package:thor_ui/thor_ui.dart';

import '../../theme/component_themes/studio_code_theme.dart';
import '../../theme/studio_extra_colors.dart';
import '../../theme/studio_extra_text_styles.dart';
import 'studio_content_icons.dart';

/// A file or a folder of a [StudioFileTree].
class StudioFileEntry {
  /// A file named [name]; give it [children] to make it a folder.
  const StudioFileEntry(this.name, {this.note, this.children});

  /// The file or folder name (`main.dart`, `lib/`).
  final String name;

  /// What it is for, shown after the name.
  final String? note;

  /// The folder's content (null for a file).
  final List<StudioFileEntry>? children;
}

/// A project's folders and files, as a nested list.
///
/// ```dart
/// StudioFileTree(entries: [
///   StudioFileEntry('lib/', children: [
///     StudioFileEntry('main.dart', note: 'Starts the app'),
///     StudioFileEntry('orders/', children: [
///       StudioFileEntry('orders_state.dart', note: 'The ViewModel'),
///     ]),
///   ]),
///   StudioFileEntry('pubspec.yaml'),
/// ])
/// ```
///
/// It is a real nested list (`<ul>`), so a screen reader announces the depth,
/// and the text is selectable and copyable. Names are mono; the folder icon
/// and the file icon are decoration and hidden from assistive technology.
///
/// `// web:` Flutter's `TreeView` is a lazy scrollable; this is a plain
/// `<ul>` of `<li>`s for a few files, so the browser gives the depth and
/// the text stays selectable.
class StudioFileTree extends StatelessWidget implements ThorElementWidget {
  /// A tree of [entries].
  const StudioFileTree({super.key, required this.entries, this.label});

  /// The top level.
  final List<StudioFileEntry> entries;

  /// The tree's accessible name.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = StudioCodeThemeData.of(context);
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.color,
          border: Border.all(color: theme.borderColor),
          borderRadius: BorderRadius.circular(theme.radius),
        ),
        child: _Level(entries),
      ),
    );
  }
}

class _Level extends StatelessWidget implements ThorElementWidget {
  const _Level(this.entries);

  final List<StudioFileEntry> entries;

  @override
  Widget build(BuildContext context) => Semantics(
    role: SemanticsRole.list,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final entry in entries) _Entry(entry)],
    ),
  );
}

class _Entry extends StatelessWidget implements ThorElementWidget {
  const _Entry(this.entry);

  final StudioFileEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final extra = StudioExtraColors.of(context);
    final text = Theme.of(context).textTheme;
    final codeStyles = StudioExtraTextStyles.of(context);
    final theme = StudioCodeThemeData.of(context);
    final children = entry.children;
    return Semantics(
      role: SemanticsRole.listItem,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              spacing: 8,
              children: [
                Semantics(
                  hidden: true,
                  child: Icon(
                    children == null
                        ? StudioContentIcons.file
                        : StudioContentIcons.folder,
                    size: 16,
                    color: children == null
                        ? scheme.onSurfaceVariant!
                        : extra.onSurfaceSoft,
                  ),
                ),
                Flexible(
                  child: Text(
                    entry.name,
                    style: codeStyles.codeSmall.copyWith(
                      color: scheme.onSurface,
                      fontWeight: children == null
                          ? FontWeight.w400
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (entry.note != null)
                  Flexible(
                    child: Text(
                      entry.note!,
                      style: text.bodySmall.copyWith(
                        color: theme.headerTextColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (children != null && children.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(left: 7),
              padding: const EdgeInsets.only(left: 15),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: theme.borderColor)),
              ),
              child: _Level(children),
            ),
        ],
      ),
    );
  }
}
