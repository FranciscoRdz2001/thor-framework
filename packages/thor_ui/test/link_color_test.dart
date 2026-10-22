// A `Link` imposes no color (Flutter's does not): its `color: inherit` and
// `text-decoration: none` sit in the lowest layer, under the child's props
// and under the app's classes.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _page(Widget w) => renderDocument(ThorApp(child: w));

/// The `@layer` block named [layer], or ''.
String _layer(String html, String layer) {
  final start = html.indexOf('@layer $layer{');
  if (start < 0) return '';
  return html.substring(start, html.indexOf('}}', start) + 2);
}

/// The class attribute of the first `<a>`.
List<String> _classes(String html) =>
    RegExp('<a class="([^"]+)"').firstMatch(html)![1]!.split(' ');

void main() {
  setUpAll(initializeThorTests);

  test(
    'the declarations are in the base layer, shared by every link',
    () async {
      final out = await _page(
        const Column(
          children: [
            Link(href: RouteUrl('/a'), child: Text('A')),
            Link(href: RouteUrl('/b'), child: Text('B')),
          ],
        ),
      );
      final base = _layer(out, 'thor.reset');
      expect(base, contains('color: inherit'));
      expect(base, contains('text-decoration: none'));
      expect(
        RegExp('color: inherit').allMatches(base),
        hasLength(1),
        reason: 'one class for all the links',
      );
      expect(_layer(out, 'thor.props'), isNot(contains('color: inherit')));
      expect(_layer(out, 'thor.overrides'), isNot(contains('color: inherit')));
    },
  );

  test('a Text color still wins over the link', () async {
    final out = await _page(
      const Link(
        href: RouteUrl('/a'),
        child: Text('A', style: TextStyle(color: Color(0xFFFF0000))),
      ),
    );
    expect(_layer(out, 'thor.props'), contains('color: #ff0000'));
    expect(_layer(out, 'thor.overrides'), isNot(contains('color')));
  });

  test('an app class on the element has no link color above it', () async {
    final out = await _page(
      const Link(
        href: RouteUrl('/a'),
        child: html.span([Widget.text('A')], classes: 'cat-chip'),
      ),
    );
    final classes = _classes(out);
    expect(classes, contains('cat-chip'));
    expect(_layer(out, 'thor.props'), isNot(contains('color')));
    expect(_layer(out, 'thor.overrides'), isNot(contains('color')));
    final base = _layer(out, 'thor.reset');
    expect(base, contains('color: inherit'));
    final link = classes.firstWhere((c) => c != 'cat-chip');
    expect(base, contains('.$link'));
  });

  test('around a Styled with classes', () async {
    final out = await _page(
      const Link(
        href: RouteUrl('/a'),
        child: Styled(classes: ['tab'], child: Text('A')),
      ),
    );
    expect(_classes(out), contains('tab'));
    expect(_layer(out, 'thor.props'), isNot(contains('color: inherit')));
    expect(_layer(out, 'thor.reset'), contains('color: inherit'));
  });
}
