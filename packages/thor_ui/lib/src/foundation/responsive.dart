import 'dart:convert';

import 'package:thor_engine/thor_engine.dart' show listAttr;
import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../core/framework.dart' show BuildChild, PageBuild, PageComponent;
import '../core/markup.dart' show FragmentNode, ParentNode, writeChildrenUtf8;
import '../web/style.dart'
    show
        ContainerType,
        Display,
        GridTrack,
        GridTracks,
        ListStyleType,
        ObjectFit,
        TextTransform,
        UserSelect,
        WhiteSpace;
import '../widgets/basic.dart' show boxCss;
import '../widgets/interaction.dart' show MouseCursor;
import '../widgets/theme.dart' show Brightness;
import 'child_rules.dart';
import 'deferred.dart' show DeferRun, DeferScope;
import 'element.dart';
import 'errors.dart' show thorError;
import 'layout_hint.dart';
import 'parent_data.dart';
import 'style_registry.dart';
import 'stylesheet.dart';

// web: not in Flutter. Flutter styles through each widget's own parameters;
// these are the web-only values and the ones that change per breakpoint or
// state (`.when()`), which the server writes as one CSS class.
/// Loose style values for `Styled(style:)`: the numbers and effects that
/// have no value type of their own (`widthFactor`, `opacity`, `scale`,
/// `zIndex`…). Changes per breakpoint or state with `.when()`:
///
/// ```dart
/// Styled(
///   style: StyleProps(widthFactor: 0.9).when(medium: StyleProps(widthFactor: 0.7)),
///   child: header,
/// )
/// ```
class StyleProps extends ConstAdaptable<StyleProps> {
  /// Creates loose style values; unset ones don't apply.
  const StyleProps({
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.constraints,
    this.color,
    this.decoration,
    this.textStyle,
    this.opacity,
    this.scale,
    this.scaleRatio,
    this.offset,
    this.fractionalTranslation,
    this.widthFactor,
    this.heightFactor,
    this.zIndex,
    this.flex,
    this.flexShrink,
    this.flexBasis,
    this.position,
    this.overflowX,
    this.overflowY,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    this.alignSelf,
    this.direction,
    this.mainAxisAlignment,
    this.crossAxisAlignment,
    this.justifyItems,
    this.wrap,
    this.spacing,
    this.runSpacing,
    this.gridTemplateColumns,
    this.gridAutoRows,
    this.outline,
    this.outlineOffset,
    this.scrollMargin,
    this.transformOrigin,
    this.turns,
    this.blur,
    this.ignorePointer,
    this.viewTransitionName,
    this.offstage,
    this.widthLength,
    this.heightLength,
    this.aspectRatio,
    this.inset,
    this.scrollPadding,
    this.textTransform,
    this.textOverflow,
    this.lineClamp,
    this.textUnderlineOffset,
    this.backgroundClip,
    this.display,
    this.cursor,
    this.textAlign,
    this.whiteSpace,
    this.textWrap,
    this.overflowWrap,
    this.verticalAlign,
    this.listStyleType,
    this.objectFit,
    this.transition,
    this.animation,
    this.filter,
    this.backdropFilter,
    this.mixBlendMode,
    this.appearance,
    this.scrollbarWidth,
    this.scrollbarThumbColor,
    this.scrollbarTrackColor,
    this.resize,
    this.boxSizing,
    this.accentColor,
    this.contentVisibility,
    this.scrollSnapType,
    this.scrollSnapAlign,
    this.scrollTargetGroup,
    this.borderCollapse,
    this.borderSpacing,
    this.fontSmoothing,
    this.float,
    this.userSelect,
    this.containerType,
    this.colorScheme,
    this.raw,
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

  /// Same as `Padding`'s `padding`.
  final EdgeInsetsGeometry? padding;

  /// Same as `Container`'s `margin`. `// web:` it may be negative
  /// (`EdgeInsets.symmetric(vertical: -12)`, a tap target taller than its
  /// line): `Container(margin:)` refuses that, as Flutter's does.
  final EdgeInsetsGeometry? margin;

  /// Same as `SizedBox`'s `width`.
  final double? width;

  /// Same as `SizedBox`'s `height`.
  final double? height;

  /// Same as `Container`'s `constraints`.
  final BoxConstraints? constraints;

  /// Same as `Container`'s `color`.
  final Color? color;

  /// Same as `Container`'s `decoration`.
  final BoxDecoration? decoration;

  /// Same as `DefaultTextStyle`'s `style`.
  final TextStyle? textStyle;

  /// Same as `Opacity`'s `opacity`.
  final double? opacity;

  /// Same as `Transform.scale`'s `scale`.
  final double? scale;

  /// A scale the browser computes from lengths, like fitting a box into its
  /// container: `Ratio.min([Ratio.value(1), Ratio.of(100.cqh, 844.px)])`
  /// (the container is an ancestor element with `containerType:
  /// ContainerType.size`; a `Styled` melts into its child's element, so the
  /// stage and the scaled box can't be the same element). Wins over [scale].
  ///
  /// `// web:` [scale] is a number Flutter computed while laying out; here
  /// the sizes are the browser's, so the division is CSS (`tan(atan2())`).
  final Ratio? scaleRatio;

  /// Same as `Transform.translate`'s `offset` (the `translate` property, so
  /// it composes with [scale]).
  final Offset? offset;

  /// Same as `FractionalTranslation`'s `translation`: a move in fractions
  /// of the box's own size (`Offset(-0.5, 0)` is `translate: -50% 0%`).
  /// With [offset], both add up.
  final Offset? fractionalTranslation;

  /// Same as `FractionallySizedBox`'s `widthFactor` (`width: 80%`).
  final double? widthFactor;

  /// Same as `FractionallySizedBox`'s `heightFactor` (`height: 80%`).
  final double? heightFactor;

  /// Paint order among overlapping siblings (`z-index`).
  final int? zIndex;

  /// The flex factor of a flex item, as CSS `flex: n` (`n 1 0%`): the item
  /// shares the free space like `Expanded(flex: n)`. `flex: 0` keeps the
  /// content's size (`0 1 auto`). For the Flutter cases in a `Row` or
  /// `Column`, `Expanded` and `Flexible` are the widgets; this is for a
  /// stylesheet rule or a variant.
  final int? flex;

  /// How much a flex item shrinks when the line is too short
  /// (`flex-shrink`; 1 with [flex]).
  final int? flexShrink;

  /// The size a flex item starts from before growing (`flex-basis`). With it
  /// the three values are written as longhands (`flex-grow`, `flex-shrink`,
  /// `flex-basis`), so `flex: 1` with `Length.maxContent` shares what is
  /// left of the line after the contents.
  final Length? flexBasis;

  // web: what Flutter does with slivers, overlays or the render
  // tree, and CSS says per box. Typed, so no CSS is written as strings.

  /// Placement outside the normal flow (`BoxPosition.sticky(top: 0.px)`).
  final BoxPosition? position;

  /// What happens to content wider than the box.
  final Overflow? overflowX;

  /// What happens to content taller than the box.
  final Overflow? overflowY;

  /// Least width, in any unit (`constraints` is logical pixels).
  final Length? minWidth;

  /// Most width, in any unit (`Length.min([100.percent, 720.px])`).
  final Length? maxWidth;

  /// Least height, in any unit (`100.dvh`: at least the window).
  final Length? minHeight;

  /// Most height, in any unit (`100.dvh - 48.px`).
  final Length? maxHeight;

  /// This child's own place on its Row/Column's cross axis, overriding the
  /// parent's `crossAxisAlignment` (`align-self`).
  final CrossAxisAlignment? alignSelf;

  // web: a `Row`/`Column`/`Wrap`/`GridView` lays out what it builds; HTML
  // that no widget builds (rendered markdown, a CMS body) is laid out by
  // its container's CSS, so these are the container's values with Flutter's
  // names. They write the layout only: the box is flex with
  // `display: Display.flex` (or grid with `Display.grid`), as in CSS.

  /// The main axis of a flex box (`Flex`'s `direction`): `flex-direction`
  /// `row` or `column`. Also which gap [spacing] and [runSpacing] are.
  final Axis? direction;

  /// How the children are placed along the main axis (`Row`'s
  /// `mainAxisAlignment`, `justify-content`; in a grid, the tracks).
  final MainAxisAlignment? mainAxisAlignment;

  /// How the children are placed on the cross axis (`Row`'s
  /// `crossAxisAlignment`, `align-items`).
  final CrossAxisAlignment? crossAxisAlignment;

  /// How a grid places each item inside its cell along the inline axis
  /// (`justify-items`), with `crossAxisAlignment`'s names: `center` centers
  /// every item in its column, `stretch` fills it. Only for a grid
  /// (`display: Display.grid`); a flex box ignores it.
  final CrossAxisAlignment? justifyItems;

  /// `true`: the children run onto more lines when they don't fit, like a
  /// `Wrap` (`flex-wrap: wrap`); `false`: one line (`nowrap`).
  final bool? wrap;

  /// The gap between children on the main axis (`Wrap`'s and `Row`'s
  /// `spacing`): `column-gap`, or `row-gap` with `direction:
  /// Axis.vertical`. In a grid, the gap between columns. Equal to
  /// [runSpacing], both are one `gap`.
  ///
  /// `// web:` a [Length], not Flutter's `double`: the content's gaps are
  /// often relative (`1.5.rem`).
  final Length? spacing;

  /// The gap between runs (`Wrap`'s `runSpacing`): `row-gap`, or
  /// `column-gap` with `direction: Axis.vertical`. In a grid, the gap
  /// between rows.
  final Length? runSpacing;

  /// The columns of a grid box (`grid-template-columns`):
  /// `GridTracks.autoFit(GridTrack.minmax(GridTrack.length(16.rem),
  /// GridTrack.fr(1)))` for as many columns as fit.
  final GridTracks? gridTemplateColumns;

  /// The height of the rows a grid box adds for its children
  /// (`grid-auto-rows`; `GridTrack.fr(1)`: every row as tall as the
  /// tallest).
  final GridTrack? gridAutoRows;

  /// A line around the box that takes no space (`outline`): focus rings.
  final BorderSide? outline;

  /// Gap between the box and its [outline], in logical pixels.
  final double? outlineOffset;

  /// Room kept around the box when the page scrolls to it (an anchor under
  /// a sticky header: `EdgeInsets.only(top: 72)`).
  final EdgeInsetsGeometry? scrollMargin;

  /// The point [scale] and [turns] pivot on (Flutter's `Transform`
  /// `alignment`).
  final Alignment? transformOrigin;

  /// Rotation in full turns, clockwise (`AnimatedRotation`'s `turns`).
  final double? turns;

  /// Gaussian blur of the box, in logical pixels (`ImageFiltered` with
  /// `ImageFilter.blur`).
  final double? blur;

  /// `true`: the box ignores the pointer, events reach what is under it
  /// (`IgnorePointer`).
  final bool? ignorePointer;

  /// Name that pairs this box with the one of the next page in a view
  /// transition (the web's `Hero` between pages).
  final String? viewTransitionName;

  /// `true`: the box is hidden and takes no space (`Offstage`'s
  /// `offstage`, `display: none`). What a stylesheet uses to hide a set of
  /// elements (`css('.list:has(> .collapsed) .row')`) and a `.when()` to
  /// hide one per breakpoint.
  ///
  /// `// web:` only hides: `false` writes nothing, so a shown box keeps its
  /// own `display` (a Row stays flex, a Container stays a box).
  final bool? offstage;

  // web: CSS properties with no Flutter parameter, one typed value each.

  /// A width in any unit or content size (`Length.maxContent`); [width] is
  /// logical pixels.
  final Length? widthLength;

  /// A height in any unit or content size; [height] is logical pixels.
  final Length? heightLength;

  /// Width over height (`AspectRatio`'s `aspectRatio`). A ratio that is a
  /// small fraction is written as one (`4 / 3` for `4 / 3`, not `1.3333`).
  final double? aspectRatio;

  /// The distance to the four edges of the containing box at once (`inset`),
  /// for a box with a [position]: `0.px` covers it, `Length.auto` resets.
  final Length? inset;

  /// Room kept inside the scroller when it scrolls to a child
  /// (`scroll-padding`): an anchor or a snap point under a sticky bar. The
  /// scroller's counterpart of [scrollMargin].
  final EdgeInsetsGeometry? scrollPadding;

  /// Capital letters from lowercase text and back (`text-transform`).
  final TextTransform? textTransform;

  /// What happens to a line cut by the box (`text-overflow`): needs one
  /// line (`white-space: nowrap`) and `overflow: hidden`, which
  /// `Text(overflow:)` writes for you.
  final TextOverflow? textOverflow;

  /// Cuts the text at this many lines with an ellipsis (`line-clamp`).
  /// `Text(maxLines:, overflow: TextOverflow.ellipsis)` is the Flutter way;
  /// this is for HTML no widget builds.
  final int? lineClamp;

  /// Distance between the text and its underline (`text-underline-offset`).
  final Length? textUnderlineOffset;

  /// How far the background reaches (`background-clip`):
  /// `BackgroundClip.text` shows it through the letters.
  final BackgroundClip? backgroundClip;

  /// How the box lays out its children (`display`).
  final Display? display;

  /// The pointer while it is over the box (`MouseRegion`'s `cursor`), for
  /// a stylesheet rule or a variant that has no `MouseRegion`.
  final MouseCursor? cursor;

  /// Alignment of the text lines (`Text`'s `textAlign`), for a rule that
  /// styles elements without a widget (`th`).
  final TextAlign? textAlign;

  /// How white space and line breaks in the text are kept (`white-space`).
  final WhiteSpace? whiteSpace;

  /// How lines break (`text-wrap`: `balance` for headings).
  final TextWrap? textWrap;

  /// Whether a word too long for its line breaks (`overflow-wrap`).
  final OverflowWrap? overflowWrap;

  /// An inline box against its line (`vertical-align`).
  final VerticalAlign? verticalAlign;

  /// The marker of a list (`list-style-type`).
  final ListStyleType? listStyleType;

  /// How an image fills its box (`object-fit`; `Image`'s `fit` is the
  /// Flutter way).
  final ObjectFit? objectFit;

  /// Properties that animate when their value changes (`transition`). Per
  /// property timing in one declaration; `AnimatedContainer` and the
  /// `Animated*` widgets cover the Flutter cases.
  final List<Transition>? transition;

  /// `@keyframes` played on the box (`animation`).
  final List<CssAnimation>? animation;

  /// Blur and color filters of the box (`ImageFiltered`); wins over
  /// [blur] when both are set.
  final ImageFilter? filter;

  /// Filters what is behind the box (`backdrop-filter`): a translucent
  /// panel that blurs the content under it. Flutter's `BackdropFilter`.
  final ImageFilter? backdropFilter;

  /// How the box mixes with what is under it (`mix-blend-mode`).
  final BlendMode? mixBlendMode;

  /// Whether a form control draws itself (`appearance`).
  final Appearance? appearance;

  /// How thick the scrollbar of the box is (`scrollbar-width`).
  final ScrollbarWidth? scrollbarWidth;

  /// The thumb of the scrollbar (`scrollbar-color`).
  final Color? scrollbarThumbColor;

  /// The track of the scrollbar (`scrollbar-color`); transparent when only
  /// [scrollbarThumbColor] is set. Needs [scrollbarThumbColor]: CSS takes
  /// both colors or none.
  final Color? scrollbarTrackColor;

  /// Which axes the reader may resize the box on (`resize`).
  final Resize? resize;

  /// What `width` and `height` measure (`box-sizing`).
  final BoxSizing? boxSizing;

  /// The color of the browser's own controls (`accent-color`: checkboxes,
  /// radios, sliders, progress).
  final Color? accentColor;

  /// Skips the rendering of the box while it is off screen
  /// (`content-visibility`).
  final ContentVisibility? contentVisibility;

  /// Makes the box a scroller that snaps to its children's
  /// [scrollSnapAlign] (`scroll-snap-type`).
  final ScrollSnapType? scrollSnapType;

  /// Where the box rests in a snapping scroller (`scroll-snap-align`).
  final ScrollSnapAlign? scrollSnapAlign;

  /// Makes the links to the box's children a scroll spy
  /// (`scroll-target-group`).
  final ScrollTargetGroup? scrollTargetGroup;

  /// Whether a table's cell borders merge (`border-collapse`).
  final BorderCollapse? borderCollapse;

  /// The gap between a table's cells, in logical pixels (`border-spacing`).
  final double? borderSpacing;

  /// How text edges are smoothed on macOS (`FontSmoothing.antialiased`);
  /// inherited, so set once on the page's root.
  final FontSmoothing? fontSmoothing;

  /// Which side the box floats to, the text wrapping around it (`float`).
  final BoxFloat? float;

  /// Whether the reader can select the box's text (`user-select`;
  /// `UserSelect.none` is Flutter's `SelectionContainer.disabled`).
  final UserSelect? userSelect;

  /// What a descendant's container query or `cq*` unit measures
  /// (`container-type`): `ContainerType.size` for `100.cqh` and `100.cqw`.
  final ContainerType? containerType;

  /// The color schemes the element may use (`color-scheme`).
  final CssColorScheme? colorScheme;

  /// Inline escape hatch for declarations `StyleProps` doesn't cover.
  final CssDeclarations? raw;

  @override
  StyleProps withVariants(Adaptive<StyleProps> variants) =>
      _AdaptiveStyleProps(variants);

  /// These values and their variants (`.when()` or the constructor), one
  /// per state.
  Iterable<StyleProps> get _parts {
    final a = adaptive;
    if (a == null) return [this];
    return [
      if (identical(a.base, this)) this else ...a.base._parts,
      for (final v in a.variants.values) ...v._parts,
    ];
  }

  /// What a Flutter widget already sets among these values, as
  /// `'padding → Padding(padding:)'`: `Styled(style:)` is for what widgets
  /// can't express (web-only values, and plain numbers that vary with
  /// `.when()`, which a widget's `double` can't carry).
  List<String> widgetProps() {
    final parts = _parts.toList();
    final varies = parts.length > 1;
    final out = <String>{};
    for (final p in parts) {
      if (p.padding != null) out.add('padding → Padding(padding:)');
      // A negative margin is the web's: `Container(margin:)` refuses it.
      if (p.margin != null && p.margin!.isNonNegative) {
        out.add('margin → Container(margin:)');
      }
      if (p.constraints != null) {
        out.add('constraints → ConstrainedBox(constraints:)');
      }
      if (p.color != null || p.decoration != null) {
        out.add('color/decoration → Container(decoration:)');
      }
      if (p.textStyle != null) {
        out.add('textStyle → DefaultTextStyle(style:) or Text(style:)');
      }
      if (varies) continue;
      if (p.width != null || p.height != null) {
        out.add('width/height → SizedBox');
      }
      if (p.opacity != null) out.add('opacity → Opacity');
      // web: scaleRatio is not Flutter's (Transform.scale takes the double
      // Flutter computed); the browser divides the lengths.
      if (p.scale != null || p.offset != null || p.turns != null) {
        out.add('scale/offset/turns → Transform');
      }
      if (p.widthFactor != null || p.heightFactor != null) {
        out.add('widthFactor/heightFactor → FractionallySizedBox');
      }
      if (p.offstage != null) out.add('offstage → Offstage');
      if (p.aspectRatio != null) out.add('aspectRatio → AspectRatio');
      if (p.filter != null) out.add('filter → ImageFiltered');
      if (p.backdropFilter != null) {
        out.add('backdropFilter → BackdropFilter');
      }
      if (p.cursor != null) out.add('cursor → MouseRegion');
    }
    return out.toList();
  }

  /// The CSS declarations of these values and their variants (`.when()` or
  /// the constructor's).
  // web: a variant only carries what it names, but the `position` is one
  // value (Flutter has no separate offsets): a variant that sets a position
  // replaces it whole, so an offset that the base or another variant set and
  // it doesn't name goes back to `auto` (else `fixed(left: 8)` under
  // `medium: sticky(top: 0)` keeps its `left`, and so does `relative()` at
  // `expanded` after `medium: absolute(left: 5)`).
  CssDeclarations toCss() {
    final a = adaptive;
    if (a == null) return _ownCss();
    if (!renderCachesEnabled ||
        a.groupHovers.isNotEmpty ||
        a.container.isNotEmpty) {
      return _variantsCss(a);
    }
    // A `.when()` builds a new object on every build, but its parts are
    // usually `const`: the same parts give the same declarations, so they
    // are merged and marked once per process. StyleProps are
    // immutable; parts built per request just miss.
    final key = _Parts([
      a.base,
      a.medium,
      a.expanded,
      a.large,
      a.extraLarge,
      a.dark,
      a.open,
      a.hover,
      a.focused,
      a.focusWithin,
      a.disabled,
      a.pressed,
      a.groupHover,
    ]);
    final known = _memo[key];
    if (known != null) return known;
    if (_memo.length >= _memoLimit) _memo.clear();
    return _memo[key] = Map.unmodifiable(_variantsCss(a));
  }

  static final _memo = <_Parts, CssDeclarations>{};
  static const _memoLimit = 4096;

  // A value that carries its own variants is its own base: its own
  // declarations, not `toCss()` (which would add the variants again).
  CssDeclarations _variantsCss(Adaptive<StyleProps> a) {
    CssDeclarations own(StyleProps p) =>
        identical(p, this) ? _ownCss() : p.toCss();
    final named = <String>{
      for (final p in [a.base, ...a.variants.values])
        ...?_positionOf(p)?.toCss().keys.where(_offsets.contains),
    };
    // By what each variant is called, not by identity: a `const` variant can
    // be the very object the base is.
    CssDeclarations of(StyleProps p) {
      final css = own(p);
      if (_positionOf(p) == null) return css;
      return {
        for (final side in _offsets)
          if (named.contains(side) && !css.containsKey(side)) side: 'auto',
        ...css,
      };
    }

    final v = a.variants;
    return Adaptive<CssDeclarations>(
      own(a.base),
      medium: _of(v['medium'], of),
      expanded: _of(v['expanded'], of),
      large: _of(v['large'], of),
      extraLarge: _of(v['extraLarge'], of),
      dark: _of(v['dark'], of),
      open: _of(v['open'], of),
      hover: _of(v['hover'], of),
      focused: _of(v['focused'], of),
      focusWithin: _of(v['focus-within'], of),
      disabled: _of(v['disabled'], of),
      pressed: _of(v['pressed'], of),
      groupHover: _of(v['group-hover'], of),
      groupHovers: {for (final e in a.groupHovers.entries) e.key: of(e.value)},
      container: {for (final e in a.container.entries) e.key: of(e.value)},
    ).declarations((css) => css);
  }

  static CssDeclarations? _of(
    StyleProps? p,
    CssDeclarations Function(StyleProps) f,
  ) => p == null ? null : f(p);

  static const _offsets = ['top', 'right', 'bottom', 'left'];

  static BoxPosition? _positionOf(StyleProps s) {
    final a = s.adaptive;
    return a != null && !identical(a.base, s)
        ? _positionOf(a.base)
        : s.position;
  }

  // `flex` is the CSS shorthand `flex: n`, as for `Expanded` (`n 1 0%`; a
  // zero factor keeps the content's size: `0 1 auto`, as `Flexible`), with
  // [flexShrink] as its shrink factor. A [flexBasis] is a size of its own,
  // so the three longhands are written instead.
  CssDeclarations _flexCss() {
    final grow = flex, shrink = flexShrink, basis = flexBasis;
    if (basis != null) {
      return {
        if (grow != null) 'flex-grow': '$grow',
        if (shrink != null) 'flex-shrink': '$shrink',
        'flex-basis': basis.css,
      };
    }
    if (grow != null) {
      return {'flex': '$grow ${shrink ?? 1} ${grow == 0 ? 'auto' : '0%'}'};
    }
    return {if (shrink != null) 'flex-shrink': '$shrink'};
  }

  CssDeclarations _ownCss() => {
    if (padding != null) ...padding!.toCss('padding'),
    if (margin != null) ...margin!.toCss('margin'),
    if (width != null) 'width': cssPx(width!),
    if (height != null) 'height': cssPx(height!),
    ...?constraints?.toCss(),
    if (color != null) 'background-color': color!.css,
    ...?decoration?.toCss(),
    ...?textStyle?.toCss(),
    if (opacity != null) 'opacity': cssNum(opacity!),
    if (scaleRatio case final r?)
      'scale': r.css
    else if (scale != null)
      'scale': cssNum(scale!),
    'translate': ?_translate(),
    if (widthFactor case final f?) 'width': '${cssNum(f * 100)}%',
    if (heightFactor case final f?) 'height': '${cssNum(f * 100)}%',
    if (zIndex case final z?) 'z-index': '$z',
    ..._flexCss(),
    ...?position?.toCss(),
    if (overflowX case final o?) 'overflow-x': o.css,
    if (overflowY case final o?) 'overflow-y': o.css,
    if (minWidth case final v?) 'min-width': v.css,
    if (maxWidth case final v?) 'max-width': v.css,
    if (minHeight case final v?) 'min-height': v.css,
    if (maxHeight case final v?) 'max-height': v.css,
    if (alignSelf case final a?) 'align-self': a.css,
    if (direction case final d?)
      'flex-direction': d == Axis.horizontal ? 'row' : 'column',
    if (mainAxisAlignment case final a?) 'justify-content': a.css,
    if (crossAxisAlignment case final a?) 'align-items': a.css,
    if (justifyItems case final a?) 'justify-items': a.css,
    if (wrap case final w?) 'flex-wrap': w ? 'wrap' : 'nowrap',
    ..._gaps(),
    if (gridTemplateColumns case final v?) 'grid-template-columns': v.css,
    if (gridAutoRows case final v?) 'grid-auto-rows': v.css,
    if (outline case final o?) 'outline': o.css,
    if (outlineOffset case final v?) 'outline-offset': cssPx(v),
    if (scrollMargin case final m?) ...m.toCss('scroll-margin'),
    if (transformOrigin case final a?)
      'transform-origin':
          '${cssNum((a.x + 1) * 50)}% ${cssNum((a.y + 1) * 50)}%',
    if (turns case final t?) 'rotate': '${cssNum(t)}turn',
    if (blur case final b?) 'filter': 'blur(${cssPx(b)})',
    if (ignorePointer case final i?) 'pointer-events': i ? 'none' : 'auto',
    'view-transition-name': ?viewTransitionName,
    if (widthLength case final v?) 'width': v.css,
    if (heightLength case final v?) 'height': v.css,
    if (aspectRatio case final v?) 'aspect-ratio': cssAspectRatio(v),
    if (inset case final v?) 'inset': v.css,
    if (scrollPadding case final p?) ...p.toCss('scroll-padding'),
    if (textTransform case final v?) 'text-transform': v.css,
    if (textOverflow case final v?)
      'text-overflow': v == TextOverflow.ellipsis ? 'ellipsis' : 'clip',
    if (lineClamp case final n?) ...{
      'display': '-webkit-box',
      '-webkit-box-orient': 'vertical',
      '-webkit-line-clamp': '$n',
      'line-clamp': '$n',
      'overflow': 'hidden',
    },
    if (textUnderlineOffset case final v?) 'text-underline-offset': v.css,
    if (backgroundClip case final v?) ...{
      if (v == BackgroundClip.text) '-webkit-background-clip': 'text',
      'background-clip': v.css,
    },
    if (display case final v?) 'display': v.css,
    // Offstage wins over `display`.
    if (offstage ?? false) 'display': 'none',
    if (cursor case final v?) 'cursor': v.css,
    if (textAlign case final v?) 'text-align': v.css,
    if (whiteSpace case final v?) 'white-space': v.css,
    if (textWrap case final v?) 'text-wrap': v.css,
    if (overflowWrap case final v?) 'overflow-wrap': v.css,
    if (verticalAlign case final v?) 'vertical-align': v.css,
    if (listStyleType case final v?) 'list-style-type': v.css,
    if (objectFit case final v?) 'object-fit': v.css,
    if (transition case final v?) ...Transition.toCss(v),
    if (animation case final v?) ...CssAnimation.toCss(v),
    if (filter case final v?) 'filter': v.css,
    if (backdropFilter case final v?) 'backdrop-filter': v.css,
    if (mixBlendMode case final v?) 'mix-blend-mode': v.css,
    if (appearance case final v?) 'appearance': v.css,
    if (scrollbarWidth case final v?) 'scrollbar-width': v.css,
    if (scrollbarThumbColor case final thumb?)
      'scrollbar-color':
          '${thumb.css} ${scrollbarTrackColor?.css ?? 'transparent'}',
    if (resize case final v?) 'resize': v.css,
    if (boxSizing case final v?) 'box-sizing': v.css,
    if (accentColor case final v?) 'accent-color': v.css,
    if (contentVisibility case final v?) 'content-visibility': v.css,
    if (scrollSnapType case final v?) 'scroll-snap-type': v.css,
    if (scrollSnapAlign case final v?) 'scroll-snap-align': v.css,
    if (scrollTargetGroup case final v?) 'scroll-target-group': v.css,
    if (borderCollapse case final v?) 'border-collapse': v.css,
    if (borderSpacing case final v?) 'border-spacing': cssPx(v),
    ...?fontSmoothing?.toCss(),
    if (float case final v?) 'float': v.css,
    if (userSelect case final v?) 'user-select': v.css,
    if (containerType case final v?) 'container-type': v.css,
    if (colorScheme case final v?) 'color-scheme': v.css,
    ...?raw,
  };

  // [offset] in pixels and [fractionalTranslation] in shares of the box:
  // one `translate`, a `calc()` sum when both are set.
  String? _translate() {
    final o = offset, f = fractionalTranslation;
    if (o == null && f == null) return null;
    if (f == null) return '${cssPx(o!.dx)} ${cssPx(o.dy)}';
    final x = '${cssNum(f.dx * 100)}%', y = '${cssNum(f.dy * 100)}%';
    if (o == null) return '$x $y';
    return 'calc($x + ${cssPx(o.dx)}) calc($y + ${cssPx(o.dy)})';
  }

  // [spacing] on the main axis, [runSpacing] across: one `gap` when equal.
  CssDeclarations _gaps() {
    final main = spacing?.css, run = runSpacing?.css;
    if (main == null && run == null) return const {};
    if (main == run) return {'gap': main!};
    final vertical = direction == Axis.vertical;
    return {
      vertical ? 'row-gap' : 'column-gap': ?main,
      vertical ? 'column-gap' : 'row-gap': ?run,
    };
  }
}

/// Marks its child as a hover group: descendants' `.when(groupHover: …)`
/// apply while the pointer is anywhere over it. No extra node.
///
/// ```dart
/// HoverGroup(child: Card(child: Column(children: [
///   Styled(style: StyleProps().when(groupHover: StyleProps(scale: 1.05)),
///       child: Image.network(src)),
///   Text(name),
/// ])))
/// ```
///
/// With a [name] it is a group of its own (Tailwind's `group/name`):
/// nested groups are addressed apart, `.when(groupHovers: {'card': …})`
/// reads the nearest group of that name, and `groupHover` keeps reading the
/// unnamed one.
///
/// ```dart
/// HoverGroup(name: 'card', child: Card(child: HoverGroup(name: 'row', child: Row(children: [
///   Styled(style: StyleProps().when(groupHovers: {'card': StyleProps(opacity: 1)}), child: icon),
/// ]))))
/// ```
///
/// `// web:` Flutter needs a `MouseRegion` + `setState` for this; here it is
/// one selector, with no state.
class HoverGroup extends ParentDataWrapper {
  /// Makes `child` a hover group, named [name] or not.
  const HoverGroup({super.key, this.name, required super.child});

  /// The group's name (one plain token: letters, digits, `-` and `_`), or
  /// null for the unnamed group.
  final String? name;

  static const _class = 't-group';

  static final _token = RegExp(r'^[A-Za-z][A-Za-z0-9_-]*$');

  /// The condition `.when(groupHover: …)` uses.
  static const hovered = CssCondition.within('.$_class:hover');

  /// The condition of `.when(groupHovers: {name: …})`.
  static CssCondition hoveredIn(String name) =>
      CssCondition.within('.$_class-$name:hover');

  @override
  WrapData get wrapData {
    assert(
      name == null || _token.hasMatch(name!),
      'a HoverGroup name is one plain token (letters, digits, - and _): '
      '"$name"',
    );
    return WrapData(classes: [name == null ? _class : '$_class-$name']);
  }
}

/// Shows its child only between window size classes (CSS only: correct on
/// the first server-rendered paint, no resize listeners).
///
/// ```dart
/// ResponsiveVisibility(visibleFrom: WindowSizeClass.expanded, child: rail)
/// ```
///
/// `// web:` Flutter picks a widget in `build` from `MediaQuery`/
/// `LayoutBuilder`; here both are built and CSS hides one (no rebuild on
/// resize, right on the first paint).
///
/// Only hiding rules are emitted (`display: none` outside the range), so
/// the element keeps its own `display` when visible: a Row stays flex and a
/// Container stays grid, whether the wrapper fuses into the element's class
/// or not.
class ResponsiveVisibility extends ParentDataWrapper {
  /// Wraps `child`, hiding it outside `[visibleFrom, hiddenFrom)`.
  const ResponsiveVisibility({
    super.key,
    this.visibleFrom,
    this.hiddenFrom,
    this.brightness,
    this.containerVisibleFrom,
    this.containerHiddenFrom,
    required super.child,
  }) : assert(
         visibleFrom != null ||
             hiddenFrom != null ||
             brightness != null ||
             containerVisibleFrom != null ||
             containerHiddenFrom != null,
       );

  /// Hidden below this window size class.
  final WindowSizeClass? visibleFrom;

  /// Hidden from this window size class up.
  final WindowSizeClass? hiddenFrom;

  /// Hidden while the nearest `LayoutScope` is narrower than this (px): the
  /// web's `LayoutBuilder` that drops a piece in a narrow box.
  final double? containerVisibleFrom;

  /// Hidden while the nearest `LayoutScope` is at least this wide (px).
  final double? containerHiddenFrom;

  /// Shown only in this theme (`Brightness.dark`: only while the dark
  /// theme is on, following the page's `ThemeToggle`).
  final Brightness? brightness;

  @override
  WrapData get wrapData => WrapData(
    conditions: [
      if (visibleFrom != null)
        ConditionalCss(CssCondition.belowBreakpoint(visibleFrom!), const {
          'display': 'none',
        }),
      if (hiddenFrom != null)
        ConditionalCss(hiddenFrom!.condition, const {'display': 'none'}),
      if (containerVisibleFrom case final px?)
        ConditionalCss(CssCondition.belowContainer(px), const {
          'display': 'none',
        }),
      if (containerHiddenFrom case final px?)
        ConditionalCss(CssCondition.container(px), const {'display': 'none'}),
      if (brightness != null)
        ConditionalCss(
          brightness == Brightness.dark
              ? CssCondition.light
              : CssCondition.dark,
          const {'display': 'none'},
        ),
    ],
  );
}

/// Different layouts per screen size — the web counterpart of switching on
/// `MediaQuery.sizeOf(context).width` or `LayoutBuilder`.
///
/// **Every variant is rendered** and CSS shows the right one, so it works
/// with SSR and never flashes. The price: the hidden variants are in the
/// HTML too, so what is in both is sent, parsed and kept twice (a 24-product
/// grid in `mobile` and in `desktop` is a 24-product grid shipped twice, and
/// a `FutureBuilder` or a `Watch.list` in both is drawn and kept in sync
/// twice). Use it for chrome that really differs (a drawer against a top
/// bar), and keep what the variants have in common out of it.
///
/// When only the *arrangement* changes, prefer **one tree** with `.when()`:
/// the same widgets, another layout per breakpoint, nothing duplicated.
///
/// ```dart
/// // WRONG: the grid is in the page twice
/// ResponsiveLayout(
///   mobile: ProductGrid(columns: 2, products: products),
///   desktop: ProductGrid(columns: 4, products: products),
/// )
///
/// // RIGHT: one grid, its columns per breakpoint
/// Grid(
///   layout: GridLayout(columns: 2, gap: 8).when(expanded: GridLayout(columns: 4)),
///   children: [for (final p in products) ProductCard(p)],
/// )
///
/// // RIGHT: a column that becomes a row from `lg`
/// Column(
///   layout: FlexLayout().when(expanded: FlexLayout(direction: Axis.horizontal)),
///   children: [sidebar, Expanded(child: content)],
/// )
/// ```
///
/// `thor dev` warns (THOR-R034) when two variants both carry a
/// `FutureBuilder`, both a `Watch.list`, or both more than 16 KB of HTML.
class ResponsiveLayout extends StatelessWidget {
  /// Renders [mobile], [tablet] or [desktop] depending on the viewport.
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.tabletFrom = WindowSizeClass.medium,
    this.desktopFrom = WindowSizeClass.expanded,
  });

