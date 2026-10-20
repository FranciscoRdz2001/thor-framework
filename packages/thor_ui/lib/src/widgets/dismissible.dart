import 'dart:async' show FutureOr;

import 'package:thor_engine/thor_engine.dart'
    show
        argAttr,
        dismissibleAttr,
        dismissibleBackgroundAttr,
        dismissibleBodyAttr,
        dismissibleDragAttr,
        dismissibleGoneAttr,
        dismissibleOnAttr,
        dismissibleOutAttr,
        dismissibleSetupAttr,
        dismissibleVarX,
        dismissibleVarY;
import 'package:thor_style/thor_style.dart';

import '../core/core.dart' show Key, StatelessWidget, Widget, BuildContext;
import '../engine/watch.dart' show gestureAttributes;
import '../foundation/child_rules.dart' show ThorBuiltIn, ThorElementWidget;
import '../foundation/element.dart' show thorElement;
import '../foundation/parent_data.dart' show WrapData, WrapWith;
import '../foundation/style_registry.dart'
    show ConditionalCss, CssCondition, ThorStyleRegistry;
import 'gesture_detector.dart' show HitTestBehavior;

/// The directions a [Dismissible] can be dismissed in (Flutter's
/// `DismissDirection`).
///
/// `startToEnd` and `endToStart` follow the text direction: in right-to-left
/// text a drag toward the left is `startToEnd`.
enum DismissDirection {
  /// The [Dismissible] can be dismissed by dragging either up or down.
  vertical,

  /// The [Dismissible] can be dismissed by dragging either left or right.
  horizontal,

  /// The [Dismissible] can be dismissed by dragging in the reverse of the
  /// reading direction (to the left in left-to-right text).
  endToStart,

  /// The [Dismissible] can be dismissed by dragging in the reading
  /// direction (to the right in left-to-right text).
  startToEnd,

  /// The [Dismissible] can be dismissed by dragging up only.
  up,

  /// The [Dismissible] can be dismissed by dragging down only.
  down,

  /// The [Dismissible] cannot be dismissed by dragging.
  none,
}

