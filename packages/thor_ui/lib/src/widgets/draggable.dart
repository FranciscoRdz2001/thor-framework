import 'dart:convert' show jsonEncode;

import 'package:thor_engine/thor_engine.dart'
    show
        argAttr,
        dragActiveAttr,
        dragDataAttr,
        dragFeedbackAttr,
        dragGhostAttr,
        dragGoneAttr,
        dragLabelsAttr,
        dragOverAttr,
        dragPlaceholderAttr,
        dragRejectAttr,
        dragSetupAttr,
        dragSourceAttr,
        dragTargetAttr,
        dragTypeAttr,
        dragVarX,
        dragVarY,
        encodeArg,
        textAttr,
        fieldAttr;
import 'package:thor_style/thor_style.dart';

import '../core/core.dart' show BuildContext, Element, StatelessWidget, Widget;
import '../core/framework.dart' show BuildChild, PageBuild, PageComponent;
import '../core/markup.dart';
import '../engine/watch.dart' show gestureAttributes;
import '../foundation/child_rules.dart'
    show ChildRules, ChildRulesScope, ThorBuiltIn, ThorElementWidget;
import '../foundation/errors.dart' show thorError;
import '../foundation/material_localizations.dart'
    show ThorLocalizations, ThorLocalizationsEn;
import '../foundation/parent_data.dart' show WrapData, WrapWith;
import '../foundation/responsive.dart' show StyleProps;
import '../foundation/style_registry.dart'
    show ConditionalCss, CssCondition, ThorStyleRegistry;
import 'native_control.dart';

/// Where the feedback of a [Draggable] starts relative to the pointer
/// (Flutter's `DragAnchorStrategy`). Only [childDragAnchorStrategy] and
/// [pointerDragAnchorStrategy] have an equivalent in the browser.
typedef DragAnchorStrategy =
    Offset Function(
      Draggable<Object> draggable,
      BuildContext context,
      Offset position,
    );

/// The feedback starts where the child is, and keeps its distance from the
/// pointer (Flutter's default).
Offset childDragAnchorStrategy(
  Draggable<Object> draggable,
  BuildContext context,
  Offset position,
) => Offset.zero;

/// The feedback's corner is at the pointer.
Offset pointerDragAnchorStrategy(
  Draggable<Object> draggable,
  BuildContext context,
  Offset position,
) => Offset.zero;

/// The words a [Draggable] says to assistive technology (a live region).
/// `{item}` and `{target}` stand for the draggable's and the drop target's
/// names (their `aria-label`, or their text).
///
/// What you leave out is the page's language: `ThorLocalizations`
/// (`dragPickedUp`…).
class DragLabels {
  /// The texts; what is null comes from `ThorLocalizations`.
  const DragLabels({
    this.roleDescription,
    this.pickedUp,
    this.over,
    this.cannotDrop,
    this.dropped,
    this.cancelled,
  });

  /// `aria-roledescription` of the draggable.
  final String? roleDescription;

  /// Said when the keyboard picks the draggable up.
  final String? pickedUp;

  /// Said when the keyboard moves to a target that takes it.
  final String? over;

  /// Said when the keyboard moves to a target that does not.
  final String? cannotDrop;

  /// Said when it is dropped.
  final String? dropped;

  /// Said when Escape cancels.
  final String? cancelled;

  List<String> _words(ThorLocalizations l) => [
    pickedUp ?? l.dragPickedUp,
    over ?? l.dragOver,
    cannotDrop ?? l.dragCannotDrop,
    dropped ?? l.dragDropped,
    cancelled ?? l.dragCancelled,
  ];

  /// The `aria-roledescription` of the draggable.
  String roleDescriptionFor(ThorLocalizations l10n) =>
      roleDescription ?? l10n.dragRoleDescription;

  /// What the engine reads (the page's `data-t-dg-say`) with [l10n]'s texts
  /// under these, or null for the English ones it has built in.
  String? attributeFor(ThorLocalizations l10n) {
    final mine = _words(l10n);
    final english = const DragLabels()._words(const ThorLocalizationsEn());
    for (var i = 0; i < mine.length; i++) {
      if (mine[i] != english[i]) return mine.join('\n');
    }
    return null;
  }
}

// The data of a draggable as the page writes it: text, a number, an enum's
// name, or JSON for a `Map` or a `List`.
String? _encodeData(Object? data) => data == null
    ? null
    : data is Map || data is List
    ? jsonEncode(data)
    : encodeArg(data);

