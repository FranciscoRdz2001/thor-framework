@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart' as flutter;
import 'package:thor_ui/web.dart';

Future<String> page(Widget body) => renderDocument(ThorApp(child: body));

String bodyOf(String html) => html.substring(html.indexOf('<body'));

/// The opening tags `<tag …>` in the body.
List<String> tags(String html, String tag) => [
  for (final m in RegExp('<$tag(?=[\\s>])[^>]*>').allMatches(bodyOf(html)))
    m[0]!,
];

Widget orders() => Table(
  style: tw('w-full text-sm'),
  children: [
    const Caption(text: 'Orders today'),
    Thead(
      children: [
        Tr(
          children: [
            const Th(scope: 'col', text: 'Customer'),
            Th(scope: 'col', text: 'Total', style: tw('text-right')),
          ],
        ),
      ],
    ),
    const Tbody(
      children: [
        Tr(
          children: [
            Th(scope: 'row', text: 'Jane Doe'),
            Td(text: r'$120'),
          ],
        ),
        Tr(
          children: [
            Th(scope: 'row', text: 'John Smith'),
            Td(text: r'$80'),
          ],
        ),
      ],
    ),
    const Tfoot(
      children: [
        Tr(children: [Td(colSpan: 2, text: r'Total: $200')]),
      ],
    ),
  ],
);

void main() {
  setUpAll(initializeThorTests);

  group('table elements', () {
    test('each is its HTML element with at most one class', () async {
      final html = await page(orders());
      for (final (tag, count) in [
        ('table', 1),
        ('caption', 1),
        ('thead', 1),
        ('tbody', 1),
        ('tfoot', 1),
        ('tr', 4),
        ('th', 4),
        ('td', 3),
      ]) {
        final found = tags(html, tag);
        expect(found, hasLength(count), reason: tag);
        for (final t in found) {
          // No class when nothing styles it; never two.
          expect(
            RegExp(r'class="[^"]* [^"]*"').hasMatch(t),
            isFalse,
            reason: t,
          );
        }
      }
      // No wrappers: the rows sit right inside their sections.
      expect(bodyOf(html), contains(RegExp(r'<tbody[^>]*><tr[\s>]')));
    });

    test('native semantics: caption, header scopes and spans', () async {
      final html = await page(orders());
      final body = bodyOf(html);
      expect(body, contains('>Orders today</caption>'));
      expect(
        tags(html, 'th').where((t) => t.contains('scope="col"')),
        hasLength(2),
      );
      expect(
        tags(html, 'th').where((t) => t.contains('scope="row"')),
        hasLength(2),
      );
      expect(
        tags(html, 'td').where((t) => t.contains('colspan="2"')),
        hasLength(1),
      );
      // The table's own roles, never replaced.
      expect(body, isNot(contains('role=')));
    });

    test('the table starts collapsed, below any Style', () async {
      final html = await page(orders());
      final table = tags(html, 'table').single;
      final cls = RegExp(r'class="([^"]+)"').firstMatch(table)![1]!;
      final rules = RegExp(
        '[^{}]*\\.$cls[^{}]*\\{[^}]*\\}',
      ).allMatches(html).map((m) => m[0]).join('\n');
      expect(rules, contains('border-collapse: collapse'));
      expect(rules, contains('width: 100%'));
    });

    test('rowSpan 0 is valid HTML; bad scopes and spans are not', () {
      expect(() => const Td(rowSpan: 0, text: 'x'), returnsNormally);
      expect(() => Td(colSpan: 0, text: 'x'), throwsA(isA<AssertionError>()));
      expect(() => Th(rowSpan: -1, text: 'x'), throwsA(isA<AssertionError>()));
      expect(
        () => Th(scope: 'column', text: 'x'),
        throwsA(isA<AssertionError>()),
      );
    });

    test(
      "web.dart's Table is HTML's; Flutter's stays in thor_ui.dart",
      () async {
        expect(const Table(), isA<WebElement>());
        final html = await page(
          const flutter.Table(
            children: [
              flutter.TableRow(children: [Text('a'), Text('b')]),
            ],
          ),
        );
        expect(tags(html, 'table'), hasLength(1));
        expect(tags(html, 'tr'), hasLength(1));
      },
    );
  });
}
