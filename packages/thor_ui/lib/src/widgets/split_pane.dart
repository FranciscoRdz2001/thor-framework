import 'package:thor_engine/thor_engine.dart'
    show splitPaneAttr, splitPaneBarAttr, splitPaneMinAttr;
import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../engine/watch.dart' show elementEventAttributes;
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/native_id.dart';
import '../foundation/style_registry.dart';
import '../foundation/theme_tokens.dart';

/// Two panes with a draggable divider between them: the editors' split view.
///
/// ```dart
/// SplitPane(
///   initialFraction: 0.3,
///   minFirstSize: 160,
///   minSecondSize: 320,
///   semanticLabel: 'Resize the sidebar',
///   first: const Sidebar(),
///   second: const Canvas(),
/// )
/// ```
///
/// [axis] is Flutter's `Row` / `Column` direction: [Axis.horizontal] puts
/// [first] on the start side and [second] on the end side (a vertical
/// divider), [Axis.vertical] stacks them. The size of [first] is
/// `initialFraction` of the room left by the divider, kept between
/// [minFirstSize] and the room that leaves [minSecondSize] to [second]: that
/// is CSS (`clamp()` on a custom property), so the first paint is right, the
/// bounds hold when the window resizes and the page works with no JS.
///
/// The divider is a focusable `role="separator"` (the WAI-ARIA window
/// splitter) with `aria-valuenow` as the percent given to [first]. With the
/// lite engine it moves: the arrows resize by 2 % (10 % with Shift), Home and
/// End go to the smallest and the largest [first], and a pointer drags it.
///
/// `// web:` Flutter has no split view (an app writes a `Row` of two
/// `Expanded` and a `GestureDetector`, and keeps the fraction in a
/// `State`); the divider is one more element of the page, and the browser
/// holds the fraction: it is not a field of a `ThorState`. [onChanged] tells
/// a state method the fraction (0 to 1) *after* each interaction (the end of
/// a drag, a key press), not on every pixel of the drag, so the state can
/// persist it.
class SplitPane extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Creates a split view of [first] and [second].
  const SplitPane({
    super.key,
    this.id,
    this.axis = Axis.horizontal,
    required this.first,
    required this.second,
    this.initialFraction = 0.5,
    this.minFirstSize = 0,
    this.minSecondSize = 0,
    this.dividerThickness = 6,
    this.dividerColor,
    this.semanticLabel,
    this.onChanged,
  }) : assert(initialFraction >= 0 && initialFraction <= 1),
       assert(minFirstSize >= 0),
       assert(minSecondSize >= 0),
       assert(dividerThickness >= 1);

  /// `// web:` DOM id of the first pane (the divider's `aria-controls`).
  /// Optional: without one it is named by its `ValueKey` or its place in
  /// the page (the same on every render).
  final String? id;

  /// Whether the panes sit side by side ([Axis.horizontal], the default) or
  /// one above the other ([Axis.vertical]).
  final Axis axis;

  /// The pane on the start (or top) side.
  final Widget first;

  /// The pane on the end (or bottom) side.
  final Widget second;

  /// Share of the room left by the divider that [first] starts with
  /// (0 to 1, default: half).
  final double initialFraction;

  /// The smallest size of [first] along [axis], in logical pixels.
  final double minFirstSize;

  /// The smallest size of [second] along [axis], in logical pixels.
  final double minSecondSize;

  /// Thickness of the divider, in logical pixels (default 6; the hit area
  /// is the same).
  final double dividerThickness;

  /// Color of the divider (default: `outlineVariant`, `primary` while
  /// hovered, focused or dragged).
  final Color? dividerColor;

  /// What a screen reader says for the divider (default: "Resize panes").
  final String? semanticLabel;

  /// Called with the fraction of [first] (0 to 1) when a drag ends or a key
  /// moves the divider (a `ThorState` method, e.g. `layout.setSplit`).
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final horizontal = axis == Axis.horizontal;
    final size = horizontal ? 'width' : 'height';
    final min = horizontal ? 'min-width' : 'min-height';
    final cross = horizontal ? 'min-height' : 'min-width';
    final thickness = cssPx(dividerThickness);
    final paneId = nativeId(context, prefix: 'split', id: id, key: key);
    final line = dividerColor?.css ?? ThemeTokens.outlineVariant;
    final fraction = initialFraction.clamp(0.0, 1.0);
    return thorElement(
      'div',
      debugName: 'SplitPane',
      fillsWidth: true,
      fillsHeight: true,
      css: {
        'display': 'flex',
        'flex-direction': horizontal ? 'row' : 'column',
        'box-sizing': 'border-box',
        'min-width': '0',
        'min-height': '0',
        // The browser moves it (the divider's pointer and keys); the client
        // writes this one number, never a style.
        '--tsp': _number(fraction),
      },
      attributes: {
        splitPaneAttr: horizontal ? 'x' : 'y',
        splitPaneMinAttr: '${_number(minFirstSize)},${_number(minSecondSize)}',
        ...elementEventAttributes({'split': onChanged}),
      },
      children: [
        thorElement(
          'div',
          id: paneId,
          debugName: 'SplitPane.first',
          css: {
            'flex': 'none',
            size:
                'clamp(${cssPx(minFirstSize)}, '
                'calc((100% - $thickness) * var(--tsp)), '
                'calc(100% - $thickness - ${cssPx(minSecondSize)}))',
            min: '0',
            cross: '0',
            'overflow': 'auto',
            'box-sizing': 'border-box',
          },
          children: [first],
        ),
        thorElement(
          'div',
          debugName: 'SplitPane.divider',
          css: {
            'flex': 'none',
            size: thickness,
            'background': line,
            'cursor': horizontal ? 'col-resize' : 'row-resize',
            // The finger drags the divider, not the page.
            'touch-action': 'none',
            'user-select': 'none',
            'outline': 'none',
            'box-sizing': 'border-box',
          },
          conditions: [
            const ConditionalCss(CssCondition.selector(':hover'), {
              'background': ThemeTokens.primary,
            }),
            const ConditionalCss(CssCondition.selector(':focus-visible'), {
              'background': ThemeTokens.primary,
            }),
            const ConditionalCss(CssCondition.selector('[data-dragging]'), {
              'background': ThemeTokens.primary,
            }),
          ],
          attributes: {
            'role': 'separator',
            'tabindex': '0',
            // The line is vertical when the panes are side by side.
            'aria-orientation': horizontal ? 'vertical' : 'horizontal',
            'aria-controls': paneId,
            'aria-label': semanticLabel ?? 'Resize panes',
            'aria-valuenow': '${(fraction * 100).round()}',
            'aria-valuemin': '0',
            'aria-valuemax': '100',
            splitPaneBarAttr: '',
          },
        ),
        thorElement(
          'div',
          debugName: 'SplitPane.second',
          css: {
            'flex': '1 1 0',
            min: '0',
            cross: '0',
            'overflow': 'auto',
            'box-sizing': 'border-box',
          },
          children: [second],
        ),
      ],
    );
  }
}

/// `0.5`, `160`: [v] with no trailing zeros.
String _number(double v) {
  final s = v.toStringAsFixed(4);
  final t = s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
  return t.isEmpty ? '0' : t;
}
