// ScrollController.animateTo and TextEditingController.selection, as
// plain values on the server (the browser side is in the lite parts).
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
  group('ScrollController.animateTo', () {
    test('without a view it sets the offset, like jumpTo', () async {
      final c = ScrollController();
      await c.animateTo(
        120,
        duration: Duration.zero,
        curve: const _Curve('ease'),
      );
      expect(c.offset, 120);
    });

    test('a negative offset is 0', () async {
      final c = ScrollController(initialScrollOffset: 50);
      await c.animateTo(
        -10,
        duration: Duration.zero,
        curve: const _Curve('ease'),
      );
      expect(c.offset, 0);
    });

    test('with a view it asks the view, and waits for it', () async {
      final c = ScrollController();
      final d = _Driver();
      c.attachDriver(d);
      await c.animateTo(
        80,
        duration: const Duration(milliseconds: 250),
        curve: const _Curve('ease'),
      );
      expect(d.calls, ['animate 80.0 250 ease']);
    });

    test(
      'the curve is CSS easing: linear is none; a non-curve is refused',
      () async {
        final c = ScrollController();
        final d = _Driver();
        c.attachDriver(d);
        await c.animateTo(
          1,
          duration: Duration.zero,
          curve: const _Curve('linear'),
        );
        expect(d.calls, ['animate 1.0 0 null']);
        expect(
          () => c.animateTo(1, duration: Duration.zero, curve: 'ease'),
          throwsArgumentError,
        );
      },
    );

    test('initialScrollOffset is where it starts', () {
      expect(ScrollController(initialScrollOffset: 40).offset, 40);
    });
  });

  group('ScrollController.hasClients', () {
    test('is false without a driver (the server)', () {
      expect(ScrollController().hasClients, isFalse);
    });

    test('follows whether the driver has a view', () {
      final c = ScrollController();
      final d = _Driver();
      c.attachDriver(d);
      expect(c.hasClients, isTrue);
      d.view = false;
      expect(c.hasClients, isFalse);
      d.view = true;
      c.attachDriver(null);
      expect(c.hasClients, isFalse);
    });
  });

  group('TextSelection', () {
    test('collapsed, ordered and valid', () {
      const c = TextSelection.collapsed(offset: 3);
      expect(c.isCollapsed, isTrue);
      expect((c.baseOffset, c.extentOffset, c.start, c.end), (3, 3, 3, 3));
      const back = TextSelection(baseOffset: 5, extentOffset: 2);
      expect((back.start, back.end), (2, 5));
      expect(back.isCollapsed, isFalse);
      expect(back.isValid, isTrue);
      expect(const TextSelection.collapsed(offset: -1).isValid, isFalse);
    });

    test('== by value', () {
      expect(
        const TextSelection(baseOffset: 1, extentOffset: 2),
        const TextSelection(baseOffset: 1, extentOffset: 2),
      );
      expect(
        const TextSelection(baseOffset: 1, extentOffset: 2),
        isNot(const TextSelection(baseOffset: 2, extentOffset: 1)),
      );
    });
  });

  group('TextEditingValue', () {
    test('holds the text and the selection, == by value', () {
      const v = TextEditingValue(
        text: 'Ana',
        selection: TextSelection.collapsed(offset: 1),
      );
      expect(v.text, 'Ana');
      expect(v.selection, const TextSelection.collapsed(offset: 1));
      expect(
        v,
        const TextEditingValue(
          text: 'Ana',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      expect(v, isNot(const TextEditingValue(text: 'Ana')));
      expect(v.hashCode, v.copyWith().hashCode);
    });

    test('empty and the default selection are invalid, like Flutter', () {
      expect(TextEditingValue.empty.text, '');
      expect(TextEditingValue.empty.selection.isValid, isFalse);
      expect(const TextEditingValue(text: 'x').selection.isValid, isFalse);
    });

    test('copyWith changes only what it is given', () {
      const v = TextEditingValue(
        text: 'Ana',
        selection: TextSelection.collapsed(offset: 3),
      );
      expect(v.copyWith(text: 'Maria').selection, v.selection);
      expect(
        v.copyWith(selection: const TextSelection.collapsed(offset: 0)).text,
        'Ana',
      );
    });
  });

  group('TextEditingController.value', () {
    test('reads the text and the selection together', () {
      final c = TextEditingController(text: 'Ana');
      expect(c.value.text, 'Ana');
      expect(c.value.selection.isValid, isFalse);
      c.selection = const TextSelection(baseOffset: 0, extentOffset: 2);
      expect(c.value.selection, c.selection);
    });

    test('set puts both at once', () {
      final c = TextEditingController(text: 'Ana');
      var runs = 0;
      final stop = effect(() {
        c.value;
        runs++;
      });
      c.value = const TextEditingValue(
        text: 'Maria',
        selection: TextSelection(baseOffset: 1, extentOffset: 3),
      );
      expect(runs, 2, reason: 'text and selection are one change');
      expect(c.text, 'Maria');
      expect(c.selection, const TextSelection(baseOffset: 1, extentOffset: 3));
      stop();
    });

    test('the selection is kept inside the text', () {
      final c = TextEditingController(text: 'Ana');
      c.value = const TextEditingValue(
        text: 'Al',
        selection: TextSelection.collapsed(offset: 9),
      );
      expect(c.selection, const TextSelection.collapsed(offset: 2));
    });

    test('a new text with no selection puts the caret at its end (web)', () {
      final c = TextEditingController(text: 'Ana');
      c.value = const TextEditingValue(text: 'Maria');
      expect(c.selection, const TextSelection.collapsed(offset: 5));
    });

    test('the same text with no selection leaves the selection invalid', () {
      final c = TextEditingController(text: 'Ana');
      c.selection = const TextSelection.collapsed(offset: 1);
      c.value = const TextEditingValue(text: 'Ana');
      expect(c.selection.isValid, isFalse);
    });

    test('is tracked', () {
      final c = TextEditingController(text: 'Ana');
      var runs = 0;
      final stop = effect(() {
        c.value;
        runs++;
      });
      c.text = 'Maria';
      expect(runs, 2);
      c.selection = const TextSelection.collapsed(offset: 1);
      expect(runs, 3);
      stop();
    });
  });

  group('TextEditingController.selection', () {
    test('starts invalid, like Flutter', () {
      final c = TextEditingController(text: 'Ana');
      expect(c.selection.isValid, isFalse);
      expect(c.selection.baseOffset, -1);
    });

    test('set keeps it inside the text', () {
      final c = TextEditingController(text: 'Ana');
      c.selection = const TextSelection(baseOffset: 1, extentOffset: 2);
      expect((c.selection.baseOffset, c.selection.extentOffset), (1, 2));
      c.selection = const TextSelection.collapsed(offset: 99);
      expect(c.selection.baseOffset, 3);
      c.selection = const TextSelection(baseOffset: 0, extentOffset: 99);
      expect((c.selection.baseOffset, c.selection.extentOffset), (0, 3));
      // A negative end is an invalid selection (Flutter's), not a clamp.
      c.selection = const TextSelection(baseOffset: -5, extentOffset: 2);
      expect(c.selection.isValid, isFalse);
    });

    test('an invalid selection stays invalid', () {
      final c = TextEditingController(text: 'Ana');
      c.selection = const TextSelection.collapsed(offset: -1);
      expect(c.selection.isValid, isFalse);
    });

    test('changing the text puts the caret at its end (web)', () {
      final c = TextEditingController(text: 'Ana');
      c.text = 'Maria';
      expect(c.selection, const TextSelection.collapsed(offset: 5));
      c.clear();
      expect(c.selection, const TextSelection.collapsed(offset: 0));
    });

    test('the same text again keeps the selection', () {
      final c = TextEditingController(text: 'Ana');
      c.selection = const TextSelection.collapsed(offset: 1);
      c.text = 'Ana';
      expect(c.selection, const TextSelection.collapsed(offset: 1));
      c.text = 'Anas';
      expect(c.selection, const TextSelection.collapsed(offset: 4));
    });

    test('the selection is tracked', () {
      final c = TextEditingController(text: 'Ana');
      var runs = 0;
      final stop = effect(() {
        c.selection;
        runs++;
      });
      c.selection = const TextSelection.collapsed(offset: 1);
      expect(runs, 2);
      stop();
    });
  });
}
