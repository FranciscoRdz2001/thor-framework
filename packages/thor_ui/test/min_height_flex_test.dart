@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// A box taller than its Row (a minimum height, a fixed height) hands the
// extra height to the Row, whose children stay vertically centered like
// Flutter's default `CrossAxisAlignment.center`.
void main() {
  initializeThorTests();

  const row = Row(children: [Icon(Icons.close), Text('a'), Text('b')]);

  void expectCenteredRow(String html, String minHeight) {
    expect(html, contains(minHeight));
    expect(html, contains('flex-direction: row'));
    expect(html, contains('align-items: center'));
  }

  test('ConstrainedBox(minHeight) fuses into the Row and centers it', () async {
    final html = await renderHtml(
      const ConstrainedBox(
        constraints: BoxConstraints(minHeight: 64),
        child: row,
      ),
    );
    expectCenteredRow(html, 'min-height: 64px');
    expect(RegExp('<div[ >]').allMatches(html).length, 1);
  });

  test('Container(constraints: minHeight) holding a Row is the Row', () async {
    final html = await renderHtml(
      const Container(
        constraints: BoxConstraints(minHeight: 64),
        padding: EdgeInsets.all(8),
        child: row,
      ),
    );
    expectCenteredRow(html, 'min-height: 64px');
    expect(RegExp('<div[ >]').allMatches(html).length, 1);
  });

  test('a decorated box in between gives the Row the free height', () async {
    final html = await renderHtml(
      const ConstrainedBox(
        constraints: BoxConstraints(minHeight: 64),
        child: DecoratedBox(
          decoration: BoxDecoration(color: Color(0xFFFF0000)),
          child: row,
        ),
      ),
    );
    expect(html, contains('min-height: 64px'));
    // The Row grows into the box (flex: 1 1 auto) and centers its children.
    expect(html, contains('flex: 1 1 auto'));
    expect(html, contains('align-items: center'));
  });

  test('SizedBox(height) around a Row sizes the Row itself', () async {
    final html = await renderHtml(const SizedBox(height: 64, child: row));
    expectCenteredRow(html, 'height: 64px');
    expect(RegExp('<div[ >]').allMatches(html).length, 1);
  });

  test('SizedBox(height) around a Column of a Row keeps the Row centered', () {
    return renderHtml(
      const SizedBox(height: 64, child: Column(children: [row])),
    ).then((html) {
      expect(html, contains('height: 64px'));
      expect(html, contains('flex-direction: row'));
      expect(html, contains('align-items: center'));
    });
  });

  test(
    'a padded Row in a centered, min-height, max-width box totals 64',
    () async {
      final html = await renderHtml(
        Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 672, minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Row(
                    spacing: 12,
                    children: [
                      Link(
                        href: const RouteUrl('/'),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F4F5),
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: const SizedBox(width: 32, height: 32),
                        ),
                      ),
                      const Text('a'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      // One border-box Row: its 64px minimum counts the 12px paddings, and the
      // children are centered in it.
      expect(RegExp('<div[^>]*flex-direction: row').allMatches(html).length, 1);
      expect(html, contains('box-sizing: border-box'));
      expect(html, contains('min-height: 64px'));
      expect(
        html,
        contains('align-items: center; gap: 12px; padding: 12px 16px'),
      );
      expect(html, contains('max-width: 672px'));
    },
  );
}
