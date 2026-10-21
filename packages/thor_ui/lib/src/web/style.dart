import 'package:thor_style/thor_style.dart';

import '../widgets/interaction.dart' show MouseCursor;

// The web layer's style: CSS properties with their CSS names (camelCase, as in
// the DOM's `CSSStyleDeclaration`) and thor_style's value types. It compiles to
// the same declaration map every widget does, so it ends in the element's one
// class (layer `thor.props`) and varies with `.when()` like the rest.

/// `display`.
enum Display {
  /// `block`.
  block('block'),

  /// `inline`.
  inline('inline'),

  /// `inline-block`.
  inlineBlock('inline-block'),

  /// `flex`.
  flex('flex'),

  /// `inline-flex`.
  inlineFlex('inline-flex'),

  /// `grid`.
  grid('grid'),

  /// `inline-grid`.
  inlineGrid('inline-grid'),

  /// `contents`: the box disappears, its children stay.
  contents('contents'),

  /// `none`: not rendered.
  none('none');

  const Display(this.css);

  /// The CSS keyword.
  final String css;
}

/// `position`.
enum Position {
  /// `static`: in the flow, the offsets don't apply.
  normal('static'),

  /// `relative`.
  relative('relative'),

  /// `absolute`.
  absolute('absolute'),

  /// `fixed`.
  fixed('fixed'),

  /// `sticky`.
  sticky('sticky');

  const Position(this.css);

  /// The CSS keyword.
  final String css;
}

/// `flex-direction`.
enum FlexDirection {
  /// `row`.
  row('row'),

  /// `row-reverse`.
  rowReverse('row-reverse'),

  /// `column`.
  column('column'),

  /// `column-reverse`.
  columnReverse('column-reverse');

  const FlexDirection(this.css);

  /// The CSS keyword.
  final String css;
}

/// `flex-wrap`.
enum FlexWrap {
  /// `nowrap`.
  nowrap('nowrap'),

  /// `wrap`.
  wrap('wrap'),

  /// `wrap-reverse`.
  wrapReverse('wrap-reverse');

  const FlexWrap(this.css);

  /// The CSS keyword.
  final String css;
}

/// `justify-content`.
enum JustifyContent {
  /// `flex-start`: the start of the flex direction (reversed by
  /// `row-reverse`).
  flexStart('flex-start'),

  /// `flex-end`.
  flexEnd('flex-end'),

  /// `start`: the start of the writing mode, whatever the direction.
  start('start'),

  /// `end`: the end of the writing mode.
  end('end'),

  /// `center`.
  center('center'),

  /// `space-between`.
  spaceBetween('space-between'),

  /// `space-around`.
  spaceAround('space-around'),

  /// `space-evenly`.
  spaceEvenly('space-evenly'),

  /// `stretch`.
  stretch('stretch');

  const JustifyContent(this.css);

  /// The CSS keyword.
  final String css;
}

/// `align-items`.
enum AlignItems {
  /// `flex-start`: the start of the flex direction (reversed by
  /// `row-reverse`).
  flexStart('flex-start'),

  /// `flex-end`.
  flexEnd('flex-end'),

  /// `start`: the start of the writing mode, whatever the direction.
  start('start'),

  /// `end`: the end of the writing mode.
  end('end'),

  /// `center`.
  center('center'),

  /// `baseline`.
  baseline('baseline'),

  /// `stretch`.
  stretch('stretch');

  const AlignItems(this.css);

  /// The CSS keyword.
  final String css;
}

/// `align-self`.
enum AlignSelf {
  /// `auto`.
  auto('auto'),

  /// `flex-start`: the start of the flex direction (reversed by
  /// `row-reverse`).
  flexStart('flex-start'),

  /// `flex-end`.
  flexEnd('flex-end'),

  /// `start`: the start of the writing mode, whatever the direction.
  start('start'),

  /// `end`: the end of the writing mode.
  end('end'),

  /// `center`.
  center('center'),

  /// `baseline`.
  baseline('baseline'),

  /// `stretch`.
  stretch('stretch');

  const AlignSelf(this.css);

  /// The CSS keyword.
  final String css;
}

