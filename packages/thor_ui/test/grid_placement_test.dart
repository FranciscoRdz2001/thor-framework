@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> page(Widget body) => renderDocument(ThorApp(child: body));

String bodyOf(String html) => html.substring(html.indexOf('<body'));

/// Every rule of the class of the element with text [text].
String rulesOf(String html, String text) {
  final body = bodyOf(html);
  final at = body.indexOf('>$text<');
  final open = body.lastIndexOf('class="', at);
  final cls = body.substring(open + 7, body.indexOf('"', open + 7));
  return [
    for (final m in RegExp('[^{}]*\\.$cls\\{[^}]*\\}').allMatches(html)) m[0],
  ].join('\n');
}

void main() {
  setUpAll(initializeThorTests);

  group('GridLayout.columnSizes', () {
    test('flex, fixed and auto are the column tracks', () {
      expect(
        const GridLayout(
          columnSizes: [
            GridSize.flex(2),
            GridSize.flex(),
            GridSize.fixed(240),
            GridSize.auto,
          ],
        ).toCss(),
        {'grid-template-columns': 'minmax(0, 2fr) minmax(0, 1fr) 240px auto'},
      );
    });

    test('const variants and .when() give the same CSS', () {
      const sizes2 = [GridSize.flex(2), GridSize.flex(1)];
      const a = GridLayout(columns: 1, medium: GridLayout(columnSizes: sizes2));
      final b = const GridLayout(
        columns: 1,
      ).when(medium: const GridLayout(columnSizes: sizes2));
      expect(a.toCss(), b.toCss());
      expect(
        a.toCss()['@media (min-width: 768px)'] ?? a.toCss().toString(),
        contains('minmax(0, 2fr) minmax(0, 1fr)'),
      );
    });

    test(
      'a variant replaces the base tracks and a Grid renders them',
      () async {
        final html = await page(
          Grid(
            layout:
                const GridLayout(
                  columnSizes: [GridSize.fixed(240), GridSize.flex()],
                ).when(
                  medium: const GridLayout(
                    columnSizes: [GridSize.flex(2), GridSize.flex(1)],
                  ),
                ),
            children: const [Text('a'), Text('b')],
          ),
        );
        expect(html, contains('240px minmax(0, 1fr)'));
        expect(html, contains('minmax(0, 2fr) minmax(0, 1fr)'));
      },
    );

    test('rejects columns together with columnSizes', () {
      expect(
        () => GridLayout(columns: 2, columnSizes: const [GridSize.flex()]),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('GridPlacement', () {
    test('spans, lines and areas are the CSS grid properties', () {
      expect(const GridPlacement(columnSpan: 2).toCss(), {
        'grid-column': 'span 2',
      });
      expect(const GridPlacement(columnStart: 2, columnSpan: 3).toCss(), {
        'grid-column': '2 / span 3',
      });
      expect(GridPlacement.fullWidth.toCss(), {'grid-column': '1 / -1'});
      expect(const GridPlacement(rowStart: 2).toCss(), {'grid-row': '2'});
      expect(const GridPlacement(rowEnd: -1).toCss(), {
        'grid-row': 'auto / -1',
      });
      expect(const GridPlacement(area: 'main').toCss(), {'grid-area': 'main'});
      expect(const GridPlacement().toCss(), isEmpty);
    });

    test('impossible placements fail instead of writing bad CSS', () {
      expect(
        () => const GridPlacement(columnEnd: 3, columnSpan: 2).toCss(),
        throwsArgumentError,
      );
      expect(
        () => const GridPlacement(columnStart: 0).toCss(),
        throwsArgumentError,
      );
      expect(
        () => const GridPlacement(rowSpan: 0).toCss(),
        throwsArgumentError,
      );
      // The name goes into the stylesheet: nothing but an identifier.
      expect(
        () => const GridPlacement(area: 'a; color: red').toCss(),
        throwsArgumentError,
      );
    });
  });

  group('GridItem', () {
    test('fuses into its child: no node of its own', () async {
      final html = bodyOf(
        await page(
          const Grid(
            layout: GridLayout(columns: 3),
            children: [
              GridItem(
                placement: GridPlacement(columnSpan: 2),
                child: Text('wide'),
              ),
              Text('narrow'),
            ],
          ),
        ),
      );
      // The body, the grid and its two texts.
      expect(RegExp('<[a-z]').allMatches(html).length, 4);
      expect(html, contains('data-thor-grid-item'));
    });

    test('the span lands in the child\'s class, over its own', () async {
      final html = await page(
        const Grid(
          layout: GridLayout(columns: 3),
          children: [
            GridItem(
              placement: GridPlacement(columnSpan: 2, rowSpan: 2),
              child: Text('wide'),
            ),
          ],
        ),
      );
      final rules = rulesOf(html, 'wide');
      expect(rules, contains('grid-column: span 2'));
      expect(rules, contains('grid-row: span 2'));
      // The grid still keeps its children from overflowing.
      expect(rules, contains('min-width: 0'));
    });

    test('.when(): wide from a breakpoint up, one class', () async {
      final html = await page(
        Grid(
          layout: const GridLayout(
            columns: 1,
          ).when(medium: const GridLayout(columns: 3)),
          children: [
            GridItem(
              placement: const GridPlacement().when(
                medium: const GridPlacement(columnSpan: 2),
              ),
              child: const Text('chart'),
            ),
          ],
        ),
      );
      final rules = rulesOf(html, 'chart');
      // The first rule is the base: below md one column, no span into
      // implicit columns.
      expect(rules.split('\n').first, isNot(contains('grid-column')));
      expect(html, matches(RegExp(r'@media[^{]*\{[^@]*grid-column: span 2')));
    });

    test('around a component (not a thor element) too', () async {
      final html = await page(
        const Grid(
          layout: GridLayout(columns: 2),
          children: [
            GridItem(placement: GridPlacement.fullWidth, child: _Card()),
          ],
        ),
      );
      expect(html, contains('grid-column: 1 / -1'));
    });
  });

  group('GridLayout.areas', () {
    test('named areas: the template, and children placed by name', () async {
      final html = await page(
        const Grid(
          layout: GridLayout(
            columns: 2,
            areas: ['header header', 'nav   main', '. footer'],
          ),
          children: [
            GridItem(
              placement: GridPlacement(area: 'header'),
              child: Text('top'),
            ),
          ],
        ),
      );
      expect(
        html,
        contains('grid-template-areas: "header header" "nav main" ". footer"'),
      );
      expect(rulesOf(html, 'top'), contains('grid-area: header'));
    });

    test('ragged rows or bad names fail', () {
      expect(
        () => const GridLayout(areas: ['a b', 'c']).toCss(),
        throwsArgumentError,
      );
      expect(
        () => const GridLayout(areas: ['a "b']).toCss(),
        throwsArgumentError,
      );
      expect(() => const GridLayout(areas: ['']).toCss(), throwsArgumentError);
    });

    test('areas change per breakpoint', () async {
      final html = await page(
        Grid(
          layout: const GridLayout(
            columns: 1,
            areas: ['nav', 'main'],
          ).when(medium: const GridLayout(columns: 2, areas: ['nav main'])),
          children: const [Text('x')],
        ),
      );
      expect(html, contains('grid-template-areas: "nav" "main"'));
      expect(
        html,
        matches(RegExp(r'@media[^{]*\{[^@]*grid-template-areas: "nav main"')),
      );
    });
  });
}

// Not a ThorElementWidget on purpose: the wrapper path for components.
// ignore: thor_lints/missing_thor_element_widget
class _Card extends StatelessWidget {
  const _Card();

  @override
  Widget build(BuildContext context) => const Card(child: Text('card'));
}
