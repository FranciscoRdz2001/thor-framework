import 'package:thor_ui/thor_ui.dart';

import '../../theme/component_themes/studio_chip_theme.dart';
import '../../tokens/spacing/studio_spacing.dart';
import '../content/studio_prose.dart';

/// The opening of a page: an optional [eyebrow] pill, the `h1` [title] and a
/// [lead] paragraph.
///
/// ```dart
/// StudioPageHeader(
///   eyebrow: l10n.sectionLearn, // 'Learn'
///   title: l10n.widgetsTitle,    // 'Widgets'
///   lead: l10n.widgetsLead,      // 'Everything is a widget…'
/// )
/// ```
///
/// The title is the page's only `h1`: 36 px (30 on a phone), balanced over
/// its lines; the lead is 17 px in the soft ink, at most 640 px wide.
class StudioPageHeader extends StatelessWidget implements ThorElementWidget {
  /// A header titled [title].
  const StudioPageHeader({
    super.key,
    this.eyebrow,
    required this.title,
    this.lead,
    this.leadMarkup,
  });

  /// The section the page belongs to, as a gray pill over the title.
  final String? eyebrow;

  /// The page's title (`h1`).
  final String title;

  /// One or two sentences under the title.
  final String? lead;

  /// The lead as trusted HTML (a rendered markdown paragraph), in place of
  /// [lead]: its links and inline code keep their look.
  final String? leadMarkup;

  @override
  Widget build(BuildContext context) {
    final chip = StudioChipThemeData.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final title = text.displaySmall.copyWith(
      color: scheme.onSurface,
      height: 1.15,
      letterSpacing: -0.72, // -0.02em at 36 px
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: StudioSpacing.sm,
      children: [
        if (eyebrow != null)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: chip.padding.horizontal / 2,
              vertical: StudioSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: chip.color,
              borderRadius: BorderRadius.circular(chip.radius),
            ),
            child: Text(
              eyebrow!,
              style: text.labelMedium.copyWith(color: chip.labelColor),
            ),
          ),
        Semantics(
          headingLevel: 1,
          child: Styled(
            style: const StyleProps(textWrap: TextWrap.balance),
            child: Text(
              this.title,
              style: title
                  .copyWith(fontSize: 30, letterSpacing: -0.6)
                  .when(medium: title),
            ),
          ),
        ),
        if (leadMarkup != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: StudioProse.lead(leadMarkup!),
          )
        else if (lead != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Text(lead!, style: StudioProse.leadStyle(context)),
          ),
      ],
    );
  }
}
