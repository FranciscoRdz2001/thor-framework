import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import 'parent_data.dart' show WrapData;

/// What a thor element gives to its **direct children**: the web version of
/// the constraints a Flutter parent passes down.
///
/// Instead of relational selectors (`.t-flex > *`, `.t-col > .t-fill-w`),
/// which force every element to carry structural classes, the parent
/// publishes these rules through the tree and each child compiles them into
/// its own single class. Result: one class per element (like CSS Modules),
/// no structural CSS at all, and rules that only depend on data.
class ChildRules {
  /// Creates a set of rules a thor element publishes to its children.
  const ChildRules({
    this.all = const {},
    this.fillWidth = const {},
    this.fillHeight = const {},
    this.flexible = const {},
    this.fillMaxWidth = const {},
  });

  /// Added for a flexible child (`Expanded`, `Flexible`): what lets it
  /// shrink below its content on this parent's main axis, and only that
  /// axis (a button in a `Row` keeps its minimum height).
  final CssDeclarations flexible;

  /// Applied to every direct child.
  final CssDeclarations all;

  /// Added for children that take the max width in Flutter (`LayoutHint`).
  final CssDeclarations fillWidth;

  /// Replaces [fillWidth] for a child that takes the max width but caps it
  /// with its own `max-width` (see [capsWidth]): Flutter sizes it to
  /// `min(max width, available)` and the parent still positions it, so it
  /// must not be stretched to the start. Empty: [fillWidth] applies.
  final CssDeclarations fillMaxWidth;

  /// Added for children that take the max height (`HeightHint`).
  final CssDeclarations fillHeight;

  /// No rules for any child.
  static const none = ChildRules();

  /// Row: non-flex children keep their intrinsic size (Flutter never
  /// shrinks them); children that want the max height stretch across.
  static const row = ChildRules(
    all: {'flex': '0 0 auto'},
    fillHeight: {'align-self': 'stretch'},
    flexible: {'min-width': '0'},
  );

  /// Column: same, across the width.
  static const column = ChildRules(
    all: {'flex': '0 0 auto'},
    fillWidth: {'align-self': 'stretch'},
    flexible: {'min-height': '0'},
  );

  /// Column that centers (or ends) its children: like [column], but a
  /// child that takes the max width and caps it (`ConstrainedBox(maxWidth:
  /// 820)`) is as wide as it may be and positioned by `align-items`, as
  /// Flutter does, instead of stretched to the start.
  static const columnAligned = ChildRules(
    all: {'flex': '0 0 auto'},
    fillWidth: {'align-self': 'stretch'},
    flexible: {'min-height': '0'},
    fillMaxWidth: {'box-sizing': 'border-box', 'width': '100%'},
  );

  /// Sized box: its single child gets tight constraints (stretched across by
  /// `align-items: stretch`, down by `flex-grow`).
  static const box = ChildRules(
    all: {'flex': '1 1 auto', 'min-width': '0', 'min-height': '0'},
  );

  /// Stack: every child in the same grid cell.
  static const stack = ChildRules(
    all: {'grid-area': '1 / 1'},
    fillWidth: {'justify-self': 'stretch'},
  );

  /// Aligned box / Align: loose constraints positioned with physical auto
  /// margins (`align-self: center` when centered), except for children that
  /// take the max width (stretched). A child that takes the max width up to
  /// its own max width is as wide as it may be and keeps its position:
  /// `Align(topCenter) >
  /// Container(width: infinity, maxWidth: 1180)` is centered, as in Flutter.
  ///
  /// One instance per alignment, so its [forChild] merges are shared.
  static ChildRules aligned(AlignmentGeometry alignment) {
    final known = _aligned[alignment];
    if (known != null) return known;
    // Bounded: an alignment computed from data must not grow it forever.
    if (_aligned.length >= 256) _aligned.clear();
    return _aligned[alignment] = _align(alignment);
  }

  static final _aligned = <AlignmentGeometry, ChildRules>{};

