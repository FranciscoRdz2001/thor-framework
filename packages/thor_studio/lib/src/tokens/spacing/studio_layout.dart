import 'package:thor_ui/thor_ui.dart';

import 'studio_spacing.dart';

/// The fixed measures of the page frame, in one place: sticky panels are
/// placed from the bars' heights, so changing a bar here moves them with it.
abstract final class StudioLayout {
  /// The top bar.
  static const double topbarHeight = 56;

  /// The status bar.
  static const double statusHeight = 32;

  /// Between the page edge and the cards, and between cards.
  static const double gap = StudioSpacing.sm;

  /// A side panel's width.
  static const double panelWidth = 304;

  /// The sidebar of a docs page (also the width of its drawer on a phone).
  static const double sidebarWidth = 260;

  /// The "on this page" column.
  static const double tocWidth = 232;

  /// The reading column's widest line.
  static const double readingWidth = 720;

  /// Where a sticky panel stops: under the top bar, one gap below.
  static const double stickyTop = topbarHeight + gap;

  /// What a sticky panel leaves of the window (it scrolls inside beyond).
  ///
  /// `// web:` a [Length] (`100dvh - …`): the viewport unit has no Flutter
  /// counterpart.
  static Length get panelMaxHeight =>
      100.dvh - (topbarHeight + statusHeight + gap * 2).px;

  /// The `id` of the page's `<main>` (the skip link's target).
  static const String mainId = 'main-content';
}
