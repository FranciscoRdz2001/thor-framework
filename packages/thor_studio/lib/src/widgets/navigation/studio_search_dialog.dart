import 'package:thor_ui/thor_ui.dart';

import '../../attributes.dart';
import '../../icons.dart';
import '../../l10n/studio_localizations.dart';
import '../../theme/studio_extra_colors.dart';
import '../../theme/studio_extra_text_styles.dart';
import '../../tokens/color/studio_shadow_colors.dart';
import '../../tokens/color/studio_surface_colors.dart';
import '../../tokens/shape/studio_radii.dart';
import '../../tokens/spacing/studio_spacing.dart';

/// The search dialog a `StudioSearchPill` can open: a modal `<dialog>`
/// 640 px wide, 12 % from the top, with a borderless 48 px field, the
/// [results] under it and a line of key [hints] at the bottom.
///
/// ```dart
/// StudioSearchDialog(
///   id: 'docs-search',
///   action: '/search',              // the field submits here (GET, `q`)
///   placeholder: l10n.searchHint,
///   results: const MyResults(),     // what a script fills as you type
///   hints: [('↑↓', 'Move'), ('↵', 'Open'), ('Esc', 'Close')],
/// )
/// ```
///
/// It is a plain form: Enter sends the query to [action], so the dialog
/// works as a way into the search page when no script answers. Searching as
/// you type and opening it from the pill or a key are the site's script
/// (`document.getElementById(id).showModal()`).
///
/// `// web:` Flutter's `SearchAnchor` opens a view over the page; here it is
/// a native modal `<dialog>` (focus trap, Esc and a click on the backdrop
/// close it). It fades in and rises 8 px (160 ms); under
/// `prefers-reduced-motion` it just appears.
class StudioSearchDialog extends StatelessWidget implements ThorElementWidget {
  /// A search dialog with the DOM [id] whose field submits to [action].
  const StudioSearchDialog({
    super.key,
    required this.id,
    required this.action,
    required this.results,
    this.label,
    this.placeholder,
    this.inputName = 'q',
    this.hints = const [],
  });

  /// The dialog's DOM id (what the script opens).
  final String id;

  /// Where the field sends the query (a GET, as [inputName]).
  final String action;

  /// The results' area (a script fills it).
  final Widget results;

  /// The dialog's accessible name (default: `StudioLocalizations.search`).
  final String? label;

  /// The field's placeholder (default: `StudioLocalizations.search`).
  final String? placeholder;

  /// The query's parameter name.
  final String inputName;

  /// The key hints of the bottom line: (keys, what they do).
  final List<(String, String)> hints;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final extra = StudioExtraColors.of(context);
    final mono = StudioExtraTextStyles.of(context);
    final l10n = StudioLocalizations.of(context);
    return Dialog(
      id: id,
      label: label ?? l10n.search,
      backgroundColor: scheme.surfaceContainer,
      // The page behind reads dimmed, as behind the drawer.
      barrierColor: StudioShadowColors.scrim,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StudioRadii.card),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: StudioSpacing.md,
        vertical: StudioSpacing.lg,
      ),
      // web: a fixed height, so the centred dialog does not move as the
      // results grow (the browser caps it at the window).
      constraints: const BoxConstraints(
        maxWidth: 640,
        minHeight: 560,
        maxHeight: 560,
      ),
      child: SizedBox(
        width: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StudioAttributes(
              {'role': 'search', 'action': action, 'method': 'get'},
              child: Semantics(
                role: SemanticsRole.form,
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(
                    horizontal: StudioSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: scheme.outlineVariant),
                    ),
                  ),
                  child: Row(
                    spacing: StudioSpacing.sm,
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          StudioIcons.search,
                          size: 18,
                          color: scheme.onSurfaceVariant!,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          name: inputName,
                          keyboardType: TextInputType.webSearch,
                          style: text.bodyLarge.copyWith(
                            color: scheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: placeholder ?? l10n.search,
                            hintStyle: text.bodyLarge.copyWith(
                              color: scheme.onSurfaceVariant!,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: StudioSpacing.sm,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Styled(
              style: const StyleProps(
                maxHeight: Length.vh(56),
                overflowY: Overflow.auto,
              ),
              child: Padding(
                padding: const EdgeInsets.all(StudioSpacing.xs),
                child: results,
              ),
            ),
            if (hints.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: StudioSpacing.md,
                  vertical: StudioSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: StudioSurfaceColors.canvas,
                  border: Border(top: BorderSide(color: scheme.outlineVariant)),
                ),
                child: Row(
                  spacing: StudioSpacing.md,
                  children: [
                    for (final (keys, what) in hints)
                      Row(
                        spacing: 6,
                        children: [
                          Semantics(
                            role: SemanticsRole.keyboardKey,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainer,
                                border: Border.all(
                                  color: scheme.outlineVariant,
                                ),
                                borderRadius: BorderRadius.circular(
                                  StudioRadii.small,
                                ),
                              ),
                              child: Text(
                                keys,
                                style: mono.codeSmall.copyWith(
                                  fontSize: 11,
                                  color: extra.onSurfaceFaint,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            what,
                            style: text.bodySmall.copyWith(
                              color: extra.onSurfaceFaint,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
