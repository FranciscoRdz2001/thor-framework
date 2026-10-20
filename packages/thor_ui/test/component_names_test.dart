@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> page(Widget body) => renderDocument(ThorApp(child: body));

/// The classes of every element in [html]'s body.
List<String> classesOf(String html) => [
  for (final m in RegExp(
    'class="([^"]*)"',
  ).allMatches(html.substring(html.indexOf('<body'))))
    m[1]!,
];

class ProductCard extends StatelessWidget implements ThorElementWidget {
  const ProductCard({super.key});

  @override
  Widget build(BuildContext context) => const Container(
    padding: EdgeInsets.all(14),
    child: Column(
      children: [
        Row(children: [Text('Cold brew', style: TextStyle(fontSize: 17))]),
        Text('Chiapas', style: TextStyle(fontSize: 13)),
        PriceTag(),
      ],
    ),
  );
}

class PriceTag extends StatelessWidget implements ThorElementWidget {
  const PriceTag({super.key});

  @override
  Widget build(BuildContext context) => const Container(
    padding: EdgeInsets.all(4),
    child: Text(r'$4.50', style: TextStyle(fontWeight: FontWeight.w700)),
  );
}

class StoreCard extends StatelessWidget implements ThorElementWidget {
  const StoreCard({super.key});

  @override
  Widget build(BuildContext context) => const Container(
    padding: EdgeInsets.all(20),
    child: Row(children: [Text('Centro', style: TextStyle(fontSize: 15))]),
  );
}

/// A component whose kebab name equals a class the app puts on its
/// elements (`cls('article-meta', …)`).
class ArticleMeta extends StatelessWidget implements ThorElementWidget {
  const ArticleMeta({super.key});

  @override
  Widget build(BuildContext context) => const Styled(
    classes: ['article-meta'],
    child: Padding(padding: EdgeInsets.all(9), child: Text('Ana')),
  );
}

void main() {
  setUpAll(initializeThorTests);

  test("a component's first element takes its class name", () async {
    final classes = classesOf(await page(const ProductCard()));
    expect(classes.first, 't-product-card');
  });

  test('elements inside are named after the component and widget', () async {
    final classes = classesOf(await page(const ProductCard()));
    expect(classes, contains('t-product-card__row'));
    expect(classes, contains('t-product-card__text'));
    expect(classes, contains('t-product-card__text-2'), reason: 'other style');
  });

  test('a component inside another starts its own names', () async {
    final classes = classesOf(await page(const ProductCard()));
    expect(classes, contains('t-price-tag'));
  });

  test('two kinds of cards on one screen keep their own names', () async {
    final classes = classesOf(
      await page(const Column(children: [ProductCard(), StoreCard()])),
    );
    expect(classes, containsAll(['t-product-card', 't-store-card']));
    // StoreCard's Container and Row are one element (store-card).
    expect(classes, contains('t-store-card__text'));
  });

  test('equal elements of a component share one class', () async {
    final html = await page(
      const Column(children: [ProductCard(), ProductCard()]),
    );
    expect('.t-product-card{'.allMatches(html), hasLength(1));
  });

  test('outside any component, classes are content hashes', () async {
    final classes = classesOf(
      await page(const Container(padding: EdgeInsets.all(3))),
    );
    expect(classes.first, matches(RegExp(r'^t[0-9a-z]+$')));
  });

  test("debug names never equal the app's own class names", () async {
    // The app styles `.article-meta` itself; a thor rule named the same
    // would also hit every other element the app gives that class.
    final html = await page(
      const Column(
        children: [
          ArticleMeta(),
          Styled(classes: ['article-meta'], child: Text('Luis')),
        ],
      ),
    );
    expect(html, isNot(contains('.article-meta{')));
    expect(html, isNot(contains('.article-meta ')));
    expect(classesOf(html).join(' ').split(' '), contains('t-article-meta'));
  });
}