/// Flutter's `Dismissible`: a widget that is dismissed by dragging it away.
///
/// ```dart
/// Dismissible(
///   key: ValueKey(m.id),
///   direction: DismissDirection.endToStart,
///   onDismissed: inbox.archived.withArg(m.id),   // void archived(int id, DismissDirection d)
///   confirmDismiss: inbox.ask.withArg(m.id),     // Future<bool> ask(int id, DismissDirection d)
///   background: const ColoredBox(color: Color(0xFF16A34A)),
///   child: MessageTile(m),
/// )
/// ```
///
/// The child follows the pointer (pointer events and a CSS `translate`: the
/// browser moves it, no Dart per frame) and shows the [background] under it.
/// Past [dismissThresholds] (a fraction of its size; 0.4 by default) or with a
/// quick fling it slides out of the way; then [confirmDismiss] is asked
/// (false or null brings it back), the root collapses over [resizeDuration]
/// (a CSS transition of a grid track) and [onDismissed] runs once, with the
/// direction. The state removes the item (a `Watch.list` row leaves the list);
/// a Dismissible that was dismissed and kept stays collapsed, as in Flutter.
///
/// Keyboard (WCAG 2.5.1 and 2.1.1: a path gesture needs another way): the
/// root can be focused and Delete or Backspace dismisses it (Shift+arrow along
/// the axis too), which `aria-keyshortcuts` says; focus moves to the next row,
/// so it never lands on the page. A keystroke in a text field inside it is the
/// field's. Offer a visible button for the same action as well.
///
/// `// web:` the callbacks are methods of a `ThorState`, not closures:
/// [onDismissed] gets the [DismissDirection], [confirmDismiss] returns a
/// `bool` or a `Future<bool>`. Flutter's per-frame `onUpdate` and `onResize`,
/// `crossAxisEndOffset` and `dragStartBehavior` have no equivalent. Without
/// JavaScript it is only the child (nothing swipes): give the same action to a
/// button or a form. The child's own `translate` is replaced while it moves.
class Dismissible extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Dismisses [child] when it is dragged away.
  const Dismissible({
    required Key key,
    required this.child,
    this.background,
    this.secondaryBackground,
    this.confirmDismiss,
    this.onDismissed,
    this.direction = DismissDirection.horizontal,
    this.resizeDuration = const Duration(milliseconds: 300),
    this.dismissThresholds = const {},
    this.movementDuration = const Duration(milliseconds: 200),
    this.behavior,
  }) : super(key: key);

  /// The widget that slides.
  final Widget child;

  /// Shown under the child while it moves toward [DismissDirection.startToEnd]
  /// or down; also for the other directions when there is no
  /// [secondaryBackground].
  final Widget? background;

  /// Shown under the child while it moves toward [DismissDirection.endToStart]
  /// or up.
  final Widget? secondaryBackground;

  /// Asked after the child slid out: true dismisses it, false (or null) brings
  /// it back. A method of a `ThorState` returning a `bool` or a `Future<bool>`.
  final FutureOr<bool?> Function(DismissDirection direction)? confirmDismiss;

  /// Called once the child is dismissed (after the collapse), with the
  /// direction it left in. A method of a `ThorState`.
  final void Function(DismissDirection direction)? onDismissed;

  /// The directions it can be dragged in.
  final DismissDirection direction;

  /// How long the root takes to collapse once the child is gone, or null to
  /// call [onDismissed] right after it slid out.
  final Duration? resizeDuration;

  /// The fraction of the child's size it must be dragged by, per direction
  /// (0.4 where none is given).
  final Map<DismissDirection, double> dismissThresholds;

  /// How long the child takes to slide out (or back).
  final Duration movementDuration;

  /// Accepted for Flutter's API; the root is the hit target.
  final HitTestBehavior? behavior;

  static const _directions = [
    DismissDirection.startToEnd,
    DismissDirection.endToStart,
    DismissDirection.up,
    DismissDirection.down,
  ];

  // The concrete directions [direction] allows.
  Set<DismissDirection> get _allowed => switch (direction) {
    DismissDirection.horizontal => const {
      DismissDirection.startToEnd,
      DismissDirection.endToStart,
    },
    DismissDirection.vertical => const {
      DismissDirection.up,
      DismissDirection.down,
    },
    DismissDirection.none => const {},
    final one => {one},
  };

  bool get _vertical => _allowed.any(
    (d) => d == DismissDirection.up || d == DismissDirection.down,
  );

  @override
  Widget build(BuildContext context) {
    final allowed = _allowed;
    final g = gestureAttributes({
      'dismissed': onDismissed,
      'confirm': confirmDismiss,
    }, attribute: dismissibleAttr);
    final live = allowed.isNotEmpty && g.attributes.isNotEmpty;
    final vertical = _vertical;
    final move = cssDuration(movementDuration);
    final resize = resizeDuration;
    final registry = ThorStyleRegistry.active(context);
    if (live) {
      // Typed, and not inherited: a pointer move rewrites them and only this
      // element's style needs to be invalidated (Gesture's reasoning).
      for (final name in const [dismissibleVarX, dismissibleVarY]) {
        registry?.addProperty(
          name,
          "syntax:'<length>';inherits:false;initial-value:0px",
        );
      }
    }
    final axis = vertical ? 'columns' : 'rows';
    // The backgrounds: `background` for startToEnd and down (and for every
    // direction when there is no secondary), `secondaryBackground` for
    // endToStart and up.
    final primary = {
      for (final d in _directions)
        if (allowed.contains(d) &&
            (secondaryBackground == null ||
                d == DismissDirection.startToEnd ||
                d == DismissDirection.down))
          d,
    };
    final secondary = {
      for (final d in _directions)
        if (allowed.contains(d) &&
            secondaryBackground != null &&
            (d == DismissDirection.endToStart || d == DismissDirection.up))
          d,
    };
    Widget layer(Widget content, Set<DismissDirection> shownFor) => thorElement(
      'div',
      debugName: 'Dismissible background',
      css: {
        'display': 'grid',
        'grid-area': '1 / 1',
        'min-width': '0',
        'min-height': '0',
        'visibility': 'hidden',
      },
      conditions: [
        const ConditionalCss(CssCondition.selector('[$dismissibleOnAttr]'), {
          'visibility': 'visible',
        }),
      ],
      attributes: {
        'aria-hidden': 'true',
        dismissibleBackgroundAttr: [for (final d in shownFor) d.name].join(' '),
      },
      children: [content],
    );

    final body = WrapWith(
      WrapData(
        css: {
          'grid-area': '1 / 1',
          'min-width': '0',
          'min-height': '0',
          if (live) ...{
            'translate':
                'var($dismissibleVarX, 0px) var($dismissibleVarY, 0px)',
            'touch-action': vertical ? 'pan-x' : 'pan-y',
          },
        },
        conditions: [
          if (live) ...[
            ConditionalCss(
              const CssCondition.selector('[$dismissibleOutAttr]'),
              {'transition': 'translate $move ease-out'},
            ),
            const ConditionalCss(
              CssCondition.selector('[$dismissibleDragAttr]'),
              {
                'transition': 'none',
                'user-select': 'none',
                'cursor': 'grabbing',
              },
            ),
            // web: motion is instant (1ms, so the change still lands and the
            // collapse still ends) with "reduce motion".
            const ConditionalCss(CssCondition.reducedMotion, {
              'transition-duration': '1ms',
            }),
          ],
        ],
        attributes: {if (live) dismissibleBodyAttr: ''},
      ),
      child: child,
    );

    return thorElement(
      'div',
      debugName: 'Dismissible',
      css: {
        'display': 'grid',
        'grid-template-$axis': '1fr',
        'overflow': 'clip',
        if (live && resize != null)
          'transition':
              'grid-template-$axis ${cssDuration(resize)} ease-in-out',
      },
      conditions: [
        if (live) ...[
          ConditionalCss(
            const CssCondition.selector('[$dismissibleGoneAttr]'),
            {'grid-template-$axis': '0fr'},
          ),
          const ConditionalCss(CssCondition.reducedMotion, {
            'transition-duration': '1ms',
          }),
        ],
      ],
      attributes: {
        if (live) ...{
          ...g.attributes,
          argAttr: ?g.fixed,
          dismissibleSetupAttr: [
            vertical ? 'v' : 'h',
            for (final d in _directions)
              allowed.contains(d) ? cssNum(dismissThresholds[d] ?? 0.4) : '-',
            '${movementDuration.inMilliseconds}',
            '${resize?.inMilliseconds ?? 0}',
          ].join('|'),
          'tabindex': '0',
          'aria-keyshortcuts': 'Delete',
        },
      },
      children: [
        if (background != null && primary.isNotEmpty)
          layer(background!, primary),
        if (secondaryBackground != null && secondary.isNotEmpty)
          layer(secondaryBackground!, secondary),
        body,
      ],
    );
  }
}
