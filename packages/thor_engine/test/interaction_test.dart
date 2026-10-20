import 'package:test/test.dart';
import 'package:thor_engine/src/keyboard.dart' show physicalKeyName;
import 'package:thor_engine/thor_engine.dart';

class _Scroll implements ScrollDriver {
  final jumps = <double>[];
  @override
  bool get hasView => true;
  @override
  void jumpTo(double offset) => jumps.add(offset);
  @override
  Future<void> animateTo(
    double offset,
    Duration duration,
    String? easing,
  ) async => jumps.add(offset);
}

class _Focus implements FocusDriver {
  var requests = 0;
  var blurs = 0;
  @override
  void requestFocus() => requests++;
  @override
  void unfocus() => blurs++;
}

void main() {
  group('shortcuts', () {
    test('specs match exact modifiers, any letter case, repeats', () {
      const undo = SingleActivator(LogicalKeyboardKey.keyZ, meta: true);
      expect(undo.spec, 'm+z');
      bool hit(
        String spec,
        String key, {
        bool shift = false,
        bool meta = false,
        bool repeat = false,
      }) => shortcutMatches(
        spec,
        key,
        control: false,
        shift: shift,
        alt: false,
        meta: meta,
        repeat: repeat,
      );
      expect(hit(undo.spec, 'z', meta: true), isTrue);
      expect(hit(undo.spec, 'Z', meta: true), isTrue);
      expect(hit(undo.spec, 'z'), isFalse);
      expect(hit(undo.spec, 'z', meta: true, shift: true), isFalse);
      const once = SingleActivator(
        LogicalKeyboardKey.enter,
        includeRepeats: false,
      );
      expect(hit(once.spec, 'Enter'), isTrue);
      expect(hit(once.spec, 'Enter', repeat: true), isFalse);
      expect(hit('garbage', 'z'), isFalse);
      expect(
        const SingleActivator(
          LogicalKeyboardKey.space,
          control: true,
          shift: true,
        ).spec,
        'cs+ ',
      );
    });

    test('skipWithTextSelection leaves the key to the browser', () {
      const copy = SingleActivator(
        LogicalKeyboardKey.keyC,
        meta: true,
        skipWithTextSelection: true,
      );
      expect(copy.spec, 'mt+c');
      bool hit(String spec, {required bool selected}) => shortcutMatches(
        spec,
        'c',
        control: false,
        shift: false,
        alt: false,
        meta: true,
        textSelected: selected,
      );
      expect(hit(copy.spec, selected: false), isTrue);
      expect(hit(copy.spec, selected: true), isFalse);
      // Without the flag the selection does not matter.
      expect(hit('m+c', selected: true), isTrue);
      expect(
        const CharacterActivator('c', skipWithTextSelection: true).spec,
        't=99',
      );
    });

    test('CharacterActivator: the character typed, case-sensitive, Shift '
        'ignored; any printable character', () {
      const question = CharacterActivator('?');
      const semicolon = CharacterActivator(';', control: true);
      expect(question.spec, '=63');
      expect(semicolon.spec, 'c=59', reason: 'no ; or > in the page form');
      bool hit(
        String spec,
        String key, {
        bool control = false,
        bool shift = false,
      }) => shortcutMatches(
        spec,
        key,
        control: control,
        shift: shift,
        alt: false,
        meta: false,
      );
      expect(hit(question.spec, '?', shift: true), isTrue);
      expect(hit(question.spec, '/'), isFalse);
      expect(hit(semicolon.spec, ';', control: true), isTrue);
      expect(hit(semicolon.spec, ';'), isFalse);
      expect(hit(const CharacterActivator('a').spec, 'A'), isFalse);
      expect(decodeShortcuts(encodeShortcuts({semicolon.spec: 'G.x'})), [
        (semicolon.spec, 'G.x'),
      ]);
      bool printable(
        String k, {
        bool c = false,
        bool a = false,
        bool m = false,
      }) => isPrintableKey(k, control: c, alt: a, meta: m);
      expect(printable('a'), isTrue);
      expect(printable('€', c: true, a: true), isTrue, reason: 'AltGr');
      expect(printable('😀'), isTrue);
      expect(printable('c', m: true), isFalse);
      expect(printable('c', c: true), isFalse);
      expect(printable('Enter'), isFalse);
      expect(printable('Dead'), isFalse);
      expect(printable('\t'), isFalse);
    });

    test('bindings round-trip, in order', () {
      final encoded = encodeShortcuts({
        '+arrowdown': 'G.down',
        'm+z': 'G.go~3',
      });
      expect(decodeShortcuts(encoded), [
        ('+arrowdown', 'G.down'),
        ('m+z', 'G.go~3'),
      ]);
      expect(decodeShortcuts(''), isEmpty);
      expect(decodeShortcuts('nothing'), isEmpty);
    });

    test("every letter and digit has Flutter's name and its DOM key", () {
      const letters = [
        LogicalKeyboardKey.keyA,
        LogicalKeyboardKey.keyB,
        LogicalKeyboardKey.keyC,
        LogicalKeyboardKey.keyD,
        LogicalKeyboardKey.keyE,
        LogicalKeyboardKey.keyF,
        LogicalKeyboardKey.keyG,
        LogicalKeyboardKey.keyH,
        LogicalKeyboardKey.keyI,
        LogicalKeyboardKey.keyJ,
        LogicalKeyboardKey.keyK,
        LogicalKeyboardKey.keyL,
        LogicalKeyboardKey.keyM,
        LogicalKeyboardKey.keyN,
        LogicalKeyboardKey.keyO,
        LogicalKeyboardKey.keyP,
        LogicalKeyboardKey.keyQ,
        LogicalKeyboardKey.keyR,
        LogicalKeyboardKey.keyS,
        LogicalKeyboardKey.keyT,
        LogicalKeyboardKey.keyU,
        LogicalKeyboardKey.keyV,
        LogicalKeyboardKey.keyW,
        LogicalKeyboardKey.keyX,
        LogicalKeyboardKey.keyY,
        LogicalKeyboardKey.keyZ,
      ];
      expect(
        letters.map((k) => k.keyLabel).join(),
        'abcdefghijklmnopqrstuvwxyz',
      );
      const digits = [
        LogicalKeyboardKey.digit0,
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
        LogicalKeyboardKey.digit5,
        LogicalKeyboardKey.digit6,
        LogicalKeyboardKey.digit7,
        LogicalKeyboardKey.digit8,
        LogicalKeyboardKey.digit9,
      ];
      expect(digits.map((k) => k.keyLabel).join(), '0123456789');
      expect(
        [
          LogicalKeyboardKey.slash,
          LogicalKeyboardKey.period,
          LogicalKeyboardKey.comma,
          LogicalKeyboardKey.minus,
          LogicalKeyboardKey.equal,
          LogicalKeyboardKey.add,
        ].map((k) => k.keyLabel),
        ['/', '.', ',', '-', '=', '+'],
      );
      // ⌘K: its page form, and a keydown of `k` with Meta matches it.
      const palette = SingleActivator(LogicalKeyboardKey.keyK, meta: true);
      expect(palette.spec, 'm+k');
      expect(
        shortcutMatches(
          palette.spec,
          'k',
          control: false,
          shift: false,
          alt: false,
          meta: true,
        ),
        isTrue,
      );
      expect(
        const SingleActivator(LogicalKeyboardKey.digit1, control: true).spec,
        'c+1',
      );
      expect(const SingleActivator(LogicalKeyboardKey.slash).spec, '+/');
    });

    test('keys compare by their label, ignoring case', () {
      expect(const LogicalKeyboardKey('Z'), LogicalKeyboardKey.keyZ);
      expect(HardwareKeyboard.instance.isShiftPressed, isFalse);
    });

    test('a non-Latin key falls back to its physical letter or digit; a '
        'Latin one never does', () {
      const save = SingleActivator(LogicalKeyboardKey.keyS, meta: true);
      const first = SingleActivator(LogicalKeyboardKey.digit1, control: true);
      bool hit(
        String spec,
        String key,
        String code, {
        bool control = false,
        bool meta = false,
      }) => shortcutMatches(
        spec,
        key,
        control: control,
        shift: false,
        alt: false,
        meta: meta,
        code: code,
      );
      expect(hit(save.spec, 'ы', 'KeyS', meta: true), isTrue, reason: 'ru');
      expect(hit(save.spec, 'σ', 'KeyS', meta: true), isTrue, reason: 'el');
      expect(hit(save.spec, 'ы', 'KeyS'), isFalse, reason: 'modifiers');
      expect(hit(save.spec, 'ф', 'KeyA', meta: true), isFalse);
      expect(hit(first.spec, 'ש', 'Digit1', control: true), isTrue);
      expect(
        hit(save.spec, 'o', 'KeyS', meta: true),
        isFalse,
        reason: "Dvorak's o on KeyS is an o",
      );
      expect(hit(save.spec, 's', 'KeyO', meta: true), isTrue);
      expect(hit('+semicolon', 'ж', 'Semicolon'), isFalse);
      expect(physicalKeyName('ы', 'KeyS'), 's');
      expect(physicalKeyName('ArrowUp', 'ArrowUp'), isNull);
      expect(
        shortcutMatches(
          '=1099',
          'ы',
          control: false,
          shift: false,
          alt: false,
          meta: false,
          code: 'KeyS',
        ),
        isTrue,
        reason: 'CharacterActivator keeps the character typed',
      );
    });
  });

  group('intents and key events', () {
    test('an intent is named by its class, generics made plain', () {
      expect(intentName(const _Save()), '_Save');
      expect(intentName(_Save), '_Save');
      expect(intentName(_Move<int>), r'_Move_int_');
      expect(intentName(const _Move<int>()), r'_Move_int_');
    });

    test('Actions: the id of an intent, DoNothingAction empty or "!"', () {
      final a = encodeActions({'Save': 'E.save', 'Off': '', 'Pass': '!'});
      expect(a, 'Save>E.save;Off>;Pass>!');
      expect(actionFor(a, 'Save'), 'E.save');
      expect(actionFor(a, 'Off'), '');
      expect(actionFor(a, 'Pass'), ignoreKeyAction);
      expect(actionFor(a, 'Sav'), isNull);
    });

    test('a keydown goes to the page and back as a KeyEvent', () {
      KeyEvent round(String key, String code, {bool repeat = false}) =>
          KeyEvent.decode(encodeKeyEvent(key, code, repeat: repeat));
      final enter = round('Enter', 'Enter');
      expect(enter, isA<KeyDownEvent>());
      expect(enter.logicalKey, LogicalKeyboardKey.enter);
      expect(enter.character, isNull);
      final shiftA = round('A', 'KeyA', repeat: true);
      expect(shiftA, isA<KeyRepeatEvent>());
      expect(shiftA.logicalKey.keyLabel, 'a', reason: 'like the constants');
      expect(shiftA.character, 'A');
      final cyrillic = round('ы', 'KeyS');
      expect(cyrillic.logicalKey, LogicalKeyboardKey.keyS);
      expect(cyrillic.character, 'ы');
      expect(round(' ', 'Space').logicalKey, LogicalKeyboardKey.space);
      expect(round('~', 'Backquote').character, '~');
      expect(encodeKeyEvent('ArrowUp', 'ArrowUp'), '[0,"ArrowUp",null]');
    });
  });

  group('variables', () {
    test('names and values are sanitized', () {
      expect(isCssVariableName('--w-1_x'), isTrue);
      for (final bad in ['w', '--', '--a;b', '--a:b', '--a b', 'color']) {
        expect(isCssVariableName(bad), isFalse, reason: bad);
      }
      expect(cssPxValue(12), '12px');
      expect(cssPxValue(12.345), '12.35px');
      expect(cssPxValue(double.nan), '0px');
      expect(cssPxValue(double.infinity), '0px');
      expect(decodeVariables('--a:G.x;--b:G.y~2;junk'), [
        ('--a', 'G.x'),
        ('--b', 'G.y~2'),
      ]);
    });
  });

  group('controllers', () {
    test(
      'ScrollController: position from the page, jumps through the driver',
      () {
        final c = ScrollController(initialScrollOffset: 10);
        expect(c.offset, 10);
        expect(c.hasClients, isFalse);
        c.jumpTo(20);
        expect(c.offset, 20, reason: 'no element: the value still moves');
        final d = _Scroll();
        c.attachDriver(d);
        c.jumpTo(30);
        expect(d.jumps, [30]);
        final seen = <double>[];
        final stop = effect(
          () => seen.add(c.position.pixels + c.position.viewportDimension),
        );
        c.updatePosition(
          pixels: 5,
          viewportDimension: 100,
          maxScrollExtent: 900,
        );
        expect(seen, [30, 105], reason: 'one update for the three values');
        expect(c.position.maxScrollExtent, 900);
        stop();
      },
    );

    test('TextEditingController is a signal', () {
      final c = TextEditingController(text: 'a');
      final seen = <String>[];
      final stop = effect(() => seen.add(c.text));
      c.text = 'b';
      c.clear();
      expect(seen, ['a', 'b', '']);
      stop();
    });

    test(
      'FocusNode asks after the current task, and only with an element',
      () async {
        final n = FocusNode();
        n.requestFocus(); // no element: nothing to do
        final d = _Focus();
        n.attachDriver(d);
        n.requestFocus();
        expect(d.requests, 0);
        await Future<void>.delayed(Duration.zero);
        expect(d.requests, 1);
        n.unfocus();
        expect(d.blurs, 1);
        n.updateFocus(true);
        expect(n.hasFocus, isTrue);
      },
    );

    test('SystemNavigator only acts with a handler', () {
      final seen = <String>[];
      SystemNavigator.routeInformationUpdated(location: '/a');
      SystemNavigator.handler = (uri, replace) => seen.add('$uri $replace');
      addTearDown(() => SystemNavigator.handler = null);
      SystemNavigator.routeInformationUpdated(
        location: '/b?x=1',
        replace: true,
      );
      SystemNavigator.routeInformationUpdated(uri: Uri.parse('/c'));
      SystemNavigator.routeInformationUpdated();
      expect(seen, ['/b?x=1 true', '/c false']);
    });
  });
}

class _Save extends Intent {
  const _Save();
}

class _Move<T> extends Intent {
  const _Move();
}
