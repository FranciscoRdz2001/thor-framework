import 'package:thor_ui/thor_ui.dart';

import '../../attributes.dart';
import '../../theme/component_themes/studio_nav_theme.dart';
import 'studio_nav_destination.dart';

const _clear = Colors.transparent;

/// The link of the top bar and the locale menu: a pill whose text brightens
/// on hover and that marks the current page with `aria-current="page"` in
/// the accent on its tint. Not exported (the sidebar and the table of
/// contents mark theirs with a bar on a rail instead).
///
/// `// web:` it squeezes under the finger (`:active`, [pressScale]) like
/// every pressable of the studio; the squeeze is dropped by the motion guard
/// of `Styled`'s transition under `prefers-reduced-motion`.
class NavItemLink extends StatelessWidget implements ThorElementWidget {
  /// A pill linking to [destination].
  const NavItemLink(
    this.destination, {
    super.key,
    this.padding,
    this.attributes = const {},
    this.pressScale,
    this.current = false,
  });

  /// Where it goes.
  final StudioNavDestination destination;

  /// Whether it is the current page (`aria-current="page"`).
  final bool current;

  /// The space inside the pill (default: the nav theme's).
  final EdgeInsets? padding;

  /// Extra attributes of the link (`hreflang`).
  final Map<String, String> attributes;

  /// The scale while pressed (a wide pill squeezes less than a small one;
  /// default: the nav theme's).
  final double? pressScale;

  @override
  Widget build(BuildContext context) {
    final nav = StudioNavThemeData.of(context);
    final text = Theme.of(context).textTheme;
    return Styled(
      duration: nav.duration,
      curve: nav.curve,
      style: const StyleProps(
        scale: 1,
      ).when(pressed: StyleProps(scale: pressScale ?? nav.pressScale)),
      child: Link(
        href: RouteUrl(destination.href),
        current: current,
        child: StudioAttributes(
          attributes,
          // The label's color fades with the fill (same timing), instead of
          // snapping while the fill eases.
          child: AnimatedDefaultTextStyle(
            duration: nav.duration,
            curve: nav.curve,
            style: TextStyle(
              color: current
                  ? nav.currentMarkColor
                  : nav.itemColor.when(hover: nav.selectedItemColor),
            ),
            child: AnimatedContainer(
              duration: nav.duration,
              curve: nav.curve,
              padding: padding ?? nav.itemPadding,
              decoration: BoxDecoration(
                color: current
                    ? nav.selectedItemBackground
                    : _clear.when(hover: nav.itemHoverColor),
                borderRadius: BorderRadius.circular(nav.itemRadius),
              ),
              child: Text(destination.label, style: text.labelLarge),
            ),
          ),
        ),
      ),
    );
  }
}
