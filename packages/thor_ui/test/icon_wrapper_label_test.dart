@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

const _trash = IconData.svg('test-trash', '<path d="M3 6h18"/>');

Future<String> page(Widget body) => renderDocument(ThorApp(child: body));

/// The `<svg …>` start tag of the page's icon.
String svgTag(String html) => RegExp(r'<svg [^>]*>').firstMatch(html)![0]!;

void main() {
  // An icon without semanticLabel is decorative
  // (aria-hidden); a Semantics label around it must name it, not be hidden
  // with it (the button it sits in had no accessible name).
  test('a Semantics label around an Icon names it', () async {
    final html = await page(
      TextButton(
        onPressed: () {},
        child: const Semantics(label: 'Quitar variable', child: Icon(_trash)),
      ),
    );
    final svg = svgTag(html);
    expect(svg, contains('aria-label="Quitar variable"'));
    expect(svg, contains('role="img"'));
    expect(svg, isNot(contains('aria-hidden')));
  });

  test('an Icon alone stays decorative', () async {
    final svg = svgTag(await page(const Icon(_trash)));
    expect(svg, contains('aria-hidden="true"'));
    expect(svg, isNot(contains('role=')));
  });

  test('semanticLabel still names it', () async {
    final svg = svgTag(await page(const Icon(_trash, semanticLabel: 'Delete')));
    expect(svg, contains('aria-label="Delete"'));
    expect(svg, isNot(contains('aria-hidden')));
  });

  // A wrapper that is its own element (a link) keeps the label: the icon
  // inside stays decorative.
  test('a labelled Link around an Icon keeps the icon decorative', () async {
    final html = await page(
      const Link(href: RouteUrl('/in'), label: 'LinkedIn', child: Icon(_trash)),
    );
    expect(html, contains('aria-label="LinkedIn"'));
    final svg = svgTag(html);
    expect(svg, contains('aria-hidden="true"'));
    expect(svg, isNot(contains('role=')));
  });
}
