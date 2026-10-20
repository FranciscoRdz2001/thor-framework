// Recipe: state that changes in the browser. A ThorState is a class of
// `state()` fields and methods; widgets take its methods as tear-offs
// (never closures) and Watch shows what changes. The builder turns it into
// the browser engine; the first paint is the server's.
import 'package:thor_ui/thor_ui.dart';

/// Likes of a product and whether the visitor liked it.
class LikesState extends ThorState {
  /// How many.
  final count = state(12);

  /// Whether this visitor liked it.
  final liked = state(false);

  /// The count as text (an infinite value: a String, not variants).
  String label() => '${count.value} me gusta';

  /// A finite state: Watch builds one variant per value.
  bool isLiked() => liked.value;

  /// Toggles, writing both fields in one batch (one update).
  void toggle() => batch(() {
    count.value += liked.value ? -1 : 1;
    liked.value = !liked.value;
  });
}

/// The page's instance.
final likes = LikesState();
