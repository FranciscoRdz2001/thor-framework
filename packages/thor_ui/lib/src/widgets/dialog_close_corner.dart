import '../core/core.dart';
import '../foundation/material_localizations.dart' show MaterialLocalizations;
import '../foundation/parent_data.dart';
import '../foundation/style_registry.dart' show ConditionalCss, CssCondition;
import '../foundation/stylesheet.dart' show WindowSizeClass;
import 'icon.dart' show Icon, IconButton;
import 'icons.dart' show Icons;
import 'material.dart' show DialogClose;

/// The close button of a panel built with `showClose: true`: an icon button
/// in its top corner, named by the localized "Close", that closes the dialog
/// it is in.
///
/// `// web:` Flutter's dialogs have no built-in close button (the route
/// pops from a button the app writes); here the panel can bring it, so the
/// app doesn't repeat the same corner button in each one.
class DialogCloseCorner extends StatelessWidget {
  /// The button; [hiddenFrom] hides it from that breakpoint up (the inline
  /// state of a `Drawer(permanentFrom:)`, which has nothing to close).
  const DialogCloseCorner({super.key, this.hiddenFrom});

  /// Breakpoint from which the button is not drawn.
  final WindowSizeClass? hiddenFrom;

  @override
  Widget build(BuildContext context) => WrapWith(
    WrapData(
      css: const {
        'position': 'absolute',
        'inset-block-start': '8px',
        'inset-inline-end': '8px',
        'z-index': '1',
      },
      conditions: [
        if (hiddenFrom case final bp?)
          ConditionalCss(CssCondition.breakpoint(bp), const {
            'display': 'none',
          }),
      ],
    ),
    child: DialogClose(
      child: IconButton(
        icon: const Icon(Icons.close),
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
      ),
    ),
  );
}
