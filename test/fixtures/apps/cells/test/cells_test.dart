// The page renders, and the sheet's formulas compute.
import 'package:cells/app.dart';
import 'package:cells/cells.dart';
import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';

Sheet _sheet(Map<int, String> cells) => Sheet((i) => cells[i] ?? '');

void main() {
  test('the sheet page is drawn', () async {
    final page = await appHandler().client().get('/');
    expect(page, hasStatus(200));
    expect(page.text, contains('<main'));
    expect(page.text, contains('Load 100 dependents of A1'));
  });

  test('A1 with 100 dependents: each cell computes from what it reads', () {
    sheet.loadDependents();
    // B1 is cell 1, C1 cell 2, B100 cell 99 * 26 + 1.
    expect(
      [sheet.text(1), sheet.text(2), sheet.text(99 * 26 + 1)],
      ['2', '5150', '101'],
    );
    sheet.edit(0);
    sheet.editor.text = '5';
    sheet.commit();
    expect([sheet.text(0), sheet.text(1), sheet.text(2)], ['5', '6', '5550']);
  });

  group('sheet', () {
    // A1..A3 are cells 0, 26, 52; B1 is cell 1.
    test('references, arithmetic and ranges', () {
      final s = _sheet({
        0: '1',
        26: '2',
        52: '3',
        78: '=SUM(A1:A3)',
        1: '=A1*2+A2',
        2: '=(A1+A2)*A3-1/2',
      });
      expect(s.show(78), '6');
      expect(s.show(1), '4');
      expect(s.show(2), '8.5');
    });

    test('functions over lists and ranges', () {
      final s = _sheet({
        0: '4',
        26: '8',
        1: '=AVG(A1:A2)',
        2: '=MAX(A1,A2,10)',
        3: '=MIN(A1:A2)',
        4: '=COUNT(A1:A2)',
      });
      expect(
        [s.show(1), s.show(2), s.show(3), s.show(4)],
        ['6', '10', '4', '2'],
      );
    });

    test('errors are text, not crashes', () {
      final s = _sheet({
        0: '=B1',
        1: '=A1',
        2: '=1/0',
        3: '=foo(',
        4: '=SUM(Z101)',
      });
      expect(s.show(0), '#CYCLE');
      expect(s.show(2), '#DIV/0');
      expect(s.show(3), '#ERROR');
    });
  });
}