  /// Shown below [tabletFrom] (or [desktopFrom] when there is no [tablet]).
  final Widget mobile;

  /// Shown from [tabletFrom] up to [desktopFrom], if given.
  final Widget? tablet;

  /// Shown from [desktopFrom] up, if given.
  final Widget? desktop;

  /// Window size class at which [tablet] replaces [mobile].
  final WindowSizeClass tabletFrom;

  /// Window size class at which [desktop] replaces [tablet]/[mobile].
  final WindowSizeClass desktopFrom;

  @override
  Widget build(BuildContext context) {
    final t = tablet, d = desktop;
    if (t == null && d == null) return mobile;
    // web: `thor dev` weighs each variant (see [_Weighed]); a release
    // builds nothing extra.
    final cost = kDebugMode
        ? _VariantCosts(1 + (t != null ? 1 : 0) + (d != null ? 1 : 0))
        : null;
    Widget weigh(String name, Widget variant) =>
        cost == null ? variant : _Weighed(cost, name, variant);
    return Widget.fragment([
      ResponsiveVisibility(
        hiddenFrom: t != null ? tabletFrom : desktopFrom,
        child: weigh('mobile', mobile),
      ),
      if (t != null)
        ResponsiveVisibility(
          visibleFrom: tabletFrom,
          hiddenFrom: d != null ? desktopFrom : null,
          child: weigh('tablet', t),
        ),
      if (d != null)
        ResponsiveVisibility(
          visibleFrom: desktopFrom,
          child: weigh('desktop', d),
        ),
    ]);
  }
}

