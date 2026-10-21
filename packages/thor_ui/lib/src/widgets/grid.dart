import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/layout_hint.dart';
import '../foundation/parent_data.dart';

/// The columns and gaps of a [Grid]; change them per breakpoint with
/// `.when()`, giving only what changes:
///
/// ```dart
/// Grid(
///   layout: GridLayout(columns: 1, gap: 16)
///       .when(medium: GridLayout(columns: 2), expanded: GridLayout(columns: 3, gap: 32)),
///   children: cards,
/// )
/// ```
///
/// [columnWidth] swaps the equal columns for fixed-width tracks, as many as
/// fit (what `GridView.extent(stretch: false)` does), so one grid can be two
/// fluid columns on a phone and 260 px cards with a 73 px gap from `md`:
///
/// ```dart
/// GridLayout(columns: 2, gap: 16)
///     .when(medium: GridLayout(columnWidth: 260, gap: 73))
/// ```
///
/// [columnSizes] gives each column its own size, the way `Expanded(flex:)`
/// does in a `Row`: a 2:1 split, a fixed sidebar, a column that fits its
/// content:
///
/// ```dart
/// GridLayout(columnSizes: [GridSize.fixed(240), GridSize.flex(1)])
///     .when(medium: GridLayout(columnSizes: [GridSize.flex(2), GridSize.flex(1)]))
/// ```
class GridLayout extends ConstAdaptable<GridLayout> {
  /// Columns and gaps; unset values keep the grid's (or the base's).
  const GridLayout({
    this.columns,
    this.columnWidth,
    this.columnSizes,
    this.alignment,
    this.childAspectRatio,
    this.gap,
    this.columnGap,
    this.rowGap,
    this.areas,
    super.medium,
    super.expanded,
    super.large,
    super.extraLarge,
    super.dark,
    super.open,
    super.hover,
    super.focused,
    super.focusWithin,
    super.disabled,
    super.pressed,
    super.groupHover,
    super.groupHovers,
    super.container,
  }) : assert(
         (columns == null ? 0 : 1) +
                 (columnWidth == null ? 0 : 1) +
                 (columnSizes == null ? 0 : 1) <=
             1,
         'GridLayout takes columns, a columnWidth or columnSizes, not several',
       ),
       assert(columnWidth == null || columnWidth > 0),
       assert(childAspectRatio == null || childAspectRatio > 0);

  /// Number of equal columns (default 1).
  final int? columns;

  // web: not in Flutter.
  /// Every column exactly this wide (px) with exactly the [gap]
  /// between, as many as fit the grid's width (a single, narrower column
  /// when not even one fits). The space left over goes where [alignment]
  /// says. Not with [columns]; a variant that sets one replaces the other.
  ///
  /// `// web:` Flutter's `GridView.extent` always stretches its tiles to
  /// fill the row; fixed tracks are a `Wrap` there. CSS `auto-fill`.
  final double? columnWidth;

  // web: not in Flutter.
  /// One size per column, in order: [GridSize.flex] shares the free space by
  /// proportion (`Expanded(flex:)`), [GridSize.fixed] is exactly that wide (px)
  /// and [GridSize.auto] fits its content. Not with [columns] or
  /// [columnWidth]; a variant that sets one of them replaces the others.
  ///
  /// `// web:` Flutter has no per-column sizes in a grid delegate; this is
  /// `grid-template-columns`, precompiled like every breakpoint.
  final List<GridSize>? columnSizes;

  // web: not in Flutter.
  /// Where the space left over goes when [columnWidth] leaves
  /// some (Flutter's `Wrap(alignment:)`).
  final WrapAlignment? alignment;

