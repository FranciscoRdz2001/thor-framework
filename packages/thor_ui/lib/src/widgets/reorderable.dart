import 'package:thor_engine/thor_engine.dart'
    show
        Animation,
        argAttr,
        listTemplateAttr,
        itemKeyAttr,
        listAttr,
        listKeyAttr,
        listVirtualAttr,
        reorderAttr,
        reorderDragAttr,
        reorderHandleAttr,
        reorderItemAttr,
        reorderLabelsAttr,
        reorderSetupAttr,
        reorderSettleAttr,
        reorderShiftAttr,
        reorderVarX,
        reorderVarY;
import 'package:thor_style/thor_style.dart';

import '../core/core.dart' show BuildContext, StatelessWidget, Widget;
import '../core/framework.dart' show isElementWith, mapElementChildren;
import '../engine/watch.dart' show gestureAttributes;
import '../foundation/child_rules.dart'
    show ChildRules, ChildRulesScope, ThorBuiltIn, ThorElementWidget;
import '../foundation/element.dart' show thorElement;
import '../foundation/errors.dart' show thorError;
import '../foundation/material_localizations.dart'
    show ThorLocalizations, ThorLocalizationsEn;
import '../foundation/parent_data.dart'
    show ParentDataWrapper, WrapData, WrapWith;
import '../foundation/responsive.dart' show StyleProps;
import '../foundation/style_registry.dart'
    show ConditionalCss, CssCondition, ThorStyleRegistry;
import '../foundation/theme_tokens.dart';
import 'basic.dart' show buttonResetCss;
import 'flex.dart' show flexCss;
import 'icon.dart' show Icon;
import 'icons.dart' show Icons;
import 'native_control.dart';
import 'scroll.dart' show IndexedWidgetBuilder, ScrollPhysics;

/// The words a [ReorderableListView] says to assistive technology (a live
/// region). `{item}` is the item's name (its text), `{position}` its place
/// and `{count}` how many there are.
///
/// What you leave out is the page's language: `ThorLocalizations`
/// (`reorderPickedUp`…).
class ReorderLabels {
  /// The texts; what is null comes from `ThorLocalizations`.
  const ReorderLabels({
    this.handle,
    this.pickedUp,
    this.moved,
    this.dropped,
    this.cancelled,
  });

  /// The name of the drag handle (`aria-label`): the engine adds the item's
  /// name where `{item}` is when the handle is focused.
  final String? handle;

  /// Said when the keyboard picks an item up.
  final String? pickedUp;

  /// Said when an arrow key moves the picked-up item.
  final String? moved;

  /// Said when it is dropped (or moved with Alt+arrow).
  final String? dropped;

  /// Said when Escape puts it back.
  final String? cancelled;

  List<String> _words(ThorLocalizations l) => [
    pickedUp ?? l.reorderPickedUp,
    moved ?? l.reorderMoved,
    dropped ?? l.reorderDropped,
    cancelled ?? l.reorderCancelled,
    handle ?? l.reorderHandleLabel,
  ];

  /// What the engine reads (the page's `data-t-ro-say`) with [l10n]'s
  /// texts under these, or null for the English ones it has built in.
  String? attributeFor(ThorLocalizations l10n) {
    final mine = _words(l10n);
    final english = const ReorderLabels()._words(const ThorLocalizationsEn());
    for (var i = 0; i < mine.length; i++) {
      if (mine[i] != english[i]) return mine.join('\n');
    }
    return null;
  }

  /// The handle's name before the engine adds the item's.
  String handleNameFor(ThorLocalizations l10n) =>
      (handle ?? l10n.reorderHandleLabel).replaceAll('{item}', '').trim();
}

/// Flutter's `ReorderCallback`: where an item came from and where it goes.
/// [newIndex] counts the list before the item leaves, as in Flutter: moving
/// down, subtract one.
typedef ReorderCallback = void Function(int oldIndex, int newIndex);