/// A border's `border-style`.
enum LineStyle {
  /// `solid`.
  solid('solid'),

  /// `dashed`.
  dashed('dashed'),

  /// `dotted`.
  dotted('dotted'),

  /// `double`.
  double('double'),

  /// `none`.
  none('none');

  const LineStyle(this.css);

  /// The CSS keyword.
  final String css;
}

/// `text-transform`.
enum TextTransform {
  /// `none`.
  none('none'),

  /// `uppercase`.
  uppercase('uppercase'),

  /// `lowercase`.
  lowercase('lowercase'),

  /// `capitalize`.
  capitalize('capitalize');

  const TextTransform(this.css);

  /// The CSS keyword.
  final String css;
}

/// `white-space`.
enum WhiteSpace {
  /// `normal`.
  normal('normal'),

  /// `nowrap`.
  nowrap('nowrap'),

  /// `pre`.
  pre('pre'),

  /// `pre-line`.
  preLine('pre-line'),

  /// `pre-wrap`.
  preWrap('pre-wrap'),

  /// `break-spaces`.
  breakSpaces('break-spaces');

  const WhiteSpace(this.css);

  /// The CSS keyword.
  final String css;
}

/// `object-fit`.
enum ObjectFit {
  /// `contain`.
  contain('contain'),

  /// `cover`.
  cover('cover'),

  /// `fill`.
  fill('fill'),

  /// `none`.
  none('none'),

  /// `scale-down`.
  scaleDown('scale-down');

  const ObjectFit(this.css);

  /// The CSS keyword.
  final String css;
}

/// `list-style-type`.
enum ListStyleType {
  /// `none`.
  none('none'),

  /// `disc`.
  disc('disc'),

  /// `decimal`.
  decimal('decimal');

  const ListStyleType(this.css);

  /// The CSS keyword.
  final String css;
}

/// `font-variant-numeric`.
enum FontVariantNumeric {
  /// `normal`.
  normal('normal'),

  /// `tabular-nums`: every digit as wide (columns of numbers line up).
  tabularNums('tabular-nums');

  const FontVariantNumeric(this.css);

  /// The CSS keyword.
  final String css;
}

/// `pointer-events`.
enum PointerEvents {
  /// `auto`.
  auto('auto'),

  /// `none`: the pointer goes through.
  none('none');

  const PointerEvents(this.css);

  /// The CSS keyword.
  final String css;
}

/// `user-select`.
enum UserSelect {
  /// `auto`.
  auto('auto'),

  /// `none`.
  none('none'),

  /// `text`.
  text('text'),

  /// `all`.
  all('all');

  const UserSelect(this.css);

  /// The CSS keyword.
  final String css;
}

/// `container-type`: what a descendant's container query measures.
enum ContainerType {
  /// `normal`.
  normal('normal'),

  /// `inline-size`: its width (what `.when(container:)` asks).
  inlineSize('inline-size'),

  /// `size`: width and height.
  size('size');

  const ContainerType(this.css);

  /// The CSS keyword.
  final String css;
}

/// `line-height`: a multiple of the font size or a length.
final class LineHeight {
  /// [ratio] times the font size (`line-height: 1.5`).
  const LineHeight(num ratio) : _ratio = ratio, _length = null;

  /// A fixed [length] (`line-height: 24px`).
  const LineHeight.length(Length length) : _ratio = null, _length = length;

  final num? _ratio;
  final Length? _length;

  /// The CSS value.
  String get css => _length?.css ?? cssNum(_ratio!);
}

/// `grid-template-columns` / `grid-template-rows`.
///
/// ```dart
/// GridTracks.repeat(3)                                    // 3 equal columns
/// GridTracks.sizes([GridTrack.length(200.px), GridTrack.fr(1)])
/// // As many columns of at least 24rem as fit (never wider than the box):
/// GridTracks.autoFit(GridTrack.minmax(
///   GridTrack.length(Length.min([100.percent, 24.rem])), GridTrack.fr(1)))
/// ```
///
/// `// web:` Flutter's grids are a `SliverGridDelegate` of one widget
/// (`GridView`); HTML that no widget builds (markdown, a CMS body) only has
/// the CSS track list, so this is its typed form.
final class GridTracks {
  /// [count] equal tracks that may shrink below their content
  /// (`repeat(3, minmax(0, 1fr))`, Tailwind's `grid-cols-3`).
  const GridTracks.repeat(int count)
    : _count = count,
      _sizes = null,
      _fill = null,
      _track = null;

