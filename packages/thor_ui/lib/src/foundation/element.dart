import 'package:thor_engine/thor_engine.dart'
    show
        ThorState,
        attributesAttr,
        decodeOn,
        dragSourceAttr,
        dragTargetAttr,
        encodeOn,
        fieldAttr,
        listAttr,
        onAttr,
        parseBindingId,
        rowAttributesAttr,
        rowVariantAttr,
        textAttr,
        variantAttr;
import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../core/framework.dart' show wrapKeepsTag;
import 'bound_lengths.dart' show boundLengthAttributes;
import 'child_rules.dart';
import 'errors.dart';
import 'parent_data.dart'
    show RowWrapWith, WrapData, mergeAttributes, splitNestedAttributes;
import 'row_bind.dart' show bindRowMarkers;
import 'style_registry.dart';

/// Builds a thor DOM element.
///
/// Every thor widget ends in one of these (or in a [Widget.wrapElement]),
/// so the output is plain HTML.
///
/// The element's styles are its own [css] plus what its parent grants its
/// children ([ChildRules], resolved with [fillsWidth]/[fillsHeight]). Inside
/// a [ThorApp] they become **one** deduplicated class; without one they are
/// inlined (and [conditions] go into a scoped `<style>`). [childRules] is
/// what this element grants its own children.
///
/// [baseCss] holds resets (lowest priority). [classes] is only for app classes (e.g. from `Styled`): structural
/// behavior never needs a class.
Widget thorElement(
  String tag, {
  Key? key,
  String? id,
  List<String> classes = const [],
  CssDeclarations baseCss = const {},
  CssDeclarations css = const {},
  List<ConditionalCss> conditions = const [],
  ThorLayer layer = ThorLayer.props,
  bool fillsWidth = false,
  bool fillsHeight = false,
  ChildRules childRules = ChildRules.none,
  String? debugName,
  Map<String, String>? attributes,
  List<Widget> children = const [],
}) {
  final spec = _ThorElement(
    tag: tag,
    id: id,
    classes: classes,
    baseCss: baseCss,
    css: css,
    conditions: conditions,
    layer: layer,
    fillsWidth: fillsWidth,
    fillsHeight: fillsHeight,
    childRules: childRules,
    debugName: debugName,
    attributes: attributes,
    children: children,
  );
  // The element is its children's rules scope: one framework element (plus the
  // DOM one) per node.
  return ChildRulesScope.element(
    key: key,
    rules: childRules,
    render: spec.render,
  );
}

bool _isGrid(String? display) => display == 'grid' || display == 'inline-grid';

/// Elements a wrapper's tag can't replace: they are nested in it instead.
const _keepsTag = wrapKeepsTag;

class _ThorElement {
  const _ThorElement({
    required this.tag,
    this.id,
    required this.classes,
    required this.baseCss,
    required this.css,
    required this.conditions,
    required this.layer,
    required this.fillsWidth,
    required this.fillsHeight,
    required this.childRules,
    this.debugName,
    this.attributes,
    required this.children,
  });

  final String tag;
  final String? id;
  final List<String> classes;

  /// Resets (UA margins, button chrome): lowest priority, so they never
  /// override the layout a parent grants.
  final CssDeclarations baseCss;
  final CssDeclarations css;
  final List<ConditionalCss> conditions;
  final ThorLayer layer;
  final bool fillsWidth;
  final bool fillsHeight;
  final ChildRules childRules;
  final String? debugName;
  final Map<String, String>? attributes;
  final List<Widget> children;

