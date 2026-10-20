@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> page(Widget body) => renderDocument(ThorApp(child: body));

/// An app component that is not a ThorElementWidget: its root is a Row.
// The case under test: an app that didn't add the marker.
// ignore: thor_lints/missing_thor_element_widget
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) =>
      const Row(children: [Text('F'), Text('orge')]);
}

/// Its root keeps its own tag (an icon-like element).
class _Picture extends StatelessWidget {
  const _Picture();

  @override
  Widget build(BuildContext context) =>
      const Widget.element(tag: 'img', attributes: {'alt': 'x', 'src': '/x'});
}

/// An app component whose root is a link.
class _RecentLink extends StatelessWidget {
  const _RecentLink();

  @override
  Widget build(BuildContext context) =>
      const Link(href: RouteUrl('/d/1'), child: Text('deploy 1'));
}

void main() {
  setUpAll(initializeThorTests);

  // Two wrapper tags on one element, the innermost won.
  group('a tag around a link nests: <li><a>', () {
    final li = RegExp(r'<li[^>]*><a [^>]*href="/d/1"[^>]*>deploy 1</a></li>');

    test('Semantics(role: listItem) right around a Link', () async {
      final html = await page(
        const Semantics(
          role: SemanticsRole.listItem,
          child: Link(href: RouteUrl('/d/1'), child: Text('deploy 1')),
        ),
      );
      expect(html, contains(li));
    });

    test('around an app component whose root is a Link', () async {
      final html = await page(
        const Semantics(role: SemanticsRole.listItem, child: _RecentLink()),
      );
      expect(html, contains(li));
    });

    test(
      'the outer wrappers decorate the <li>, the inner ones the <a>',
      () async {
        final html = await page(
          const Padding(
            padding: EdgeInsets.all(8),
            child: Semantics(
              role: SemanticsRole.listItem,
              child: Link(
                href: RouteUrl('/d/1'),
                label: 'open',
                child: Text('deploy 1'),
              ),
            ),
          ),
        );
        expect(html, contains(RegExp(r'<li[^>]*><a [^>]*aria-label="open"')));
        expect(html, isNot(contains(RegExp(r'<li[^>]*aria-label'))));
      },
    );
  });

  // The wrapper's tag was dropped around a custom component.
  group('a wrapper tag around a component that is no ThorElementWidget', () {
    test('Link makes its root an <a>', () async {
      final html = await page(const Link(href: RouteUrl('/a'), child: _Logo()));
      expect(html, contains(RegExp(r'<a [^>]*href="/a"')));
      expect(html, isNot(contains(RegExp(r'<div [^>]*href="/a"'))));
    });

    test('Semantics(role: main) makes it a <main>', () async {
      final html = await page(
        const Semantics(role: SemanticsRole.main, child: _Logo()),
      );
      expect(html, contains('<main'));
    });

    test('a heading level makes it an <h2>', () async {
      final html = await page(const Semantics(headingLevel: 2, child: _Logo()));
      expect(html, contains('<h2'));
    });

    test('an element that keeps its tag is not replaced', () async {
      final html = await page(
        const Link(href: RouteUrl('/p'), child: _Picture()),
      );
      expect(html, contains(RegExp(r'<img [^>]*href="/p"')));
    });
  });
}
