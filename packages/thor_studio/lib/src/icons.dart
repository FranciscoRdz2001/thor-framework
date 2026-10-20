// Lucide icons (https://lucide.dev): the set the studio uses. ISC license
// (part MIT, from Feather); the notice is
// packages/thor_studio/third_party/lucide/LICENSE.
// Each is sent once per page in the icon sprite, only if the page uses it.
import 'package:thor_ui/thor_ui.dart';

/// The studio's icons.
abstract final class StudioIcons {
  /// Guides.
  static const bookOpen = IconData.svg(
    'lucide-book-open',
    '<path d="M12 7v14"/><path d="M3 18a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h5a4 4 0 0 1 4 4 4 4 0 0 1 4-4h5a1 1 0 0 1 1 1v13a1 1 0 0 1-1 1h-6a3 3 0 0 0-3 3 3 3 0 0 0-3-3z"/>',
    strokeWidth: 2,
  );

  /// Widgets, catalogs.
  static const layoutGrid = IconData.svg(
    'lucide-layout-grid',
    '<rect width="7" height="7" x="3" y="3" rx="1"/><rect width="7" height="7" x="14" y="3" rx="1"/><rect width="7" height="7" x="14" y="14" rx="1"/><rect width="7" height="7" x="3" y="14" rx="1"/>',
    strokeWidth: 2,
  );

  /// The engine.
  static const zap = IconData.svg(
    'lucide-zap',
    '<path d="M4 14a1 1 0 0 1-.78-1.63l9.9-10.2a.5.5 0 0 1 .86.46l-1.92 6.02A1 1 0 0 0 13 10h7a1 1 0 0 1 .78 1.63l-9.9 10.2a.5.5 0 0 1-.86-.46l1.92-6.02A1 1 0 0 0 11 14z"/>',
    strokeWidth: 2,
  );

  /// The server.
  static const server = IconData.svg(
    'lucide-server',
    '<rect width="20" height="8" x="2" y="2" rx="2" ry="2"/><rect width="20" height="8" x="2" y="14" rx="2" ry="2"/><line x1="6" x2="6.01" y1="6" y2="6"/><line x1="6" x2="6.01" y1="18" y2="18"/>',
    strokeWidth: 2,
  );

  /// API reference, code.
  static const code = IconData.svg(
    'lucide-code',
    '<polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/>',
    strokeWidth: 2,
  );

  /// Search.
  static const search = IconData.svg(
    'lucide-search',
    '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>',
    strokeWidth: 2,
  );

  /// Dark theme.
  static const moon = IconData.svg(
    'lucide-moon',
    '<path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/>',
    strokeWidth: 2,
  );

  /// Light theme.
  static const sun = IconData.svg(
    'lucide-sun',
    '<circle cx="12" cy="12" r="4"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="m4.93 4.93 1.41 1.41"/><path d="m17.66 17.66 1.41 1.41"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="m6.34 17.66-1.41 1.41"/><path d="m19.07 4.93-1.41 1.41"/>',
    strokeWidth: 2,
  );

  /// The repository.
  static const github = IconData.svg(
    'lucide-github',
    '<path d="M15 22v-4a4.8 4.8 0 0 0-1-3.5c3 0 6-2 6-5.5.08-1.25-.27-2.48-1-3.5.28-1.15.28-2.35 0-3.5 0 0-1 0-3 1.5-2.64-.5-5.36-.5-8 0C6 2 5 2 5 2c-.3 1.15-.3 2.35 0 3.5A5.403 5.403 0 0 0 4 9c0 3.5 3 5.5 6 5.5-.39.49-.68 1.05-.85 1.65-.17.6-.22 1.23-.15 1.85v4"/><path d="M9 18c-4.51 2-5-2-7-2"/>',
    strokeWidth: 2,
  );

  /// Copy.
  static const copy = IconData.svg(
    'lucide-copy',
    '<rect width="14" height="14" x="8" y="8" rx="2" ry="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/>',
    strokeWidth: 2,
  );

  /// A link to this place.
  static const link = IconData.svg(
    'lucide-link',
    '<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/>',
    strokeWidth: 2,
  );

