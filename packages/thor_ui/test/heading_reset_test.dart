@TestOn('vm')
library;

// Every heading thor emits loses the browser's margins, size and weight,
// whatever its child is, not only when it fuses with a Text.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

/// The inline style of the first `<tag>` in [html].
String _style(String html, String tag) =>
    RegExp('<$tag style="([^"]*)"').firstMatch(html)![1]!;

void main() {
  setUpAll(initializeThorTests);

  group('a heading around a child that is not a Text', () {
    for (final (name, child) in const <(String, Widget)>[
      ('Row', Row(children: [Text('a'), Text('b')])),
      ('Column', Column(children: [Text('a')])),
      ('Link', Link(href: RouteUrl('/x'), child: Text('a'))),
    ]) {
      test('$name: no UA margins, inherited size and weight', () async {
        final html = await renderHtml(Semantics(headingLevel: 3, child: child));
        final style = _style(html, 'h3');
        expect(style, contains('margin: 0'));
        expect(style, contains('font-size: inherit'));
        expect(style, contains('font-weight: inherit'));
      });
    }

    test('a Row under ThorApp gets the reset in its class', () async {
      final html = await renderDocument(
        const ThorApp(
          child: Semantics(headingLevel: 2, child: Row(children: [Text('a')])),
        ),
      );
      final cls = RegExp('<h2 class="([^"]+)"').firstMatch(html)![1]!;
      final rule = RegExp('\\.$cls\\{([^}]*)\\}').firstMatch(html)![1]!;
      expect(rule, contains('margin: 0'));
      expect(rule, contains('font-size: inherit'));
    });
  });

  test('a heading inside a Link is <a><h3>, not an <h3 href>', () async {
    final html = await renderHtml(
      const Link(
        href: RouteUrl('/x'),
        child: Semantics(headingLevel: 3, child: Text('Docs')),
      ),
    );
    expect(html, isNot(contains(RegExp('<h3[^>]*href'))));
    expect(
      html,
      matches(RegExp(r'^<a [^>]*href="/x"><h3 [^>]*>Docs</h3></a>$')),
    );
    expect(_style(html, 'h3'), contains('margin: 0'));
  });

  test('a Link inside a heading is <h3><a>', () async {
    final html = await renderHtml(
      const Semantics(
        headingLevel: 3,
        child: Link(href: RouteUrl('/x'), child: Text('Docs')),
      ),
    );
    expect(
      html,
      matches(RegExp(r'^<h3 [^>]*><a [^>]*href="/x">Docs</a></h3>$')),
    );
    expect(_style(html, 'h3'), contains('margin: 0'));
  });
}
