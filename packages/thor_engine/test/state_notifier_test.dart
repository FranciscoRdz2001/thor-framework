// A StateSignal is a Flutter ValueNotifier.
import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart';

void main() {
  test(
    'a StateSignal is a ValueNotifier: listeners hear real changes only',
    () {
      final count = state(0);
      final ValueNotifier<int> notifier = count;
      final heard = <int>[];
      void listener() => heard.add(notifier.value);
      notifier.addListener(listener);
      expect(count.hasListeners, isTrue);
      count.value = 1;
      count.value = 1; // equal: nobody hears it
      notifier.value = 2; // through the interface
      expect(heard, [1, 2]);
      notifier.removeListener(listener);
      count.value = 3;
      expect(heard, [1, 2]);
      expect(count.hasListeners, isFalse);
    },
  );

  test('a listener removed by an earlier one is skipped; one added waits', () {
    final n = state(0);
    final log = <String>[];
    late void Function() b;
    void a() {
      log.add('a');
      n.removeListener(b);
      n.addListener(() => log.add('late'));
    }

    b = () => log.add('b');
    n.addListener(a);
    n.addListener(b);
    n.value = 1;
    expect(log, ['a']);
    n.value = 2;
    expect(log, ['a', 'a', 'late']);
  });

  test('the same listener added twice runs twice; removing takes one', () {
    final n = state(0);
    var calls = 0;
    void l() => calls++;
    n
      ..addListener(l)
      ..addListener(l);
    n.value = 1;
    expect(calls, 2);
    n
      ..removeListener(l)
      ..value = 2;
    expect(calls, 3);
    n.removeListener(() {}); // not there: fine
  });

  test('addListener after dispose throws; the rest is safe', () {
    final n = state(0)..addListener(() {});
    n.dispose();
    expect(n.hasListeners, isFalse);
    expect(() => n.addListener(() {}), throwsStateError);
    n
      ..removeListener(() {})
      ..notifyListeners()
      ..dispose();
    n.value = 1; // still a signal
    expect(n.value, 1);
  });

  test('a request scope writes nobody hears (nothing is shared)', () {
    final n = state(0);
    var calls = 0;
    n.addListener(() => calls++);
    SignalScope.run(() => n.value = 5);
    expect(calls, 0);
    expect(n.value, 0);
  });

  test('a ChangeNotifier skips a listener removed meanwhile', () {
    final c = ChangeNotifier();
    final log = <String>[];
    late void Function() b;
    c.addListener(() {
      log.add('a');
      c.removeListener(b);
    });
    b = () => log.add('b');
    c.addListener(b);
    c.notifyListeners();
    expect(log, ['a']);
  });
}
