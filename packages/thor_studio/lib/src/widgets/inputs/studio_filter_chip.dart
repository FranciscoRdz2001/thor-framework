import 'package:thor_ui/thor_ui.dart';

import '../../theme/component_themes/studio_chip_theme.dart';
import '../../tokens/color/studio_tone.dart';
import 'state_styles.dart';

/// A pill for filtering (Flutter's `FilterChip`): gray when off, the
/// selected fill when on.
///
/// ```dart
/// StudioFilterChip(
///   label: Text('Buttons'),
///   selected: filter.isButtons(),
///   onSelected: filter.setButtons, // a ThorState method: void (bool)
/// )
/// StudioFilterChip(
///   label: Text('Inputs'),
///   selected: false,
///   href: '/components?filter=inputs', // web: a link that applies it
/// )
/// ```
///
/// Like Flutter, a chip with neither [onSelected] nor [href] is disabled: it
/// is not a label (use `StudioStatusLabel` for one). With [onSelected] it is
/// a toggle button (`aria-pressed`, native focus, Enter and Space); the
/// callback has `FilterChip.onSelected`'s shape (`ValueChanged<bool>`), so a
/// `ThorState` method with a `bool` parameter drives it. With [href] it is a
/// link to the page that applies the filter (`aria-current` when [selected]),
/// which works without JavaScript.
///
/// Colors, height and padding come from the nearest [StudioChipThemeData];
/// [theme] overrides it. A [tone] other than neutral tints the selected chip
/// with that tone's colors.
///
/// `// web:` Flutter's `FilterChip` has a checkmark and an elevation; this
/// one is a pill with the selected fill and no checkmark, built on thor's
/// `FilterChip` element, so it is one `<button>` or `<a>`. It squeezes to
/// `scale(.97)` while pressed (the studio's press feedback) and eases its
/// fill on hover. `StudioTheme` also fills `chipTheme`, so a plain
/// `FilterChip` is already this pill; this widget adds the squeeze and
/// the tone.
class StudioFilterChip extends StatelessWidget implements ThorElementWidget {
  /// A chip showing [label].
  const StudioFilterChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.href,
    this.tone = StudioTone.neutral,
    this.theme,
  });

  /// The content, usually a `Text`.
  final Widget label;

  /// Whether the filter is on.
  final bool selected;

  /// Called with the new `selected` when the chip is pressed (a `ThorState`
  /// method); null (and no [href]) disables the chip.
  final ValueChanged<bool>? onSelected;

  /// Makes the chip a link to the page that applies (or removes) the filter.
  final String? href;

  /// The tint of the selected chip (neutral, or a status).
  final StudioTone tone;

  /// Overrides the chip theme.
  final StudioChipThemeData? theme;

  @override
  Widget build(BuildContext context) {
    final t = StudioChipThemeData.of(context, theme);
    final toned = switch (tone) {
      StudioTone.neutral => null,
      StudioTone.info => t.info,
      StudioTone.ok => t.ok,
      StudioTone.warn => t.warn,
      StudioTone.danger => t.danger,
      StudioTone.flutter => t.flutter,
    };
    return Styled(
      duration: t.duration,
      curve: t.curve,
      style: const StyleProps(
        scale: 1,
      ).when(pressed: StyleProps(scale: t.pressScale)),
      child: StateStyles(
        states: [
          // The chip keeps one label color for both states; the chosen one
          // flips it on its own element, so no class changes.
          StateStyle.selector(
            ':is([aria-pressed="true"],[aria-current="true"]):not(:disabled)',
            StyleProps(
              textStyle: TextStyle(
                color: toned?.foreground ?? t.selectedLabelColor,
              ),
            ),
          ),
        ],
        child: FilterChip(
          label: label,
          selected: selected,
          onSelected: onSelected,
          href: href,
          showCheckmark: false,
          backgroundColor: t.color,
          selectedColor: toned?.background ?? t.selectedColor,
          side: BorderSide(color: t.borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radius),
          ),
          padding: t.padding,
          labelStyle: t.labelStyle.copyWith(color: t.labelColor),
        ),
      ),
    );
  }
}
