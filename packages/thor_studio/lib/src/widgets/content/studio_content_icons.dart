// Lucide icons (https://lucide.dev) the content widgets use; license notice
// in packages/thor_studio/third_party/lucide/LICENSE.
// Each is sent once per page in the icon sprite, only if the page uses it.
import 'package:thor_ui/thor_ui.dart';

/// The icons of the content widgets (callouts, file trees, cards). The rest
/// of the studio's icons are in `StudioIcons`.
abstract final class StudioContentIcons {
  /// A tip.
  static const lightbulb = IconData.svg(
    'lucide-lightbulb',
    '<path d="M15 14c.2-1 .7-1.7 1.5-2.5 1-.9 1.5-2.2 1.5-3.5A6 6 0 0 0 6 8c0 1 .2 2.2 1.5 3.5.7.7 1.3 1.5 1.5 2.5"/><path d="M9 18h6"/><path d="M10 22h4"/>',
    strokeWidth: 2,
  );

  /// A danger.
  static const octagonAlert = IconData.svg(
    'lucide-octagon-alert',
    '<path d="M12 16h.01"/><path d="M12 8v4"/><path d="M15.312 2a2 2 0 0 1 1.414.586l4.688 4.688A2 2 0 0 1 22 8.688v6.624a2 2 0 0 1-.586 1.414l-4.688 4.688a2 2 0 0 1-1.414.586H8.688a2 2 0 0 1-1.414-.586l-4.688-4.688A2 2 0 0 1 2 15.312V8.688a2 2 0 0 1 .586-1.414l4.688-4.688A2 2 0 0 1 8.688 2z"/>',
    strokeWidth: 2,
  );

  /// Flutter and Thor side by side.
  static const arrowLeftRight = IconData.svg(
    'lucide-arrow-left-right',
    '<path d="M8 3 4 7l4 4"/><path d="M4 7h16"/><path d="m16 21 4-4-4-4"/><path d="M20 17H4"/>',
    strokeWidth: 2,
  );

  /// A folder of a file tree.
  static const folder = IconData.svg(
    'lucide-folder',
    '<path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/>',
    strokeWidth: 2,
  );

  /// A file of a file tree.
  static const file = IconData.svg(
    'lucide-file',
    '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/>',
    strokeWidth: 2,
  );

  /// A copied snippet.
  static const check = IconData.svg(
    'lucide-check',
    '<path d="M20 6 9 17l-5-5"/>',
    strokeWidth: 2,
  );

  /// A link that leaves the site.
  static const arrowUpRight = IconData.svg(
    'lucide-arrow-up-right',
    '<path d="M7 7h10v10"/><path d="M7 17 17 7"/>',
    strokeWidth: 2,
  );
}