/// A variant of a [ResponsiveLayout] above this many bytes of HTML is heavy
/// enough that having it twice is worth a warning.
const _heavyVariantBytes = 16 * 1024;

/// What a variant weighs once built, for [responsiveCostWarning].
typedef VariantCost = ({String name, int bytes, int futures, bool list});

/// The THOR-R034 message for the variants of a `ResponsiveLayout` (in the
/// order they were drawn), or null when nothing is repeated: at least two
/// of them carry a `FutureBuilder`, at least two a `Watch.list`, or at least
/// two are more than 16 KB of HTML each.
///
/// Cheap and precise on purpose: a variant that is small, or the only one
/// with a list, costs nothing worth saying.
@visibleForTesting
String? responsiveCostWarning(List<VariantCost> variants) {
  String names(Iterable<VariantCost> some) {
    final list = [for (final v in some) v.name];
    return list.length == 1
        ? list.single
        : '${list.sublist(0, list.length - 1).join(', ')} and ${list.last}';
  }

  final futures = variants.where((v) => v.futures > 0).toList();
  final lists = variants.where((v) => v.list).toList();
  final heavy = variants.where((v) => v.bytes >= _heavyVariantBytes).toList();
  final what = [
    if (futures.length > 1) 'a FutureBuilder in ${names(futures)}',
    if (lists.length > 1) 'a Watch.list in ${names(lists)}',
    if (heavy.length > 1)
      '${names(heavy)} are ${[for (final v in heavy) '${v.bytes ~/ 1024} KB'].join(' and ')} of HTML',
  ];
  if (what.isEmpty) return null;
  return thorError(
    'THOR-R034',
    'a ResponsiveLayout draws every variant and CSS hides the others, so '
        'what is in two of them is shipped twice: ${what.join('; ')}. Keep '
        'one tree and change its layout per breakpoint with `.when()` '
        '(GridLayout/FlexLayout), or leave only the chrome that really '
        'differs in the variants',
  );
}

