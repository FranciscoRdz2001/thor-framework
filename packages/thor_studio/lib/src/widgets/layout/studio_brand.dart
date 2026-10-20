import 'package:thor_ui/thor_ui.dart';

import '../../theme/studio_extra_colors.dart';
import '../../theme/studio_extra_text_styles.dart';
import '../../tokens/shape/studio_radii.dart';
import '../../tokens/spacing/studio_spacing.dart';

/// The product mark and name, linking home: the accent square with one
/// letter, then the name in the title role.
///
/// ```dart
/// StudioTopBar(brand: StudioBrand(name: 'Thor', href: '/'), …)
/// ```
///
/// Colors come from the theme's `ColorScheme` (`accent`, `onAccent`,
/// `onSurface`) and the type from `StudioExtraTextStyles` (`codeSmall`) and
/// the `TextTheme` (`titleMedium`), so the brand follows both themes and a swapped accent.
class StudioBrand extends StatelessWidget implements ThorElementWidget {
  /// A brand linking to [href].
  const StudioBrand({
    super.key,
    required this.name,
    this.href = '/',
    this.mark,
    this.version,
  });

  /// A version chip after the name (`0.1`), or null.
  final String? version;

  /// The product's name.
  final String name;

  /// Home.
  final String href;

  /// The letter in the mark (default: the first letter of [name]).
  final String? mark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final codeStyles = StudioExtraTextStyles.of(context);
    return Link(
      href: RouteUrl(href),
      child: Row(
        spacing: StudioSpacing.xs,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.accent,
              borderRadius: BorderRadius.circular(StudioRadii.small),
            ),
            child: ExcludeSemantics(
              child: Text(
                mark ?? (name.isEmpty ? '' : name.substring(0, 1)),
                style: codeStyles.codeSmall.copyWith(
                  fontWeight: FontWeight.w500,
                  color: scheme.onAccent,
                ),
              ),
            ),
          ),
          Text(
            name,
            style: text.titleMedium.copyWith(
              fontSize: 15,
              color: scheme.onSurface,
            ),
          ),
          if (version != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(StudioRadii.control),
              ),
              child: Text(
                version!,
                style: codeStyles.codeSmall.copyWith(
                  fontWeight: FontWeight.w500,
                  color: StudioExtraColors.of(context).onSurfaceSoft,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