  /// The ratio of every cell's width to its height, per breakpoint (Flutter's
  /// `SliverGridDelegateWithFixedCrossAxisCount.childAspectRatio`, which has
  /// no variants there). A `GridView` (and a [Grid]) takes the one from here
  /// over its own `childAspectRatio` from where the layout applies:
  ///
  /// ```dart
  /// GridView.count(
  ///   crossAxisCount: 2,
  ///   childAspectRatio: 1,
  ///   layout: GridLayout().when(medium: GridLayout(columns: 4, childAspectRatio: 0.75)),
  ///   children: cards,
  /// )
  /// ```
  ///
  /// `// web:` it is written on the cells (their own class, compiled by the
  /// server like any breakpoint), not on the grid. There is no way back to
  /// "no ratio" at a larger breakpoint: set the one you want.
  final double? childAspectRatio;

  /// Space between columns and between rows.
  final double? gap;

  /// Space between columns (wins over [gap]).
  final double? columnGap;

  /// Space between rows (wins over [gap]).
  final double? rowGap;

  /// Named areas, one string per row and one name per column
  /// (`['header header', 'nav main']`; `.` leaves a cell empty):
  /// `grid-template-areas`. Children take an area with
  /// `GridItem(placement: GridPlacement(area: 'main'))`.
  final List<String>? areas;

  @override
  GridLayout withVariants(Adaptive<GridLayout> variants) =>
      _AdaptiveGridLayout(variants);

  /// The CSS of the values that are set, with the variants of
  /// the `.when()` or the constructor.
  CssDeclarations toCss() {
    final a = adaptive;
    if (a == null) return _ownCss();
    return a.declarations((l) => identical(l, this) ? _ownCss() : l.toCss());
  }

  CssDeclarations _ownCss() => {
    if (columns case final n?)
      'grid-template-columns': 'repeat($n, minmax(0, 1fr))',
    if (columnWidth case final w?)
      'grid-template-columns':
          'repeat(auto-fill, minmax(min(${cssPx(w)}, 100%), ${cssPx(w)}))',
    if (columnSizes case final sizes?)
      'grid-template-columns': sizes.map((s) => s._css).join(' '),
    if (alignment case final a?) 'justify-content': a.css,
    if (columnGap ?? gap case final g?) 'column-gap': cssPx(g),
    if (rowGap ?? gap case final g?) 'row-gap': cssPx(g),
    if (areas case final rows?) 'grid-template-areas': _areasCss(rows),
  };
}

// web: not in Flutter.
/// The size of one column of a [GridLayout.columnSizes].
///
/// ```dart
/// const GridLayout(columnSizes: [GridSize.flex(2), GridSize.flex(1), GridSize.auto])
/// ```
class GridSize {
  /// A share of the free space, like `Expanded(flex:)` (`2` takes twice
  /// what `1` does); `minmax(0, Nfr)`, so long content cannot widen it.
  const GridSize.flex([double flex = 1])
    : _kind = _GridSizeKind.flex,
      _value = flex,
      assert(flex > 0);

  /// Exactly [width] logical pixels.
  const GridSize.fixed(double width)
    : _kind = _GridSizeKind.fixed,
      _value = width,
      assert(width > 0);

  const GridSize._auto() : _kind = _GridSizeKind.auto, _value = null;

  /// As wide as its content needs.
  static const auto = GridSize._auto();

  final _GridSizeKind _kind;
  final double? _value;

  String get _css => switch (_kind) {
    _GridSizeKind.flex => 'minmax(0, ${cssNum(_value!)}fr)',
    _GridSizeKind.fixed => cssPx(_value!),
    _GridSizeKind.auto => 'auto',
  };

  @override
  bool operator ==(Object other) =>
      other is GridSize && other._kind == _kind && other._value == _value;

  @override
  int get hashCode => Object.hash(_kind, _value);
}

enum _GridSizeKind { flex, fixed, auto }

