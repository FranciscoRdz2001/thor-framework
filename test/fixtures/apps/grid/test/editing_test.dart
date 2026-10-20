import 'package:grid/data.dart';
import 'package:grid/grid_state.dart';
import 'package:test/test.dart';

void main() {
  late GridState g;
  Launch record(int i) => g.rows()[i].record!;

  setUp(() => g = GridState());

  test('TSV round-trips quoted cells (tabs, line breaks, quotes)', () {
    final cells = ['plain', 'a\tb', 'two\nlines', 'say "hi"'];
    final text = '${cells.map(tsvCell).join('\t')}\r\nx\ty\n';
    expect(parseTsv(text), [
      cells,
      ['x', 'y'],
    ], reason: 'CRLF and a trailing line break add no row');
    expect(parseTsv(''), isEmpty);
    expect(parseDay('Mar 3, 2026'), isNotNull);
    expect(parseDay('3/3/2026'), isNull);
  });

  test('a block pastes from the corner, skips what does not fit, and is '
      'one undo step', () {
    final a = record(0), b = record(1);
    final (nameA, nameB, statusB) = (a.name, b.name, b.status);
    g.tapCell('r${a.id}.0');
    g.pasteTsv('One\tBeta\nTwo\tnot a status\n');
    expect(
      [a.name, a.status, b.name, b.status],
      ['One', Status.beta, 'Two', statusB],
    );
    g.undo();
    expect([a.name, b.name, b.status], [nameA, nameB, statusB]);
  });

  test('a single value fills the selected range', () {
    final a = record(0), b = record(1), c = record(2);
    final statusC = c.status;
    g
      ..tapCell('r${a.id}.1')
      ..extendDown()
      ..pasteTsv('Paused');
    expect(
      [a.status, b.status, c.status],
      [Status.paused, Status.paused, statusC],
    );
  });

  test('typing on a cell edits it starting with the character; not on a '
      'checkbox', () {
    final a = record(0);
    g
      ..tapCell('r${a.id}.0')
      ..typeInto('Z');
    expect(g.editing.value, isNot('none'));
    expect(g.draft.text, 'Z');

    final h = GridState();
    final shipped = h.rows()[0].record!;
    final before = shipped.shipped;
    h
      ..tapCell('r${shipped.id}.${GridField.shipped.index}')
      ..typeInto('x');
    expect(h.editing.value, 'none');
    expect(shipped.shipped, before);
  });
}
