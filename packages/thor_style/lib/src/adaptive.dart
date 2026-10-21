import 'css.dart';
import 'equality.dart';

/// Window size class names in cascade order, smallest first (thor_ui's
/// `WindowSizeClass` values, `compact` is the base and has no variant).
///
/// `medium`..`extraLarge` are Material's (600, 840, 1200, 1600 by default).
const adaptiveBreakpoints = ['medium', 'expanded', 'large', 'extraLarge'];

/// Variant key of a container width: `c400` for `container: {400: …}`.
const containerKeyPrefix = 'c';

/// The container width of a variant key, or null for other keys.
num? containerWidthOf(String key) =>
    key.startsWith(containerKeyPrefix) ? num.tryParse(key.substring(1)) : null;

/// The variant key of container width [px]: a whole width is written
/// without decimals (`400` and `400.0` are the same threshold).
String containerKeyOf(num px) =>
    '$containerKeyPrefix${px == px.truncate() ? px.truncate() : px}';

/// Interaction states a value can change in (applied after breakpoints).
const adaptiveStates = [
  'dark',
  'open',
  'hover',
  'focused',
  'focus-within',
  'disabled',
  'pressed',
  'group-hover',
];

/// Variant key prefix of a named hover group: `group-hover/card` for
/// `groupHovers: {'card': …}` (Tailwind's `group-hover/card`).
const groupHoverKeyPrefix = 'group-hover/';

/// The name of a named group variant key (`card` of `group-hover/card`), or
/// null for other keys.
String? groupHoverNameOf(String key) => key.startsWith(groupHoverKeyPrefix)
    ? key.substring(groupHoverKeyPrefix.length)
    : null;

/// Whether [key] is a state variant (hover, a named group…).
bool isStateKey(String key) =>
    adaptiveStates.contains(key) || key.startsWith(groupHoverKeyPrefix);

/// Whether [key] is a breakpoint or a container width.
bool isWidthKey(String key) =>
    adaptiveBreakpoints.contains(key) || containerWidthOf(key) != null;

/// Variant key of a width and a state that apply together (`md+hover`): a
/// state whose value changes by breakpoint, or a breakpoint whose value
/// changes by state.
String compoundKey(String width, String state) => '$width+$state';

/// The `(width, state)` of a [compoundKey], or null for other keys.
(String, String)? compoundOf(String key) {
  final i = key.indexOf('+');
  return i < 0 ? null : (key.substring(0, i), key.substring(i + 1));
}

// Marker around a value that changes per breakpoint, inside a CSS string:
// ⟦base␟md␞value␟lg␞value⟧. Never reaches the page: thor_ui splits it into
// breakpoint conditions of the element's class.
const _open = '⟦', _close = '⟧', _alt = '␟', _kv = '␞';
const _openAlt = '$_open$_alt';