  static ChildRules _align(AlignmentGeometry alignment) => ChildRules(
    all: {'min-width': '0', ...alignment.flexChildCss},
    fillWidth: const {
      'align-self': 'stretch',
      'margin-left': '0',
      'margin-right': '0',
      'max-width': 'none',
    },
    // web: auto margins turn off `align-self: stretch`, so the width is
    // explicit; border-box because Flutter's constraints include padding.
    fillMaxWidth: const {'box-sizing': 'border-box', 'width': '100%'},
  );

  /// Rules that follow a flex container's direction per variant: [base]
  /// below every variant, and each of [variants] (keyed like `.when()`:
  /// `md`, `c900`, a state) from its condition up. A `Column` a
  /// `FlexLayout` turns into a row gives its children a row's rules there
  /// (a child that takes the max width is no longer stretched across the
  /// row's height), compiled into each child's own class as conditions.
  static ChildRules directional(
    ChildRules base,
    Map<String, ChildRules> variants,
  ) {
    if (variants.isEmpty) return base;
    final key = StringBuffer(identityHashCode(base));
    for (final e in variants.entries) {
      key.write('|${e.key}:${identityHashCode(e.value)}');
    }
    final k = key.toString();
    final known = _directional[k];
    if (known != null) return known;
    // Bounded: layouts are few, but keys come from widgets.
    if (_directional.length >= 256) _directional.clear();
    return _directional[k] = _DirectionalRules(base, variants);
  }

  static final _directional = <String, ChildRules>{};

  /// Whether a child is stretched across by `align-self: stretch`.
  bool get growsAcross =>
      fillWidth.containsKey('align-self') ||
      fillHeight.containsKey('align-self') ||
      fillMaxWidth.containsKey('align-self');

  /// These rules for the children of a flex container that is a grid
  /// instead (`display: grid` from a `Styled`): without `align-self`, so the
  /// grid's `align-items` places each child, and a child's own `alignSelf`
  /// is the only thing that overrides it.
  ChildRules get inGrid => _inGrid[this] ??= ChildRules(
    all: all,
    fillWidth: _withoutAlignSelf(fillWidth),
    fillHeight: _withoutAlignSelf(fillHeight),
    flexible: flexible,
    fillMaxWidth: _withoutAlignSelf(fillMaxWidth),
  );

  static final _inGrid = Expando<ChildRules>('ChildRules.inGrid');

  static CssDeclarations _withoutAlignSelf(CssDeclarations css) => css.isEmpty
      ? css
      : Map.unmodifiable({
          for (final e in css.entries)
            if (e.key != 'align-self') e.key: e.value,
        });

  /// Whether these rules add no declarations at all.
  bool get isEmpty =>
      all.isEmpty &&
      fillWidth.isEmpty &&
      fillHeight.isEmpty &&
      flexible.isEmpty &&
      fillMaxWidth.isEmpty;

  /// The declarations a child with these fill hints receives. [capsWidth]:
  /// the child also caps its width (see [ChildRules.capsWidth]), so it gets
  /// [fillMaxWidth] instead of [fillWidth] when this parent has one.
  CssDeclarations forChild({
    bool fillsWidth = false,
    bool fillsHeight = false,
    bool capsWidth = false,
  }) {
    // Read-only for the caller: the common case copies nothing.
    if (!fillsWidth && !fillsHeight) return all;
    final width = capsWidth && fillMaxWidth.isNotEmpty
        ? fillMaxWidth
        : fillWidth;
    // The rules are fixed: each combination is merged once (every child of
    // every Row and Column asks).
    final combos = _forChild[this] ??= List.filled(8, null);
    final i =
        (fillsWidth ? 1 : 0) | (fillsHeight ? 2 : 0) | (capsWidth ? 4 : 0);
    return combos[i] ??= Map.unmodifiable({
      ...all,
      if (fillsWidth) ...width,
      if (fillsHeight) ...fillHeight,
    });
  }

  static final _forChild = Expando<List<CssDeclarations?>>(
    'ChildRules.forChild',
  );