  /// One track per size (`200px 1fr`:
  /// `[GridTrack.length(200.px), GridTrack.fr(1)]`).
  const GridTracks.sizes(List<GridTrack> sizes)
    : _count = null,
      _sizes = sizes,
      _fill = null,
      _track = null;

  /// As many [track]s as fit, the empty ones collapsed so the others
  /// share the row (`repeat(auto-fit, …)`).
  const GridTracks.autoFit(GridTrack track)
    : _count = null,
      _sizes = null,
      _fill = 'auto-fit',
      _track = track;

  /// As many [track]s as fit, the empty ones kept (`repeat(auto-fill, …)`):
  /// a short row leaves room at its end.
  const GridTracks.autoFill(GridTrack track)
    : _count = null,
      _sizes = null,
      _fill = 'auto-fill',
      _track = track;

  /// No explicit tracks (`none`).
  static const none = GridTracks.sizes([]);

  final int? _count;
  final List<GridTrack>? _sizes;
  final String? _fill;
  final GridTrack? _track;

  /// The CSS value.
  String get css {
    if (_count case final n?) return 'repeat($n, minmax(0, 1fr))';
    if (_fill case final fill?) return 'repeat($fill, ${_track!.css})';
    final sizes = _sizes!;
    return sizes.isEmpty ? 'none' : sizes.map((s) => s.css).join(' ');
  }
}

/// One grid track's size.
final class GridTrack {
  const GridTrack._(this.css);

  /// [n] parts of the free space (`1fr`).
  GridTrack.fr(num n) : css = '${cssNum(n)}fr';

  /// A fixed [length] (`200px`, `Length.min([100.percent, 24.rem])`).
  GridTrack.length(Length length) : css = length.css;

  /// At least [min] and at most [max] (`minmax(200px, 1fr)`).
  GridTrack.minmax(GridTrack min, GridTrack max)
    : css = 'minmax(${min.css}, ${max.css})';

  /// As wide as its content allows (`auto`).
  static const auto = GridTrack._('auto');

  /// Its content's widest unbreakable part (`min-content`).
  static const minContent = GridTrack._('min-content');

  /// Its content on one line (`max-content`).
  static const maxContent = GridTrack._('max-content');

  /// The CSS value.
  final String css;
}

/// A grid item's `grid-column` / `grid-row`.
final class GridLine {
  /// Spans [count] tracks from where it lands (`span 2 / span 2`).
  const GridLine.span(int count) : _css = 'span $count / span $count';

  /// From line [start] to line [end] (`2 / 4`; negative lines count from
  /// the end).
  const GridLine.between(int start, int end) : _css = '$start / $end';

  const GridLine._(this._css);

  /// Every track (`1 / -1`).
  static const full = GridLine._('1 / -1');

  final String _css;

  /// The CSS value.
  String get css => _css;
}