/// Flutter's `ReorderItemProxyDecorator`. Not supported (see
/// [ReorderableListView.draggingStyle]).
typedef ReorderItemProxyDecorator =
    Widget Function(Widget child, int index, Animation<double> animation);

// The key of a row of a `Watch.list`, written on it by the list.
bool _isKeyedRow(Widget c) =>
    c is WrapWith && c.wrapData.attributes.containsKey(itemKeyAttr);

/// Flutter's `ReorderableListView`: a list whose items are reordered by
/// dragging.
///
/// ```dart
/// ReorderableListView(
///   onReorder: todo.reorder,        // void reorder(int oldIndex, int newIndex)
///   children: [for (final t in tasks) TaskTile(key: ValueKey(t.id), task: t)],
/// )
///
/// // A list the browser changes (rows are cloned from a template):
/// Watch.list(
///   todo.items,
///   itemKey: todo.keyOf,
///   container: (rows) => ReorderableListView(onReorder: todo.reorder, children: rows),
///   each: (row) => TaskTile(task: row),
/// )
/// ```
///
/// Each item gets a handle (a button with an icon, `buildDefaultDragHandles`)
/// and a finger held on the item drags it (a touch); the mouse drags by the
/// handle, or by a [ReorderableDragStartListener] you place. The dragged item
/// follows the pointer through a CSS `translate` and the others slide out of
/// the way with CSS transitions (no Dart per frame); the page scrolls when the
/// pointer is near its edge. On release the engine moves the item in the page
/// and calls [onReorder] (a method of a `ThorState`) with the indexes as Flutter
/// gives them: over a `Watch.list` the list finds its rows already in order.
///
/// Keyboard (WCAG 2.5.7 and 2.1.1: a drag needs another way): the handle is a
/// button. Space or Enter picks the item up, the arrow keys move it, Space or
/// Enter drops it (that calls [onReorder]), Escape puts it back; Alt+arrow
/// anywhere in an item moves it one place at once. A live region says each step
/// ([labels] changes the words).
///
/// `// web:` Flutter's `proxyDecorator` has no equivalent ([draggingStyle]
/// is the dragged item's look); the per-frame callbacks and
/// `autoScrollerVelocityScalar` neither. One item is dragged at a time. Without
/// JavaScript the list is only its items. A state that does not apply a
/// reorder leaves the item where it was dropped until the list changes again.
class ReorderableListView extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// A list of [children] (each one with a key in Flutter) reordered by
  /// dragging; [onReorder] hears the change.
  const ReorderableListView({
    super.key,
    required List<Widget> this.children,
    required this.onReorder,
    this.onReorderStart,
    this.onReorderEnd,
    this.proxyDecorator,
    this.buildDefaultDragHandles = true,
    this.padding,
    this.header,
    this.footer,
    this.scrollDirection = Axis.vertical,
    this.shrinkWrap = false,
    this.physics,
    this.labels = const ReorderLabels(),
    this.draggingStyle,
  }) : itemBuilder = null,
       itemCount = null;

  /// A list of [itemCount] items built by [itemBuilder].
  const ReorderableListView.builder({
    super.key,
    required IndexedWidgetBuilder this.itemBuilder,
    required int this.itemCount,
    required this.onReorder,
    this.onReorderStart,
    this.onReorderEnd,
    this.proxyDecorator,
    this.buildDefaultDragHandles = true,
    this.padding,
    this.header,
    this.footer,
    this.scrollDirection = Axis.vertical,
    this.shrinkWrap = false,
    this.physics,
    this.labels = const ReorderLabels(),
    this.draggingStyle,
  }) : children = null;

  /// The items.
  final List<Widget>? children;

  /// Builds item `index`, for [ReorderableListView.builder].
  final IndexedWidgetBuilder? itemBuilder;

  /// How many items [itemBuilder] builds.
  final int? itemCount;

  /// Called when an item is dropped in another place: its old index and the
  /// new one, counted as in Flutter (before the item leaves). A state method.
  final ReorderCallback onReorder;

  /// Called when an item is picked up, with its index. A state method.
  final void Function(int index)? onReorderStart;

  /// Called when the drag ends, with the item's index then. A state method.
  final void Function(int index)? onReorderEnd;

  /// Not supported: the dragged item's look is CSS ([draggingStyle]).
  final ReorderItemProxyDecorator? proxyDecorator;

  /// Whether each item gets a handle (and a held finger drags it).
  final bool buildDefaultDragHandles;

  /// Same as Flutter's `ReorderableListView.padding`.
  final EdgeInsetsGeometry? padding;

  /// A widget before the items (not one of them).
  final Widget? header;

  /// A widget after the items (not one of them).
  final Widget? footer;

  /// The axis the items are in.
  final Axis scrollDirection;

  /// Accepted so Flutter code compiles; changes nothing.
  // web: a list is a block in the page's flow, as tall as its items unless a
  // parent gives it a height.
  final bool shrinkWrap;

  /// Accepted so Flutter code compiles; changes nothing.
  // web: the browser owns scrolling.
  final ScrollPhysics? physics;

  /// The words said to assistive technology.
  final ReorderLabels labels;

  /// The dragged item's look (Flutter draws it with `proxyDecorator`):
  /// applied while it is dragged, over the default lift (a shadow).
  final StyleProps? draggingStyle;

  @override
  Widget build(BuildContext context) {
    if (proxyDecorator != null) {
      throw ArgumentError.value(
        'proxyDecorator',
        'ReorderableListView',
        thorError(
          'THOR-R040',
          'ReorderableListView: `proxyDecorator` has no equivalent in the '
              'browser (the dragged item is the item itself, moved by CSS). '
              'Use `draggingStyle: StyleProps(...)` for its look.',
        ),
      );
    }
    ThorStyleRegistry.active(context)?.useEngine();
    final l10n = ThorLocalizations.of(context);
    final registry = ThorStyleRegistry.active(context);
    for (final name in const [reorderVarX, reorderVarY]) {
      registry?.addProperty(
        name,
        "syntax:'<length>';inherits:false;initial-value:0px",
      );
    }
    final vertical = scrollDirection == Axis.vertical;
    final g = gestureAttributes({
      'reorder': onReorder,
      'start': onReorderStart,
      'end': onReorderEnd,
    }, attribute: reorderAttr);
    final built =
        children ??
        [for (var i = 0; i < itemCount!; i++) itemBuilder!(context, i)];
    Widget item(Widget child) => _ReorderItem(
      vertical: vertical,
      handle: buildDefaultDragHandles,
      handleName: labels.handleNameFor(l10n),
      draggingStyle: draggingStyle,
      child: child,
    );
    final items = [
      for (final c in built)
        // The row template of a `Watch.list` holds the item to clone: the
        // item is made inside it. A row keeps its key on the item.
        if (isElementWith(c, 'template', listTemplateAttr))
          mapElementChildren(c, item)!
        else if (c is WrapWith && _isKeyedRow(c))
          WrapWith(c.wrapData, key: c.key, child: item(c.child))
        else
          item(c),
    ];
    final rules = vertical ? ChildRules.column : ChildRules.row;
    final hasEnds = header != null || footer != null;
    // The mark of a `Watch.list` around it (`container:`) belongs to the
    // element that holds the rows: with a header or a footer, the list, not
    // the box around the three (without JavaScript the list is the list, and
    // lite, which binds a list only when its state wakes, finds it there).
    final scope = hasEnds ? ChildRulesScope.maybeOf(context) : null;
    final pending = scope?.pending;
    final marks = <String, String>{};
    WrapData? outerPending;
    if (scope != null && pending != null && !scope.isElement) {
      final rest = {...pending.attributes};
      for (final a in const [listAttr, listKeyAttr, listVirtualAttr]) {
        final v = rest.remove(a);
        if (v != null) marks[a] = v;
      }
      if (marks.isNotEmpty) {
        final p = pending;
        outerPending = WrapData(
          classes: p.classes,
          baseCss: p.baseCss,
          css: p.css,
          classCss: p.classCss,
          conditions: p.conditions,
          attributes: rest,
          fillsWidth: p.fillsWidth,
          fixesWidth: p.fixesWidth,
          fillsHeight: p.fillsHeight,
          debugAttributes: p.debugAttributes,
          tag: p.tag,
          flexible: p.flexible,
          viewTransitionName: p.viewTransitionName,
          closesDialog: p.closesDialog,
        );
      }
    }
    final list = thorElement(
      'div',
      debugName: 'ReorderableListView',
      fillsWidth: true,
      childRules: ChildRules(
        all: rules.all,
        fillWidth: rules.fillWidth,
        fillHeight: rules.fillHeight,
      ),
      // With a header or a footer the box around them scrolls and holds the
      // padding; the list is as long as its items.
      css: {
        ...flexCss(scrollDirection),
        if (!hasEnds) 'overflow': 'auto',
        'align-items': 'stretch',
        if (!hasEnds && !vertical) 'overflow-y': 'hidden',
        'position': 'relative',
        if (!hasEnds && padding != null) ...padding!.toCss('padding'),
        if (hasEnds) 'flex': '0 0 auto',
      },
      attributes: {
        'role': 'list',
        reorderAttr: g.attributes[reorderAttr] ?? '',
        argAttr: ?g.fixed,
        reorderSetupAttr:
            '${vertical ? 'v' : 'h'}|${buildDefaultDragHandles ? 1 : 0}',
        reorderLabelsAttr: ?labels.attributeFor(l10n),
        ...marks,
      },
      children: items,
    );
    if (!hasEnds) return list;
    // web: the header and the footer are siblings of the `role="list"`
    // element, not children of it: a list's only children are its items
    // (the engine's indexes count the items; assistive technology reads
    // "list, N items"). The box around the three scrolls, so they scroll
    // with the items as in Flutter, and the padding goes around all three
    // as Flutter splits it among them.
    final box = thorElement(
      'div',
      debugName: 'ReorderableListView ends',
      fillsWidth: true,
      childRules: ChildRules(
        all: rules.all,
        fillWidth: rules.fillWidth,
        fillHeight: rules.fillHeight,
      ),
      css: {
        ...flexCss(scrollDirection),
        'overflow': 'auto',
        'align-items': 'stretch',
        if (!vertical) 'overflow-y': 'hidden',
        if (padding != null) ...padding!.toCss('padding'),
      },
      children: [?header, list, ?footer],
    );
    return outerPending == null
        ? box
        : ChildRulesScope(
            rules: scope!.rules,
            pending: outerPending,
            child: box,
          );
  }
}

