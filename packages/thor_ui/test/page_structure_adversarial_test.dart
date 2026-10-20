@TestOn('vm')
library;

// Adversarial probes of the page structure widgets (ids, drawers, grids).
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _html(Widget w) => renderHtml(ThorApp(child: w));

List<String> _dialogIds(String html) => [
  for (final m in RegExp('<dialog[^>]* id="([^"]*)"').allMatches(html)) m[1]!,
];

void main() {
  setUpAll(initializeThorTests);

  group('ids never collide', () {
    test('a key that looks like a dedup suffix takes its own id', () async {
      final ids = _dialogIds(
        await _html(
          const Column(
            children: [
              AlertDialog(key: ValueKey('a'), title: Text('1')),
              AlertDialog(key: ValueKey('a'), title: Text('2')),
              AlertDialog(key: ValueKey('a-2'), title: Text('3')),
            ],
          ),
        ),
      );
      expect(ids, hasLength(3));
      expect(ids.toSet(), hasLength(3), reason: '$ids');
    });

    test('an explicit id written first is skipped by the auto ones', () async {
      final ids = _dialogIds(
        await _html(
          const Column(
            children: [
              AlertDialog(id: 't-dlg1', title: Text('1')),
              AlertDialog(title: Text('2')),
              AlertDialog(key: ValueKey('x'), title: Text('3')),
              AlertDialog(id: 'dlg-x-2', title: Text('4')),
              AlertDialog(key: ValueKey('x'), title: Text('5')),
            ],
          ),
        ),
      );
      expect(ids.toSet(), hasLength(5), reason: '$ids');
    });

    test('const dialogs twice get two ids', () async {
      final ids = _dialogIds(
        await _html(
          const Column(
            children: [
              AlertDialog(title: Text('c')),
              AlertDialog(title: Text('c')),
            ],
          ),
        ),
      );
      expect(ids.toSet(), hasLength(2), reason: '$ids');
    });
  });

  group('Drawer in RTL', () {
    test('sides, corners and slide follow the writing direction', () async {
      final doc = await renderDocument(
        const ThorApp(
          child: Column(
            children: [
              Drawer(id: 'a', child: Text('a')),
              Drawer(id: 'b', side: DrawerSide.end, child: Text('b')),
            ],
          ),
        ),
      );
      // No physical left/right: the browser flips them with `dir`.
      expect(doc, isNot(contains('margin: 0 auto 0 0')));
      expect(doc, isNot(contains('margin: 0 0 0 auto')));
      expect(doc, isNot(contains('border-radius: 0 16px 16px 0')));
      expect(doc, contains('margin-inline: 0 auto'));
      expect(doc, contains('margin-inline: auto 0'));
      // The closed panel waits on the other side in RTL.
      expect(doc, contains(':dir(rtl)'));
    });
  });

  group('GridView.extent is a cap like Flutter', () {
    Future<String> page(Widget w) => renderDocument(ThorApp(child: w));

    test('a step per column count, where ceil moves up', () async {
      final html = await page(
        const GridView.extent(
          maxCrossAxisExtent: 100,
          crossAxisSpacing: 10,
          padding: EdgeInsets.symmetric(horizontal: 8),
          children: [Text('a')],
        ),
      );
      // ceil(w / 110): 2 columns from 110 (+ 16 of padding) + a hair.
      expect(html, contains('@container (min-width: 126.02px)'));
      expect(html, contains('@container (min-width: 236.02px)'));
      expect(html, contains('repeat(2, minmax(0, 1fr))'));
      expect(html, isNot(contains('auto-fill')));
    });

    test('a huge maximum writes no step, a tiny one stops at 64', () async {
      final one = await page(
        const GridView.extent(maxCrossAxisExtent: 5000, children: [Text('a')]),
      );
      expect(one, isNot(contains('@container')));
      final many = await page(
        const GridView.extent(maxCrossAxisExtent: 1, children: [Text('a')]),
      );
      expect(many, contains('repeat(64, minmax(0, 1fr))'));
      expect(many, isNot(contains('repeat(65,')));
    });
  });
}