  /// Whether a child whose own declarations are [own] (and [conditional],
  /// its breakpoint/state rules) caps its width: it sets a `max-width` and
  /// no horizontal margin (a margin next to `width: 100%` would overflow, and
  /// would replace the parent's auto margins anyway). A vertical-only
  /// `margin` shorthand is fine: see [splitVerticalMargin].
  ///
  /// With [margins] (a parent that does not position its children with
  /// auto margins, see [positionsWithMargins]), a fixed horizontal margin
  /// in [own] is fine too: [widthInsideMargins] takes it out of the width,
  /// as Flutter lays out `Container(margin:)` (a padding around the capped
  /// box, which the parent positions).
  static bool capsWidth(
    Iterable<CssDeclarations> own,
    Iterable<CssDeclarations> conditional, {
    bool margins = false,
  }) {
    var max = false;
    for (final css in [...own, ...conditional]) {
      if (css.containsKey('max-width')) max = true;
    }
    if (!max) return false;
    final fixed = margins && own.every((css) => marginSum(css) != null);
    for (final css in [if (!fixed) ...own, ...conditional]) {
      for (final e in css.entries) {
        final horizontal = switch (e.key) {
          'margin' => _verticalMargin(e.value) == null,
          final key => _horizontalKey(key),
        };
        if (horizontal) return false;
      }
    }
    return true;
  }

  /// Whether these rules position a child with its horizontal margins (an
  /// `Align` to one side): a margin of the child's own would replace them.
  bool get positionsWithMargins =>
      all.keys.any((k) => k == 'margin' || _horizontalKey(k));

  /// [css] (a [capsWidth] child's, with what its parent granted) with its
  /// `width: 100%` minus its horizontal margins: `max-width` caps the box
  /// and the margins stay outside it. Unchanged without such margins.
  ///
  /// `// web:` `box-sizing` cannot take a margin in, so the width does.
  static CssDeclarations widthInsideMargins(CssDeclarations css) {
    if (css['width'] != '100%') return css;
    final sum = marginSum(css);
    if (sum == null || sum.isEmpty) return css;
    return {...css, 'width': 'calc(100% - $sum)'};
  }

  static bool _horizontalKey(String key) => switch (key) {
    'margin-left' ||
    'margin-right' ||
    'margin-inline' ||
    'margin-inline-start' ||
    'margin-inline-end' => true,
    _ => false,
  };

  /// The sum of the horizontal margins [css] sets (`32px`, `16px + 1rem`),
  /// in declaration order; empty without any. Null when one is not a fixed
  /// length (`auto`, a breakpoint or state value): fail closed.
  static String? marginSum(CssDeclarations css) {
    String? left, right;
    for (final e in css.entries) {
      if (e.key != 'margin' && !_horizontalKey(e.key)) continue;
      final value = e.value.trim();
      if (isAdaptive(value) || value.contains('auto')) return null;
      final parts = value.split(RegExp(r'\s+'));
      switch (e.key) {
        case 'margin':
          if (parts.isEmpty || parts.length > 4) return null;
          right = parts.length == 1 ? parts[0] : parts[1];
          left = parts.length == 4 ? parts[3] : right;
        case 'margin-inline':
          if (parts.isEmpty || parts.length > 2) return null;
          left = parts.first;
          right = parts.last;
        case 'margin-left' || 'margin-inline-start':
          left = value;
        default:
          right = value;
      }
    }
    final terms = [
      for (final v in [?left, ?right])
        if (v != '0' && v != '0px') v,
    ];
    final px = [
      for (final t in terms)
        if (t.endsWith('px')) double.tryParse(t.substring(0, t.length - 2)),
    ];
    if (px.length == terms.length && !px.contains(null)) {
      final total = px.fold<double>(0, (a, b) => a + b!);
      return total == 0 ? '' : cssPx(total);
    }
    return terms.join(' + ');
  }

