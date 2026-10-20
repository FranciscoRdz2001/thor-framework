// Adversarial: the listener semantics of Flutter's ChangeNotifier
// (flutter/flutter packages/flutter/test/foundation/change_notifier_test.dart)
// on both notifiers here: `ChangeNotifier` and a `StateSignal`.
import 'dart:async';

import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart';

class _Notifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// What each notifier gives a test: add, remove, fire, hasListeners.
class _Sut {
  _Sut(this.add, this.remove, this.fire, this.has);
  final void Function(void Function()) add;
  final void Function(void Function()) remove;
  final void Function() fire;
  final bool Function() has;
}

_Sut _changeNotifier() {
  final n = _Notifier();
  return _Sut(n.addListener, n.removeListener, n.notify, () => n.hasListeners);
}

_Sut _stateSignal() {
  final n = state(0);
  var next = 0;
  return _Sut(
    n.addListener,
    n.removeListener,
    () => n.value = ++next,
    () => n.hasListeners,
  );
}

void main() {
  for (final entry in {
    'ChangeNotifier': _changeNotifier,
    'StateSignal': _stateSignal,
  }.entries) {
    group(entry.key, () {
      test('Flutter: a listener that removes two others and adds one', () {
        final n = entry.value();
        final log = <String>[];
        void l1() => log.add('l1');
        void l3() => log.add('l3');
        void l4() => log.add('l4');
        void l2() {
          log.add('l2');
          n.remove(l1);
          n.remove(l3);
          n.add(l4);
        }

        n
          ..add(l1)
          ..add(l2)
          ..add(l3)
          ..fire();
        expect(log, ['l1', 'l2']);
        log.clear();
        n.fire();
        expect(log, ['l2', 'l4']);
        log.clear();
        n.fire();
        expect(log, ['l2', 'l4', 'l4']);
      });

      test('Flutter: added and removed at once, only the last is heard next '
          'time', () {
        final n = entry.value();
        final log = <String>[];
        void l3() => log.add('l3');
        void l2() => log.add('l2');
        void l1() {
          log.add('l1');
          n
            ..add(l2)
            ..remove(l2)
            ..add(l3);
        }

        n
          ..add(l1)
          ..fire();
        expect(log, ['l1']);
      });

      test('a listener removed and added back by an earlier one is skipped '
          'this time (its old place is gone)', () {
        final n = entry.value();
        final log = <String>[];
        late void Function() b;
        void a() {
          log.add('a');
          n
            ..remove(b)
            ..add(b);
        }

        b = () => log.add('b');
        n
          ..add(a)
          ..add(b)
          ..fire();
        expect(log, ['a']);
        log.clear();
        n.remove(a);
        n.fire();
        expect(log, ['b']);
      });

      test(
        'a listener that throws is reported and the others still run',
        () async {
          final n = entry.value();
          final log = <String>[];
          final errors = <Object>[];
          await runZonedGuarded(() async {
            n
              ..add(() => log.add('a'))
              ..add(() => throw StateError('boom'))
              ..add(() => log.add('c'))
              ..fire();
            await Future<void>.delayed(Duration.zero);
            // and it keeps working afterwards
            log.clear();
            n.fire();
            await Future<void>.delayed(Duration.zero);
          }, (e, s) => errors.add(e));
          expect(log, ['a', 'c']);
          expect(errors, hasLength(2));
          expect(errors.first, isA<StateError>());
        },
      );

      test('removing a listener that was never added, twice, is harmless', () {
        final n = entry.value();
        n
          ..remove(() {})
          ..remove(() {});
        expect(n.has(), isFalse);
      });

      test('a listener that removes itself in the middle: the rest still '
          'hear it', () {
        final n = entry.value();
        final log = <String>[];
        late void Function() b;
        b = () {
          log.add('b');
          n.remove(b);
        };
        n
          ..add(() => log.add('a'))
          ..add(b)
          ..add(() => log.add('c'))
          ..fire();
        expect(log, ['a', 'b', 'c']);
        log.clear();
        n.fire();
        expect(log, ['a', 'c']);
        expect(n.has(), isTrue);
      });

      test('hasListeners is false once the last one leaves, even inside a '
          'notification', () {
        final n = entry.value();
        var inside = true;
        late void Function() only;
        only = () {
          n.remove(only);
          inside = n.has();
        };
        n
          ..add(only)
          ..fire();
        expect(inside, isFalse);
        expect(n.has(), isFalse);
      });
    });
  }
}