/// Makes a value type changeable per breakpoint and per interaction state
/// with one inherited method (Flutter's `WidgetStateProperty` idea, as a
/// value):
///
/// ```dart
/// padding: const EdgeInsets.all(96).when(medium: EdgeInsets.all(128))
/// color: surface.when(hover: background)
/// ```
///
/// A type opts in with `with Adaptable<T>` and implements [withVariants]
/// (how it carries them). Implemented by `EdgeInsets`, `BorderRadius`,
/// `BoxConstraints`, `BoxDecoration`, `TextStyle`, `Color` and `Length`.
/// Numbers can't (Dart's `double` and `int` are final): use a `Length`
/// (`SizedBox(heightLength: 40.px.when(expanded: 56.px))`) or
/// `Responsive(medium: StyleProps(width: …))`. Wrap in an `Animated*` widget
/// (`AnimatedContainer(duration:)`) to transition between states.
abstract mixin class Adaptable<T extends Object> {
  /// This value below the first given window size class (`compact` is the
  /// base); each class variant from its width up (mobile-first: [medium]
  /// 600, [expanded] 840, [large] 1200, [extraLarge] 1600, Material 3's
  /// window size classes, or the theme's `Breakpoints`); each state variant while the
  /// element is hovered, focused (keyboard), pressed, or while the nearest
  /// `HoverGroup` is hovered; each [container] variant while the nearest
  /// `LayoutScope` is at least that wide (px, mobile-first): the same value
  /// adapting to a sidebar or a full page. The keys are `num`, any width:
  /// `{592.02: …}` or a breakpoint's own (`{WindowSizeClass.medium.minWidth: …}`);
  /// the scope is the nearest one, there are no named containers.
  ///
  /// A variant can have variants of its own: a hover that changes from `md`
  /// up (`c.when(hover: h.when(medium: m))`), a breakpoint that has its own
  /// hover. Both are one rule of the element's class, under the media query
  /// and the state together. [groupHovers] are the variants of *named*
  /// `HoverGroup`s (`{'card': …}`), apart from [groupHover]'s unnamed one.
  T when({
    T? medium,
    T? expanded,
    T? large,
    T? extraLarge,
    T? dark,
    T? open,
    T? hover,
    T? focused,
    T? focusWithin,
    T? disabled,
    T? pressed,
    T? groupHover,
    Map<String, T> groupHovers = const {},
    Map<num, T> container = const {},
  }) => withVariants(
    Adaptive<T>(
      this as T,
      medium: medium,
      expanded: expanded,
      large: large,
      extraLarge: extraLarge,
      dark: dark,
      open: open,
      hover: hover,
      focused: focused,
      focusWithin: focusWithin,
      disabled: disabled,
      pressed: pressed,
      groupHover: groupHover,
      groupHovers: groupHovers,
      container: container,
    ),
  );

  /// The same type carrying [variants] in its CSS (see [Adaptive]).
  T withVariants(Adaptive<T> variants);
}

/// An [Adaptable] value whose variants can also be written in its `const`
/// constructor (named parameters), so a value that changes per breakpoint
/// or state is still a constant expression:
///
/// ```dart
/// const FlexLayout(medium: FlexLayout(direction: Axis.horizontal))
/// // same CSS as: const FlexLayout().when(medium: FlexLayout(direction: Axis.horizontal))
/// ```
///
/// `.when()` is a method call, so its result is never `const` and drops
/// the `const` of everything around it. The subclass forwards the
/// variants with `super.medium`… and calls [adaptive] to build the CSS
/// (the values it holds are the base, the variants the named ones).
abstract class ConstAdaptable<T extends Object> with Adaptable<T> {
  /// The variants given to the constructor; none means a plain value.
  const ConstAdaptable({
    this.medium,
    this.expanded,
    this.large,
    this.extraLarge,
    this.dark,
    this.open,
    this.hover,
    this.focused,
    this.focusWithin,
    this.disabled,
    this.pressed,
    this.groupHover,
    this.groupHovers = const {},
    this.container = const {},
  });

  /// From `WindowSizeClass.medium` up; see [Adaptable.when].
  final T? medium;

  /// From `WindowSizeClass.expanded` up.
  final T? expanded;

  /// From `WindowSizeClass.large` up.
  final T? large;

  /// From `WindowSizeClass.extraLarge` up.
  final T? extraLarge;

  /// While the dark theme is on.
  final T? dark;

  /// While the nearest `<details>` around the element is open.
  final T? open;

  /// While the pointer is over the element.
  final T? hover;

  /// While the element has keyboard focus.
  final T? focused;

  /// While the element or something inside it has focus.
  final T? focusWithin;

  /// While the control is disabled.
  final T? disabled;

  /// While the element is pressed.
  final T? pressed;

  /// While the nearest `HoverGroup` is hovered.
  final T? groupHover;

  /// While the nearest `HoverGroup` of each name is hovered.
  final Map<String, T> groupHovers;

  /// From each width (px) of the nearest `LayoutScope` up.
  final Map<num, T> container;

