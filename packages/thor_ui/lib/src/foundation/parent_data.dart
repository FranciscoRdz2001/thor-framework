import 'package:thor_engine/thor_engine.dart'
    show
        actionsAttr,
        animationAttr,
        attributesAttr,
        decodeOn,
        encodeOn,
        intentShortcutsAttr,
        onAttr,
        rowAttributesAttr,
        shortcutsAttr,
        variablesAttr;
import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../core/framework.dart' show wrapKeepsTag;
import 'child_rules.dart';
import 'dialog_scope.dart' show DialogScope;
import 'element.dart' show thorElement, useEngineStates, warnWithoutThorApp;
import 'errors.dart';
import 'style_registry.dart';
import 'transparent.dart';

/// [merged] with the `transform` of [outer] and [inner] composed instead of
/// the inner one replacing the outer (`Transform.rotate` around a
/// `Transform.scale` or a `Container(transform:)`).
CssDeclarations _composeTransform(
  CssDeclarations outer,
  CssDeclarations inner,
  CssDeclarations merged,
) {
  final composed = composeTransforms(outer, inner);
  return composed == null ? merged : {...merged, ...composed};
}

/// What a wrapper contributes to its child's DOM element.
class WrapData {
  /// Creates a wrapper's contribution to its child's element.
  const WrapData({
    this.classes = const [],
    this.baseCss = const {},
    this.css = const {},
    this.classCss = const {},
    this.conditions = const [],
    this.attributes = const {},
    this.fillsWidth = false,
    this.fixesWidth = false,
    this.fillsHeight = false,
    this.debugAttributes = const {},
    this.tag,
    this.flexible = false,
    this.viewTransitionName,
    this.closesDialog = false,
  });

  /// The element's `view-transition-name` (a `Hero`'s): one per page, so it
  /// goes in the element's `style`, never in its shared class. The
  /// outermost wrapper claims it on the page before applying it.
  final String? viewTransitionName;

  /// The wrapper closes the nearest dialog above it (`DialogClose()`
  /// without an id): the chain gets its `commandfor` from the dialog's
  /// scope when it is built, where the context is known.
  final bool closesDialog;

  /// A flex item (`Expanded`, `Flexible`): it gets its parent's
  /// [ChildRules.flexible] (the main axis may shrink below the content).
  final bool flexible;

  /// Extra classes added to the element.
  final List<String> classes;

  /// Replaces the tag of the wrapped thor element (e.g. `main` for a
  /// Scaffold body), so a landmark needs no extra node. Only honored by
  /// [ThorElementWidget]s; meant for sectioning tags, not interactive ones.
  final String? tag;

  /// The wrapped element should take the max width/height: resolved against
  /// the *parent's* `ChildRules` (e.g. a SizedBox(width: inf) merged into its
  /// child).
  final bool fillsWidth;

  /// The wrapper sets the element's width itself (a fraction, a fixed
  /// size), so the element no longer takes the max width even if it would
  /// alone: its parent positions it like any sized child (centered by a
  /// `Center`).
  final bool fixesWidth;

  /// Same as [fillsWidth], for height.
  final bool fillsHeight;

  /// Emitted only in debug builds with ThorApp (inspector / DevTools).
  final Map<String, String> debugAttributes;

  /// Defaults *under* the element's own props (a link's `color: inherit`
  /// must not beat a `Text`'s color), like an element's reset styles. On
  /// a non-thor child they apply with the wrapper's other declarations.
  final CssDeclarations baseCss;

  /// Declarations that win over the element's own props, like Flutter
  /// parent data wins over the child's preferences (`Positioned(width:)`).
  final CssDeclarations css;

  /// Same priority as [css], but [conditions] (media queries, states) may
  /// change them.
  final CssDeclarations classCss;

  /// Extra [ConditionalCss] rules to attach to the generated class.
  final List<ConditionalCss> conditions;

  /// Extra HTML attributes to set on the element.
  final Map<String, String> attributes;

