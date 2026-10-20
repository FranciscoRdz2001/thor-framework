import 'package:thor_ui/thor_ui.dart';

import '../../theme/component_themes/studio_nav_theme.dart';
import '../../tokens/shape/studio_radii.dart';

/// A round icon button of the top bar (the repository, settings), the same
/// size and look as the search magnifier and the theme toggle: no border, the
/// hover surface under the pointer, a press that squeezes it.
///
/// ```dart
/// StudioIconButton(
///   icon: Icon(StudioIcons.github, size: 18),
///   tooltip: 'Repository', // its accessible name
///   href: 'https://github.com/…',
///   newTab: true,
/// )
/// ```
///
/// Like Flutter's `IconButton`: an [icon], a [tooltip] (its accessible name)
/// and [onPressed]. With [href] it is a link instead, which works without
/// JavaScript.
///
/// `// web:` [href] and [newTab] have no Flutter counterpart (a web page goes
/// to an address; `target="_blank"` opens a new tab and adds
/// `rel="noopener"`). Flutter's plain `IconButton(href:, tooltip:)` is the
/// same button without the studio's round hover surface and squeeze.
class StudioIconButton extends StatelessWidget implements ThorElementWidget {
  /// A button showing [icon], named [tooltip].
  const StudioIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.href,
    this.newTab = false,
    this.size,
  });

  /// The side of the round button (default: the nav theme's search height,
  /// 36).
  final double? size;

  /// The icon (an `Icon` of about 18 px).
  final Widget icon;

  /// Its accessible name.
  final String tooltip;

  /// Called when the button is pressed (a `ThorState` method).
  final VoidCallback? onPressed;

  /// Makes the button a link to this address.
  final String? href;

  /// Opens [href] in a new tab.
  final bool newTab;

  @override
  Widget build(BuildContext context) {
    final nav = StudioNavThemeData.of(context);
    final glyph = DefaultTextStyle(
      style: TextStyle(color: nav.hintColor),
      child: icon,
    );
    final round = AnimatedContainer(
      duration: nav.duration,
      curve: nav.curve,
      width: size ?? nav.searchHeight,
      height: size ?? nav.searchHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: nav.barColor.when(hover: nav.itemHoverColor),
        borderRadius: BorderRadius.circular(StudioRadii.control),
      ),
      child: glyph,
    );
    return Styled(
      duration: nav.duration,
      curve: nav.curve,
      style: const StyleProps(
        scale: 1,
      ).when(pressed: StyleProps(scale: nav.pressScale)),
      child: href != null
          // The link is named by [tooltip]; the bubble only repeats it.
          ? Tooltip(
              message: tooltip,
              excludeFromSemantics: true,
              child: Link(
                href: RouteUrl(href!),
                newTab: newTab,
                label: tooltip,
                child: round,
              ),
            )
          : IconButton(
              onPressed: onPressed,
              tooltip: tooltip,
              icon: round,
              padding: EdgeInsets.zero,
            ),
    );
  }
}