  /// The variants of this value (itself the base), or null for a plain one.
  /// A value made with `.when()` overrides it with its own.
  Adaptive<T>? get adaptive =>
      medium == null &&
          expanded == null &&
          large == null &&
          extraLarge == null &&
          dark == null &&
          open == null &&
          hover == null &&
          focused == null &&
          focusWithin == null &&
          disabled == null &&
          pressed == null &&
          groupHover == null &&
          groupHovers.isEmpty &&
          container.isEmpty
      ? null
      : Adaptive<T>(
          this as T,
          medium: medium,
          expanded: expanded,
          large: large,
          extraLarge: extraLarge,
          dark: dark,
          open: open,
          hover: hover,
          focused: focused,
          focusWithin: focusWithin,
          disabled: disabled,
          pressed: pressed,
          groupHover: groupHover,
          groupHovers: groupHovers,
          container: container,
        );
}

/// A value that changes from breakpoints up (mobile-first), the shared core
/// of [Adaptable.when].
///
/// ```dart
/// Container(padding: const EdgeInsets.all(96).when(medium: EdgeInsets.all(128)))
/// ```
///
/// The widget's CSS carries the variants and thor compiles them into
/// `@media` rules of the same class: no wrapper, no extra class, same CSS as
/// `Responsive(medium: StyleProps(...))`.
class Adaptive<T> {
  /// [base] below the first breakpoint, each variant from its breakpoint up.
  const Adaptive(
    this.base, {
    this.medium,
    this.expanded,
    this.large,
    this.extraLarge,
    this.dark,
    this.open,
    this.hover,
    this.focused,
    this.focusWithin,
    this.disabled,
    this.pressed,
    this.groupHover,
    this.groupHovers = const {},
    this.container = const {},
  });

  /// The value below the first given breakpoint.
  final T base;

  /// From `WindowSizeClass.medium` up (600 by default).
  final T? medium;

  /// From `WindowSizeClass.expanded` up (840 by default).
  final T? expanded;

  /// From `WindowSizeClass.large` up (1200 by default).
  final T? large;

  /// From `WindowSizeClass.extraLarge` up (1600 by default).
  final T? extraLarge;

  /// While the dark theme is on (system preference or the theme switch).
  final T? dark;

  /// While the nearest `<details>` around the element is open (an
  /// `ExpansionTile`, open or closed: its header and its content). A
  /// `<details>` nested in it is its own: what is inside follows that one.
  final T? open;

  /// While the pointer is over the element.
  final T? hover;

  /// While the element has keyboard focus.
  final T? focused;

  /// While the element or something inside it has focus (`:focus-within`:
  /// a field's box around its input).
  final T? focusWithin;

  /// While the control is disabled (`:disabled`).
  final T? disabled;

  /// While the element is pressed.
  final T? pressed;

  /// While the pointer is over the nearest `HoverGroup`.
  final T? groupHover;

  /// While the pointer is over the nearest `HoverGroup` of each name.
  final Map<String, T> groupHovers;

  /// From each width (px) of the nearest `LayoutScope` up.
  final Map<num, T> container;

  /// The same variants with [f] applied to the base and to every variant:
  /// what an operation on a value built with `.when()` (arithmetic,
  /// `copyWith`, `merge`) does, so it does not drop the variants.
  Adaptive<R> map<R>(R Function(T value) f) {
    R? one(T? v) => v == null ? null : f(v);
    return Adaptive<R>(
      f(base),
      medium: one(medium),
      expanded: one(expanded),
      large: one(large),
      extraLarge: one(extraLarge),
      dark: one(dark),
      hover: one(hover),
      focused: one(focused),
      focusWithin: one(focusWithin),
      disabled: one(disabled),
      pressed: one(pressed),
      groupHover: one(groupHover),
      groupHovers: {for (final e in groupHovers.entries) e.key: f(e.value)},
      container: {for (final e in container.entries) e.key: f(e.value)},
    );
  }

