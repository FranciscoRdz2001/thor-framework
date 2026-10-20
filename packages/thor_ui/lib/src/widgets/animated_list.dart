import 'package:thor_engine/thor_engine.dart'
    show Animation, listEnterAttr, listExitAttr;

import '../animation/tween.dart' show ListItemAnimation;
import '../core/core.dart';
import '../engine/watch.dart' show Watch, WatchRow;
import '../foundation/parent_data.dart';
import 'flex.dart' show Column;

/// Flutter's `AnimatedList`: a list whose rows animate when they come in
/// and when they go out.
///
/// It is a [Watch.list]: change the list in the state and the browser adds,
/// moves and removes the rows by their key; this animates the two ends. A
/// row that enters starts from the first value of its [itemBuilder]'s
/// animation and goes to the last; one that leaves goes back before it is
/// removed. Each row is built **once** on the server, so the animation is a
/// CSS transition, never a Dart frame:
///
/// ```dart
/// AnimatedList<Note, int>(
///   notes.items.call,
///   itemKey: notes.idOf,
///   duration: const Duration(milliseconds: 250),
///   itemBuilder: (context, row, animation) => SizeTransition(
///     sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOut),
///     child: FadeTransition(
///       opacity: animation,
///       child: ListTile(
///         title: row.text(notes.titleOf),
///         trailing: IconButton(
///           onPressed: notes.remove.withArg(row.key),
///           icon: const Icon(Icons.delete),
///         ),
///       ),
///     ),
///   ),
/// )
/// ```
///
/// The rows the page draws the first time (Flutter's `initialItemCount`)
/// don't animate, and with no JavaScript or with `prefers-reduced-motion`
/// nothing does: rows just appear and disappear.
///
/// `// web:` differences with Flutter's:
/// - there is no `AnimatedListState` or `GlobalKey`: `insertItem` is adding
///   the item to the list of the state and `removeItem` removing it, with
///   the state's own methods (`onPressed: notes.remove.withArg(row.key)`);
/// - [itemBuilder] gets the row (its typed `key`, `row.text`, …) in place of
///   the `index`: rows are found by their key;
/// - the same builder serves a row that enters and one that leaves (Flutter
///   takes a `removeItem(…, builder)` for the second), with an `animation`
///   that is 1 for a row at rest and 0 where it starts: `animation` is not a
///   controller (it has no listeners, and `status` is `completed`), only the
///   transition widgets (`FadeTransition`, `ScaleTransition`,
///   `SlideTransition`, `SizeTransition`, `RotationTransition`,
///   `DecoratedBoxTransition`), `Tween`s, `CurvedAnimation`s and
///   `CurveTween`s accept it;
/// - [duration] is the list's, not each call's;
/// - a row that leaves stays in the page (inert) for [duration], so a
///   `Watch.list` with the same key added again meanwhile shows twice.
class AnimatedList<I, K extends Object> extends StatelessWidget {
  /// Animates the rows of [source] (a `List` of the state: `notes.items.call`,
  /// like [Watch.list]), each built by [itemBuilder].
  const AnimatedList(
    this.source, {
    super.key,
    required this.itemKey,
    required this.itemBuilder,
    this.duration = const Duration(milliseconds: 300),
    this.container,
  });

  /// The list: a field of a `ThorState` read as `.call`, or a method of it.
  final List<I> Function() source;

  /// A method of the state giving each item's key (an `int` or a `String`).
  final K Function(I item) itemKey;

  /// Builds a row: the typed [WatchRow] and its [ListItemAnimation]-backed
  /// `animation` (1 at rest, 0 where it starts).
  final Widget Function(
    BuildContext context,
    WatchRow<I, K> row,
    Animation<double> animation,
  )
  itemBuilder;

  /// How long a row takes to enter and to leave.
  final Duration duration;

  /// Wraps the rows (default: a `Column`), like [Watch.list]'s.
  final Widget Function(List<Widget> rows)? container;

  @override
  Widget build(BuildContext context) {
    final animation = ListItemAnimation(duration);
    return Watch.list<I, K>(
      source,
      itemKey: itemKey,
      each: (row) {
        final built = itemBuilder(context, row, animation);
        // Only the template's rows (the ones the browser adds) enter.
        return row.isTemplate
            ? WrapWith(
                const WrapData(attributes: {listEnterAttr: ''}),
                child: built,
              )
            : built;
      },
      container: (rows) => WrapWith(
        WrapData(attributes: {listExitAttr: '${duration.inMilliseconds}'}),
        child: container?.call(rows) ?? Column(children: rows),
      ),
    );
  }
}
