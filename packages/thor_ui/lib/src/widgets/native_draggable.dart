import 'dart:convert' show jsonEncode;

import 'package:thor_engine/thor_engine.dart'
    show
        argAttr,
        dragOverAttr,
        dragRejectAttr,
        encodeArg,
        nativeDragActiveAttr,
        nativeDragDataAttr,
        nativeDragSetupAttr,
        nativeDragSourceAttr,
        nativeDragTransferAttr,
        nativeDragTypeAttr,
        nativeDropEffectAttr,
        nativeDropMimeAttr,
        nativeDropTargetAttr;

import '../core/core.dart' show BuildContext, StatelessWidget, Widget;
import '../engine/watch.dart' show gestureAttributes;
import '../foundation/child_rules.dart' show ThorBuiltIn, ThorElementWidget;
import '../foundation/parent_data.dart' show WrapData, WrapWith;
import '../foundation/responsive.dart' show StyleProps;
import '../foundation/style_registry.dart'
    show ConditionalCss, CssCondition, ThorStyleRegistry;
import 'draggable.dart' show DragTarget, DragTargetBuilder, Draggable;
import 'iframe.dart' show Iframe;

/// The `dataTransfer.effectAllowed` / `dropEffect` values: what a drop may
/// do with what was dragged.
///
/// A [NativeDraggable] says which it [NativeDraggable.effectAllowed]; a
/// [NativeDragTarget] picks one ([NativeDragTarget.dropEffect]) the drag
/// allows, and the browser shows its cursor.
enum DragEffect {
  /// The drag cannot be dropped.
  none,

  /// `copy`
  copy,

  /// `copyLink`
  copyLink,

  /// `copyMove`
  copyMove,

  /// `link`
  link,

  /// `linkMove`
  linkMove,

  /// `move`
  move,

  /// `all`
  all,
}

// The data as the page writes it (see `Draggable`): text, a number, an
// enum's name, or JSON for a `Map` or a `List`.
String? _encode(Object? data) => data == null
    ? null
    : data is Map || data is List
    ? jsonEncode(data)
    : encodeArg(data);

/// A widget the browser drags with its own drag and drop (HTML5, the
/// `dataTransfer` the drop receives): web-only, next to Flutter's
/// pointer-driven [Draggable] (Flutter has no equivalent, as its drags never
/// leave the app).
///
/// ```dart
/// NativeDraggable<String>(
///   data: node.id,
///   dataTransfer: {'application/x-editor-node': node.toJson()},
///   effectAllowed: DragEffect.copy,
///   draggingStyle: const StyleProps(opacity: 0.4),
///   child: PaletteItem(node),
/// )
/// ```
///
/// What it is for: a drop **outside this page's widgets**. The data goes to
/// `dataTransfer`, so a page in an [Iframe] (which a pointer drag cannot
/// reach: the pointer events go to the frame), another window or the desktop
/// can read it in its own `drop` event with `getData`. Inside the page, use
/// [Draggable] (it works with a finger, has a feedback and a keyboard way);
/// a [NativeDragTarget] takes the drops of this widget in the same page too.
///
/// [data] is written under [mimeType]; [dataTransfer] adds more (MIME type →
/// text). The callbacks are methods of a `ThorState`, like [Draggable]'s:
/// [onDragEnd] and [onDragCompleted] hear whether anything took the drag from
/// the browser's `dropEffect` (a drop in a frame counts), [onDraggableCanceled]
/// where the pointer was.
///
/// `// web:` the drag image is the browser's (the element itself; there is no
/// `feedback`, `childWhenDragging` or `axis`): [draggingStyle] styles the
/// element while it is dragged. There is no keyboard way (the browser has
/// none): give the action another way (a click, a menu) as well, WCAG 2.5.7.
/// Without JavaScript the element still drags (`draggable="true"`) but
/// carries no data.
class NativeDraggable<T extends Object> extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Makes [child] draggable with the browser's drag and drop.
  const NativeDraggable({
    super.key,
    required this.child,
    this.data,
    this.mimeType = 'text/plain',
    this.dataTransfer = const {},
    this.effectAllowed = DragEffect.copyMove,
    this.draggingStyle,
    this.onDragStarted,
    this.onDraggableCanceled,
    this.onDragEnd,
    this.onDragCompleted,
  });

  /// The widget that is dragged.
  final Widget child;

  /// What a [NativeDragTarget] of this page receives, and what is written to
  /// `dataTransfer` under [mimeType] (as text; see [Draggable.data]).
  final T? data;

  /// The type [data] is written under in `dataTransfer`.
  final String mimeType;

  /// More `dataTransfer` entries: MIME type → text (a JSON of the node, a
  /// `text/uri-list`). A frame reads them with `getData`.
  final Map<String, String> dataTransfer;

  /// What the drop may do with the data.
  final DragEffect effectAllowed;

  /// Applied to the element while it is dragged (after the browser took its
  /// drag image).
  final StyleProps? draggingStyle;

  /// Called when the drag starts.
  final void Function()? onDragStarted;

  /// Called when nothing took the drag, with where the pointer was (client
  /// coordinates).
  final void Function(double x, double y)? onDraggableCanceled;

  /// Called when the drag ends, with whether something took it.
  final void Function(bool wasAccepted)? onDragEnd;

  /// Called when the drag ends and something took it.
  final void Function()? onDragCompleted;

  @override
  Widget build(BuildContext context) {
    ThorStyleRegistry.active(context)?.useEngine();
    final g = gestureAttributes({
      'start': onDragStarted,
      'cancel': onDraggableCanceled,
      'end': onDragEnd,
      'done': onDragCompleted,
    }, attribute: nativeDragSourceAttr);
    final encoded = _encode(data);
    return WrapWith(
      WrapData(
        css: const {'cursor': 'grab'},
        conditions: [
          if (draggingStyle case final s?)
            ConditionalCss(
              const CssCondition.selector('[$nativeDragActiveAttr]'),
              s.toCss(),
            ),
        ],
        attributes: {
          'draggable': 'true',
          nativeDragSourceAttr: g.attributes[nativeDragSourceAttr] ?? '',
          argAttr: ?g.fixed,
          nativeDragDataAttr: ?encoded,
          nativeDragTypeAttr: '$T',
          nativeDragSetupAttr: '$mimeType|${effectAllowed.name}',
          if (dataTransfer.isNotEmpty)
            nativeDragTransferAttr: jsonEncode(dataTransfer),
        },
      ),
      child: child,
    );
  }
}

