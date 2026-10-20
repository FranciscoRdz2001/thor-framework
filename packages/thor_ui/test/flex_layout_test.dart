@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  setUpAll(initializeThorTests);

  test('Column(verticalDirection: up) stacks from the bottom', () async {
    final html = await renderDocument(
      const ThorApp(
        child: Column(
          verticalDirection: VerticalDirection.up,
          children: [Text('a'), Text('b')],
        ),
      ),
    );
    expect(html, contains('flex-direction: column-reverse'));
  });

  test('FlexLayout: up in a column, row wins when it turns horizontal', () {
    expect(const FlexLayout(verticalDirection: VerticalDirection.up).toCss(), {
      'flex-direction': 'column-reverse',
    });
    expect(
      const FlexLayout(
        direction: Axis.horizontal,
        verticalDirection: VerticalDirection.up,
      ).toCss(),
      {'flex-direction': 'row'},
    );
    expect(const FlexLayout(spacing: 4).toCss(), {'gap': '4px'});
  });

  test('ResponsiveVisibility by the LayoutScope width', () async {
    final html = await renderDocument(
      const ThorApp(
        child: LayoutScope(
          child: Row(
            children: [
              ResponsiveVisibility(
                containerVisibleFrom: 500,
                child: Text('page'),
              ),
              ResponsiveVisibility(
                containerHiddenFrom: 800,
                child: Text('short'),
              ),
            ],
          ),
        ),
      ),
    );
    expect(html, contains('@container (max-width: 499.98px)'));
    expect(html, contains('@container (min-width: 800px)'));
  });

  test('Row(crossAxisAlignment: baseline) lines up text baselines', () async {
    for (final baseline in TextBaseline.values) {
      final html = await renderDocument(
        ThorApp(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: baseline,
            children: const [Text('big'), Text('small')],
          ),
        ),
      );
      // web: no ideographic flex baseline in CSS; both are alphabetic.
      expect(html, contains('align-items: baseline'), reason: '$baseline');
    }
  });

  test('baseline without a textBaseline fails like Flutter', () {
    expect(
      () => Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        children: const [],
      ),
      throwsA(isA<AssertionError>()),
    );
    // Any other alignment needs none.
    expect(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.empty(),
      ),
      returnsNormally,
    );
  });

  group('child rules follow the direction a FlexLayout sets', () {
    // A child that takes the max width: a column stretches it across.
    const filling = SizedBox(width: double.infinity, child: Text('a'));

    String? mediaBlock(String html) {
      final at = html.indexOf('@media');
      return at < 0 ? null : html.substring(at);
    }

    test('a column turned into a row stops stretching the child', () async {
      final html = await renderDocument(
        ThorApp(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            layout: const FlexLayout().when(
              medium: const FlexLayout(
                direction: Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.start,
              ),
            ),
            children: const [filling],
          ),
        ),
      );
      // Below md, a column's rule; from md up, the row's (none): back to
      // the container's align-items: start.
      expect(html, contains('align-self: stretch'));
      expect(mediaBlock(html), contains('align-self: auto'));
    });

    test('and back: a row a variant turns into a column', () async {
      final html = await renderDocument(
        ThorApp(
          child: Row(
            layout: const FlexLayout().when(
              medium: const FlexLayout(direction: Axis.vertical),
            ),
            children: const [filling],
          ),
        ),
      );
      final media = mediaBlock(html)!;
      expect(media, contains('align-self: stretch'));
      // A row's flexible rule (min-width) isn't a column's.
      expect(html, isNot(contains('min-width: auto')));
    });

    test('a layout with a fixed direction uses its rules', () async {
      final html = await renderDocument(
        const ThorApp(
          child: Column(
            layout: FlexLayout(direction: Axis.horizontal),
            children: [filling],
          ),
        ),
      );
      expect(html, isNot(contains('align-self: stretch')));
      expect(html, contains('flex-direction: row'));
    });

    test('a variant that sets no direction changes no child rule', () async {
      final html = await renderDocument(
        ThorApp(
          child: Column(
            layout: const FlexLayout().when(
              medium: const FlexLayout(spacing: 8),
            ),
            children: const [filling],
          ),
        ),
      );
      expect(html, contains('align-self: stretch'));
      expect(html, isNot(contains('align-self: auto')));
    });

    test('medium row then expanded column: expanded undoes medium', () {
      final rules = ChildRules.directional(ChildRules.column, {
        'medium': ChildRules.row,
        'expanded': ChildRules.column,
      });
      final grant = rules.forChild(fillsWidth: true);
      expect(resolveAdaptive(grant['align-self']!, null), 'stretch');
      expect(resolveAdaptive(grant['align-self']!, 'medium'), 'auto');
      expect(resolveAdaptive(grant['align-self']!, 'expanded'), 'stretch');
      expect(resolveAdaptive(grant['align-self']!, 'large'), 'stretch');
      // Same everywhere: no marker.
      expect(grant['flex'], '0 0 auto');
    });
  });

  test('StyleProps(flexBasis) emits flex-basis', () {
    expect(const StyleProps(flex: 1, flexBasis: Length.px(0)).toCss(), {
      'flex-grow': '1',
      'flex-basis': '0px',
    });
  });
}