  Widget render(BuildContext context, ChildRulesScope? scope) {
    final parent = scope?.rules;
    // Data of the wrappers directly around this element (Expanded, a folded
    // margin, Opacity…): compiled into the same class instead of a second one.
    final wrap = scope?.pending;
    // A wrapper's tag replaces a container's (`Link` makes a Text's span an
    // `<a>`); an element that can't change tag (an icon's svg, an image, a
    // control) keeps its own and is nested in the wrapper's tag instead.
    final nestIn = wrap?.tag != null && _keepsTag.contains(tag)
        ? wrap!.tag
        : null;
    final resolvedTag = nestIn != null ? tag : (wrap?.tag ?? tag);
    final fillsW =
        !(wrap?.fixesWidth ?? false) &&
        (fillsWidth || (wrap?.fillsWidth ?? false));
    final fillsH = fillsHeight || (wrap?.fillsHeight ?? false);
    // Priority: resets < what the parent grants < the element's own props <
    // its wrappers (Flutter parent data wins).
    // A filling child that caps its own width (`maxWidth: 1180`) is sized to
    // min(max, available) and still positioned by an aligning parent; with
    // a fixed horizontal margin too, where the parent positions it without
    // auto margins (a centered Column, a Center) and the width is `100%`.
    final capsW =
        fillsW &&
        (parent?.fillMaxWidth.isNotEmpty ?? false) &&
        ChildRules.capsWidth(
          margins:
              parent!.fillMaxWidth['width'] == '100%' &&
              !parent.positionsWithMargins,
          [
            css,
            if (wrap != null) ...[wrap.css, wrap.classCss],
          ],
          [
            for (final c in conditions) c.css,
            if (wrap != null)
              for (final c in wrap.conditions) c.css,
          ],
        );
    final granted = parent?.forChild(
      fillsWidth: fillsW,
      fillsHeight: fillsH,
      capsWidth: capsW,
    );
    // A flex item frees its parent's main axis only (Row: min-width).
    final flexible = wrap != null && wrap.flexible
        ? parent?.flexible ?? const <String, String>{}
        : const <String, String>{};
    // The class is a pure function of these inputs: computed once per
    // distinct inputs in the process (merges, dark-mode and breakpoint
    // variants), then shared by every element and request that has them.
    final style =
        knownElementStyle(
          layer: layer,
          capsWidth: capsW,
          baseCss: baseCss,
          wrapBaseCss: wrap?.baseCss ?? const {},
          granted: granted ?? const {},
          css: css,
          flexible: flexible,
          wrapClassCss: wrap?.classCss ?? const {},
          wrapCss: wrap?.css ?? const {},
          conditions: conditions,
          wrapConditions: wrap?.conditions ?? const [],
        ) ??
        newElementStyle(
          layer,
          _computeStyle(wrap, granted, flexible, capsWidth: capsW),
        );
    final own = style.css;
    final allConditions = style.conditions;

    final registry = ThorStyleRegistry.active(context);
    final debug = kDebugMode && registry != null;
    // Inside an element with descendant rules (`Styled(descendants:)`),
    // thor elements are where those rules stop.
    final boundary =
        registry != null &&
        context
                .getElementForInheritedWidgetOfExactType<
                  DescendantRulesScope
                >() !=
            null;
    if (boundary) registry.dependsOnPlace();

    // Children see *this* element as their scope (its rules, no pending
    // data), so rules and wrapper data never leak to grandchildren.
    var kids = registry != null && allConditions.any((c) => c.when.isDescendant)
        ? [DescendantRulesScope(child: Widget.fragment(children))]
        : children;
    // web: a Row or Column turned into a grid (`Styled(style:
    // StyleProps(display: Display.grid))`) places its children with the
    // grid's `align-items`; the `align-self: stretch` a flex parent grants
    // to a child that fills the cross axis would override it.
    if (_isGrid(own['display']) && childRules.growsAcross) {
      kids = [
        ChildRulesScope(rules: childRules.inGrid, child: Widget.fragment(kids)),
      ];
    }

    // `row.bind(…)` values (a `semanticLabel:` in a list row) become the
    // row's bound attributes here, wherever they came from.
    // Around an element that keeps its tag (`<a><img>`), the attributes
    // the element owns (`src`, `alt`…) are its; the rest stay on the tag.
    final (nestedTag, nestedChild) = nestIn != null
        ? splitNestedAttributes(wrap!.attributes)
        : (const <String, String>{}, const <String, String>{});
    final wrapAttrs = nestIn != null
        ? nestedChild
        : (wrap?.attributes ?? const <String, String>{});
    final withWrap = mergeAttributes(wrapAttrs, attributes ?? const {});
    // web: a button the wrapper wires natively (`MenuAnchor`'s anchor,
    // `DialogTrigger`, `DialogClose`: `popovertarget` / `commandfor`) has its
    // action: the browser runs it with no handler, so a missing `onPressed`
    // must not leave it `disabled` (Flutter code needs `onPressed: () {}`
    // there only to enable the button). A `disabled` the wrapper itself sets
    // (`DialogTrigger(enabled: false)`) is on purpose and stays.
    // web: the browser only runs `commandfor` on a button. Around anything
    // else (a tappable card) the element is announced and focusable like
    // one, and the lite engine carries the command (`aria-disabled` stands
    // in for `disabled`, which a div ignores).
    final commandOnBox =
        nestIn == null &&
        wrap != null &&
        wrap.attributes.containsKey('commandfor') &&
        resolvedTag != 'button' &&
        resolvedTag != 'input';
    final merged = bindRowMarkers(
      commandOnBox
          ? {
              for (final e in withWrap.entries)
                if (e.key != 'disabled') e.key: e.value,
              if (!withWrap.containsKey('role')) 'role': 'button',
              if (!withWrap.containsKey('tabindex'))
                'tabindex': withWrap.containsKey('disabled') ? '-1' : '0',
              if (withWrap.containsKey('disabled')) 'aria-disabled': 'true',
            }
          : wrap != null &&
                withWrap.containsKey('disabled') &&
                !wrap.attributes.containsKey('disabled') &&
                (wrap.attributes.containsKey('popovertarget') ||
                    wrap.attributes.containsKey('commandfor'))
          ? {
              for (final e in withWrap.entries)
                if (e.key != 'disabled') e.key: e.value,
            }
          : withWrap,
    );
    // A `BoundLength` the class reads: its binding and first value go on
    // this element, wherever the value came from.
    final bound = style.boundLengths;
    final rowReads = style.rowLengths;
    final withRow = rowReads.isEmpty
        ? merged
        : mergeAttributes(merged, _rowLengthAttributes(context, rowReads));
    final withBound = bound.isEmpty
        ? withRow
        : mergeAttributes(withRow, boundLengthAttributes(bound));
    // Shared, never modified: the node only reads it.
    final attrs = debug || boundary
        ? {
            ...withBound,
            if (debug) ...?wrap?.debugAttributes,
            // Widget names for DevTools and the debug inspector (debug
            // only, and only with ThorApp, which ships the inspector).
            if (debug && debugName != null) 'data-thor': debugName!,
            if (boundary) descendantBoundaryAttr: '',
          }
        : withBound;
    final allClasses = wrap == null || wrap.classes.isEmpty
        ? classes
        : [...wrap.classes, ...classes];

    if (registry != null) {
      useEngineStates(registry, attrs);
      // Debug builds name the class after the app component it belongs to
      // (`t-product-card`, `t-product-card__row`): readable in DevTools.
      // Release keeps the content hash.
      final named = kDebugMode && !style.isEmpty
          ? _componentClass(context)
          : null;
      final generated = named == null
          ? classForElementStyle(registry, style)
          : registry.classFor(
              own,
              conditions: elementClassConditions(style),
              layer: layer,
              named: named,
            );
      // The rules on the elements inside: one class shared by every
      // variant of this element's own values.
      final inside = style.inside;
      final insideClass = inside == null
          ? null
          : named == null
          ? classForElementStyle(registry, inside)
          : registry.classFor(
              const {},
              conditions: inside.conditions,
              layer: layer,
              named: '${named}__inside',
            );
      final elementClasses = [...allClasses, ?generated, ?insideClass];
      if (kDebugMode) {
        // Only what thor itself puts here: a wrapper's classes are the
        // app's, and a debug class name can equal one of them (the
        // component `ArticleMeta` and the app's `article-meta`). The
        // inside class styles other elements only: it can't compete with
        // the element's own class, whatever their order.
        registry.debugCheckOneClassPerLayer([
          ...classes,
          ?generated,
        ], resolvedTag);
      }
      if (nestIn != null) useEngineStates(registry, nestedTag);
      return _nest(
        nestIn,
        wrap,
        nestedTag,
        _dom(resolvedTag, elementClasses, null, attrs, kids),
        registry: registry,
      );
    }

    if (kDebugMode) warnWithoutThorApp(attrs);

    // Fallback: inline styles, plus a scoped <style> for conditions. The
    // properties conditions change go into that class too: an inline value
    // would beat the media query / state rule.
    if (allConditions.isEmpty) {
      return _nest(
        nestIn,
        wrap,
        nestedTag,
        _dom(
          resolvedTag,
          allClasses,
          own.isEmpty ? null : Styles(raw: own.sanitized),
          attrs,
          kids,
        ),
      );
    }
    final conditional = {for (final c in allConditions) ...c.css.keys};
    final inline = {
      for (final e in own.entries)
        if (!conditional.contains(e.key)) e.key: e.value,
    };
    final local = ThorStyleRegistry.local(
      {
        for (final e in own.entries)
          if (conditional.contains(e.key)) e.key: e.value,
      },
      conditions: allConditions,
      layer: layer,
    );
    return Widget.fragment([
      Widget.element(tag: 'style', children: [RawText(local.rules)]),
      _nest(
        nestIn,
        wrap,
        nestedTag,
        _dom(
          resolvedTag,
          [...allClasses, local.className],
          inline.isEmpty ? null : Styles(raw: inline.sanitized),
          attrs,
          kids,
        ),
      ),
    ]);
  }

