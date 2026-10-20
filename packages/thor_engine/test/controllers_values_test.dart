// The controllers as plain values on the server (the browser side is in
// thor_engine_oracle's client tests and the lite parts).
import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart';

class _Driver implements ScrollDriver {
  final calls = <String>[];
  bool view = true;
  @override
  bool get hasView => view;
  @override
  void jumpTo(double offset) => calls.add('jump $offset');
  @override
  Future<void> animateTo(
    double offset,
    Duration duration,
    String? easing,
  ) async => calls.add('animate $offset ${duration.inMilliseconds} $easing');
}

/// What a thor_style `Curve` is to the controller: an object with a CSS
/// easing.
class _Curve {
  const _Curve(this.css);
  final String css;
}

void main() {
  group('FocusNode listeners', () {
    test('a listener hears each change, and hasFocus is already new', () {
      final n = FocusNode();
      final seen = <bool>[];
      n.addListener(() => seen.add(n.hasFocus));
      n.updateFocus(true);
      n.updateFocus(true);
      n.updateFocus(false);
      expect(seen, [true, false], reason: 'a repeat is not a change');
    });

    test('removeListener stops it; others keep hearing', () {
      final n = FocusNode();
      var a = 0, b = 0;
      void la() => a++;
      void lb() => b++;
      n
        ..addListener(la)
        ..addListener(lb);
      n.updateFocus(true);
      n.removeListener(la);
      n.updateFocus(false);
      expect((a, b), (1, 2));
    });

    test('a listener may remove itself while it is called', () {
      final n = FocusNode();
      var calls = 0;
      late void Function() once;
      once = () {
        calls++;
        n.removeListener(once);
      };
      var other = 0;
      n
        ..addListener(once)
        ..addListener(() => other++);
      n.updateFocus(true);
      n.updateFocus(false);
      expect((calls, other), (1, 2));
    });

    test('a listener that throws does not cut the others', () {
      final n = FocusNode();
      var heard = 0;
      n
        ..addListener(() => throw StateError('boom'))
        ..addListener(() => heard++);
      n.updateFocus(true);
      expect(heard, 1);
    });

    test('hasFocus stays tracked', () {
      final n = FocusNode();
      var runs = 0;
      final stop = effect(() {
        n.hasFocus;
        runs++;
      });
      n.updateFocus(true);
      expect(runs, 2);
      stop();
    });

    test('dispose forgets the listeners', () {
      final n = FocusNode();
      var calls = 0;
      n.addListener(() => calls++);
      n.dispose();
      n.updateFocus(true);
      expect(calls, 0);
    });
  });

  group('FocusNode listeners (adversarial)', () {
    test('one removed by an earlier listener in the same dispatch is not '
        'called; one added during it waits for the next', () {
      final n = FocusNode();
      final log = <String>[];
      void second() => log.add('second');
      void late() => log.add('late');
      void first() {
        log.add('first');
        n
          ..removeListener(second)
          ..addListener(late);
      }

      n
        ..addListener(first)
        ..addListener(second);
      n.updateFocus(true);
      expect(log, ['first']);
      n.updateFocus(false);
      expect(log, ['first', 'first', 'late']);
    });

    test('added twice it is called twice; a removal takes one', () {
      final n = FocusNode();
      var calls = 0;
      void f() => calls++;
      n
        ..addListener(f)
        ..addListener(f);
      n.updateFocus(true);
      expect(calls, 2);
      n.removeListener(f);
      n.updateFocus(false);
      expect(calls, 3);
    });

    test('addListener after dispose throws (Flutter asserts); removing is '
        'allowed', () {
      final n = FocusNode()..dispose();
      expect(() => n.addListener(() {}), throwsStateError);
      expect(() => n.removeListener(() {}), returnsNormally);
      n.dispose();
    });
  });

  group('TextEditingController equal values', () {
    test('the same selection or value is not a change', () {
      final c = TextEditingController(text: 'Ana');
      c.selection = const TextSelection.collapsed(offset: 1);
      var runs = 0;
      final stop = effect(() {
        c.value;
        runs++;
      });
      c.selection = const TextSelection.collapsed(offset: 1);
      c.value = c.value;
      c.value = const TextEditingValue(
        text: 'Ana',
        selection: TextSelection.collapsed(offset: 1),
      );
      expect(runs, 1);
      c.selection = const TextSelection.collapsed(offset: 99);
      expect(runs, 2, reason: 'a clamped one is a new one');
      c.selection = const TextSelection.collapsed(offset: 3);
      expect(runs, 2, reason: '99 was clamped to 3');
      stop();
    });
  });

  group('PageController', () {
    PageController measured({int initialPage = 0, double viewport = 400}) {
      final c = PageController(initialPage: initialPage);
      c.updatePosition(
        pixels: 0,
        viewportDimension: viewport,
        maxScrollExtent: viewport * 4,
      );
      return c;
    }

    test('is a ScrollController: offset, position and hasClients', () {
      final c = PageController();
      expect(c, isA<ScrollController>());
      expect(c, isA<ThorController>());
      expect(c.hasClients, isFalse);
      expect(c.offset, 0);
      expect(c.initialPage, 0);
    });

    test('page is the offset in viewports, tracked', () {
      final c = measured();
      expect(c.page, 0);
      var runs = 0;
      final stop = effect(() {
        c.page;
        runs++;
      });
      c.updatePosition(
        pixels: 600,
        viewportDimension: 400,
        maxScrollExtent: 1600,
      );
      expect(c.page, 1.5);
      expect(runs, 2);
      stop();
    });

    test('before the view is measured, page is the initial page', () {
      expect(PageController().page, 0);
      expect(PageController(initialPage: 3).page, 3);
    });

    test('jumpToPage goes to page * viewport', () {
      final c = measured();
      final d = _Driver();
      c.attachDriver(d);
      c.jumpToPage(2);
      expect(d.calls, ['jump 800.0']);
      expect(c.offset, 800);
      expect(c.page, 2);
    });

    test('animateToPage asks the view and waits for it, with the duration '
        'and the curve', () async {
      final c = measured();
      final d = _Driver();
      c.attachDriver(d);
      await c.animateToPage(
        3,
        duration: const Duration(milliseconds: 300),
        curve: const _Curve('ease'),
      );
      expect(d.calls, ['animate 1200.0 300 ease']);
    });

    test('without a view jumpToPage is kept for when it comes', () {
      final c = PageController();
      c.jumpToPage(2);
      expect(c.page, 2, reason: 'asked for, not measured yet');
      expect(c.takeStart(400), 800);
      expect(c.takeStart(400), isNull, reason: 'once');
    });

    test('the initial page is where the view starts', () {
      final c = PageController(initialPage: 3);
      expect(c.takeStart(500), 1500);
      expect(c.takeStart(500), isNull);
      expect(PageController().takeStart(500), isNull);
    });

    test('an unmeasured view (0 wide) keeps the page for later', () {
      final c = PageController(initialPage: 1);
      final d = _Driver();
      c.attachDriver(d);
      c.jumpToPage(2);
      expect(d.calls, isEmpty);
      expect(c.takeStart(0), isNull, reason: 'still hidden');
      expect(c.takeStart(300), 600);
    });

    test('viewportFraction other than 1 is refused with the reason', () {
      expect(
        () => PageController(viewportFraction: 0.8),
        throwsA(
          isA<ArgumentError>().having(
            (e) => '$e',
            'message',
            contains('viewportFraction'),
          ),
        ),
      );
      expect(PageController(viewportFraction: 1), isNotNull);
    });
  });

  group('ScrollController.initialScrollOffset reaches the view', () {
    test('takeStart gives it once', () {
      final c = ScrollController(initialScrollOffset: 40);
      expect(c.takeStart(300), 40);
      expect(c.takeStart(300), isNull);
      expect(ScrollController().takeStart(300), isNull);
    });
  });
}