  /// [outer] (the size constraints of the wrappers around an element:
  /// `max-width`, `min-height`, `width`…) with the margins of [inner] (the
  /// element's own, or a `Padding` folded into it) taken out of them.
  ///
  /// In Flutter a `Padding` or a `Container(margin:)` below a
  /// `ConstrainedBox` or a `SizedBox` sits *inside* its constraints, so
  /// `ConstrainedBox(maxWidth: 1180, child: Padding(horizontal: 28))` is
  /// 1180 wide in total.
  ///
  /// `// web:` the padding is folded into the child's element as a margin,
  /// and a margin lies outside the `max-width` of its own box, which would
  /// make the band 1180 + 56. Instead of a second element, the constraint
  /// gives up the margin (`max-width: 1124px`, or a `calc()` when the
  /// lengths are not both pixels). Unchanged without margins, for a margin
  /// that is not a fixed length, and for a key [inner] sets itself.
  static CssDeclarations constraintsInside(
    CssDeclarations outer,
    CssDeclarations inner,
  ) {
    if (outer.isEmpty || inner.isEmpty) return outer;
    CssDeclarations? out;
    final horizontal = marginSum(inner);
    final vertical = _verticalMarginSum(inner);
    for (final e in outer.entries) {
      final sum = switch (e.key) {
        'width' || 'min-width' || 'max-width' => horizontal,
        'height' || 'min-height' || 'max-height' => vertical,
        _ => null,
      };
      if (sum == null || sum.isEmpty || inner.containsKey(e.key)) continue;
      final value = _lessMargins(e.value, sum);
      if (value != null) (out ??= {...outer})[e.key] = value;
    }
    return out ?? outer;
  }

  // `value` minus `sum`, or null when `value` is not a length that can be
  // reduced (a keyword, a breakpoint value, zero).
  static String? _lessMargins(String value, String sum) {
    final v = value.trim();
    // `calc(100% - margin)`: already made room for them (an `Align` folded
    // into a capped child with a margin of its own).
    if (isAdaptive(v) ||
        v == '0' ||
        v.startsWith('calc(100% - ') ||
        RegExp(r'^[a-z-]+$').hasMatch(v)) {
      return null;
    }
    final a = _px(v), b = _px(sum);
    if (a != null && b != null) return cssPx(a > b ? a - b : 0);
    return 'calc($v - ${sum.contains(' ') ? '($sum)' : sum})';
  }

  static double? _px(String v) =>
      v.endsWith('px') ? double.tryParse(v.substring(0, v.length - 2)) : null;

  /// [marginSum] for the vertical margins.
  static String? _verticalMarginSum(CssDeclarations css) {
    String? top, bottom;
    for (final e in css.entries) {
      final key = e.key;
      if (key != 'margin' &&
          key != 'margin-top' &&
          key != 'margin-bottom' &&
          key != 'margin-block' &&
          key != 'margin-block-start' &&
          key != 'margin-block-end') {
        continue;
      }
      final value = e.value.trim();
      if (isAdaptive(value) || value.contains('auto')) return null;
      final parts = value.split(RegExp(r'\s+'));
      switch (key) {
        case 'margin':
          if (parts.isEmpty || parts.length > 4) return null;
          top = parts.first;
          bottom = parts.length >= 3 ? parts[2] : top;
        case 'margin-block':
          if (parts.length > 2) return null;
          top = parts.first;
          bottom = parts.last;
        case 'margin-top' || 'margin-block-start':
          top = value;
        default:
          bottom = value;
      }
    }
    final terms = [
      for (final v in [?top, ?bottom])
        if (v != '0' && v != '0px') v,
    ];
    final px = [for (final t in terms) _px(t)];
    if (!px.contains(null)) {
      final total = px.fold<double>(0, (a, b) => a + b!);
      return total == 0 ? '' : cssPx(total);
    }
    return terms.join(' + ');
  }

