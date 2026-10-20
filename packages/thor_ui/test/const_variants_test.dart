@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/web.dart';

// Variants written in a const constructor are the same value as `.when()`.
void main() {
  setUpAll(initializeThorTests);

  Future<String> page(Widget child) => renderDocument(ThorApp(child: child));

  test('FlexLayout(medium:) is const and renders like .when()', () async {
    const constant = Column(
      spacing: 16,
      layout: FlexLayout(medium: FlexLayout(direction: Axis.horizontal)),
      children: [Text('a'), Text('b')],
    );
    final viaWhen = Column(
      spacing: 16,
      layout: const FlexLayout().when(
        medium: const FlexLayout(direction: Axis.horizontal),
      ),
      children: const [Text('a'), Text('b')],
    );
    final html = await page(constant);
    expect(html, await page(viaWhen));
    expect(html, contains('@media'));
    expect(html, contains('flex-direction: row'));
  });

  test('FlexLayout: states, containers and nested variants', () {
    const a = FlexLayout(
      spacing: 8,
      expanded: FlexLayout(spacing: 24),
      hover: FlexLayout(wrap: true),
      container: {400: FlexLayout(direction: Axis.horizontal)},
    );
    final b = const FlexLayout(spacing: 8).when(
      expanded: const FlexLayout(spacing: 24),
      hover: const FlexLayout(wrap: true),
      container: {400: const FlexLayout(direction: Axis.horizontal)},
    );
    expect(a.toCss(), b.toCss());
    expect(
      const FlexLayout(
        hover: FlexLayout(spacing: 2, medium: FlexLayout(spacing: 4)),
      ).toCss(),
      const FlexLayout()
          .when(
            hover: const FlexLayout(
              spacing: 2,
            ).when(medium: const FlexLayout(spacing: 4)),
          )
          .toCss(),
    );
  });

  test('GridLayout and GridPlacement, with the cell aspect ratio', () async {
    const constant = Grid(
      layout: GridLayout(
        columns: 1,
        gap: 8,
        medium: GridLayout(columns: 3, childAspectRatio: 1.5),
      ),
      children: [
        GridItem(
          placement: GridPlacement(medium: GridPlacement(columnSpan: 2)),
          child: Text('a'),
        ),
        Text('b'),
      ],
    );
    final viaWhen = Grid(
      layout: const GridLayout(
        columns: 1,
        gap: 8,
      ).when(medium: const GridLayout(columns: 3, childAspectRatio: 1.5)),
      children: [
        GridItem(
          placement: const GridPlacement().when(
            medium: const GridPlacement(columnSpan: 2),
          ),
          child: const Text('a'),
        ),
        const Text('b'),
      ],
    );
    final html = await page(constant);
    expect(html, await page(viaWhen));
    expect(html, contains('grid-column: span 2'));
    expect(html, contains('aspect-ratio: 1.5'));
  });

  test('CarouselLayout(medium:) matches .when()', () {
    expect(
      const CarouselLayout(
        itemsPerView: 1,
        medium: CarouselLayout(itemsPerView: 3),
      ).toCss(),
      const CarouselLayout(
        itemsPerView: 1,
      ).when(medium: const CarouselLayout(itemsPerView: 3)).toCss(),
    );
  });

  test('a plain layout has no variants', () {
    expect(const FlexLayout(spacing: 4).adaptive, isNull);
    expect(
      const FlexLayout().when(medium: const FlexLayout(spacing: 4)).adaptive,
      isNotNull,
    );
  });

  test('StyleProps: variants in the const constructor match .when()', () {
    const a = StyleProps(
      widthFactor: 0.9,
      medium: StyleProps(widthFactor: 0.7, opacity: 0.5),
      expanded: StyleProps(widthFactor: 0.5),
      hover: StyleProps(scale: 1.1, medium: StyleProps(scale: 1.2)),
      container: {400: StyleProps(widthFactor: 0.3)},
    );
    final b = const StyleProps(widthFactor: 0.9).when(
      medium: const StyleProps(widthFactor: 0.7, opacity: 0.5),
      expanded: const StyleProps(widthFactor: 0.5),
      hover: const StyleProps(
        scale: 1.1,
      ).when(medium: const StyleProps(scale: 1.2)),
      container: {400: const StyleProps(widthFactor: 0.3)},
    );
    expect(a.toCss(), b.toCss());
    expect(a.widgetProps(), b.widgetProps());
    expect(a.toCss().values.any(isAdaptive), isTrue);
    expect(const StyleProps(opacity: 1).adaptive, isNull);
  });

  test('StyleProps: position variants reset offsets like .when()', () {
    const a = StyleProps(
      position: BoxPosition.fixed(left: Length.px(8)),
      medium: StyleProps(position: BoxPosition.sticky(top: Length.px(0))),
      expanded: StyleProps(position: BoxPosition.relative()),
    );
    final b = const StyleProps(position: BoxPosition.fixed(left: Length.px(8)))
        .when(
          medium: const StyleProps(
            position: BoxPosition.sticky(top: Length.px(0)),
          ),
          expanded: const StyleProps(position: BoxPosition.relative()),
        );
    expect(a.toCss(), b.toCss());
    expect(a.toCss()['left'], contains('auto'));
  });

  test('Style: variants in the const constructor match .when()', () {
    const a = Style(
      display: Display.flex,
      padding: Length.px(16),
      paddingTop: Length.px(4),
      medium: Style(padding: Length.px(32)),
      hover: Style(opacity: 0.8, dark: Style(opacity: 0.6)),
      groupHovers: {'card': Style(opacity: 1)},
    );
    final b =
        const Style(
          display: Display.flex,
          padding: Length.px(16),
          paddingTop: Length.px(4),
        ).when(
          medium: const Style(padding: Length.px(32)),
          hover: const Style(
            opacity: 0.8,
          ).when(dark: const Style(opacity: 0.6)),
          groupHovers: {'card': const Style(opacity: 1)},
        );
    expect(a.toCss(), b.toCss());
    expect(a.themeTokens, b.themeTokens);
    expect(
      a.merge(const Style(gap: Length.px(2))).toCss(),
      b.merge(const Style(gap: Length.px(2))).toCss(),
    );
  });
}