  /// Merges an [inner] wrapper into this (outer) one. Inner values win on
  /// conflicts because they are closer to the element; handlers for the same
  /// event are chained instead of replaced. [baseCss] is the exception: the
  /// outer one wins, since an inner default is a reset (a heading's
  /// `font-size: inherit` under `Semantics(headingLevel:)`) and an outer one
  /// is a component's text style for its slot (an `AlertDialog` title).
  WrapData merge(WrapData inner) => WrapData(
    classes: [...classes, ...inner.classes],
    baseCss: mergeCss(inner.baseCss, baseCss),
    css: _composeTransform(
      css,
      inner.css,
      mergeCss(ChildRules.constraintsInside(css, inner.css), inner.css),
    ),
    classCss: mergeCss(classCss, inner.classCss),
    conditions: [
      ...conditions,
      for (final c in inner.conditions)
        if (!conditions.any(
          (o) =>
              o.when.toString() == c.when.toString() &&
              o.css.inline == c.css.inline,
        ))
          c,
    ],
    attributes: mergeAttributes(attributes, inner.attributes),
    fillsWidth: fillsWidth || inner.fillsWidth,
    fixesWidth: fixesWidth || inner.fixesWidth,
    fillsHeight: fillsHeight || inner.fillsHeight,
    debugAttributes: kDebugMode
        ? {...debugAttributes, ...inner.debugAttributes}
        : const {},
    tag: inner.tag ?? tag,
    flexible: flexible || inner.flexible,
    viewTransitionName: inner.viewTransitionName ?? viewTransitionName,
    closesDialog: closesDialog || inner.closesDialog,
  );

  /// This data with the `commandfor` of the nearest dialog above [context]
  /// when [closesDialog] (a build error when there is none: the button
  /// would silently do nothing).
  WrapData _withNearestDialog(BuildContext context) {
    if (!closesDialog) return this;
    final id = DialogScope.maybeOf(context);
    if (id == null) {
      throw StateError(
        'DialogClose() without an id must be inside a dialog '
        '(AlertDialog, Dialog, Drawer, ModalBottomSheet…): there is none '
        'above it. Pass id: to close another one.',
      );
    }
    return WrapData(
      classes: classes,
      baseCss: baseCss,
      css: css,
      classCss: classCss,
      conditions: conditions,
      attributes: {...attributes, 'commandfor': id},
      fillsWidth: fillsWidth,
      fixesWidth: fixesWidth,
      fillsHeight: fillsHeight,
      debugAttributes: debugAttributes,
      tag: tag,
      flexible: flexible,
      viewTransitionName: viewTransitionName,
    );
  }

  /// This data with [viewTransitionName] claimed on the page of [context]
  /// and moved into the `style` attribute (dropped when another element of
  /// the page has it: THOR-R019 in debug).
  WrapData _withViewTransitionName(BuildContext context) {
    final name = viewTransitionName;
    if (name == null) return this;
    final registry = ThorStyleRegistry.active(context);
    final claimed = registry?.claimViewTransitionName(name) ?? true;
    if (!claimed && kDebugMode) {
      throw StateError(
        thorError(
          'THOR-R019',
          'two Hero widgets on this page have the name "$name": a view '
              'transition needs one element per name (the browser would '
              'skip it)',
        ),
      );
    }
    final style = attributes['style'];
    return WrapData(
      classes: classes,
      baseCss: baseCss,
      css: css,
      classCss: classCss,
      conditions: conditions,
      attributes: claimed
          ? {
              ...attributes,
              'style': [
                if (style != null && style.isNotEmpty) style,
                'view-transition-name:$name',
              ].join(';'),
            }
          : attributes,
      fillsWidth: fillsWidth,
      fixesWidth: fixesWidth,
      fillsHeight: fillsHeight,
      debugAttributes: debugAttributes,
      tag: tag,
      flexible: flexible,
    );
  }
}

/// Flutter's `ParentDataWidget` / "proxy" widgets on the web.
///
/// Widgets like `Expanded`, `Positioned`, `Opacity` or `Gesture` do not
/// create a DOM node: they decorate their child's element (flex item props,
/// absolute offsets, events…). Around a [ThorElementWidget] the data is
/// compiled into that element's own class; around any other component it
/// goes through [Widget.wrapElement]. Directly nested wrappers are
/// flattened into one.
abstract class ParentDataWrapper extends StatelessWidget {
  /// Wraps [child], decorating its element instead of creating a new one.
  const ParentDataWrapper({super.key, required this.child});

  /// The wrapped widget.
  final Widget child;

  /// The contribution of this wrapper to the child element.
  WrapData get wrapData;

