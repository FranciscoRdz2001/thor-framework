@TestOn('vm')
library;

// `withArgs(a, b)` on a state method and the escapes that keep a `~`
// or a `%` of a value from moving the split.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

enum Role { admin, guest }

abstract class _GridMembers extends ThorState {
  @override
  String get $type => 'GridState';

  @override
  List<ThorMember> get $members {
    final s = this as GridState;
    return [
      ThorMember(
        'pick',
        s.pick,
        arity: 2,
        call: (a) {
          final x = splitArgs(a, 2);
          return s.pick(int.parse(x[0]), x[1]);
        },
      ),
      ThorMember(
        'setTag',
        s.setTag,
        arity: 2,
        call: (a) {
          final x = splitArgs(a, 2);
          return s.setTag(x[0], x[1] == 'true');
        },
      ),
      ThorMember(
        'grant',
        s.grant,
        arity: 3,
        call: (a) {
          final x = splitArgs(a, 3);
          return s.grant(x[0], Role.values.byName(x[1]), x[2] == 'true');
        },
      ),
      ThorMember('rename', s.rename, arity: 1, call: (a) => s.rename(a!)),
    ];
  }
}

class GridState extends _GridMembers {
  void pick(int row, String label) {}
  void setTag(String tag, bool on) {}
  void grant(String who, Role role, bool on) {}
  void rename(String to) {}
}

final grid = GridState();

void main() {
  initializeThorTests();

  Future<String> button(void Function() onPressed) =>
      renderHtml(FilledButton(onPressed: onPressed, child: const Text('go')));

  test('withArgs writes every argument, typed values as text', () async {
    final html = await button(grid.pick.withArgs(3, 'x'));
    expect(html, contains('data-t-on="click:GridState.pick" data-tx="3~x"'));
    final three = await button(grid.grant.withArgs('ana', Role.guest, true));
    expect(three, contains('data-tx="ana~guest~true"'));
    expect(three, isNot(contains('data-txv')));
  });

  test('a ~ or a % in a value never moves the split', () async {
    final html = await button(grid.pick.withArgs(3, 'a~b'));
    // The last part keeps its own `~`: it is the rest of the value.
    expect(html, contains('data-tx="3~a~b"'));
    final first = await button(grid.grant.withArgs('a~b%', Role.admin, false));
    expect(first, contains('data-tx="a%7Eb%25~admin~false"'));
    expect(splitArgs('a%7Eb%25~admin~false', 3), ['a~b%', 'admin', 'false']);
  });

  test('a fixed text of a two-parameter method is escaped, with the '
      "control's value coming after it", () async {
    final html = await renderHtml(
      Switch(value: false, onChanged: grid.setTag.withArg('a~b')),
    );
    expect(html, contains('data-tx="a%7Eb" data-txv'));
  });

  test('a single-parameter method keeps its text as it is', () async {
    final html = await button(grid.rename.withArg('a~b%7E'));
    expect(html, contains('data-tx="a~b%7E"'));
  });

  test('hostile characters are escaped in the attribute', () async {
    final html = await button(
      grid.pick.withArgs(1, '"><script>alert(1)</script>'),
    );
    expect(html, isNot(contains('<script>alert(1)</script>')));
    expect(html, contains('data-tx="1~'));
  });
}
