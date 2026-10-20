// A scroll view a keyboard can reach (WCAG 2.1.1, axe
// `scrollable-region-focusable`): `tabindex="0"` unless something inside
// already takes focus.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _html(Widget w) => renderHtml(w);

void main() {
  setUpAll(initializeThorTests);

  test('a scroll view with no focusable content is a tab stop', () async {
    final html = await _html(
      const SizedBox(
        height: 100,
        child: SingleChildScrollView(child: Text('Long text')),
      ),
    );
    expect(html, contains('tabindex="0"'));
    expect(html, isNot(contains('data-t-scrollfocus')));
    expect(html, isNot(contains('role="region"')));
  });

  test('ListView and GridView too', () async {
    final list = await _html(
      const SizedBox(
        height: 100,
        child: ListView(children: [Text('a'), Text('b')]),
      ),
    );
    expect(list, contains('tabindex="0"'));
    final grid = await _html(
      const SizedBox(
        height: 100,
        child: GridView.count(crossAxisCount: 2, children: [Text('a')]),
      ),
    );
    expect(grid, contains('tabindex="0"'));
  });

  test('a named view is a region', () async {
    final html = await _html(
      const SizedBox(
        height: 100,
        child: Semantics(
          label: 'Results',
          child: SingleChildScrollView(child: Text('Long text')),
        ),
      ),
    );
    expect(html, contains('tabindex="0"'));
    expect(html, contains('role="region"'));
    expect(html, contains('aria-label="Results"'));
  });

  test('a link, a button or a field inside is the way in', () async {
    for (final child in <Widget>[
      const Link(href: RouteUrl('/x'), child: Text('x')),
      const Semantics(button: true, child: Text('x')),
      const TextField(decoration: InputDecoration(labelText: 'Name')),
    ]) {
      final html = await _html(
        SizedBox(height: 100, child: SingleChildScrollView(child: child)),
      );
      expect(html, isNot(contains('tabindex')), reason: '$child');
      expect(html, isNot(contains('data-t-scrollfocus')));
    }
  });

  test('a view that never scrolls is not a tab stop', () async {
    final html = await _html(
      const SizedBox(
        height: 100,
        child: ListView(
          physics: NeverScrollableScrollPhysics(),
          children: [Text('a')],
        ),
      ),
    );
    expect(html, isNot(contains('tabindex')));
  });

  test('a view that never scrolls clips instead of scrolling', () async {
    final html = await _html(
      const SizedBox(
        height: 100,
        child: ListView(
          physics: NeverScrollableScrollPhysics(),
          children: [Text('a')],
        ),
      ),
    );
    expect(html, contains('overflow: hidden'));
    expect(html, isNot(contains('overflow: auto')));
  });

  test('a view inside another leaves the outer to its stop', () async {
    final html = await _html(
      const SizedBox(
        height: 100,
        child: SingleChildScrollView(
          child: SizedBox(
            height: 50,
            child: SingleChildScrollView(child: Text('inner')),
          ),
        ),
      ),
    );
    // The inner one is the stop; the outer sees it inside.
    expect(RegExp('tabindex="0"').allMatches(html), hasLength(1));
  });
}