  /// Registers what this wrapper's CSS needs besides classes (`@property`
  /// rules, keyframes) in the page's [registry], when it is built.
  @protected
  void registerStyles(ThorStyleRegistry registry) {}

  /// The contribution of this wrapper once it is built in [context]: the
  /// same as [wrapData] unless it needs the page (an id the page names).
  /// A wrapper that comes with markup of its own (a `DialogTrigger`'s
  /// dialog) adds it to [after]: it is rendered right after the element.
  @protected
  WrapData wrapDataIn(BuildContext context, List<Widget> after) => wrapData;

  /// Whether this wrapper renders markup of its own next to the element
  /// (see [wrapDataIn]), so the whole draws more than one root.
  @internal
  bool get addsSiblings => false;

  /// Whether this wrapper publishes something to its descendants (see
  /// [scoped]). It is then built on its own, not flattened into the wrapper
  /// above it.
  @internal
  bool get opensScope => false;

  /// [built] inside what this wrapper publishes to its descendants (only
  /// when [opensScope]).
  @internal
  Widget scoped(BuildContext context, Widget built) => built;

  @override
  @nonVirtual
  Widget build(BuildContext context) {
    final after = <Widget>[];
    final built = scoped(context, _build(context, after));
    return after.isEmpty ? built : Widget.fragment([built, ...after]);
  }

  Widget _build(BuildContext context, List<Widget> after) {
    var data = wrapDataIn(context, after);
    var target = child;
    final styles = ThorStyleRegistry.active(context);
    if (styles != null) registerStyles(styles);
    final scope = ChildRulesScope.maybeOf(context);
    final outer = scope?.pending;
    while (target is ParentDataWrapper && !target.opensScope) {
      final next = target.wrapDataIn(context, after);
      if (styles != null) target.registerStyles(styles);
      // `Semantics(role: listItem, child: Link(…))`: both want the tag of
      // one element; the link's element keeps its own inside the item's.
      if (_nests(data.tag, next.tag)) {
        return _nestIn(
          context,
          scope,
          outer == null ? data : outer.merge(data),
          target,
        );
      }
      data = data.merge(next);
      target = target.child;
    }
    // The same with the item's wrapper above an app component
    // whose root is the link.
    if (outer != null && _nests(outer.tag, data.tag)) {
      return _nestIn(context, scope, outer, WrapWith(data, child: target));
    }
    if (outer != null) data = outer.merge(data);
    // A Hero in the chain: claimed once for the whole chain, here.
    data = data._withNearestDialog(context)._withViewTransitionName(context);

    // A thor element below (also through app components): it
    // compiles the data into its own single class.
    if (target is ThorElementWidget || resolvesToElement(target)) {
      return ChildRulesScope(rules: scope?.rules, pending: data, child: target);
    }

    // Any other component: decorate its element with Widget.wrapElement.
    // With a registry, even plain wrapper declarations go into a class in the
    // overrides layer: it still beats the child's props (Flutter parent data
    // wins), repeated wrappers share one rule, and app CSS can override it.
    final registry = ThorStyleRegistry.active(context);
    final parent = scope?.rules;
    final fill =
        parent == null ||
            !(data.fillsWidth || data.fillsHeight || data.flexible)
        ? const <String, String>{}
        : {
            if (data.fillsWidth) ...parent.fillWidth,
            if (data.fillsHeight) ...parent.fillHeight,
            if (data.flexible) ...parent.flexible,
          };
    if (registry != null) {
      // web: the wrapper's engine attributes (a Gesture's `data-t-on`, a
      // Watch.list's `data-tl`) land on an element thorElement never sees;
      // its states must still make the page ship the engine.
      useEngineStates(registry, data.attributes);
      final (classCss, conditions) = expandAdaptive({
        ...data.baseCss,
        ...fill,
        ...data.css,
        ...data.classCss,
      }, data.conditions);
      data = WrapData(
        tag: data.tag,
        classes: data.classes,
        classCss: classCss,
        conditions: conditions,
        attributes: {
          ...data.attributes,
          if (kDebugMode) ...data.debugAttributes,
        },
      );
    } else {
      if (kDebugMode) warnWithoutThorApp(data.attributes);
      // No ThorApp: wrapElement merges wrapper styles *under* the child's own, key
      // by key (the child wins), and the child's inline resets / parent rules
      // would replace them. A scoped rule with `!important` beats inline
      // normal declarations, so Flutter parent data still wins.
      final (classCss, conditions) = expandAdaptive({
        ...data.baseCss,
        ...fill,
        ...data.css,
        ...data.classCss,
      }, data.conditions);
      data = WrapData(
        tag: data.tag,
        classes: data.classes,
        classCss: {
          for (final e in classCss.entries) e.key: '${e.value} !important',
        },
        conditions: [
          for (final c in conditions)
            ConditionalCss(c.when, {
              for (final e in c.css.entries) e.key: '${e.value} !important',
            }),
        ],
        attributes: data.attributes,
      );
    }
    String? generated;
    String? localRules;
    if (data.classCss.isNotEmpty || data.conditions.isNotEmpty) {
      if (registry != null) {
        generated = registry.classFor(
          data.classCss,
          conditions: data.conditions,
          layer: ThorLayer.overrides,
        );
      } else {
        // No ThorApp: scope the rules with a local <style>.
        final local = ThorStyleRegistry.local(
          data.classCss,
          conditions: data.conditions,
          layer: ThorLayer.overrides,
        );
        generated = local.className;
        localRules = local.rules;
      }
    }

    final classes = [...data.classes, ?generated];
    Widget wrapped = Widget.wrapElement(
      tag: data.tag,
      classes: classes.isEmpty ? null : classes.join(' '),
      attributes: data.attributes.isEmpty ? null : data.attributes,
      child: target,
    );
    // The data was applied here: descendants must not consume it again.
    if (outer != null) {
      wrapped = ChildRulesScope(rules: scope?.rules, child: wrapped);
    }
    if (localRules == null) return wrapped;
    return Widget.fragment([
      Widget.element(tag: 'style', children: [RawText(localRules)]),
      wrapped,
    ]);
  }
}

