@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> page(Widget body) => renderDocument(ThorApp(child: body));

void main() {
  test('a SizedBox folds into a margin in a plain Column', () async {
    final html = await page(
      const Column(children: [Text('A'), SizedBox(height: 13), Text('B')]),
    );
    expect(html, contains('margin-top: 13px'));
  });

  test('a reversed Column keeps its SizedBox as an element', () async {
    final html = await page(
      const Column(
        verticalDirection: VerticalDirection.up,
        children: [Text('A'), SizedBox(height: 13), Text('B')],
      ),
    );
    expect(html, isNot(contains('margin-top: 13px')));
    expect(html, contains('height: 13px'));
  });

  test('an RTL Row keeps its Spacer as an element', () async {
    final html = await page(
      const Row(
        textDirection: TextDirection.rtl,
        children: [Text('A'), Spacer(), Text('B')],
      ),
    );
    expect(html, isNot(contains('margin-inline-start: auto')));
  });

  test('a Column with a responsive layout keeps its SizedBox', () async {
    final html = await page(
      Column(
        layout: const FlexLayout().when(
          medium: const FlexLayout(direction: Axis.horizontal),
        ),
        children: const [Text('A'), SizedBox(height: 17), Text('B')],
      ),
    );
    expect(html, isNot(contains('margin-top: 17px')));
  });
}