  /// [css] with a vertical-only `margin` shorthand (`0 0 16px`) split into
  /// `margin-top`/`margin-bottom`, so it doesn't reset the auto margins a
  /// parent positions a [capsWidth] child with.
  static CssDeclarations splitVerticalMargin(CssDeclarations css) {
    final margin = css['margin'];
    final vertical = margin == null ? null : _verticalMargin(margin);
    if (vertical == null) return css;
    return {
      for (final e in css.entries)
        if (e.key != 'margin') e.key: e.value,
      'margin-top': vertical.$1,
      'margin-bottom': vertical.$2,
    };
  }

  // (top, bottom) of a `margin` shorthand whose left and right are zero;
  // null otherwise (adaptive values included: fail closed).
  static (String, String)? _verticalMargin(String value) {
    if (isAdaptive(value)) return null;
    final parts = value.trim().split(RegExp(r'\s+'));
    bool zero(String v) => v == '0' || v == '0px';
    final (top, right, bottom, left) = switch (parts) {
      [final a] => (a, a, a, a),
      [final a, final b] => (a, b, a, b),
      [final a, final b, final c] => (a, b, c, b),
      [final a, final b, final c, final d] => (a, b, c, d),
      _ => (null, null, null, null),
    };
    if (top == null || !zero(right!) || !zero(left!)) return null;
    return (top, bottom!);
  }

  // Compared on every rebuild (updateShouldNotify): structural, no strings.
  static bool _same(CssDeclarations a, CssDeclarations b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChildRules &&
          _same(all, other.all) &&
          _same(fillWidth, other.fillWidth) &&
          _same(fillHeight, other.fillHeight) &&
          _same(flexible, other.flexible) &&
          _same(fillMaxWidth, other.fillMaxWidth);

  @override
  int get hashCode =>
      Object.hash(all.length, fillWidth.length, fillHeight.length);

  /// Rules published by the nearest thor element above [context].
  static ChildRules? of(BuildContext context) =>
      ChildRulesScope.maybeOf(context)?.rules;
}

/// [ChildRules.directional]: each field and each child's grant is the base
/// rules' value marked with the variants' values, so the child's class
/// gets one condition per variant.
class _DirectionalRules extends ChildRules {
  _DirectionalRules(this._base, this._variants)
    : super(
        all: _mark(_base.all, {
          for (final e in _variants.entries) e.key: e.value.all,
        }),
        fillWidth: _mark(_base.fillWidth, {
          for (final e in _variants.entries) e.key: e.value.fillWidth,
        }),
        fillHeight: _mark(_base.fillHeight, {
          for (final e in _variants.entries) e.key: e.value.fillHeight,
        }),
        flexible: _mark(_base.flexible, {
          for (final e in _variants.entries) e.key: e.value.flexible,
        }),
        fillMaxWidth: _mark(_base.fillMaxWidth, {
          for (final e in _variants.entries) e.key: e.value.fillMaxWidth,
        }),
      );

  final ChildRules _base;
  final Map<String, ChildRules> _variants;

  final _grants = List<CssDeclarations?>.filled(8, null);

  @override
  CssDeclarations forChild({
    bool fillsWidth = false,
    bool fillsHeight = false,
    bool capsWidth = false,
  }) {
    final i =
        (fillsWidth ? 1 : 0) | (fillsHeight ? 2 : 0) | (capsWidth ? 4 : 0);
    CssDeclarations of(ChildRules r) => r.forChild(
      fillsWidth: fillsWidth,
      fillsHeight: fillsHeight,
      capsWidth: capsWidth,
    );
    return _grants[i] ??= _mark(of(_base), {
      for (final e in _variants.entries) e.key: of(e.value),
    });
  }

  // What a declaration one direction sets and the other doesn't goes back
  // to where it would be without it (`align-self: auto`, `min-width:
  // auto`): a variant can't just omit it, the base value would carry over.
  static const _neutral = {
    'align-self': 'auto',
    'min-width': 'auto',
    'min-height': 'auto',
    'flex': '0 1 auto',
  };

