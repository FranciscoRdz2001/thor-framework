// Lucide icons (ISC license, https://lucide.dev; notice in
// packages/thor_studio/third_party/lucide/LICENSE).
import 'package:thor_ui/thor_ui.dart';

IconData _lucide(String name, String body) =>
    IconData.svg('lucide-$name', body, strokeWidth: 2);

final gridIcon = _lucide(
  'sheet',
  '<rect width="18" height="18" x="3" y="3" rx="2"/><path d="M3 9h18"/><path d="M3 15h18"/><path d="M9 9v12"/><path d="M15 9v12"/>',
);
final eyeOff = _lucide(
  'eye-off',
  '<path d="M10.73 5.08A10.43 10.43 0 0 1 12 5c7 0 10 7 10 7a13.16 13.16 0 0 1-1.67 2.68"/><path d="M6.61 6.61A13.53 13.53 0 0 0 2 12s3 7 10 7a9.74 9.74 0 0 0 5.39-1.61"/><line x1="2" x2="22" y1="2" y2="22"/>',
);
final filterIcon = _lucide(
  'list-filter',
  '<path d="M3 6h18"/><path d="M7 12h10"/><path d="M10 18h4"/>',
);
final groupIcon = _lucide(
  'layers',
  '<path d="m12.83 2.18a2 2 0 0 0-1.66 0L2.6 6.08a1 1 0 0 0 0 1.83l8.58 3.91a2 2 0 0 0 1.66 0l8.58-3.9a1 1 0 0 0 0-1.83Z"/><path d="m22 17.65-9.17 4.16a2 2 0 0 1-1.66 0L2 17.65"/><path d="m22 12.65-9.17 4.16a2 2 0 0 1-1.66 0L2 12.65"/>',
);
final sortIcon = _lucide(
  'arrow-up-down',
  '<path d="m21 16-4 4-4-4"/><path d="M17 20V4"/><path d="m3 8 4-4 4 4"/><path d="M7 4v16"/>',
);
final rowsIcon = _lucide(
  'rows-3',
  '<rect width="18" height="18" x="3" y="3" rx="2"/><path d="M21 9H3"/><path d="M21 15H3"/>',
);
final searchIcon = _lucide(
  'search',
  '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>',
);
final chevronDown = _lucide('chevron-down', '<path d="m6 9 6 6 6-6"/>');
final chevronRight = _lucide('chevron-right', '<path d="m9 18 6-6-6-6"/>');
final chevronUp = _lucide('chevron-up', '<path d="m18 15-6-6-6 6"/>');
final expandIcon = _lucide(
  'maximize-2',
  '<polyline points="15 3 21 3 21 9"/><polyline points="9 21 3 21 3 15"/><line x1="21" x2="14" y1="3" y2="10"/><line x1="3" x2="10" y1="21" y2="14"/>',
);
final plusIcon = _lucide('plus', '<path d="M5 12h14"/><path d="M12 5v14"/>');
final closeIcon = _lucide('x', '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>');
final checkIcon = _lucide('check', '<path d="M20 6 9 17l-5-5"/>');
final trashIcon = _lucide(
  'trash-2',
  '<path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/>',
);
const starIcon = IconData.svg(
  'lucide-star-solid',
  '<path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01z"/>',
);
final clipIcon = _lucide(
  'paperclip',
  '<path d="m21.44 11.05-9.19 9.19a6 6 0 0 1-8.49-8.49l8.57-8.57A4 4 0 1 1 18 8.84l-8.59 8.57a2 2 0 0 1-2.83-2.83l8.49-8.48"/>',
);
final undoIcon = _lucide(
  'undo-2',
  '<path d="M9 14 4 9l5-5"/><path d="M4 9h10.5a5.5 5.5 0 0 1 5.5 5.5 5.5 5.5 0 0 1-5.5 5.5H11"/>',
);
final redoIcon = _lucide(
  'redo-2',
  '<path d="m15 14 5-5-5-5"/><path d="M20 9H9.5A5.5 5.5 0 0 0 4 14.5 5.5 5.5 0 0 0 9.5 20H13"/>',
);
final baseIcon = _lucide(
  'rocket',
  '<path d="M4.5 16.5c-1.5 1.26-2 5-2 5s3.74-.5 5-2c.71-.84.7-2.13-.09-2.91a2.18 2.18 0 0 0-2.91-.09z"/><path d="m12 15-3-3a22 22 0 0 1 2-3.95A12.88 12.88 0 0 1 22 2c0 2.72-.78 7.5-6 11a22.35 22.35 0 0 1-4 2z"/><path d="M9 12H4s.55-3.03 2-4c1.62-1.08 5 0 5 0"/><path d="M12 15v5s3.03-.55 4-2c1.08-1.62 0-5 0-5"/>',
);

/// The icon of a field's type (header).
final fieldIcons = <String, IconData>{
  'text': _lucide(
    'type',
    '<path d="M4 7V4h16v3"/><path d="M9 20h6"/><path d="M12 4v16"/>',
  ),
  'select': _lucide(
    'circle-chevron-down',
    '<circle cx="12" cy="12" r="10"/><path d="m16 10-4 4-4-4"/>',
  ),
  'multi': _lucide(
    'list',
    '<path d="M3 12h.01"/><path d="M3 18h.01"/><path d="M3 6h.01"/><path d="M8 12h13"/><path d="M8 18h13"/><path d="M8 6h13"/>',
  ),
  'person': _lucide(
    'user',
    '<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>',
  ),
  'date': _lucide(
    'calendar',
    '<rect width="18" height="18" x="3" y="4" rx="2"/><path d="M16 2v4"/><path d="M8 2v4"/><path d="M3 10h18"/>',
  ),
  'currency': _lucide(
    'dollar-sign',
    '<line x1="12" x2="12" y1="2" y2="22"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/>',
  ),
  'percent': _lucide(
    'percent',
    '<line x1="19" x2="5" y1="5" y2="19"/><circle cx="6.5" cy="6.5" r="2.5"/><circle cx="17.5" cy="17.5" r="2.5"/>',
  ),
  'checkbox': _lucide(
    'square-check',
    '<rect width="18" height="18" x="3" y="3" rx="2"/><path d="m9 12 2 2 4-4"/>',
  ),
  'rating': _lucide(
    'star',
    '<path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01z"/>',
  ),
  'url': _lucide(
    'link',
    '<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/>',
  ),
  'longText': _lucide(
    'align-left',
    '<path d="M15 12H3"/><path d="M17 18H3"/><path d="M21 6H3"/>',
  ),
  'attachments': clipIcon,
};
