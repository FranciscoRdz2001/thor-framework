import 'package:thor_engine/thor_engine.dart' show switcherAttr;
import 'package:thor_style/thor_style.dart';

import '../foundation/page_navigation.dart' show switcherTiming;
import '../foundation/parent_data.dart';

/// Flutter's `AnimatedSwitcher`: animates the switch between the states
/// of the `Watch` it wraps.
///
/// It adds no element: it marks the `Watch`'s element, and when the
/// state changes in the browser the engine applies the new state inside a
/// view transition. The element cross-fades from one state to the next
/// (or morphs, when both states share it), and every `Hero` inside it
/// glides from its old place and size to the new one; the rest of the page
/// changes at once. Around anything that isn't a `Watch` with states it
/// does nothing.
///
/// ```dart
/// AnimatedSwitcher(
///   duration: const Duration(milliseconds: 300),
///   switchInCurve: Curves.easeInOut,
///   child: Watch(layout.isRow, builder: (row) => Flex(
///     direction: row ? Axis.horizontal : Axis.vertical,
///     children: [for (final l in labels) Hero(tag: 'item-$l', child: Text(l))],
///   )),
/// )
/// ```
///
/// It works from either side of the `Watch`: around it (above), or as the
/// root of its builder (through `Padding` and the like), where the `Watch`
/// swaps its whole element and the switcher marks that one; deeper in the
/// builder's tree it marks an element nothing swaps:
///
/// ```dart
/// Watch(page.step, builder: (step) => AnimatedSwitcher(
///   duration: const Duration(milliseconds: 200),
///   child: Text(titles[step]),
/// ))
/// ```
///
/// Anywhere else (no `Watch` above or below) it does nothing; the
/// `animated_switcher_without_watch` lint (THOR-S016) says so while you
/// write it.
///
/// Without view transitions in the browser, with `prefers-reduced-motion`
/// or without JavaScript, the state changes at once.
///
/// `// web:` Flutter keeps both children in a `Stack` and runs
/// `transitionBuilder` on each; here the browser animates snapshots of
/// the page, so there is no `transitionBuilder` or `layoutBuilder` (the
/// animation is always the cross-fade, plus the `Hero`es' moves).
/// A `Hero` inside the states needs a tag unique in each state (not across
/// states: the same tag in two states is how an element moves).
class AnimatedSwitcher extends ParentDataWrapper {
  /// Animates the state switches of [child] (a `Watch`).
  const AnimatedSwitcher({
    super.key,
    required this.duration,
    this.reverseDuration,
    this.switchInCurve = Curves.linear,
    this.switchOutCurve = Curves.linear,
    required super.child,
  });

  /// How long the new state takes to come in (and each `Hero` to move).
  final Duration duration;

  /// How long the old state takes to go (default: [duration]).
  final Duration? reverseDuration;

  /// The easing of the new state and of the `Hero`es' moves.
  final Curve switchInCurve;

  /// The easing of the old state's fade.
  final Curve switchOutCurve;

  @override
  WrapData get wrapData => WrapData(
    attributes: {
      switcherAttr: switcherTiming(
        duration: duration,
        reverseDuration: reverseDuration,
        switchInCurve: switchInCurve,
        switchOutCurve: switchOutCurve,
      ),
    },
  );
}