/// One item: its own box (the row of a `Watch.list`) with the child and, when
/// the list builds default handles, the handle.
class _ReorderItem extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  const _ReorderItem({
    required this.child,
    required this.vertical,
    required this.handle,
    required this.handleName,
    required this.draggingStyle,
  });

  final Widget child;
  final bool vertical;
  final bool handle;
  final String handleName;
  final StyleProps? draggingStyle;

  @override
  Widget build(BuildContext context) {
    final lift = <String, String>{
      'z-index': '1',
      'box-shadow': '0 6px 16px rgba(0, 0, 0, 0.28)',
      'cursor': 'grabbing',
      ...?draggingStyle?.toCss(),
    };
    return thorElement(
      'div',
      debugName: 'ReorderableListView item',
      css: {
        'position': 'relative',
        'translate': 'var($reorderVarX, 0px) var($reorderVarY, 0px)',
        // web: a finger held on the item drags it; until then the page scrolls.
        if (handle) 'touch-action': 'manipulation',
        '-webkit-touch-callout': 'none',
      },
      conditions: [
        const ConditionalCss(CssCondition.selector('[$reorderShiftAttr]'), {
          'transition': 'translate 200ms ease',
        }),
        const ConditionalCss(CssCondition.selector('[$reorderSettleAttr]'), {
          'transition': 'translate 200ms ease',
          'z-index': '1',
        }),
        ConditionalCss(const CssCondition.selector('[$reorderDragAttr]'), lift),
        const ConditionalCss(CssCondition.reducedMotion, {
          'transition-duration': '1ms',
        }),
      ],
      attributes: const {'role': 'listitem', reorderItemAttr: ''},
      children: [
        child,
        if (handle) _DefaultHandle(name: handleName, vertical: vertical),
      ],
    );
  }
}

