// `Pagination`, the links of a list whose page lives in the URL:
// a `<nav>` with real links (no JavaScript), the current page marked with
// `aria-current`, every other parameter of the URL kept.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart'
    show HttpMethod, ListQueryRequest, PageRequest;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _html(
  String query, {
  required int total,
  int pageSize = 10,
  int window = 1,
}) async {
  final request = PageRequest(
    method: HttpMethod.get,
    uri: Uri.parse('http://s.test/orders${query.isEmpty ? '' : '?$query'}'),
  );
  final list = request.listQuery(pageSize: pageSize);
  return bodyOfPage(
    await renderDocument(
      ThorApp(
        child: Pagination(list: list, total: total, window: window),
      ),
    ),
  );
}

List<String> _hrefs(String html) => [
  for (final m in RegExp(r'<a [^>]*href="([^"]*)"').allMatches(html)) m[1]!,
];

List<String> _labels(String html) => [
  for (final m in RegExp(r'<a [^>]*>([^<]*)</a>').allMatches(html)) m[1]!,
];

void main() {
  setUpAll(initializeThorTests);

  test('a nav with a list of real links', () async {
    final html = await _html('page=2', total: 50);
    expect(html, contains('<nav'));
    expect(html, contains('aria-label="Pagination"'));
    expect(html, contains('<ul'));
    expect('<li'.allMatches(html).length, greaterThan(5));
    // Previous, 1..5 and Next: 5 pages fit with no gap.
    expect(_labels(html), ['Previous', '1', '2', '3', '4', '5', 'Next']);
  });

  test('the current page has aria-current, and only it', () async {
    final html = await _html('page=3', total: 50);
    expect('aria-current="page"'.allMatches(html), hasLength(1));
    expect(html, matches(RegExp(r'<a [^>]*aria-current="page"[^>]*>3</a>')));
  });

  test(
    'page 1 is the URL without `page`; others keep the whole query',
    () async {
      final html = await _html(
        'q=caf%C3%A9&status=open&page=2&sort=-name',
        total: 30,
      );
      expect(_hrefs(html), [
        '/orders?q=caf%C3%A9&amp;status=open&amp;sort=-name', // previous → 1
        '/orders?q=caf%C3%A9&amp;status=open&amp;sort=-name', // 1
        '/orders?q=caf%C3%A9&amp;status=open&amp;page=2&amp;sort=-name',
        '/orders?q=caf%C3%A9&amp;status=open&amp;page=3&amp;sort=-name',
        '/orders?q=caf%C3%A9&amp;status=open&amp;page=3&amp;sort=-name', // next
      ]);
    },
  );

  test('a number link is named "Page N" for assistive tech', () async {
    final html = await _html('page=3', total: 50);
    expect(
      html,
      matches(RegExp(r'<a [^>]*aria-label="Page 3"[^>]*aria-current="page"')),
    );
    expect(html, contains('aria-label="Page 1"'));
    // Previous and Next keep their own text as their name.
    expect(html, isNot(contains('aria-label="Page Previous"')));
  });

  test(
    'previous and next say so to the browser and to assistive tech',
    () async {
      final html = await _html('page=2', total: 30);
      expect(html, matches(RegExp(r'<a [^>]*rel="prev"[^>]*>Previous</a>')));
      expect(html, matches(RegExp(r'<a [^>]*rel="next"[^>]*>Next</a>')));
    },
  );

  test('at the ends the missing direction is not a link', () async {
    final first = await _html('', total: 30);
    expect(first, isNot(matches(RegExp(r'rel="prev"'))));
    expect(
      first,
      matches(RegExp(r'<span [^>]*aria-disabled="true"[^>]*>Previous</span>')),
    );
    final last = await _html('page=3', total: 30);
    expect(last, isNot(matches(RegExp(r'rel="next"'))));
    expect(
      last,
      matches(RegExp(r'<span [^>]*aria-disabled="true"[^>]*>Next</span>')),
    );
  });

  test('a long list shows the ends, the neighbours and gaps', () async {
    final html = await _html('page=50', total: 1000);
    expect(_labels(html), ['Previous', '1', '49', '50', '51', '100', 'Next']);
    // The gaps are text, hidden from assistive tech.
    expect('aria-hidden="true"'.allMatches(html), hasLength(2));
    expect(html, contains('…'));
  });

  test('a gap of one page shows that page instead of dots', () async {
    final html = await _html('page=4', total: 100);
    expect(_labels(html), ['Previous', '1', '2', '3', '4', '5', '10', 'Next']);
    expect('aria-hidden="true"'.allMatches(html), hasLength(1));
  });

  test('window widens the neighbours', () async {
    final html = await _html('page=50', total: 1000, window: 3);
    expect(_labels(html), [
      'Previous',
      '1',
      '47',
      '48',
      '49',
      '50',
      '51',
      '52',
      '53',
      '100',
      'Next',
    ]);
  });

  test('one page (or none) needs no links', () async {
    expect(await _html('', total: 10), isNot(contains('<nav')));
    expect(await _html('', total: 0), isNot(contains('<nav')));
  });

  test('a page past the end is shown as the last one', () async {
    final html = await _html('page=99', total: 30);
    expect(html, matches(RegExp(r'<a [^>]*aria-current="page"[^>]*>3</a>')));
  });

  test('a million pages still make a handful of links', () async {
    final html = await _html('page=500000', total: 10000000);
    expect(_labels(html).length, lessThan(10));
  });

  test('the action key of a failed post never appears in a link', () async {
    final html = await _html('tab=a&/save&page=2', total: 50);
    expect(html, isNot(contains('save')));
    expect(_hrefs(html).first, '/orders?tab=a');
  });

  test('hostile parameters are escaped, not injected', () async {
    final html = await _html(
      'q=%22%3E%3Cscript%3Ealert(1)%3C/script%3E&page=2',
      total: 50,
    );
    expect(html, isNot(contains('<script>alert')));
  });

  test('labels can be translated', () async {
    final request = PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://s.test/x?page=2'),
    );
    final html = bodyOfPage(
      await renderDocument(
        ThorApp(
          child: Pagination(
            list: request.listQuery(pageSize: 10),
            total: 30,
            previousLabel: 'Back',
            nextLabel: 'Forward',
            semanticLabel: 'Results pages',
            pageLabel: 'Results page',
          ),
        ),
      ),
    );
    expect(_labels(html), ['Back', '1', '2', '3', 'Forward']);
    expect(html, contains('aria-label="Results pages"'));
    expect(html, contains('aria-label="Results page 2"'));
  });

  test('Pagination.custom shows a page past the end as the last one', () async {
    final html = bodyOfPage(
      await renderDocument(
        ThorApp(
          child: Pagination.custom(
            page: 10,
            pageCount: 5,
            href: (n) => '/p/$n',
          ),
        ),
      ),
    );
    expect('aria-current="page"'.allMatches(html), hasLength(1));
    expect(html, contains('href="/p/4" rel="prev"'));
    expect(html, isNot(contains('/p/9')));
    expect(html, isNot(contains('rel="next"')));
  });
}