  /// Previous.
  static const chevronLeft = IconData.svg(
    'lucide-chevron-left',
    '<path d="m15 18-6-6 6-6"/>',
    strokeWidth: 2,
  );

  /// Next.
  static const chevronRight = IconData.svg(
    'lucide-chevron-right',
    '<path d="m9 18 6-6-6-6"/>',
    strokeWidth: 2,
  );

  /// Chevron down (a select's trigger).
  static const chevronDown = IconData.svg(
    'lucide-chevron-down',
    '<path d="m6 9 6 6 6-6"/>',
    strokeWidth: 2,
  );

  /// Forward, "go".
  static const arrowRight = IconData.svg(
    'lucide-arrow-right',
    '<path d="M5 12h14"/><path d="m12 5 7 7-7 7"/>',
    strokeWidth: 2,
  );

  /// The navigation menu (small screens).
  static const menu = IconData.svg(
    'lucide-menu',
    '<line x1="4" x2="20" y1="12" y2="12"/><line x1="4" x2="20" y1="6" y2="6"/><line x1="4" x2="20" y1="18" y2="18"/>',
    strokeWidth: 2,
  );

  /// Close.
  static const x = IconData.svg(
    'lucide-x',
    '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
    strokeWidth: 2,
  );

  /// Information.
  static const info = IconData.svg(
    'lucide-info',
    '<circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/>',
    strokeWidth: 2,
  );

  /// Warning.
  static const triangleAlert = IconData.svg(
    'lucide-triangle-alert',
    '<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3"/><path d="M12 9v4"/><path d="M12 17h.01"/>',
    strokeWidth: 2,
  );

  /// Success, done.
  static const circleCheck = IconData.svg(
    'lucide-circle-check',
    '<circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/>',
    strokeWidth: 2,
  );

  /// Getting started.
  static const rocket = IconData.svg(
    'lucide-rocket',
    '<path d="M4.5 16.5c-1.5 1.26-2 5-2 5s3.74-.5 5-2c.71-.84.7-2.13-.09-2.91a2.18 2.18 0 0 0-2.91-.09z"/><path d="m12 15-3-3a22 22 0 0 1 2-3.95A12.88 12.88 0 0 1 22 2c0 2.72-.78 7.5-6 11a22.35 22.35 0 0 1-4 2z"/><path d="M9 12H4s.55-3.03 2-4c1.62-1.08 5 0 5 0"/><path d="M12 15v5s3.03-.55 4-2c1.08-1.62 0-5 0-5"/>',
    strokeWidth: 2,
  );

  /// Layers, architecture.
  static const layers = IconData.svg(
    'lucide-layers',
    '<path d="M12.83 2.18a2 2 0 0 0-1.66 0L2.6 6.08a1 1 0 0 0 0 1.83l8.58 3.91a2 2 0 0 0 1.66 0l8.58-3.9a1 1 0 0 0 0-1.83Z"/><path d="m22 17.65-9.17 4.16a2 2 0 0 1-1.66 0L2 17.65"/><path d="m22 12.65-9.17 4.16a2 2 0 0 1-1.66 0L2 12.65"/>',
    strokeWidth: 2,
  );

  /// Themes and styles.
  static const palette = IconData.svg(
    'lucide-palette',
    '<circle cx="13.5" cy="6.5" r=".5" fill="currentColor"/><circle cx="17.5" cy="10.5" r=".5" fill="currentColor"/><circle cx="8.5" cy="7.5" r=".5" fill="currentColor"/><circle cx="6.5" cy="12.5" r=".5" fill="currentColor"/><path d="M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10c.926 0 1.648-.746 1.648-1.688 0-.437-.18-.835-.437-1.125-.29-.289-.438-.652-.438-1.125a1.64 1.64 0 0 1 1.668-1.668h1.996c3.051 0 5.555-2.503 5.555-5.554C21.965 6.012 17.461 2 12 2z"/>',
    strokeWidth: 2,
  );