  /// The declarations and conditions of the class of this element under
  /// [wrap] with what its parent [granted]: what the element style memo
  /// keeps for these inputs.
  (CssDeclarations, List<ConditionalCss>) _computeStyle(
    WrapData? wrap,
    CssDeclarations? granted,
    CssDeclarations flexible, {
    required bool capsWidth,
  }) {
    // Most elements have no wrapper: no maps built for what isn't there.
    final under = wrap == null
        ? (granted == null || granted.isEmpty
              ? baseCss
              : (baseCss.isEmpty ? granted : {...baseCss, ...granted}))
        : {...baseCss, ...wrap.baseCss, ...?granted};
    var combined = mergeCss(
      mergeCss(under, css),
      wrap == null
          ? const <String, String>{}
          : mergeCss({
              ...flexible,
              ...wrap.classCss,
            }, ChildRules.constraintsInside(wrap.css, css)),
    );
    // A wrapper's `transform` (`Transform.rotate`) nests around the
    // element's own (`Container(transform:)`), it does not replace it.
    if (wrap != null) {
      final composed = composeTransforms(wrap.css, css);
      if (composed != null) combined = {...combined, ...composed};
    }
    // web: a `Padding` folded into a bare element (a `Text`) sits inside the
    // size a wrapper gives it (`ConstrainedBox`, `SizedBox`), but CSS adds
    // the padding to the content box: `border-box` brings it back inside.
    if (wrap != null &&
        !combined.containsKey('box-sizing') &&
        _hasPadding(combined) &&
        _hasSize(combined)) {
      combined = {...combined, 'box-sizing': 'border-box'};
    }
    // A vertical-only margin must not reset the parent's auto margins.
    // A fixed horizontal margin comes out of its `width: 100%`.
    final merged = capsWidth
        ? ChildRules.widthInsideMargins(
            ChildRules.splitVerticalMargin(combined),
          )
        : combined;
    // Values with breakpoint variants (`EdgeInsets.all(8).from(md: …)`)
    // become breakpoint conditions of this same class.
    return expandAdaptive(
      merged,
      wrap == null || wrap.conditions.isEmpty
          ? conditions
          : [...conditions, ...wrap.conditions],
    );
  }

