// Lucide icons (https://lucide.dev) the bench uses; license notice in
// packages/thor_studio/third_party/lucide/LICENSE.
// Each is sent once per page in the icon sprite, only if the page uses it.
import 'package:thor_ui/thor_ui.dart';

/// The glyphs of the bench's own controls.
abstract final class BenchIcons {
  /// The live demo.
  static const box = IconData.svg(
    'lucide-box',
    '<path d="M21 8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z"/><path d="m3.3 7 8.7 5 8.7-5"/><path d="M12 22V12"/>',
    strokeWidth: 2,
  );

  /// The code view.
  static const code = IconData.svg(
    'lucide-code',
    '<polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/>',
    strokeWidth: 2,
  );

  /// Replay.
  static const rotateCcw = IconData.svg(
    'lucide-rotate-ccw',
    '<path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/>',
    strokeWidth: 2,
  );
}