/// CSS properties for the elements of `package:thor_ui/web.dart`, with CSS
/// names and typed values:
///
/// ```dart
/// Box(style: Style(display: Display.flex, gap: 8.px, padding: 16.px)
///     .when(medium: Style(padding: 32.px), hover: Style(backgroundColor: hover)))
/// ```
///
/// Every property is the CSS property of the same name (`paddingInline` is
/// `padding-inline`); unset ones are not written. What `tw()` returns is a
/// `Style` too, so both mix.
class Style extends ConstAdaptable<Style> {
  /// CSS properties; unset ones don't apply.
  const Style({
    this.display,
    this.position,
    this.top,
    this.right,
    this.bottom,
    this.left,
    this.inset,
    this.zIndex,
    this.flexDirection,
    this.flexWrap,
    this.flexGrow,
    this.flexShrink,
    this.flexBasis,
    this.flex,
    this.order,
    this.justifyContent,
    this.alignItems,
    this.alignSelf,
    this.alignContent,
    this.justifyItems,
    this.justifySelf,
    this.placeItems,
    this.placeContent,
    this.placeSelf,
    this.gap,
    this.rowGap,
    this.columnGap,
    this.gridTemplateColumns,
    this.gridTemplateRows,
    this.gridColumn,
    this.gridRow,
    this.width,
    this.height,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    this.aspectRatio,
    this.padding,
    this.paddingInline,
    this.paddingBlock,
    this.paddingTop,
    this.paddingRight,
    this.paddingBottom,
    this.paddingLeft,
    this.margin,
    this.marginInline,
    this.marginBlock,
    this.marginTop,
    this.marginRight,
    this.marginBottom,
    this.marginLeft,
    this.overflow,
    this.overflowX,
    this.overflowY,
    this.color,
    this.backgroundColor,
    this.opacity,
    this.borderWidth,
    this.borderTopWidth,
    this.borderRightWidth,
    this.borderBottomWidth,
    this.borderLeftWidth,
    this.border,
    this.borderTop,
    this.borderRight,
    this.borderBottom,
    this.borderLeft,
    this.borderStyle,
    this.borderColor,
    this.borderRadius,
    this.boxShadow,
    this.fontSize,
    this.fontWeight,
    this.fontStyle,
    this.lineHeight,
    this.letterSpacing,
    this.fontVariantNumeric,
    this.textAlign,
    this.textDecorationLine,
    this.textDecoration,
    this.textTransform,
    this.whiteSpace,
    this.cursor,
    this.pointerEvents,
    this.userSelect,
    this.objectFit,
    this.listStyleType,
    this.containerType,
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
  }) : _declarations = null,
       _themeTokens = const {};

  /// Already compiled declarations (what `tw()` builds).
  const Style.declarations(
    CssDeclarations declarations, {
    Set<String> themeTokens = const {},
  }) : _declarations = declarations,
       _themeTokens = themeTokens,
       display = null,
       position = null,
       top = null,
       right = null,
       bottom = null,
       left = null,
       inset = null,
       zIndex = null,
       flexDirection = null,
       flexWrap = null,
       flexGrow = null,
       flexShrink = null,
       flexBasis = null,
       flex = null,
       order = null,
       justifyContent = null,
       alignItems = null,
       alignSelf = null,
       alignContent = null,
       justifyItems = null,
       justifySelf = null,
       placeItems = null,
       placeContent = null,
       placeSelf = null,
       gap = null,
       rowGap = null,
       columnGap = null,
       gridTemplateColumns = null,
       gridTemplateRows = null,
       gridColumn = null,
       gridRow = null,
       width = null,
       height = null,
       minWidth = null,
       maxWidth = null,
       minHeight = null,
       maxHeight = null,
       aspectRatio = null,
       padding = null,
       paddingInline = null,
       paddingBlock = null,
       paddingTop = null,
       paddingRight = null,
       paddingBottom = null,
       paddingLeft = null,
       margin = null,
       marginInline = null,
       marginBlock = null,
       marginTop = null,
       marginRight = null,
       marginBottom = null,
       marginLeft = null,
       overflow = null,
       overflowX = null,
       overflowY = null,
       color = null,
       backgroundColor = null,
       opacity = null,
       borderWidth = null,
       borderTopWidth = null,
       borderRightWidth = null,
       borderBottomWidth = null,
       borderLeftWidth = null,
       border = null,
       borderTop = null,
       borderRight = null,
       borderBottom = null,
       borderLeft = null,
       borderStyle = null,
       borderColor = null,
       borderRadius = null,
       boxShadow = null,
       fontSize = null,
       fontWeight = null,
       fontStyle = null,
       lineHeight = null,
       letterSpacing = null,
       fontVariantNumeric = null,
       textAlign = null,
       textDecorationLine = null,
       textDecoration = null,
       textTransform = null,
       whiteSpace = null,
       cursor = null,
       pointerEvents = null,
       userSelect = null,
       objectFit = null,
       listStyleType = null,
       containerType = null;

