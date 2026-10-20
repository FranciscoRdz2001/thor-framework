import 'css.dart';
import 'length.dart';

/// What a box does with content bigger than itself, on one axis
/// (`overflow-x` / `overflow-y`). `// web:` Flutter clips with `Clip` and
/// scrolls with a scroll view; CSS decides it per box.
enum Overflow {
  /// The content shows outside the box.
  visible('visible'),

  /// Cut at the box, still scrollable by code (`hidden`).
  hidden('hidden'),

  /// Cut at the box, never scrollable (`clip`).
  clip('clip'),

  /// Always scrollable, with its scrollbar.
  scroll('scroll'),

  /// Scrollable when the content doesn't fit (`auto`).
  auto('auto');

  const Overflow(this.css);

  /// The CSS keyword.
  final String css;
}

/// Which side a box floats to, the text wrapping around it (`float`): an
/// image beside a paragraph in rendered markdown.
///
/// `// web:` Flutter has no text flowing around a box; CSS floats are the
/// browser's, for HTML no widget lays out.
enum BoxFloat {
  /// In the flow (`none`).
  none('none'),

  /// Against the left edge.
  left('left'),

  /// Against the right edge.
  right('right'),

  /// Against the start edge, the left in left-to-right text
  /// (`inline-start`).
  start('inline-start'),

  /// Against the end edge (`inline-end`).
  end('inline-end');

  const BoxFloat(this.css);

  /// The CSS keyword.
  final String css;
}

/// How a box is placed outside the normal flow (`position` and its
/// offsets). Inside a `Stack` use Flutter's `Positioned`; this covers what
/// Flutter does with slivers or overlays:
///
/// ```dart
/// BoxPosition.sticky(top: 0)                 // a header that stays in view
/// BoxPosition.fixed(bottom: 16.px, right: 16.px)
/// ```
final class BoxPosition {
  const BoxPosition._(
    this._kind, {
    this.top,
    this.right,
    this.bottom,
    this.left,
  });

  /// Scrolls with the page until it reaches [top] (or the other offsets)
  /// from its scrolling ancestor's edge, then stays there while its parent
  /// is in view (`position: sticky`, Flutter's pinned sliver header).
  ///
  /// `// web:` Flutter has no box that sticks short of slivers
  /// (`SliverPersistentHeader(pinned: true)` inside a `CustomScrollView`);
  /// on the web it is one declaration of the box, so it stays a value.
  const BoxPosition.sticky({
    Length? top,
    Length? right,
    Length? bottom,
    Length? left,
  }) : this._('sticky', top: top, right: right, bottom: bottom, left: left);

  /// Placed against the window and kept there while scrolling
  /// (`position: fixed`).
  const BoxPosition.fixed({
    Length? top,
    Length? right,
    Length? bottom,
    Length? left,
  }) : this._('fixed', top: top, right: right, bottom: bottom, left: left);

  /// Placed against the nearest positioned ancestor (`position: absolute`;
  /// in a `Stack`, `Positioned` is the Flutter way, with `leftLength:`,
  /// `topLength:`… for a state's `card.x.px`).
  const BoxPosition.absolute({
    Length? top,
    Length? right,
    Length? bottom,
    Length? left,
  }) : this._('absolute', top: top, right: right, bottom: bottom, left: left);

  /// In the flow, moved by the offsets, and the anchor of absolutely placed
  /// descendants (`position: relative`).
  const BoxPosition.relative({
    Length? top,
    Length? right,
    Length? bottom,
    Length? left,
  }) : this._('relative', top: top, right: right, bottom: bottom, left: left);

  final String _kind;

  /// Distance from the top edge.
  final Length? top;

  /// Distance from the right edge.
  final Length? right;

  /// Distance from the bottom edge.
  final Length? bottom;

  /// Distance from the left edge.
  final Length? left;

  /// Its CSS declarations.
  CssDeclarations toCss() => {
    'position': _kind,
    if (top case final v?) 'top': v.css,
    if (right case final v?) 'right': v.css,
    if (bottom case final v?) 'bottom': v.css,
    if (left case final v?) 'left': v.css,
  };
}
