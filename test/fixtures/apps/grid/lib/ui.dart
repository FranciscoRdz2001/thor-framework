// Colors and small pieces shared by the grid's widgets.
import 'package:thor_ui/thor_ui.dart';

import 'data.dart';
import 'icons.dart';

const ink = Color(0xFF1D1F25);
const muted = Color(0xFF616670);
const faint = Color(0xFF9AA0A6);
const line = Color(0xFFE1E3E8);
const surface = Color(0xFFFFFFFF);
const chrome = Color(0xFFF6F7F9);
const blue = Color(0xFF1363D0);
const blueTint = Color(0xFFEAF2FF);
const hitTint = Color(0xFFFFF6D1);
const amber = Color(0xFFF5B400);

const small = TextStyle(fontSize: 13, color: ink);
const smallMuted = TextStyle(fontSize: 12, color: muted);
const label = TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: ink);

(Color, Color) statusColors(Status s) => switch (s) {
  Status.none => (const Color(0x00000000), ink),
  Status.idea => (const Color(0xFFEEEEEE), const Color(0xFF444444)),
  Status.planned => (const Color(0xFFD0E1FD), const Color(0xFF0B3A8C)),
  Status.building => (const Color(0xFFFFEAB6), const Color(0xFF6B4A00)),
  Status.beta => (const Color(0xFFEDE2FE), const Color(0xFF5B21B6)),
  Status.launched => (const Color(0xFFD1F7C4), const Color(0xFF1F6B19)),
  Status.paused => (const Color(0xFFFFDCE5), const Color(0xFF9B1C3B)),
};

const _tagColors = [
  Color(0xFFD0F0FD), Color(0xFFFFE0CC), Color(0xFFD1F7C4), Color(0xFFEDE2FE), //
  Color(0xFFFFEAB6), Color(0xFFE5E9F0), Color(0xFFFFDCE5), Color(0xFFC2F5E9),
];

const _avatarColors = [
  // Dark enough for white initials (WCAG AA, 4.5:1).
  Color(0x00000000), Color(0xFF1F5FCC), Color(0xFF0B6E99), Color(0xFF1B7A2B), //
  Color(0xFF8A5A00), Color(0xFFB23C0B), Color(0xFFC0163F), Color(0xFF6B2FD1),
  Color(0xFF555555), Color(0xFF0B6E61),
];

/// A rounded label (single select option).
Widget statusPill(Status s) {
  final (bg, fg) = statusColors(s);
  return Offstage(
    offstage: s == Status.none,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        s.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w500),
      ),
    ),
  );
}

/// A multi select option (slot [t]: none shows nothing).
Widget tagPill(TagSlot t) => Offstage(
  offstage: t == TagSlot.none,
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: _tagColors[t == TagSlot.none ? 0 : t.index - 1],
      borderRadius: const BorderRadius.all(Radius.circular(4)),
    ),
    child: Text(
      t == TagSlot.none ? '' : Tag.values[t.index - 1].label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12, color: ink),
    ),
  ),
);

/// Initials in a circle.
Widget avatar(Person p, {double size = 20}) => Container(
  width: size,
  height: size,
  alignment: Alignment.center,
  decoration: BoxDecoration(
    color: _avatarColors[p.index],
    shape: BoxShape.circle,
  ),
  child: Text(
    p.initials,
    style: TextStyle(
      fontSize: size * 0.45,
      fontWeight: FontWeight.w600,
      color: surface,
    ),
  ),
);

/// A person: avatar and name.
Widget personChip(Person p) => Offstage(
  offstage: p == Person.none,
  child: Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 6,
    children: [
      avatar(p),
      Text(p.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: small),
    ],
  ),
);

/// A checkbox drawn by the page (its state comes from a `Watch`).
Widget checkBox(bool on, {double size = 16}) => Container(
  width: size,
  height: size,
  alignment: Alignment.center,
  decoration: BoxDecoration(
    color: on ? blue : surface,
    border: Border.all(color: on ? blue : faint, width: 1.5),
    borderRadius: const BorderRadius.all(Radius.circular(4)),
  ),
  child: Opacity(
    opacity: on ? 1 : 0,
    child: Icon(checkIcon, size: size - 4, color: surface),
  ),
);

/// Five stars, the first [n] filled.
List<Widget> stars(int n, void Function() Function(int star) onTap) => [
  for (var i = 1; i <= 5; i++)
    Gesture(
      onTap: onTap(i),
      semanticButton: false,
      child: Semantics(
        button: true,
        label: '$i ${i == 1 ? 'star' : 'stars'}',
        child: Icon(
          starIcon,
          size: 15,
          color: i <= n ? amber : const Color(0xFFE3E5E8),
        ),
      ),
    ),
];

/// A toolbar / top bar button face: icon, label.
Widget buttonFace(IconData icon, Widget text, {bool active = false}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: active ? blueTint : null,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Icon(icon, size: 16, color: active ? blue : muted),
          DefaultTextStyle(
            style: TextStyle(
              fontSize: 13,
              color: active ? blue : ink,
              fontWeight: FontWeight.w500,
            ),
            child: text,
          ),
        ],
      ),
    );

/// The look of a toolbar popover's panel.
const menuDecoration = BoxDecoration(
  color: surface,
  borderRadius: BorderRadius.all(Radius.circular(8)),
  border: Border.fromBorderSide(BorderSide(color: line)),
  boxShadow: [
    BoxShadow(color: Color(0x26000000), blurRadius: 16, offset: Offset(0, 4)),
  ],
);

/// The content of a toolbar popover (its look is the popover's).
Widget menuPanel({required List<Widget> children}) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  spacing: 8,
  children: children,
);

/// A flat clickable row inside a menu.
Widget menuItem(Widget child, {required void Function() onTap}) => Gesture(
  onTap: onTap,
  semanticButton: false,
  child: Semantics(
    button: true,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x00000000).when(hover: chrome),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: DefaultTextStyle(style: small, child: child),
    ),
  ),
);