/// Anonymous [ParentDataWrapper], used internally.
class WrapWith extends ParentDataWrapper {
  /// Wraps `child` with a fixed [wrapData].
  const WrapWith(this.wrapData, {super.key, required super.child});

  @override
  final WrapData wrapData;
}

/// The row wrapper of a `Watch.list`: a [WrapWith] that also holds the row's
/// `row.length` and `row.color` bindings (name → binding id and first value,
/// as the CSS the variable takes; empty: none). `row.length`
/// can be called in a row component's `build`, after the row's attributes
/// are fixed, so the element that reads the length looks for the nearest
/// enclosing row and binds the variable on itself.
class RowWrapWith extends WrapWith {
  /// Wraps `child` with [wrapData] for a row whose lengths are [lengths]
  /// (filled by `row.length`, until the row is built).
  const RowWrapWith(
    super.wrapData,
    this.lengths, {
    super.key,
    required super.child,
  });

  /// The row's `row.length` and `row.color` bindings by variable name.
  final Map<String, ({String id, String first})> lengths;
}

/// [outer] then [inner] attributes (inner wins), except the engine's event
/// map, which combines both (`AnimatedScale(onEnd:)` around a button with
/// `onPressed`), the explicit animations' tracks (both play), and
/// attributes bound to state values (`row.attribute`, `WatchAttributes`):
/// the binding owns them, so its value wins over the other side's, and a
/// binding without a value (an unsafe URL) removes the other side's.
Map<String, String> mergeAttributes(
  Map<String, String> outer,
  Map<String, String> inner,
) {
  // One side alone merges to itself (most elements have no wrapper): no
  // copy. Callers never modify the result.
  if (outer.isEmpty) return inner;
  if (inner.isEmpty) return outer;
  // One element, one id: a wrapper's `Semantics(identifier:)` over a child
  // that has another one would drop one of them silently, and an in-page
  // link (`#a`) would stop landing anywhere.
  final outerId = outer['id'], innerId = inner['id'];
  if (outerId != null && innerId != null && outerId != innerId) {
    throw ArgumentError(
      thorError(
        'THOR-R022',
        'one element gets two ids, `$outerId` and `$innerId` (a '
            '`Semantics(identifier:)` over a child that has its own): keep '
            'one, or give the other to a different element',
      ),
    );
  }
  final a = outer[onAttr], b = inner[onAttr];
  final merged = {...outer, ...inner};
  if (a != null && b != null) {
    merged[onAttr] = encodeOn({...decodeOn(a), ...decodeOn(b)});
  }
  // Explicit animations: every transition keeps its track (outer first, so
  // the innermost plays on top).
  final x = outer[animationAttr], y = inner[animationAttr];
  if (x != null && y != null) {
    merged[animationAttr] = '${x.substring(0, x.length - 1)},${y.substring(1)}';
  }
  // Shortcuts, actions, bound variables and their first values: both
  // wrappers keep theirs (inner first: its shortcuts and actions are tried
  // first).
  for (final attr in const [
    shortcutsAttr,
    intentShortcutsAttr,
    actionsAttr,
    variablesAttr,
    rowAttributesAttr,
    attributesAttr,
    'style',
  ]) {
    final o = outer[attr], i = inner[attr];
    if (o != null && i != null && o != i) merged[attr] = '$i;$o';
  }
  for (final side in [outer, inner]) {
    for (final attr in const [rowAttributesAttr, attributesAttr]) {
      final bound = side[attr];
      if (bound == null) continue;
      for (final name in decodeOn(bound).keys) {
        final v = side[name];
        v == null ? merged.remove(name) : merged[name] = v;
      }
    }
  }
  return merged;
}

