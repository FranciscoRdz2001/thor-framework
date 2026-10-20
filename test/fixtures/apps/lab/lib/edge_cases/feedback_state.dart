import 'package:thor_ui/thor_ui.dart';

/// What `confirm()` and `toast()` do from a state method (the feedback
/// case): asks first, then changes the list and says so. The parity check
/// runs it on both engines (test/e2e/checks/parity_check.mjs).
class FeedbackState extends ThorState {
  final names = state(const <String>['Ana', 'Luis', 'Marta']);
  final log = state('');

  String nameOf(String name) => name;

  /// Asks first, then removes the name and says so.
  Future<void> removeAsk(String name) async {
    if (!await confirm(
      'Remove $name?',
      message: 'This cannot be undone',
      confirmLabel: 'Remove',
    )) {
      log.value = 'cancelled $name';
      return;
    }
    names.value = [
      for (final n in names.value)
        if (n != name) n,
    ];
    log.value = 'removed $name';
    toast('$name removed', kind: ToastKind.success);
  }

  /// Two asks at once: the page queues them, one after the other.
  Future<void> askTwice() async {
    final a = confirm('First');
    final b = confirm('Second');
    log.value = 'both ${await a} ${await b}';
  }

  void say(String message) => toast(message);

  void fail() => toast('Failed', kind: ToastKind.error);

  String logText() => log.value;
}

final feedback = FeedbackState();