/// The handle every item gets by default: a button at the end of the item.
class _DefaultHandle extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  const _DefaultHandle({required this.name, required this.vertical});

  final String name;
  final bool vertical;

  @override
  Widget build(BuildContext context) => thorElement(
    'button',
    debugName: 'ReorderableListView handle',
    baseCss: buttonResetCss,
    css: {
      'position': 'absolute',
      'display': 'flex',
      'align-items': 'center',
      'justify-content': 'center',
      'box-sizing': 'border-box',
      'width': '40px',
      'height': '40px',
      'inset-inline-end': '4px',
      if (vertical) ...{'top': '50%', 'margin-top': '-20px'} else 'top': '4px',
      'border-radius': '8px',
      'color': ThemeTokens.onSurfaceVariant,
      'cursor': 'grab',
      'touch-action': 'none',
    },
    conditions: const [
      ConditionalCss(CssCondition.hoverEnabled, {
        'background-color': 'rgba(0, 0, 0, 0.08)',
      }),
      ConditionalCss(CssCondition.focused, {
        'outline': '2px solid ${ThemeTokens.primary}',
        'outline-offset': '2px',
      }),
    ],
    attributes: {
      'type': 'button',
      reorderHandleAttr: '',
      'aria-label': name,
      'aria-roledescription': ThorLocalizations.of(
        context,
      ).reorderHandleRoleDescription,
      'aria-keyshortcuts': vertical
          ? 'Space Alt+ArrowUp Alt+ArrowDown'
          : 'Space Alt+ArrowLeft Alt+ArrowRight',
    },
    children: const [Icon(Icons.drag_handle)],
  );
}

