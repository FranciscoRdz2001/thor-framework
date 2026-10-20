// `confirm()` and `toast()` from a state method: what the engine
// answers when nothing (a test, the server) has installed a handler.
import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart';

class OrdersState extends ThorState {
  final orders = state(<int>[1, 2, 3]);

  Future<void> remove(int id) async {
    if (!await confirm('Delete order?', message: 'This cannot be undone')) {
      return;
    }
    orders.value = [
      for (final o in orders.value)
        if (o != id) o,
    ];
    toast('Deleted', kind: ToastKind.success);
  }
}

void main() {
  tearDown(() {
    ThorFeedback.confirmHandler = null;
    ThorFeedback.toastHandler = null;
    ThorFeedback.toastHideHandler = null;
  });

  group('confirm', () {
    test('without a dialog it is a no, so nothing destructive runs', () async {
      final s = OrdersState();
      await s.remove(2);
      expect(s.orders.value, [1, 2, 3]);
    });

    test('a handler answers with the spec of the call', () async {
      final asked = <ConfirmSpec>[];
      ThorFeedback.confirmHandler = (spec) async {
        asked.add(spec);
        return true;
      };
      final s = OrdersState();
      await s.remove(2);
      expect(s.orders.value, [1, 3]);
      expect(asked.single.title, 'Delete order?');
      expect(asked.single.message, 'This cannot be undone');
      expect(asked.single.confirmLabel, isNull);
    });

    test('a handler that throws is a no', () async {
      ThorFeedback.confirmHandler = (_) => throw StateError('gone');
      expect(await confirm('x'), isFalse);
    });

    test('two asks at once are two asks (the page queues them)', () async {
      final answers = <String>[];
      ThorFeedback.confirmHandler = (spec) async => spec.title == 'a';
      final both = await Future.wait([confirm('a'), confirm('b')]);
      answers.addAll(both.map((b) => '$b'));
      expect(answers, ['true', 'false']);
    });
  });

  group('toast', () {
    test('without a page it does nothing', () {
      expect(() => toast('Saved'), returnsNormally);
    });

    test('a handler gets the message, kind and duration', () async {
      final shown = <(String, ToastKind, Duration?)>[];
      ThorFeedback.toastHandler = (m, k, d) => shown.add((m, k, d));
      final s = OrdersState();
      ThorFeedback.confirmHandler = (_) async => true;
      await s.remove(1);
      toast('Saved', duration: const Duration(seconds: 9));
      expect(shown, [
        ('Deleted', ToastKind.success, null),
        ('Saved', ToastKind.info, const Duration(seconds: 9)),
      ]);
    });

    test('an empty message is never shown', () {
      var calls = 0;
      ThorFeedback.toastHandler = (_, _, _) => calls++;
      toast('');
      toast('   ');
      expect(calls, 0);
    });
  });

  group('hideToast and clearToasts', () {
    test('without a page they do nothing', () {
      expect(hideToast, returnsNormally);
      expect(clearToasts, returnsNormally);
    });

    test('hideToast asks the page to end the one showing, clearToasts '
        'also the ones waiting', () {
      final asked = <bool>[];
      ThorFeedback.toastHideHandler = asked.add;
      hideToast();
      clearToasts();
      expect(asked, [false, true]);
    });
  });

  test('ConfirmSpec keeps what it was given', () {
    const spec = ConfirmSpec(
      'Delete',
      message: 'Sure?',
      confirmLabel: 'Yes',
      cancelLabel: 'No',
    );
    expect(
      [spec.title, spec.message, spec.confirmLabel, spec.cancelLabel],
      ['Delete', 'Sure?', 'Yes', 'No'],
    );
  });
}