/// The declarations of [GridLayout.childAspectRatio] for the cells of a grid
/// (`aspect-ratio`, with its variants), over [base] the grid's own ratio.
CssDeclarations gridCellCss(GridLayout? layout, {double? base}) {
  CssDeclarations ratio(GridLayout l) => {
    if (l.childAspectRatio case final r?) 'aspect-ratio': cssAspectRatio(r),
  };
  final own =
      layout?.adaptive?.declarations(ratio) ??
      (layout == null ? const <String, String>{} : ratio(layout));
  return mergeAdaptive({
    if (base != null) 'aspect-ratio': cssAspectRatio(base),
  }, own);
}

final _areaName = RegExp(r'^[A-Za-z_][A-Za-z0-9_-]*$');

/// [name] if it is a CSS area name, else an error (it goes into the
/// stylesheet as is).
String _checkedArea(String name) {
  if (!_areaName.hasMatch(name)) {
    throw ArgumentError.value(
      name,
      'area',
      'a grid area name is letters, digits, `_` and `-`, starting with a '
          'letter or `_`',
    );
  }
  return name;
}

String _areasCss(List<String> rows) {
  final cells = [
    for (final row in rows)
      [
        for (final name in row.trim().split(RegExp(r'\s+')))
          if (name.isNotEmpty) name == '.' ? name : _checkedArea(name),
      ],
  ];
  if (cells.any((r) => r.isEmpty || r.length != cells.first.length)) {
    throw ArgumentError.value(
      rows,
      'areas',
      'every row of grid areas needs the same number of names',
    );
  }
  return cells.map((r) => '"${r.join(' ')}"').join(' ');
}

/// Where a child sits in its [Grid]: the columns and rows it spans or the
/// lines it runs between, or a named area of the grid's
/// [GridLayout.areas]. Change it per breakpoint with `.when()`:
///
/// ```dart
/// GridItem(
///   placement: const GridPlacement().when(expanded: GridPlacement(columnSpan: 2)),
///   child: chart,
/// )
/// ```
///
/// Web names, CSS semantics (`grid-column`, `grid-row`, `grid-area`): lines
/// count from 1, negative ones from the end (`columnEnd: -1` is the last
/// line: [fullWidth]).
class GridPlacement extends ConstAdaptable<GridPlacement> {
  /// A placement; unset values leave the child where the grid puts it.
  const GridPlacement({
    this.columnSpan,
    this.rowSpan,
    this.columnStart,
    this.columnEnd,
    this.rowStart,
    this.rowEnd,
    this.area,
    super.medium,
    super.expanded,
    super.large,
    super.extraLarge,
    super.dark,
    super.open,
    super.hover,
    super.focused,
    super.focusWithin,
    super.disabled,
    super.pressed,
    super.groupHover,
    super.groupHovers,
    super.container,
  });

  /// Every column, first line to last (`grid-column: 1 / -1`).
  static const fullWidth = GridPlacement(columnStart: 1, columnEnd: -1);

  /// Columns the child spans (`span 2`).
  final int? columnSpan;

  /// Rows the child spans.
  final int? rowSpan;

  /// The column line it starts at (1: the first).
  final int? columnStart;

  /// The column line it ends at (-1: the last); not with [columnSpan].
  final int? columnEnd;

  /// The row line it starts at.
  final int? rowStart;

  /// The row line it ends at; not with [rowSpan].
  final int? rowEnd;

  /// A named area of the grid (`GridLayout(areas:)`).
  final String? area;

  @override
  GridPlacement withVariants(Adaptive<GridPlacement> variants) =>
      _AdaptiveGridPlacement(variants);

  /// The CSS of the values that are set, with the variants of
  /// the `.when()` or the constructor.
  CssDeclarations toCss() {
    final a = adaptive;
    if (a == null) return _ownCss();
    return a.declarations((l) => identical(l, this) ? _ownCss() : l.toCss());
  }

  CssDeclarations _ownCss() => {
    if (area case final a?) 'grid-area': _checkedArea(a),
    'grid-column': ?_lines(columnStart, columnEnd, columnSpan, 'column'),
    'grid-row': ?_lines(rowStart, rowEnd, rowSpan, 'row'),
  };
}