  final CssDeclarations? _declarations;

  final Set<String> _themeTokens;

  /// The theme's color tokens this style reads by name (`tw('text-muted')`
  /// reads `muted`); an element checks them against
  /// `ThemeData.colorTokens` in debug.
  Set<String> get themeTokens {
    final a = adaptive;
    if (a == null) return _themeTokens;
    return {
      ...(identical(a.base, this) ? _themeTokens : a.base.themeTokens),
      for (final v in a.variants.values) ...v.themeTokens,
    };
  }

  /// `display`.
  final Display? display;

  /// `position`.
  final Position? position;

  /// `top`.
  final Length? top;

  /// `right`.
  final Length? right;

  /// `bottom`.
  final Length? bottom;

  /// `left`.
  final Length? left;

  /// `inset` (all four offsets).
  final Length? inset;

  /// `z-index`.
  final int? zIndex;

  /// `flex-direction`.
  final FlexDirection? flexDirection;

  /// `flex-wrap`.
  final FlexWrap? flexWrap;

  /// `flex-grow`.
  final num? flexGrow;

  /// `flex-shrink`.
  final num? flexShrink;

  /// `flex-basis`.
  final Length? flexBasis;

  /// `flex` (one number: `flex: 1` is `1 1 0%`, as in CSS).
  final num? flex;

  /// `order`.
  final int? order;

  /// `justify-content`.
  final JustifyContent? justifyContent;

  /// `align-items`.
  final AlignItems? alignItems;

  /// `align-self`.
  final AlignSelf? alignSelf;

  /// `align-content`.
  final JustifyContent? alignContent;

  /// `justify-items` (grid).
  final AlignItems? justifyItems;

  /// `justify-self` (grid).
  final AlignSelf? justifySelf;

  /// `place-items` (`align-items` and `justify-items`).
  final AlignItems? placeItems;

  /// `place-content`.
  final JustifyContent? placeContent;

  /// `place-self`.
  final AlignSelf? placeSelf;

  /// `gap`.
  final Length? gap;

  /// `row-gap`.
  final Length? rowGap;

  /// `column-gap`.
  final Length? columnGap;

  /// `grid-template-columns`.
  final GridTracks? gridTemplateColumns;

  /// `grid-template-rows`.
  final GridTracks? gridTemplateRows;

  /// `grid-column`.
  final GridLine? gridColumn;

  /// `grid-row`.
  final GridLine? gridRow;

  /// `width`.
  final Length? width;

  /// `height`.
  final Length? height;

  /// `min-width`.
  final Length? minWidth;

  /// `max-width`.
  final Length? maxWidth;

  /// `min-height`.
  final Length? minHeight;

  /// `max-height`.
  final Length? maxHeight;

  /// `aspect-ratio` (width / height).
  final double? aspectRatio;

  /// `padding` (four sides).
  final Length? padding;

  /// `padding-inline` (start and end).
  final Length? paddingInline;

  /// `padding-block` (top and bottom).
  final Length? paddingBlock;

  /// `padding-top`.
  final Length? paddingTop;

  /// `padding-right`.
  final Length? paddingRight;

  /// `padding-bottom`.
  final Length? paddingBottom;

  /// `padding-left`.
  final Length? paddingLeft;

  /// `margin` (four sides).
  final Length? margin;

  /// `margin-inline`.
  final Length? marginInline;

  /// `margin-block`.
  final Length? marginBlock;

  /// `margin-top`.
  final Length? marginTop;

  /// `margin-right`.
  final Length? marginRight;

  /// `margin-bottom`.
  final Length? marginBottom;

  /// `margin-left`.
  final Length? marginLeft;

  /// `overflow` (both axes).
  final Overflow? overflow;

  /// `overflow-x`.
  final Overflow? overflowX;

  /// `overflow-y`.
  final Overflow? overflowY;

  /// `color`.
  final Color? color;

  /// `background-color`.
  final Color? backgroundColor;

  /// `opacity`.
  final double? opacity;

  /// `border-width` (four sides).
  final Length? borderWidth;

  /// `border-top-width`.
  final Length? borderTopWidth;