  /// Data and state.
  static const database = IconData.svg(
    'lucide-database',
    '<ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M3 5V19A9 3 0 0 0 21 19V5"/><path d="M3 12A9 3 0 0 0 21 12"/>',
    strokeWidth: 2,
  );

  /// Shipping, publishing.
  static const send = IconData.svg(
    'lucide-send',
    '<path d="m22 2-7 20-4-9-9-4Z"/><path d="M22 2 11 13"/>',
    strokeWidth: 2,
  );

  /// Buttons.
  static const mousePointerClick = IconData.svg(
    'lucide-mouse-pointer-click',
    '<path d="m9 9 5 12 1.8-5.2L21 14Z"/><path d="M7.2 2.2 8 5.1"/><path d="m5.1 8-2.9-.8"/><path d="M14 4.1 12 6"/><path d="m6 12-1.9 2"/>',
    strokeWidth: 2,
  );

  /// Text fields.
  static const textCursorInput = IconData.svg(
    'lucide-text-cursor-input',
    '<path d="M5 4h1a3 3 0 0 1 3 3 3 3 0 0 1 3-3h1"/><path d="M13 20h-1a3 3 0 0 1-3-3 3 3 0 0 1-3 3H5"/><path d="M5 16H4a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2h1"/><path d="M13 8h7a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2h-7"/><path d="M9 7v10"/>',
    strokeWidth: 2,
  );

  /// Selection controls.
  static const squareCheck = IconData.svg(
    'lucide-square-check',
    '<rect width="18" height="18" x="3" y="3" rx="2"/><path d="m9 12 2 2 4-4"/>',
    strokeWidth: 2,
  );

  /// Content, documents.
  static const fileText = IconData.svg(
    'lucide-file-text',
    '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/><path d="M10 9H8"/><path d="M16 13H8"/><path d="M16 17H8"/>',
    strokeWidth: 2,
  );

  /// Navigation.
  static const compass = IconData.svg(
    'lucide-compass',
    '<path d="m16.24 7.76-1.804 5.411a2 2 0 0 1-1.265 1.265L7.76 16.24l1.804-5.411a2 2 0 0 1 1.265-1.265z"/><circle cx="12" cy="12" r="10"/>',
    strokeWidth: 2,
  );

  /// Notifications, feedback.
  static const bell = IconData.svg(
    'lucide-bell',
    '<path d="M10.268 21a2 2 0 0 0 3.464 0"/><path d="M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326"/>',
    strokeWidth: 2,
  );

  /// Whole apps.
  static const appWindow = IconData.svg(
    'lucide-app-window',
    '<rect x="2" y="4" width="20" height="16" rx="2"/><path d="M10 4v4"/><path d="M2 8h20"/><path d="M6 4v4"/>',
    strokeWidth: 2,
  );

  /// Interaction patterns.
  static const pointer = IconData.svg(
    'lucide-pointer',
    '<path d="M22 14a8 8 0 0 1-8 8"/><path d="M18 11v-1a2 2 0 0 0-2-2a2 2 0 0 0-2 2"/><path d="M14 10V9a2 2 0 0 0-2-2a2 2 0 0 0-2 2v1"/><path d="M10 9.5V4a2 2 0 0 0-2-2a2 2 0 0 0-2 2v10"/><path d="M18 11a2 2 0 1 1 4 0v3a8 8 0 0 1-8 8h-2c-2.8 0-4.5-.86-5.99-2.34l-3.6-3.6a2 2 0 0 1 2.83-2.82L7 15"/>',
    strokeWidth: 2,
  );

  /// Back to the top.
  static const arrowUp = IconData.svg(
    'lucide-arrow-up',
    '<path d="m5 12 7-7 7 7"/><path d="M12 19V5"/>',
    strokeWidth: 2,
  );

  /// Installing, downloads.
  static const download = IconData.svg(
    'lucide-download',
    '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" x2="12" y1="15" y2="3"/>',
    strokeWidth: 2,
  );

  /// More actions.
  static const ellipsis = IconData.svg(
    'lucide-ellipsis',
    '<circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/><circle cx="5" cy="12" r="1"/>',
    strokeWidth: 2,
  );
}