  /// The class name after the nearest app component above (a
  /// [ThorElementWidget] that isn't one of thor's own): its first element is
  /// `t-product-card`, the ones inside `t-product-card__row`, `__chip`…
  ///
  /// The `t-` prefix keeps it apart from the app's own class names: an app
  /// that writes `cls('article-meta')` next to a component `ArticleMeta`
  /// would otherwise get thor's rule on every element with its class.
  String? _componentClass(BuildContext context) {
    String? component;
    var root = true;
    context.visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is ChildRulesScope && widget.isElement) {
        root = false; // another element between: this one is inside.
      } else if (widget is ThorElementWidget && widget is! ThorBuiltIn) {
        component = 't-${_kebab(widget.runtimeType.toString())}';
        return false;
      }
      return true;
    });
    if (component == null) return null;
    return root ? component : '${component}__${_kebab(debugName ?? tag)}';
  }

  /// [element] inside a [tag] carrying the wrapper's attributes (see
  /// `_keepsTag`), laid out like the element alone.
  static Widget _nest(
    String? tag,
    WrapData? wrap,
    Map<String, String> tagAttributes,
    Widget element, {
    ThorStyleRegistry? registry,
  }) {
    if (tag == null) return element;
    // The wrapper's own defaults (a link's color reset) belong to it.
    final css = {'display': 'inline-flex', ...wrap!.baseCss};
    return Widget.element(
      tag: tag,
      classes: registry == null
          ? null
          : wrap.floorCss.isEmpty
          ? registry.classFor(css)
          : '${registry.classFor(css)} '
                '${registry.classFor(wrap.floorCss, layer: ThorLayer.base)}',
      styles: registry == null ? Styles(raw: css) : null,
      attributes: bindRowMarkers(tagAttributes),
      children: [element],
    );
  }

  Widget _dom(
    String tag,
    List<String> classes,
    Styles? styles,
    Map<String, String> attrs,
    List<Widget> kids,
  ) {
    // Without a style registry the element's styles are inline: a `style`
    // attribute (a bound variable's first value) joins them, so the element
    // never gets two.
    final extra = attrs['style'];
    if (styles != null && extra != null) {
      attrs = {...attrs}..remove('style');
      styles = Styles(
        raw: {
          ...styles.properties,
          for (final part in extra.split(';'))
            if (part.contains(':'))
              part.substring(0, part.indexOf(':')).trim(): part
                  .substring(part.indexOf(':') + 1)
                  .trim(),
        },
      );
    }
    return Widget.element(
      tag: tag,
      id: id,
      // One or two classes, most elements: no buffer for the join.
      classes: switch (classes.length) {
        0 => null,
        1 => classes[0],
        2 => '${classes[0]} ${classes[1]}',
        _ => classes.join(' '),
      },
      styles: styles,
      attributes: attrs.isEmpty ? null : attrs,
      children: kids,
    );
  }
}