/// The costs the variants of one [ResponsiveLayout] report as they are built.
class _VariantCosts {
  _VariantCosts(this.expected);

  final int expected;
  final _costs = <VariantCost>[];

  void report(VariantCost cost, DeferRun run) {
    _costs.add(cost);
    if (_costs.length != expected) return;
    if (responsiveCostWarning(_costs) case final message?) {
      run.warnOnce(message);
    }
  }
}

/// A variant of a [ResponsiveLayout] under `thor dev`: built like its child
/// (so is the page), and measured when something is listening
/// ([DeferRun.warn]): its HTML, the `FutureBuilder`s and the `Watch.list`
/// in it. Without a listener it builds its child where it stands.
class _Weighed extends PageComponent
    implements ThorBuiltIn, LayoutHint, HeightHint {
  const _Weighed(this.costs, this.name, this.child);

  final _VariantCosts costs;
  final String name;
  final Widget child;

  @override
  bool get fillsWidth => layoutFillsWidth(child);

  @override
  bool get fillsHeight => layoutFillsHeight(child);

  @override
  void buildInto(
    PageBuild page,
    Element element,
    ParentNode into,
    BuildChild build,
  ) {
    final run = element
        .dependOnInheritedWidgetOfExactType<DeferScope>()
        ?.holder
        .run;
    if (run?.warn == null) return build(child, element, into);
    final futuresBefore = run!.futureBuilders;
    final node = FragmentNode();
    build(child, element, node);
    into.add(node);
    try {
      final bytes = writeChildrenUtf8(node);
      final html = utf8.decode(bytes, allowMalformed: true);
      costs.report((
        name: name,
        bytes: bytes.length,
        futures: run.futureBuilders - futuresBefore,
        list: html.contains(' $listAttr="'),
      ), run);
      // A hint is not worth breaking the page: a variant that does not
      // serialize here fails in the real write, with its own error.
    } on Object {
      return;
    }
  }
}