/// Whether a wrapper's [outer] tag and an [inner] one it wraps make two
/// elements, the inner one inside (`<li><a>`), instead of the innermost
/// tag winning: the inner element is a link or a button (they keep their
/// tag, like an element's own) and the outer one is not interactive; or
/// the outer one is a link around a heading (`<a><h3>`), which would
/// otherwise be an `<h3 href>` that links nowhere.
bool _nests(String? outer, String? inner) =>
    outer != null &&
    inner != null &&
    outer != inner &&
    (((inner == 'a' || inner == 'button') && !wrapKeepsTag.contains(outer)) ||
        (outer == 'a' && _headings.contains(inner)));

const _headings = {'h1', 'h2', 'h3', 'h4', 'h5', 'h6'};

/// An element with [data] (its tag, classes, attributes: the outer
/// wrappers') around [inner].
Widget _nestIn(
  BuildContext context,
  ChildRulesScope? scope,
  WrapData data,
  Widget inner,
) => ChildRulesScope(
  rules: scope?.rules,
  pending: data._withViewTransitionName(context),
  child: thorElement('div', children: [inner]),
);

/// What a media element owns: it is never valid on the tag that nests
/// around it (`<a src>`), so a wrapper's value for it is the child's.
const _childOwned = {
  'src',
  'srcset',
  'sizes',
  'alt',
  'width',
  'height',
  'loading',
  'decoding',
  'fetchpriority',
  'crossorigin',
  'poster',
  'controls',
  'autoplay',
  'loop',
  'muted',
  'playsinline',
  'preload',
};

/// Splits the `attributes` of a wrapper whose `tag` nests around an element
/// that keeps its own (`<a><img></a>`): what the element owns (`src`, `alt`,
/// `width`… and the row bindings of those names) goes to it, the rest (the
/// link's `href`, events, `aria-*`, ids) stays on the tag.
///
/// An attribute aimed at a child element must not migrate to an ancestor:
/// `row.attribute(AttributeName.src, …, child: Image(…))` inside a `Link` would
/// otherwise leave the `<img>` with `src=""`.
(Map<String, String> tag, Map<String, String> child) splitNestedAttributes(
  Map<String, String> attributes,
) {
  if (!attributes.keys.any(_childOwned.contains) &&
      !attributes.containsKey(rowAttributesAttr) &&
      !attributes.containsKey(attributesAttr)) {
    return (attributes, const {});
  }
  final tag = <String, String>{}, child = <String, String>{};
  for (final MapEntry(:key, :value) in attributes.entries) {
    if (_childOwned.contains(key)) {
      child[key] = value;
    } else if (key == rowAttributesAttr || key == attributesAttr) {
      // Bindings name their attribute: one map per element.
      final own = <String, String>{}, other = <String, String>{};
      for (final b in decodeOn(value).entries) {
        (_childOwned.contains(b.key) ? other : own)[b.key] = b.value;
      }
      if (own.isNotEmpty) tag[key] = encodeOn(own);
      if (other.isNotEmpty) child[key] = encodeOn(other);
    } else {
      tag[key] = value;
    }
  }
  return (tag, child);
}