  // Every variant is kept, also one equal to the base: it may undo an
  // earlier variant (`md: row, lg: column`).
  static CssDeclarations _mark(
    CssDeclarations base,
    Map<String, CssDeclarations> variants,
  ) {
    final keys = {...base.keys, for (final v in variants.values) ...v.keys};
    String one(String k) {
      final b = base[k];
      final v = {
        for (final e in variants.entries)
          e.key: e.value[k] ?? _neutral[k] ?? 'unset',
      };
      // The same everywhere (`flex: 0 0 auto` in rows and columns): plain.
      if (b != null && v.values.every((x) => x == b)) return b;
      return markAdaptive(b ?? '', v);
    }

    return Map.unmodifiable({for (final k in keys) k: one(k)});
  }
}

/// Publishes a parent's [ChildRules] to its children (no DOM node).
///
/// It also carries the [pending] data of wrappers (`Expanded`, `Padding`
/// folded into a margin, `Opacity`…) whose child is a [ThorElementWidget]:
/// the first thor element below consumes it and compiles it into its own
/// class, so a wrapped element still has exactly one class. Every thor
/// element resets it for its children, so it never reaches grandchildren.
class ChildRulesScope extends InheritedWidget implements InheritedMemoKey {
  /// Publishes [rules] (and any [pending] wrapper data) to [child].
  const ChildRulesScope({
    super.key,
    required this.rules,
    this.pending,
    required super.child,
  }) : _render = null;

  /// A thor element: the scope *is* the element and renders its DOM node
  /// itself (one framework element instead of a component + scope + fragment).
  /// [render] receives the scope of the parent.
  const ChildRulesScope.element({
    super.key,
    required this.rules,
    required Widget Function(BuildContext context, ChildRulesScope? parent)
    render,
  }) : pending = null,
       _render = render,
       super(child: const Widget.fragment([]));

  /// The rules published to direct children, if any.
  final ChildRules? rules;

  /// Whether this scope is a thor element (not a wrapper's pending data).
  bool get isElement => _render != null;

  /// Wrapper data (from `Expanded`, `Padding`…) waiting for the next thor
  /// element to compile it into its own class.
  final WrapData? pending;
  final Widget Function(BuildContext, ChildRulesScope?)? _render;

  /// The nearest [ChildRulesScope] above [context], if any.
  static ChildRulesScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChildRulesScope>();

  @override
  Widget buildChild(InheritedElement element) {
    final render = _render;
    if (render == null) return child;
    // The parent's scope: an element's lookups skip the element itself, and
    // see its parent when that is a scope (a scope returned right around a
    // thor element, not only one above a component).
    final parent =
        element
                .getElementForInheritedWidgetOfExactType<ChildRulesScope>()
                ?.widget
            as ChildRulesScope?;
    return render(element, parent);
  }

  @override
  bool updateShouldNotify(covariant ChildRulesScope oldComponent) =>
      oldComponent.rules != rules || !identical(oldComponent.pending, pending);

  /// Children read the rules (and whether the parent is an element);
  /// pending wrapper data is this build's own, never shared.
  @override
  Object? get memoKey => pending == null ? (rules, isElement) : this;
}

/// Marks thor widgets whose first DOM element is a `thorElement` (directly
/// or through other thor widgets / wrappers).
///
/// Wrappers around them hand their data to that element instead of using
/// `Widget.wrapElement`, which would need a second class. App widgets can
/// implement it too when their `build` returns a thor widget.
abstract interface class ThorElementWidget {}

/// Marks thor's own widgets (`Row`, `Text`, `FilledButton`…), as opposed to
/// an app's components. Debug builds name an element's class after the
/// nearest app component above it (`ProductCard` → `product-card`,
/// `product-card__row`); thor's widgets are what gets named, never the name.
abstract interface class ThorBuiltIn {}

/// Marks a widget that renders more than one element side by side (a
/// trigger and its popover). As the state of a `Watch`, it gets a box of
/// its own that takes no part in the layout (`display: contents`): a state
/// is swapped in the browser as one element.
abstract interface class MultipleRoots {}