// web: Flutter reads the parent's size with `LayoutBuilder` while it lays
// out; the browser does it in CSS (a container query), with no rebuild.
/// Makes a size container around its child, so descendants can respond to
/// *its* width (`.when(container: {...})`,
/// `GridView.count(containerBreakpoints:)`, `Flex(layoutBreakpoints:)`)
/// instead of the viewport's.
///
/// ```dart
/// LayoutScope(
///   child: Container(
///     padding: const EdgeInsets.all(8).when(container: {400: EdgeInsets.all(24)}),
///     child: content,
///   ),
/// )
/// ```
///
/// `// web:` the `LayoutBuilder` of a box: Flutter hands its builder the
/// parent's constraints and rebuilds when they change; CSS container queries
/// do the same with no builder and no rebuild, so [LayoutScope] only marks
/// the box and the values of its descendants carry the widths.
///
/// It is a real element: CSS container queries never match the container
/// itself, only its descendants. Like `LayoutBuilder`, it needs a bounded
/// width; a scope that sizes to its content (e.g. a non-Expanded child of a
/// Row) collapses to 0 (reported by the debug inspector).
class LayoutScope extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a container query scope around [child].
  const LayoutScope({super.key, required this.child});

  /// The scoped subtree.
  final Widget child;

  @override
  bool get fillsWidth => true;

  @override
  Widget build(BuildContext context) => thorElement(
    'div',
    debugName: 'LayoutScope',
    fillsWidth: true,
    css: const {...boxCss, 'container-type': 'inline-size'},
    childRules: ChildRules.box,
    children: [child],
  );
}

/// The [CssCondition] equivalent of a [WindowSizeClass].
extension BreakpointCondition on WindowSizeClass {
  /// Viewport at least this breakpoint's [WindowSizeClass.minWidth] wide.
  CssCondition get condition => CssCondition.breakpoint(this);
}

class _AdaptiveStyleProps extends StyleProps {
  const _AdaptiveStyleProps(this.adaptive);

  @override
  final Adaptive<StyleProps> adaptive;
}

/// Objects compared by identity, in order (a memo key that never compares
/// values a caller could change).
final class _Parts {
  _Parts(this.parts) : hashCode = Object.hashAll(parts.map(identityHashCode));

  final List<Object?> parts;

  @override
  final int hashCode;

  @override
  bool operator ==(Object other) {
    if (other is! _Parts || other.hashCode != hashCode) return false;
    for (var i = 0; i < parts.length; i++) {
      if (!identical(parts[i], other.parts[i])) return false;
    }
    return true;
  }
}