String _decimal(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';

/// The feedback of a [Draggable] as the page ships it: `position: fixed`,
/// at the variables the engine moves (a CSS `translate`), ignoring the pointer.
class _Ghost extends StatelessWidget implements ThorBuiltIn {
  const _Ghost({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final registry = ThorStyleRegistry.active(context);
    for (final name in const [dragVarX, dragVarY]) {
      registry?.addProperty(
        name,
        "syntax:'<length>';inherits:false;initial-value:0px",
      );
    }
    return WrapWith(
      const WrapData(
        // web: the clone is a manual popover (the top layer, above a modal
        // dialog): what the browser's popover styles add is taken off.
        baseCss: {
          'margin': '0',
          'border': '0',
          'padding': '0',
          'overflow': 'visible',
          'background-color': 'transparent',
          'color': 'inherit',
          'width': 'max-content',
          'height': 'auto',
        },
        css: {
          'position': 'fixed',
          'inset': '0 auto auto 0',
          'z-index': '2147483647',
          'pointer-events': 'none',
          'translate': 'var($dragVarX, 0px) var($dragVarY, 0px)',
        },
        attributes: {dragGhostAttr: ''},
      ),
      child: child,
    );
  }
}

/// Builds [child] and the templates that go with it: the first element of
/// the child gets them as its last children (or, when it cannot hold them, the
/// fragment gets them right after it), so one element is the draggable
/// wherever it is used (a `Watch.list` row, a flex item).
final class _WithTemplates extends PageComponent {
  const _WithTemplates({required this.child, required this.templates});

  final Widget child;

  /// `<template [attribute]>` and what goes inside, in order.
  final List<(String, Widget)> templates;

  @override
  void buildInto(
    PageBuild page,
    Element element,
    ParentNode into,
    BuildChild build,
  ) {
    final live = FragmentNode();
    build(child, element, live);
    into.add(live);
    final made = <ElementNode>[];
    for (final (attribute, widget) in templates) {
      final inner = FragmentNode();
      build(widget, element, inner, bare: true);
      made.add(
        ElementNode('template', attributes: {attribute: ''})
          ..children.addAll(inner.children),
      );
    }
    final root = findElement(
      live,
      (n) => n.tag != 'style' && n.tag != 'script' && n.tag != 'template',
    )?.node;
    // A void element has no children, and a bound text would lose them
    // with its first update: the templates wait beside them.
    final holds =
        root != null &&
        !_void.contains(root.tag) &&
        !(root.attributes?.containsKey(textAttr) ?? false) &&
        !(root.attributes?.containsKey(fieldAttr) ?? false);
    if (holds) {
      root.children.addAll(made);
    } else {
      live.children.addAll(made);
    }
  }
}

const _void = {
  'area',
  'base',
  'br',
  'col',
  'embed',
  'hr',
  'img',
  'input',
  'link',
  'meta',
  'source',
  'track',
  'wbr',
  'svg',
};

/// Flutter's `Draggable`: a widget that can be dragged to a [DragTarget].
///
/// ```dart
/// Draggable<String>(
///   data: task.id,
///   feedback: TaskCard(task),
///   childWhenDragging: Opacity(opacity: 0.3, child: TaskCard(task)),
///   onDragCompleted: board.picked.withArg(task.id),
///   child: TaskCard(task),
/// )
/// ```
///
/// Pointer events (not the HTML5 drag-and-drop, which a finger cannot do): the
/// [feedback] is cloned from a `<template>` as a fixed element under the
/// pointer and moved with a CSS `translate` (no Dart per frame), the targets
/// under it are found by hit-testing and the page scrolls when the pointer is
/// near its edge. [data] reaches the target's state methods as text: a
/// `String`, a number, a `bool` or an enum value as itself, a `Map` or a `List`
/// as a JSON `String`. The callbacks are methods of a `ThorState`.
///
/// Keyboard (WCAG 2.5.7 and 2.1.1: a drag needs another way): the draggable
/// can be focused; Space or Enter picks it up, the arrow keys (and Tab) move
/// between the targets that fit it, Space or Enter drops it, Escape cancels.
/// A live region says each step ([labels] changes the words).
///
/// `// web:` the per-frame `onDragUpdate` and `rootOverlay`,
/// `ignoringFeedbackSemantics`, `dragAnchorStrategy`s of your own and
/// `maxSimultaneousDrags` beyond 1 have no equivalent: one drag runs at a
/// time. The feedback has `position: fixed` and no size of its own: give it
/// the one it should have. Without JavaScript nothing drags.
class Draggable<T extends Object> extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Makes [child] draggable; [feedback] is what follows the pointer.
  const Draggable({
    super.key,
    required this.child,
    required this.feedback,
    this.data,
    this.axis,
    this.childWhenDragging,
    this.feedbackOffset = Offset.zero,
    this.dragAnchorStrategy = childDragAnchorStrategy,
    this.maxSimultaneousDrags,
    this.onDragStarted,
    this.onDraggableCanceled,
    this.onDragEnd,
    this.onDragCompleted,
    this.labels = const DragLabels(),
  });

  /// The widget that is dragged.
  final Widget child;

  /// What follows the pointer.
  final Widget feedback;

  /// What a [DragTarget] receives.
  final T? data;

  /// Restricts the feedback to one axis.
  final Axis? axis;

  /// Shown instead of [child] while it is being dragged (the child stays
  /// as it is when null).
  final Widget? childWhenDragging;

  /// The feedback's offset from where the anchor puts it.
  final Offset feedbackOffset;

  /// [childDragAnchorStrategy] or [pointerDragAnchorStrategy].
  final DragAnchorStrategy dragAnchorStrategy;

  /// 0 turns the drag off; one drag runs at a time otherwise.
  final int? maxSimultaneousDrags;

  /// Called when the drag starts.
  final void Function()? onDragStarted;

  /// Called when the drag ends on nothing that takes it, with where the
  /// pointer was (the page's client coordinates).
  final void Function(double x, double y)? onDraggableCanceled;

  /// Called when the drag ends, with whether a target took it.
  final void Function(bool wasAccepted)? onDragEnd;

  /// Called when the drag ends on a target that took it.
  final void Function()? onDragCompleted;

  /// The words said to assistive technology.
  final DragLabels labels;

  /// How long the pointer must be held before the drag starts: nothing, or
  /// ([LongPressDraggable]) the delay.
  Duration get delay => Duration.zero;

  @override
  Widget build(BuildContext context) {
    if (maxSimultaneousDrags == 0) return child;
    final anchor = dragAnchorStrategy == pointerDragAnchorStrategy
        ? 'p'
        : dragAnchorStrategy == childDragAnchorStrategy
        ? 'c'
        : throw ArgumentError.value(
            dragAnchorStrategy,
            'dragAnchorStrategy',
            thorError(
              'THOR-R040',
              'Draggable: a dragAnchorStrategy of your own has no equivalent '
                  'in the browser. Use childDragAnchorStrategy (the feedback '
                  'keeps the child\'s place) or pointerDragAnchorStrategy '
                  '(its corner is at the pointer), and feedbackOffset.',
            ),
          );
    ThorStyleRegistry.active(context)?.useEngine();
    final g = gestureAttributes({
      'start': onDragStarted,
      'cancel': onDraggableCanceled,
      'end': onDragEnd,
      'done': onDragCompleted,
    }, attribute: dragSourceAttr);
    final native = childIsNativeControl(child);
    final hold = delay;
    final touch = hold > Duration.zero
        ? 'manipulation'
        : switch (axis) {
            Axis.horizontal => 'pan-y',
            Axis.vertical => 'pan-x',
            null => 'none',
          };
    final encoded = _encodeData(data);
    final l10n = ThorLocalizations.of(context);
    final say = labels.attributeFor(l10n);
    return _WithTemplates(
      child: WrapWith(
        WrapData(
          css: {
            'cursor': 'grab',
            'user-select': 'none',
            '-webkit-user-select': 'none',
            '-webkit-touch-callout': 'none',
            'touch-action': touch,
          },
          conditions: const [
            ConditionalCss(CssCondition.selector('[$dragActiveAttr]'), {
              'cursor': 'grabbing',
            }),
            ConditionalCss(CssCondition.selector('[$dragGoneAttr]'), {
              'display': 'none',
            }),
          ],
          attributes: {
            dragSourceAttr: g.attributes[dragSourceAttr] ?? '',
            argAttr: ?g.fixed,
            dragDataAttr: ?encoded,
            dragTypeAttr: '$T',
            dragSetupAttr: [
              switch (axis) {
                Axis.horizontal => 'h',
                Axis.vertical => 'v',
                null => 'f',
              },
              '${hold.inMilliseconds}',
              anchor,
              '1',
              _decimal(feedbackOffset.dx),
              _decimal(feedbackOffset.dy),
            ].join('|'),
            dragLabelsAttr: ?say,
            if (!native) ...{
              'tabindex': '0',
              'role': 'button',
              'aria-roledescription': labels.roleDescriptionFor(l10n),
            },
          },
        ),
        child: child,
      ),
      // web: what wraps the draggable (`Expanded`, `Padding`) decorates the
      // child, not the templates: they start a scope of their own.
      templates: [
        (
          dragFeedbackAttr,
          ChildRulesScope(
            rules: ChildRules.none,
            child: _Ghost(child: feedback),
          ),
        ),
        if (childWhenDragging case final w?)
          (
            dragPlaceholderAttr,
            ChildRulesScope(rules: ChildRules.none, child: w),
          ),
      ],
    );
  }
}

/// Flutter's `LongPressDraggable`: a [Draggable] that starts after the
/// pointer is held for [delay], so a touch can still scroll the page.
///
/// `// web:` the `touch-action` leaves the scroll alone until the hold;
/// moving before it ends cancels the hold, and after it the page stops
/// scrolling under the finger. `hapticFeedbackOnStart` is not supported by
/// the browsers' vibration policy and is not a parameter.
class LongPressDraggable<T extends Object> extends Draggable<T> {
  /// Makes [child] draggable after a hold of [delay].
  const LongPressDraggable({
    super.key,
    required super.child,
    required super.feedback,
    super.data,
    super.axis,
    super.childWhenDragging,
    super.feedbackOffset,
    super.dragAnchorStrategy,
    super.maxSimultaneousDrags,
    super.onDragStarted,
    super.onDraggableCanceled,
    super.onDragEnd,
    super.onDragCompleted,
    super.labels,
    this.delay = const Duration(milliseconds: 500),
  });

  @override
  final Duration delay;
}

/// The look of a draggable's feedback over a target is not drawn from a
/// list of candidates: see [DragTarget.overStyle].
typedef DragTargetBuilder<T> =
    Widget Function(
      BuildContext context,
      List<T?> candidateData,
      List<dynamic> rejectedData,
    );

/// Flutter's `DragTarget`: where a [Draggable] of the same type can be
/// dropped.
///
/// ```dart
/// DragTarget<String>(
///   onWillAcceptWithDetails: board.fits.withArg(column.id),   // bool fits(String column, String task)
///   onAcceptWithDetails: board.moved.withArg(column.id),      // void moved(String column, String task)
///   overStyle: const StyleProps(outline: BorderSide(color: Color(0xFF2563EB), width: 2)),
///   builder: (context, candidates, rejected) => ColumnView(column),
/// )
/// ```
///
/// The target is the element [builder] returns. Draggables are found by
/// hit-testing under the pointer, and a draggable fits when its type does
/// (`DragTarget<Object>` takes any, `num` an `int` or a `double`) and
/// [onWillAcceptWithDetails] (a state method returning a `bool`; true when
/// there is none) says so.
///
/// `// web:` [builder] runs once, on the server, with no candidates: what
/// changes while a draggable is over the target is CSS ([overStyle] while one
/// that fits is over it, [rejectStyle] while one that does not is). The
/// callbacks are methods of a `ThorState` and get the data (text,
/// a number, an enum value) rather than a details object; [onMove] gets only
/// the pointer's position inside the target (a state method takes at most three
/// parameters: with `withArg` that is the argument and the two numbers; the
/// state knows what is dragged from the draggable's `onDragStarted`).
class DragTarget<T extends Object> extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Takes the drops of a [Draggable]`<T>`.
  const DragTarget({
    super.key,
    required this.builder,
    this.onWillAcceptWithDetails,
    this.onAcceptWithDetails,
    this.onLeave,
    this.onMove,
    this.overStyle,
    this.rejectStyle,
  });

  /// Builds the target (once: see the class).
  final DragTargetBuilder<T> builder;

  /// Whether a draggable with this data can be dropped here. A state method
  /// returning a `bool`.
  final bool Function(T data)? onWillAcceptWithDetails;

  /// Called when a draggable is dropped here, with its data.
  final void Function(T data)? onAcceptWithDetails;

  /// Called when a draggable that was over this target leaves it.
  final void Function(T data)? onLeave;

  /// Called (at most once per frame) while a draggable that fits moves over
  /// this target, with the pointer's place inside it.
  final void Function(double x, double y)? onMove;

  /// Applied while a draggable that fits is over the target.
  final StyleProps? overStyle;

  /// Applied while a draggable that does not fit is over the target.
  final StyleProps? rejectStyle;

  @override
  Widget build(BuildContext context) {
    ThorStyleRegistry.active(context)?.useEngine();
    final g = gestureAttributes({
      'accept': onWillAcceptWithDetails,
      'drop': onAcceptWithDetails,
      'leave': onLeave,
      'move': onMove,
    }, attribute: dragTargetAttr);
    return WrapWith(
      WrapData(
        conditions: [
          if (overStyle case final s?)
            ConditionalCss(
              const CssCondition.selector('[$dragOverAttr]'),
              s.toCss(),
            ),
          if (rejectStyle case final s?)
            ConditionalCss(
              const CssCondition.selector('[$dragRejectAttr]'),
              s.toCss(),
            ),
        ],
        attributes: {
          dragTargetAttr: g.attributes[dragTargetAttr] ?? '',
          argAttr: ?g.fixed,
          dragTypeAttr: '$T',
        },
      ),
      child: builder(context, const [], const []),
    );
  }
}