/// Records the `ThorState`s whose members [attrs] reference (engine
/// markers), so `ThorApp` ships the engine script and their values.
void useEngineStates(ThorStyleRegistry registry, Map<String, String> attrs) {
  // Most elements carry no engine marker.
  if (attrs.isEmpty) return;
  void use(String id) {
    final member = parseBindingId(id).$1;
    final dot = member.lastIndexOf('.');
    if (dot < 0) return;
    final prefix = member.substring(0, dot);
    for (final s in ThorState.all) {
      if (s.idPrefix == prefix) registry.useState(s);
    }
  }

  for (final a in const [
    textAttr,
    variantAttr,
    listAttr,
    fieldAttr,
    rowVariantAttr,
  ]) {
    if (attrs[a] case final id?) use(id);
  }
  for (final a in const [
    onAttr,
    rowAttributesAttr,
    attributesAttr,
    dragSourceAttr,
    dragTargetAttr,
  ]) {
    if (attrs[a] case final ids?) decodeOn(ids).values.forEach(use);
  }
}

var _warnedWithoutThorApp = false;

/// A ThorState used on a page without `ThorApp`: nothing would ship the
/// engine script, so the page would stay static. Said once, in debug.
void warnWithoutThorApp(Map<String, String> attrs) {
  if (_warnedWithoutThorApp) return;
  final engine = const [
    textAttr,
    variantAttr,
    listAttr,
    onAttr,
  ].any((a) => attrs[a]?.contains('.') ?? false);
  if (!engine) return;
  _warnedWithoutThorApp = true;
  // ignore: avoid_print
  print(
    thorError(
      'THOR-S006',
      '[thor] This page uses a ThorState but has no ThorApp: wrap the page in '
          'ThorApp(child: …) so the engine script and the state ship with it.',
    ),
  );
}

// A `RowLength` or `RowColor` (`--tr-…`) is bound by the element that reads it: its binding
// and first value come from the nearest enclosing row that made the length
// (`row.length` may run in a row component's `build`, after the row's own
// attributes were fixed). THOR-S042 when no enclosing row made it, which would
// leave the variable with no value and the layout broken in silence.
Map<String, String> _rowLengthAttributes(
  BuildContext context,
  List<String> names,
) {
  final found = <String, ({String id, String first})>{};
  // Only the nearest row: the browser updates an element's bindings from the
  // list of the row it sits in, so an outer row's length read inside an
  // inner row would be computed from the inner list's items.
  context.visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is! RowWrapWith) return true;
    for (final n in names) {
      if (widget.lengths[n] case final l?) found[n] = l;
    }
    return false;
  });
  final missing = [
    for (final n in names)
      if (!found.containsKey(n)) n,
  ];
  if (missing.isNotEmpty) {
    throw StateError(
      thorError(
        'THOR-S042',
        'An element reads ${missing.join(', ')}, a row.length or row.color that '
            'its row did not make. Read it inside its own row: in the `each` '
            'of the Watch.list that made it, or in a widget it builds (not '
            'inside a nested list\'s row).',
      ),
    );
  }
  final style = [
    for (final e in found.entries)
      if (e.value.first.isNotEmpty) '${e.key}:${e.value.first}',
  ].join(';');
  return {
    rowAttributesAttr: encodeOn({
      for (final e in found.entries) e.key: e.value.id,
    }),
    if (style.isNotEmpty) 'style': style,
  };
}

/// `FilledButton` → `filled-button` (type arguments dropped).
String _kebab(String name) => name
    .split('<')
    .first
    .replaceAllMapped(RegExp('([a-z0-9])([A-Z])'), (m) => '${m[1]}-${m[2]}')
    .toLowerCase();

bool _hasPadding(CssDeclarations css) =>
    css.keys.any((k) => k == 'padding' || k.startsWith('padding-'));

bool _hasSize(CssDeclarations css) => css.keys.any(
  (k) => switch (k) {
    'width' ||
    'height' ||
    'min-width' ||
    'max-width' ||
    'min-height' ||
    'max-height' => css[k] != '0',
    _ => false,
  },
);