String? _lines(int? start, int? end, int? span, String axis) {
  if (start == null && end == null && span == null) return null;
  if (end != null && span != null) {
    throw ArgumentError(
      'GridPlacement: give a ${axis}End or a ${axis}Span, not both.',
    );
  }
  for (final line in [start, end]) {
    if (line == 0) {
      throw ArgumentError.value(
        line,
        axis,
        'grid lines count from 1 (or from -1 at the end); there is no 0',
      );
    }
  }
  if (span != null && span < 1) {
    throw ArgumentError.value(span, '${axis}Span', 'must be at least 1');
  }
  final to = end != null
      ? '$end'
      : span != null
      ? 'span $span'
      : null;
  if (start == null) return to!.startsWith('span') ? to : 'auto / $to';
  return to == null ? '$start' : '$start / $to';
}

class _AdaptiveGridPlacement extends GridPlacement {
  const _AdaptiveGridPlacement(this.adaptive);

  @override
  final Adaptive<GridPlacement> adaptive;

  @override
  CssDeclarations toCss() => adaptive.declarations((p) => p.toCss());
}

// web: not in Flutter.
/// Places [child] in its [Grid] by [placement] (spans, lines or
/// a named area), without a node of its own, like `Expanded` in a `Row`.
///
/// ```dart
/// Grid(
///   layout: GridLayout(columns: 1).when(medium: GridLayout(columns: 3)),
///   children: [
///     GridItem(
///       placement: const GridPlacement().when(medium: GridPlacement(columnSpan: 2)),
///       child: chart,
///     ),
///     summary,
///   ],
/// )
/// ```
class GridItem extends ParentDataWrapper {
  /// Places [child] by [placement].
  const GridItem({super.key, required this.placement, required super.child});

  /// Where the child sits (per breakpoint with `.when()`).
  final GridPlacement placement;

  @override
  WrapData get wrapData => WrapData(
    css: placement.toCss(),
    debugAttributes: kDebugMode ? const {'data-thor-grid-item': ''} : const {},
  );
}

class _AdaptiveGridLayout extends GridLayout {
  const _AdaptiveGridLayout(this.adaptive);

  @override
  final Adaptive<GridLayout> adaptive;

  @override
  CssDeclarations toCss() => adaptive.declarations((l) => l.toCss());
}

/// A grid that doesn't scroll and whose rows fit their content (CSS grid):
/// its [layout] sets the columns and gaps. Cells stretch to the row's
/// height, so cards in a row line up.
///
/// `// web:` Flutter's `GridView` forces a cell aspect ratio (and scrolls);
/// a page layout needs rows as tall as their tallest cell, like
/// `flutter_layout_grid`.
class Grid extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn, LayoutHint {
  /// Creates a grid.
  const Grid({
    super.key,
    this.layout = const GridLayout(),
    this.alignItems = CrossAxisAlignment.stretch,
    this.children = const [],
  });

  /// Columns and gaps (per breakpoint with `.when()`).
  final GridLayout layout;

  /// Vertical alignment of cells in their row (default: stretch).
  final CrossAxisAlignment alignItems;

  /// The cells.
  final List<Widget> children;

  @override
  bool get fillsWidth => true;

  @override
  Widget build(BuildContext context) => thorElement(
    'div',
    debugName: 'Grid',
    fillsWidth: true,
    css:
        mergeAdaptive({
          'display': 'grid',
          'grid-template-columns': 'repeat(1, minmax(0, 1fr))',
        }, layout.toCss())..addAll({
          'align-items': switch (alignItems) {
            CrossAxisAlignment.start => 'start',
            CrossAxisAlignment.end => 'end',
            CrossAxisAlignment.center => 'center',
            _ => 'stretch',
          },
        }),
    childRules: ChildRules(all: {'min-width': '0', ...gridCellCss(layout)}),
    children: children,
  );
}