  /// `border-right-width`.
  final Length? borderRightWidth;

  /// `border-bottom-width`.
  final Length? borderBottomWidth;

  /// `border-left-width`.
  final Length? borderLeftWidth;

  /// `border`: width, style and color of the four sides.
  final BorderSide? border;

  /// `border-top`.
  final BorderSide? borderTop;

  /// `border-right`.
  final BorderSide? borderRight;

  /// `border-bottom`.
  final BorderSide? borderBottom;

  /// `border-left`.
  final BorderSide? borderLeft;

  /// `border-style` (four sides).
  final LineStyle? borderStyle;

  /// `border-color` (four sides).
  final Color? borderColor;

  /// `border-radius` (four corners).
  final Length? borderRadius;

  /// `box-shadow`, first shadow on top.
  final List<BoxShadow>? boxShadow;

  /// `font-size`.
  final Length? fontSize;

  /// `font-weight`.
  final FontWeight? fontWeight;

  /// `font-style`.
  final FontStyle? fontStyle;

  /// `line-height`.
  final LineHeight? lineHeight;

  /// `letter-spacing`.
  final Length? letterSpacing;

  /// `font-variant-numeric`.
  final FontVariantNumeric? fontVariantNumeric;

  /// `text-align`.
  final TextAlign? textAlign;

  /// `text-decoration-line`.
  final TextDecoration? textDecorationLine;

  /// `text-decoration` (the line; resets its color and style).
  final TextDecoration? textDecoration;

  /// `text-transform`.
  final TextTransform? textTransform;

  /// `white-space`.
  final WhiteSpace? whiteSpace;

  /// `cursor`.
  final MouseCursor? cursor;

  /// `pointer-events`.
  final PointerEvents? pointerEvents;

  /// `user-select`.
  final UserSelect? userSelect;

  /// `object-fit`.
  final ObjectFit? objectFit;

  /// `list-style-type`.
  final ListStyleType? listStyleType;

  /// `container-type`.
  final ContainerType? containerType;

  @override
  Style withVariants(Adaptive<Style> variants) => _AdaptiveStyle(variants);

  /// This style with [other]'s properties on top (the ones [other] sets
  /// win, like two classes in that order).
  Style merge(Style other) => _MergedStyle(this, other);

  /// The CSS declarations, shorthands before their longhands (`padding`
  /// before `padding-top`), so a side always wins over all four sides
  /// whatever order they were given in.
  CssDeclarations toCss() {
    final a = adaptive;
    if (a == null) return _ownCss();
    // A value that carries its own variants is its own base: its own
    // declarations, not `toCss()` (which would add the variants again).
    return a.declarations((s) => identical(s, this) ? _ownCss() : s.toCss());
  }