/// Flutter's `ReorderableDragStartListener`: its child starts the drag of the
/// item it is in, at once. Place it where the handle should be, with
/// `buildDefaultDragHandles: false`.
///
/// `// web:` [index] is accepted and not used (the engine finds the item the
/// listener is in). The child is focusable and acts as a button for the keyboard
/// (Space picks the item up, arrows move it) unless it is a control already.
class ReorderableDragStartListener extends ParentDataWrapper {
  /// Makes [child] a drag handle.
  const ReorderableDragStartListener({
    super.key,
    required super.child,
    required this.index,
    this.enabled = true,
  });

  /// The item's index (not used: see the class).
  final int index;

  /// Whether the child starts a drag.
  final bool enabled;

  /// Whether the drag starts after a hold (`ReorderableDelayedDragStartListener`).
  bool get delayed => false;

  @override
  WrapData get wrapData {
    if (!enabled) return const WrapData();
    final native = childIsNativeControl(child);
    return WrapData(
      css: {
        'cursor': 'grab',
        'touch-action': delayed ? 'manipulation' : 'none',
      },
      attributes: {
        reorderHandleAttr: delayed ? 'delayed' : '',
        if (!native) ...{
          'tabindex': '0',
          'role': 'button',
          // web: a wrapper has no context for the page's language; the
          // default handle (`ReorderableListView`) is localized.
          'aria-roledescription': 'drag handle',
        },
      },
    );
  }
}

/// Flutter's `ReorderableDelayedDragStartListener`: its child starts the
/// drag after the pointer is held on it (a long press), so a touch can still
/// scroll the list.
class ReorderableDelayedDragStartListener extends ReorderableDragStartListener {
  /// Makes [child] a handle that waits for a hold.
  const ReorderableDelayedDragStartListener({
    super.key,
    required super.child,
    required super.index,
    super.enabled,
  });

  @override
  bool get delayed => true;
}
