/// Asking and telling from a `ThorState` method: [confirm] and [toast].
///
/// ```dart
/// Future<void> remove(int id) async {
///   if (!await confirm('Delete this order?', message: 'This cannot be undone')) return;
///   orders.value = [for (final o in orders.value) if (o.id != id) o];
///   toast('Order deleted', kind: ToastKind.success);
/// }
/// ```
///
/// `// web:` Flutter's `showDialog` and `ScaffoldMessenger.showSnackBar`
/// need a `BuildContext` and build the widget in the call. A page here is
/// server HTML: the page has one native `<dialog>` and one snack bar,
/// written once by the server (styled by the theme) and shared by every
/// call, so the browser only fills their text.
library;

/// What a message is about: how a [toast] (or a server flash) looks.
enum ToastKind {
  /// A plain note (the default).
  info,

  /// Something worked.
  success,

  /// Something failed.
  error,
}

/// The question of a confirmation: what [confirm] asks and what a button's
/// `confirm:` shows before it submits.
final class ConfirmSpec {
  /// Asks [title] (the question), with an optional [message] under it and
  /// the labels of its two buttons (the app's `ServerMessages.ok` and
  /// `.cancel` when null).
  const ConfirmSpec(
    this.title, {
    this.message,
    this.confirmLabel,
    this.cancelLabel,
  });

  /// The question: `Delete this order?`.
  final String title;

  /// More text under the question.
  final String? message;

  /// The label of the button that says yes (`Delete`).
  final String? confirmLabel;

  /// The label of the button that says no.
  final String? cancelLabel;
}

/// Where the page's dialog and snack bar plug in. The engine installs
/// these when the page loads; a test installs its own.
abstract final class ThorFeedback {
  /// Asks [ConfirmSpec] and answers whether the visitor said yes. Null:
  /// nothing can ask (the server, a test), so [confirm] says no.
  static Future<bool> Function(ConfirmSpec spec)? confirmHandler;

  /// Shows a message. Null: nothing to show it in, so [toast] does nothing.
  static void Function(String message, ToastKind kind, Duration? duration)?
  toastHandler;

  /// Ends the snack bar's message ([hideToast]); with `all` the ones
  /// waiting too ([clearToasts]). Null: nothing to hide it in.
  static void Function(bool all)? toastHideHandler;
}

/// Asks [title] in the page's one native `<dialog>` and completes with
/// whether the visitor confirmed: `false` for Cancel, Esc or a click
/// outside. Two calls at once are asked one after the other, in order.
///
/// Without a dialog to ask in (the server, a test with no handler) the
/// answer is `false`, so `if (!await confirm(…)) return;` never runs the
/// destructive part by accident.
///
/// `// web:` Flutter's `showDialog<bool>(…)` returns the same `Future<bool?>`.
Future<bool> confirm(
  String title, {
  String? message,
  String? confirmLabel,
  String? cancelLabel,
}) async {
  final handler = ThorFeedback.confirmHandler;
  if (handler == null) return false;
  try {
    return await handler(
      ConfirmSpec(
        title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
      ),
    );
    // The answer of a page that broke is a no.
    // ignore: avoid_catches_without_on_clauses
  } catch (_) {
    return false;
  }
}

/// Shows [message] in the page's one snack bar, for [duration] (4 s by
/// default). Calls that come while one is showing wait their turn (a few at
/// most: a flood keeps the newest); the same message twice in a row shows
/// once. Screen readers hear it (`role=status`).
///
/// `// web:` Flutter's `ScaffoldMessenger.of(context).showSnackBar(…)`.
void toast(
  String message, {
  ToastKind kind = ToastKind.info,
  Duration? duration,
}) {
  if (message.trim().isEmpty) return;
  ThorFeedback.toastHandler?.call(message, kind, duration);
}

/// Ends the message the snack bar is showing now; the next one waiting
/// (if any) shows. Does nothing when none is showing.
///
/// `// web:` Flutter's `ScaffoldMessenger.of(context).hideCurrentSnackBar()`.
void hideToast() => ThorFeedback.toastHideHandler?.call(false);

/// Ends the message the snack bar is showing and forgets the ones waiting.
///
/// `// web:` Flutter's `ScaffoldMessenger.of(context).clearSnackBars()`.
void clearToasts() => ThorFeedback.toastHideHandler?.call(true);