  CssDeclarations _ownCss() => orderShorthands(
    _declarations ??
        {
          if (display case final v?) 'display': v.css,
          if (position case final v?) 'position': v.css,
          if (inset case final v?) 'inset': v.css,
          if (top case final v?) 'top': v.css,
          if (right case final v?) 'right': v.css,
          if (bottom case final v?) 'bottom': v.css,
          if (left case final v?) 'left': v.css,
          if (zIndex case final v?) 'z-index': '$v',
          if (flexDirection case final v?) 'flex-direction': v.css,
          if (flexWrap case final v?) 'flex-wrap': v.css,
          if (flexGrow case final v?) 'flex-grow': cssNum(v),
          if (flexShrink case final v?) 'flex-shrink': cssNum(v),
          if (flexBasis case final v?) 'flex-basis': v.css,
          if (flex case final v?) 'flex': cssNum(v),
          if (order case final v?) 'order': '$v',
          if (justifyContent case final v?) 'justify-content': v.css,
          if (alignItems case final v?) 'align-items': v.css,
          if (alignSelf case final v?) 'align-self': v.css,
          if (alignContent case final v?) 'align-content': v.css,
          if (justifyItems case final v?) 'justify-items': v.css,
          if (justifySelf case final v?) 'justify-self': v.css,
          if (placeItems case final v?) 'place-items': v.css,
          if (placeContent case final v?) 'place-content': v.css,
          if (placeSelf case final v?) 'place-self': v.css,
          if (gap case final v?) 'gap': v.css,
          if (rowGap case final v?) 'row-gap': v.css,
          if (columnGap case final v?) 'column-gap': v.css,
          if (gridTemplateColumns case final v?) 'grid-template-columns': v.css,
          if (gridTemplateRows case final v?) 'grid-template-rows': v.css,
          if (gridColumn case final v?) 'grid-column': v.css,
          if (gridRow case final v?) 'grid-row': v.css,
          if (width case final v?) 'width': v.css,
          if (height case final v?) 'height': v.css,
          if (minWidth case final v?) 'min-width': v.css,
          if (maxWidth case final v?) 'max-width': v.css,
          if (minHeight case final v?) 'min-height': v.css,
          if (maxHeight case final v?) 'max-height': v.css,
          if (aspectRatio case final v?) 'aspect-ratio': cssAspectRatio(v),
          if (padding case final v?) 'padding': v.css,
          if (paddingInline case final v?) 'padding-inline': v.css,
          if (paddingBlock case final v?) 'padding-block': v.css,
          if (paddingTop case final v?) 'padding-top': v.css,
          if (paddingRight case final v?) 'padding-right': v.css,
          if (paddingBottom case final v?) 'padding-bottom': v.css,
          if (paddingLeft case final v?) 'padding-left': v.css,
          if (margin case final v?) 'margin': v.css,
          if (marginInline case final v?) 'margin-inline': v.css,
          if (marginBlock case final v?) 'margin-block': v.css,
          if (marginTop case final v?) 'margin-top': v.css,
          if (marginRight case final v?) 'margin-right': v.css,
          if (marginBottom case final v?) 'margin-bottom': v.css,
          if (marginLeft case final v?) 'margin-left': v.css,
          if (overflow case final v?) 'overflow': v.css,
          if (overflowX case final v?) 'overflow-x': v.css,
          if (overflowY case final v?) 'overflow-y': v.css,
          if (color case final v?) 'color': v.css,
          if (backgroundColor case final v?) 'background-color': v.css,
          if (opacity case final v?) 'opacity': cssNum(v),
          if (borderWidth case final v?) 'border-width': v.css,
          if (borderTopWidth case final v?) 'border-top-width': v.css,
          if (borderRightWidth case final v?) 'border-right-width': v.css,
          if (borderBottomWidth case final v?) 'border-bottom-width': v.css,
          if (borderLeftWidth case final v?) 'border-left-width': v.css,
          if (border case final v?) 'border': v.css,
          if (borderTop case final v?) 'border-top': v.css,
          if (borderRight case final v?) 'border-right': v.css,
          if (borderBottom case final v?) 'border-bottom': v.css,
          if (borderLeft case final v?) 'border-left': v.css,
          ...borderStyles(
            style: borderStyle,
            all: borderWidth != null,
            sides: [
              if (borderTopWidth != null) 'top',
              if (borderRightWidth != null) 'right',
              if (borderBottomWidth != null) 'bottom',
              if (borderLeftWidth != null) 'left',
            ],
          ),
          if (borderColor case final v?) 'border-color': v.css,
          if (borderRadius case final v?) 'border-radius': v.css,
          if (boxShadow case final v?)
            'box-shadow': v.isEmpty ? 'none' : v.map((s) => s.css).join(', '),
          if (fontSize case final v?) 'font-size': v.css,
          if (fontWeight case final v?) 'font-weight': '${v.value}',
          if (fontStyle case final v?) 'font-style': v.name,
          if (lineHeight case final v?) 'line-height': v.css,
          if (letterSpacing case final v?) 'letter-spacing': v.css,
          if (fontVariantNumeric case final v?) 'font-variant-numeric': v.css,
          if (textAlign case final v?) 'text-align': v.css,
          if (textDecorationLine case final v?) 'text-decoration-line': v.css,
          if (textDecoration case final v?) 'text-decoration': v.css,
          if (textTransform case final v?) 'text-transform': v.css,
          if (whiteSpace case final v?) 'white-space': v.css,
          if (cursor case final v?) 'cursor': v.css,
          if (pointerEvents case final v?) 'pointer-events': v.css,
          if (userSelect case final v?) 'user-select': v.css,
          if (objectFit case final v?) 'object-fit': v.css,
          if (listStyleType case final v?) 'list-style-type': v.css,
          if (containerType case final v?) 'container-type': v.css,
        },
  );
}

