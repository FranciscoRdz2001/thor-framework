@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> page(Widget body) async {
  final html = await renderDocument(ThorApp(child: body));
  return html.substring(html.indexOf('<body'));
}

void main() {
  setUpAll(initializeThorTests);

  test('orderedList is an <ol> with the list reset', () async {
    final html = await page(
      Semantics(
        role: SemanticsRole.orderedList,
        child: Column(
          children: [
            Semantics(role: SemanticsRole.listItem, child: const Text('One')),
            Semantics(role: SemanticsRole.listItem, child: const Text('Two')),
          ],
        ),
      ),
    );
    expect(html, contains('<ol '));
    expect(html, contains('<li '));
    expect(html, isNot(contains('<ul')));
  });

  test('strong and emphasis are inline elements around the text', () async {
    final html = await page(
      Semantics(role: SemanticsRole.strong, child: const Text('Bold')),
    );
    expect(html, contains('<strong '));
    expect(html, contains('>Bold</strong>'));
  });

  test('current writes aria-current', () async {
    final html = await page(
      Column(
        children: const [
          Semantics(current: SemanticsCurrent.page, child: Text('Here')),
          Semantics(current: SemanticsCurrent.step, child: Text('Two')),
          Semantics(current: SemanticsCurrent.item, child: Text('Three')),
          Semantics(child: Text('Not')),
        ],
      ),
    );
    expect(html, contains('aria-current="page"'));
    expect(html, contains('aria-current="step"'));
    expect(html, contains('aria-current="true"'));
    expect('aria-current'.allMatches(html), hasLength(3));
  });

  test(
    'ElementAttributes puts data-* on the element, without a wrapper',
    () async {
      final html = await page(
        Semantics(
          role: SemanticsRole.list,
          child: Column(
            children: [
              ElementAttributes(
                HtmlAttributes(data: {'track': 'cta', 'track-id': 'a'}),
                child: Semantics(
                  role: SemanticsRole.listItem,
                  child: const Text('Item'),
                ),
              ),
            ],
          ),
        ),
      );
      expect(html, contains('<li '));
      expect(html, contains('data-track="cta"'));
      expect(html, contains('data-track-id="a"'));
      expect(html, isNot(contains('<span')));
      expect(html, isNot(contains('<div')));
      expect('<li '.allMatches(html), hasLength(1));
    },
  );

  test('ElementAttributes refuses event handlers and bad data keys', () {
    expect(
      () => HtmlAttributes.custom({'onclick': 'x()'}),
      throwsArgumentError,
    );
    expect(() => HtmlAttributes(data: {'Bad Key': 'x'}), throwsArgumentError);
  });
}