/// Where a [NativeDraggable] of the same type (or a drag from outside the
/// page that carries one of [acceptMimeTypes]) can be dropped: the browser's
/// own drag and drop, next to [DragTarget].
///
/// ```dart
/// NativeDragTarget<String>(
///   onWillAcceptWithDetails: tree.fits.withArg(row.id),
///   onAcceptWithDetails: tree.moved.withArg(row.id),
///   overStyle: const StyleProps(outline: BorderSide(color: Color(0xFF2563EB), width: 2)),
///   builder: (context, candidates, rejected) => RowView(row),
/// )
/// ```
///
/// The target is the element [builder] returns, which runs once on the
/// server (what changes while a drag is over it is CSS: [overStyle] while one
/// that fits is over it, [rejectStyle] while one that does not is). A
/// [NativeDraggable] of this page fits when its type does (`Object` takes any,
/// `num` an `int` or a `double`) and [onWillAcceptWithDetails] says so. A drag
/// from outside (files, a link, a native drag of another page) fits when its
/// `dataTransfer.types` has one of [acceptMimeTypes]; its drop gives the text
/// of the first of those (so `T` is `String`; `Files` give no text).
///
/// `// web:` the callbacks are methods of a `ThorState` and get the data as
/// text, not a details object (as [DragTarget]'s); [onMove] gets the pointer's
/// place inside the target at most once a frame.
class NativeDragTarget<T extends Object> extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Takes the drops of a [NativeDraggable]`<T>`.
  const NativeDragTarget({
    super.key,
    required this.builder,
    this.onWillAcceptWithDetails,
    this.onAcceptWithDetails,
    this.onLeave,
    this.onMove,
    this.overStyle,
    this.rejectStyle,
    this.acceptMimeTypes = const [],
    this.dropEffect,
  });

  /// Builds the target (once: see the class).
  final DragTargetBuilder<T> builder;

  /// Whether a drag of this page with this data can be dropped here. A state
  /// method returning a `bool`.
  final bool Function(T data)? onWillAcceptWithDetails;

  /// Called when a drag is dropped here, with its data.
  final void Function(T data)? onAcceptWithDetails;

  /// Called when a drag that fit leaves this target.
  final void Function(T data)? onLeave;

  /// Called (at most once per frame) while a drag that fits moves over this
  /// target, with the pointer's place inside it.
  final void Function(double x, double y)? onMove;

  /// Applied while a drag that fits is over the target.
  final StyleProps? overStyle;

  /// Applied while a drag that does not fit is over the target.
  final StyleProps? rejectStyle;

  /// The MIME types of drags from outside this page's native draggables that
  /// the target takes (`text/uri-list`, `Files`).
  final List<String> acceptMimeTypes;

  /// The `dropEffect` the target answers with: the first the drag allows when
  /// null.
  final DragEffect? dropEffect;

  @override
  Widget build(BuildContext context) {
    ThorStyleRegistry.active(context)?.useEngine();
    final g = gestureAttributes({
      'accept': onWillAcceptWithDetails,
      'drop': onAcceptWithDetails,
      'leave': onLeave,
      'move': onMove,
    }, attribute: nativeDropTargetAttr);
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
          nativeDropTargetAttr: g.attributes[nativeDropTargetAttr] ?? '',
          argAttr: ?g.fixed,
          nativeDragTypeAttr: '$T',
          if (acceptMimeTypes.isNotEmpty)
            nativeDropMimeAttr: acceptMimeTypes.join('\n'),
          if (dropEffect case final e?) nativeDropEffectAttr: e.name,
        },
      ),
      child: builder(context, const [], const []),
    );
  }
}