  /// [f] applied to this and [other] together: the base with the base, each
  /// variant with the other's variant of the same name, or with the other's
  /// base where it has none (and the same the other way round).
  Adaptive<R> zip<U, R>(Adaptive<U> other, R Function(T a, U b) f) {
    R? one(T? a, U? b) =>
        a == null && b == null ? null : f(a ?? base, b ?? other.base);
    Map<K, R> both<K>(Map<K, T> a, Map<K, U> b) => {
      for (final k in {...a.keys, ...b.keys})
        k: f(a[k] ?? base, b[k] ?? other.base),
    };
    return Adaptive<R>(
      f(base, other.base),
      medium: one(medium, other.medium),
      expanded: one(expanded, other.expanded),
      large: one(large, other.large),
      extraLarge: one(extraLarge, other.extraLarge),
      dark: one(dark, other.dark),
      hover: one(hover, other.hover),
      focused: one(focused, other.focused),
      focusWithin: one(focusWithin, other.focusWithin),
      disabled: one(disabled, other.disabled),
      pressed: one(pressed, other.pressed),
      groupHover: one(groupHover, other.groupHover),
      groupHovers: both(groupHovers, other.groupHovers),
      container: both(container, other.container),
    );
  }

  /// The given variants by name (widths in cascade order, then states).
  Map<String, T> get variants => {
    'medium': ?medium,
    'expanded': ?expanded,
    'large': ?large,
    'extraLarge': ?extraLarge,
    'dark': ?dark,
    'open': ?open,
    'hover': ?hover,
    'focused': ?focused,
    'focus-within': ?focusWithin,
    'disabled': ?disabled,
    'pressed': ?pressed,
    'group-hover': ?groupHover,
    for (final e in groupHovers.entries)
      '$groupHoverKeyPrefix${e.key}': e.value,
    for (final e in container.entries) containerKeyOf(e.key): e.value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Adaptive<T> &&
          other.base == base &&
          mapsEqual(other.variants, variants);

  @override
  int get hashCode => Object.hash(base, hashMap(variants));

  /// One CSS value, marked with its variants when any differs.
  String css(String Function(T value) toCss) {
    final b = toCss(base);
    final v = _changed(b, {
      for (final e in variants.entries) e.key: toCss(e.value),
    });
    return v.isEmpty ? b : markAdaptive(b, v);
  }

  /// A declaration map whose values carry the variants of each property.
  ///
  /// A variant that leaves out a property the base or another variant sets
  /// takes its [resets] value (`max-width: none`), so it can undo a bound
  /// instead of keeping it.
  CssDeclarations declarations(
    CssDeclarations Function(T value) toCss, {
    Map<String, String> resets = const {},
  }) {
    final b = toCss(base);
    final vs = {for (final e in variants.entries) e.key: toCss(e.value)};
    final keys = {...b.keys, for (final m in vs.values) ...m.keys};
    // A state applies over the breakpoint that is on, so it only resets a
    // property no breakpoint sets (it would undo that breakpoint's value).
    bool widthSets(String k) => vs.entries.any(
      (e) => !_isStateVariant(e.key) && e.value.containsKey(k),
    );
    return {
      for (final k in keys)
        k: _markOne(b[k], {
          for (final e in vs.entries)
            e.key:
                ?(e.value[k] ??
                (_isStateVariant(e.key) &&
                        (compoundOf(e.key) != null || widthSets(k))
                    ? null
                    : resets[k])),
        }),
    };
  }

  static bool _isStateVariant(String k) =>
      isStateKey(k) || compoundOf(k) != null;

  static String _markOne(String? base, Map<String, String> v) {
    // A property only the variants set: no base declaration (the widget's
    // own default stays below them).
    final b = base ?? '';
    final changed = _changed(b, v);
    return changed.isEmpty ? b : markAdaptive(b, changed);
  }

  /// The variants that change the value that would apply without them.
  /// Breakpoints cascade mobile-first, so one that goes back to the base
  /// after another changed it is a change (`lg` = base under `md` = other
  /// keeps its rule); a state applies over whatever breakpoint is on, so it
  /// stays when a breakpoint changed the value, even if it equals the base.
  static Map<String, String> _changed(String b, Map<String, String> flat) {
    final v = _flatten(flat);
    bool isState(String k) => isStateKey(k) || compoundOf(k) != null;
    final widthChanged = v.entries.any((e) => !isState(e.key) && e.value != b);
    final out = <String, String>{};
    var prev = b;
    final containers = <String>[
      for (final k in v.keys)
        if (containerWidthOf(k) != null) k,
    ]..sort((a, c) => containerWidthOf(a)!.compareTo(containerWidthOf(c)!));
    for (final e in v.entries) {
      final k = e.key;
      if (compoundOf(k) != null) {
        // A state's own variant: the state applies over what it changes.
        out[k] = e.value;
      } else if (isState(k)) {
        if (e.value != b || widthChanged) out[k] = e.value;
      } else if (containerWidthOf(k) != null) {
        final i = containers.indexOf(k);
        final before = i == 0 ? b : v[containers[i - 1]]!;
        if (e.value != before || widthChanged) out[k] = e.value;
      } else {
        if (e.value != prev) out[k] = e.value;
        prev = e.value;
      }
    }
    return out;
  }
}

// A variant whose own value carries variants (`hover: white.when(medium: gray)`,
// `medium: white.when(hover: gray)`) becomes its base under its own key plus one
// compound key per inner variant (`md+hover`). Markers do not nest; a state
// in a state, or a breakpoint in a breakpoint, keeps the base.
Map<String, String> _flatten(Map<String, String> variants) {
  if (!variants.values.any(isAdaptive)) return variants;
  final out = <String, String>{};
  for (final e in variants.entries) {
    final k = e.key, value = e.value;
    out[k] = resolveAdaptive(value, null);
    if (!isAdaptive(value)) continue;
    final state = isStateKey(k);
    for (final inner in _definedKeys(value)) {
      if (state && isWidthKey(inner)) {
        out[compoundKey(inner, k)] = resolveAdaptive(value, inner);
      } else if (!state && isWidthKey(k) && isStateKey(inner)) {
        out[compoundKey(k, inner)] = resolveAdaptive(value, inner);
      }
    }
  }
  return out;
}

Set<String> _definedKeys(String value) => {
  for (final m in _marker.allMatches(value))
    for (final part in m[1]!.split(_alt).skip(1)) part.split(_kv).first,
};

/// [base] marked with per-breakpoint [variants] (see [Adaptive]).
String markAdaptive(String base, Map<String, String> variants) =>
    '$_open$base${[for (final e in variants.entries) '$_alt${e.key}$_kv${e.value}'].join()}$_close';

/// Whether [value] carries breakpoint variants.
bool isAdaptive(String value) => value.contains(_open);

final _marker = RegExp('$_open([^$_close]*)$_close');

/// Splits declarations that carry variants into the base declarations and
/// the declarations each breakpoint or state changes (keys of
/// [adaptiveBreakpoints] and [adaptiveStates]). Mobile-first: a breakpoint
/// without its own value keeps the nearest smaller one; a state changes only
/// what it sets.
({CssDeclarations base, Map<String, CssDeclarations> byBreakpoint})
splitAdaptive(CssDeclarations css) {
  if (!css.values.any(isAdaptive)) return (base: css, byBreakpoint: const {});
  final base = <String, String>{};
  final by = <String, CssDeclarations>{};
  for (final e in css.entries) {
    if (!isAdaptive(e.value)) {
      base[e.key] = e.value;
      continue;
    }
    final b = resolveAdaptive(e.value, null);
    if (b.isNotEmpty) base[e.key] = b;
    final defined = _definedKeys(e.value);
    final containers = defined.map(containerWidthOf).whereType<num>().toList()
      ..sort();
    // Named groups, then the compounds (width and state together) last, the
    // narrowest width first: they must beat the plain rules they refine.
    final named = [
      for (final k in defined)
        if (k.startsWith(groupHoverKeyPrefix)) k,
    ]..sort();
    final compounds = [
      for (final k in defined)
        if (compoundOf(k) != null) k,
    ]..sort(compareCompoundKeys);
    for (final bp in [
      ...adaptiveBreakpoints,
      for (final w in containers) containerKeyOf(w),
      ...adaptiveStates,
      ...named,
      ...compounds,
    ]) {
      if (defined.contains(bp)) {
        (by[bp] ??= {})[e.key] = resolveAdaptive(e.value, bp);
      }
    }
  }
  return (base: base, byBreakpoint: by);
}

num _widthRank(String width) {
  final i = adaptiveBreakpoints.indexOf(width);
  return i >= 0 ? i : 100 + (containerWidthOf(width) ?? 0);
}

/// Orders compound keys: narrowest width first, then by state.
int compareCompoundKeys(String a, String b) {
  final (wa, sa) = compoundOf(a)!;
  final (wb, sb) = compoundOf(b)!;
  final byWidth = _widthRank(wa).compareTo(_widthRank(wb));
  if (byWidth != 0) return byWidth;
  final ia = adaptiveStates.indexOf(sa), ib = adaptiveStates.indexOf(sb);
  return ia != ib ? ia.compareTo(ib) : sa.compareTo(sb);
}

/// [value] with every marker resolved at breakpoint [bp] (null: the base).
String resolveAdaptive(String value, String? bp) {
  if (!isAdaptive(value)) return value;
  final width = bp == null ? null : containerWidthOf(bp);
  return value.replaceAllMapped(_marker, (m) {
    final parts = m[1]!.split(_alt);
    var out = parts.first;
    final v = {
      for (final p in parts.skip(1)) p.split(_kv).first: p.split(_kv).last,
    };
    final upTo = bp == null
        ? const <String>[]
        : isStateKey(bp) || compoundOf(bp) != null
        ? [bp]
        : width != null
        // Container widths cascade among themselves, smallest first.
        ? ([
            for (final k in v.keys)
              if (containerWidthOf(k) case final w? when w <= width) w,
          ]..sort()).map(containerKeyOf).toList()
        : adaptiveBreakpoints.sublist(0, adaptiveBreakpoints.indexOf(bp) + 1);
    for (final b in upTo) {
      out = v[b] ?? out;
    }
    return out;
  });
}

/// [over] layered on [under]: a property whose variants have no base of
/// their own (a partial variant, `FlexLayout().when(medium: …)`) takes
/// [under]'s value as its base, so the widget's own value stays below the
/// variants instead of being dropped.
CssDeclarations mergeAdaptive(CssDeclarations under, CssDeclarations over) {
  if (over.isEmpty) return under;
  return {
    ...under,
    for (final e in over.entries)
      e.key: under[e.key] != null && e.value.startsWith(_openAlt)
          ? _layerVariants(under[e.key]!, e.value)
          : e.value,
  };
}

final _wholeMarker = RegExp('^$_open([^$_close]*)$_close\$');

// [over], a marker with no base of its own, over [under]: [under] is its
// base. When [under] carries variants itself (a parent's rule per direction
// below a wrapper's own variant of the same property), the two merge into
// one marker where [over] wins per key: markers do not nest, a marker inside
// a marker would leak into the CSS.
String _layerVariants(String under, String over) {
  if (!isAdaptive(under)) return '$_open$under${over.substring(1)}';
  final inner = _wholeMarker.firstMatch(under);
  final outer = _wholeMarker.firstMatch(over);
  if (inner == null || outer == null) {
    // Several markers in one value (a shorthand): only the base of [under]
    // can sit below [over].
    return '$_open${resolveAdaptive(under, null)}${over.substring(1)}';
  }
  final variants = <String, String>{};
  for (final part in [
    ...inner[1]!.split(_alt).skip(1),
    ...outer[1]!.split(_alt).skip(1),
  ]) {
    final kv = part.split(_kv);
    variants[kv.first] = kv.last;
  }
  return markAdaptive(inner[1]!.split(_alt).first, variants);
}
