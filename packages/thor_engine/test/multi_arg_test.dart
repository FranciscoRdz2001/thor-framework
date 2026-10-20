// Several arguments in one value (`withArgs(a, b)`, a page action's
// `bind(a, b)`): every part but the last is escaped, so a `~` or a `%` in
// A value can't move the split.
import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart';

enum Role { admin, guest }

class Grid extends ThorState {
  final log = <String>[];

  void cell(int row, String label) => log.add('$row/$label');
  void three(String a, Role role, bool on) => log.add('$a/${role.name}/$on');
  void one(String label) => log.add(label);
}

void main() {
  group('splitArgs', () {
    test('the last part keeps its own separators', () {
      expect(splitArgs('a~b~c', 2), ['a', 'b~c']);
      expect(splitArgs('a', 3), ['a', '', '']);
      expect(splitArgs(null, 2), ['', '']);
    });

    test('an escaped separator or percent in a non-last part comes back', () {
      expect(splitArgs('a%7Eb~c', 2), ['a~b', 'c']);
      expect(splitArgs('100%25~x', 2), ['100%', 'x']);
      // Escapes are not applied to the last part: it is typed by the user.
      expect(splitArgs('a~%7E', 2), ['a', '%7E']);
    });
  });

  group('fillKey (a row the browser clones)', () {
    test(
      'the key of a non-last part goes escaped, as the server escapes it',
      () {
        expect(fillKey('{{key}}~ok', 'x~y%7E'), 'x%7Ey%257E~ok');
        expect(splitArgs(fillKey('{{key}}~ok', 'x~y%7E'), 2), ['x~y%7E', 'ok']);
        expect(fillKey('a~{{key}}~c', 'k~'), 'a~k%7E~c');
      },
    );

    test('a key inside the id of a keyed state goes escaped', () {
      expect(fillKey('Row#{{key}}.label', 'a~b'), 'Row#a%7Eb.label');
      expect(fillKey('click:Row#{{key}}.inc', '100%'), 'click:Row#100%25.inc');
      expect(fillKey('click:Row#{{key}}.inc', 'a;b'), 'click:Row#a%3Bb.inc');
      expect(
        fillKey('{{key}}~x', 'a;b'),
        'a;b~x',
        reason: 'an argument is not an id',
      );
      expect(
        fillKey('Row#{{key}}.f~{{key}}', 'a~b'),
        'Row#a%7Eb.f~a~b',
        reason: 'the last part of an argument stays raw',
      );
      expect(
        fillKey('#{{key}}', 'a~b'),
        '#a~b',
        reason: 'an anchor is not an id',
      );
    });

    test('an anchor or a path that looks like an id keeps the raw key', () {
      expect(fillKey('#{{key}}.notes', 'a~b%', id: false), '#a~b%.notes');
      expect(fillKey('/x#{{key}}.notes', 'a~b', id: false), '/x#a~b.notes');
      expect(fillKey('Row#{{key}}.label', 'a~b', id: true), 'Row#a%7Eb.label');
    });

    test('the last part or a lone key stays as it is', () {
      expect(fillKey('ok~{{key}}', 'x~y%'), 'ok~x~y%');
      expect(fillKey('{{key}}', 'x~y%'), 'x~y%');
      expect(fillKey('/orders/{{key}}/edit', r'a$&b'), r'/orders/a$&b/edit');
    });
  });

  group('encodeArgs', () {
    const hostile = ['a~b', '100%', '~~', '%7E', '', 'línea\nnueva', '"><x>'];

    test('a single value is just its text (enum: its name)', () {
      expect(encodeArgs([7]), '7');
      expect(encodeArgs([Role.guest]), 'guest');
      expect(encodeArgs(['a~b']), 'a~b');
    });

    test('round trips hostile strings in any position', () {
      for (final a in hostile) {
        for (final b in hostile) {
          for (final c in hostile) {
            expect(splitArgs(encodeArgs([a, b, c]), 3), [
              a,
              b,
              c,
            ], reason: '$a | $b | $c');
          }
        }
      }
    });

    test('typed values keep their text', () {
      expect(encodeArgs([1.5, true, Role.admin]), '1.5~true~admin');
    });
  });

  group('withArgs', () {
    test('fixes every argument of a method (2 and 3)', () {
      final g = Grid();
      final two = g.cell.withArgs(4, 'x~y');
      two();
      expect(g.log, ['4/x~y']);
      final bound = BoundCall.of(two)!;
      expect(bound.function, g.cell);
      expect(encodeFixedArg(bound.arg), '4~x~y');
      final three = g.three.withArgs('a~b', Role.guest, true);
      three();
      expect(g.log.last, 'a~b/guest/true');
      expect(encodeFixedArg(BoundCall.of(three)!.arg), 'a%7Eb~guest~true');
    });

    test('withArg keeps working, and its fixed part is escaped for a '
        'method that splits', () {
      final g = Grid();
      final f = g.cell.withArg(1);
      f('z');
      expect(g.log, ['1/z']);
      // A fixed text of a two-parameter method (`withArg('a~b')`) is the
      // first part of what the page sends: escaped.
      expect(encodeFixedArg('a~b', splits: true), 'a%7Eb');
      expect(encodeFixedArg('a~b'), 'a~b');
      expect(encodeArg(BoundCall.of(g.one.withArg('a~b'))!.arg), 'a~b');
    });
  });
}