/// The `border-style` a border width needs to show (CSS's default style is
/// `none`): [style] or solid, for all sides ([all]) or only the [sides]
/// whose width is set, so a top border never draws the other three.
CssDeclarations borderStyles({
  LineStyle? style,
  required bool all,
  required List<String> sides,
}) {
  if (!all && sides.isEmpty) {
    return {if (style != null) 'border-style': style.css};
  }
  final s = (style ?? LineStyle.solid).css;
  if (all) return {'border-style': s};
  return {for (final side in sides) 'border-$side-style': s};
}

// Shorthands and the longhands they reset: a shorthand is written first so
// the longhand (a side) wins, whatever order a style listed them in.
const _longhands = {
  'flex': ['flex-grow', 'flex-shrink', 'flex-basis'],
  'border': [
    'border-width',
    'border-style',
    'border-color',
    'border-top',
    'border-right',
    'border-bottom',
    'border-left',
    'border-top-width',
    'border-right-width',
    'border-bottom-width',
    'border-left-width',
    'border-top-style',
    'border-right-style',
    'border-bottom-style',
    'border-left-style',
  ],
  'text-decoration': ['text-decoration-line'],
  'place-items': ['align-items', 'justify-items'],
  'place-content': ['align-content', 'justify-content'],
  'place-self': ['align-self', 'justify-self'],
  'inset': ['top', 'right', 'bottom', 'left', 'inset-inline', 'inset-block'],
  'padding': [
    'padding-inline',
    'padding-block',
    'padding-top',
    'padding-right',
    'padding-bottom',
    'padding-left',
    'padding-inline-start',
    'padding-inline-end',
  ],
  'margin': [
    'margin-inline',
    'margin-block',
    'margin-top',
    'margin-right',
    'margin-bottom',
    'margin-left',
    'margin-inline-start',
    'margin-inline-end',
  ],
  'border-width': [
    'border-top-width',
    'border-right-width',
    'border-bottom-width',
    'border-left-width',
  ],
  'border-style': [
    'border-top-style',
    'border-right-style',
    'border-bottom-style',
    'border-left-style',
  ],
  'border-radius': [
    'border-top-left-radius',
    'border-top-right-radius',
    'border-bottom-right-radius',
    'border-bottom-left-radius',
  ],
  'overflow': ['overflow-x', 'overflow-y'],
  'gap': ['row-gap', 'column-gap'],
};

/// [css] with every shorthand before its longhands (see [Style.toCss]).
CssDeclarations orderShorthands(CssDeclarations css) {
  if (!_longhands.keys.any(css.containsKey)) return css;
  final out = <String, String>{};
  for (final e in css.entries) {
    final longs = _longhands[e.key];
    if (longs != null && out.keys.any(longs.contains)) {
      // A longhand came first: put the shorthand before it.
      final rest = Map.of(out)..removeWhere((k, _) => longs.contains(k));
      final moved = {
        for (final k in out.keys)
          if (longs.contains(k)) k: out[k]!,
      };
      out
        ..clear()
        ..addAll(rest)
        ..[e.key] = e.value
        ..addAll(moved);
    } else {
      out[e.key] = e.value;
    }
  }
  return out;
}

class _AdaptiveStyle extends Style {
  const _AdaptiveStyle(this.adaptive) : super();

  @override
  final Adaptive<Style> adaptive;
}

class _MergedStyle extends Style {
  const _MergedStyle(this.under, this.over) : super();

  final Style under;
  final Style over;

  @override
  Set<String> get themeTokens => {...under.themeTokens, ...over.themeTokens};

  @override
  CssDeclarations toCss() =>
      orderShorthands(mergeAdaptive(under.toCss(), over.toCss()));
}
