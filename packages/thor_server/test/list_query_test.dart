// `request.listQuery(pageSize:)` reads the state of a list from the URL
// (q, page, sort, filters) the way every list page needs it, so the URL is
// the state: a link, a bookmark and «back» all work, with no JavaScript.
import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

PageRequest _at(String query) => PageRequest(
  method: HttpMethod.get,
  uri: Uri.parse('http://s.test/orders${query.isEmpty ? '' : '?$query'}'),
);

ListQuery _list(
  String query, {
  int pageSize = 20,
  Set<String> sorts = const {'name', 'created'},
  String? defaultSort,
  Set<String> filters = const {'status'},
}) => _at(query).listQuery(
  pageSize: pageSize,
  sorts: sorts,
  defaultSort: defaultSort,
  filters: filters,
);

void main() {
  group('page', () {
    test('is 1-based and 1 by default', () {
      expect(_list('').page, 1);
      expect(_list('page=1').page, 1);
      expect(_list('page=7').page, 7);
    });

    test('anything that is not a whole page number is page 1', () {
      for (final bad in [
        '0',
        '-1',
        '-99',
        'abc',
        '',
        '2.5',
        '1e3',
        '0x10',
        ' 3',
        '3 ',
        '+3',
        '٣', // Arabic-Indic digit
        '3;drop',
        '%00',
      ]) {
        expect(_list('page=$bad').page, 1, reason: bad);
      }
    });

    test('a huge page is capped, not a crash or an overflow', () {
      final l = _list('page=99999999999999999999999');
      expect(l.page, ListQuery.maxPage);
      expect(l.offset, (ListQuery.maxPage - 1) * 20);
      expect(_list('page=${ListQuery.maxPage + 1}').page, ListQuery.maxPage);
    });

    test('offset and limit follow the page size', () {
      final l = _list('page=3', pageSize: 25);
      expect(l.offset, 50);
      expect(l.limit, 25);
      expect(l.pageSize, 25);
    });

    test('the first of two page values counts', () {
      expect(_list('page=2&page=5').page, 2);
    });

    test('clampTo brings a page past the end back to the last one', () {
      final l = _list('page=50');
      expect(l.pageCount(95), 5);
      expect(l.clampTo(95).page, 5);
      expect(l.clampTo(0).page, 1);
      expect(_list('page=2').clampTo(95).page, 2);
      expect(l.pageCount(0), 1);
      expect(l.pageCount(100), 5);
      expect(l.pageCount(101), 6);
    });
  });

  group('q', () {
    test('is the search text, trimmed', () {
      expect(_list('q=+caf%C3%A9+%E6%97%A5%E6%9C%AC+').q, 'café 日本');
      expect(_list('').q, '');
    });

    test('is capped by characters, never cutting a pair in two', () {
      final l = _list('q=${'%F0%9F%98%80' * 300}');
      expect(l.q.runes.length, ListQuery.maxQueryLength);
      expect(l.q.runes.every((r) => r == 0x1F600), isTrue);
    });

    test('a broken escape does not throw', () {
      expect(_list('q=%E0%A4%A').q, isA<String>());
    });
  });

  group('sort', () {
    test('only names the page allows, `-` for descending', () {
      expect(_list('sort=name').sort, 'name');
      expect(_list('sort=name').descending, isFalse);
      expect(_list('sort=-created').sort, 'created');
      expect(_list('sort=-created').descending, isTrue);
    });

    test('anything else falls back to the default (no injection)', () {
      for (final bad in [
        'password',
        'name;DROP TABLE orders',
        'name desc',
        '-',
        '--name',
        'NAME',
        '../name',
        'name,created',
        '',
        '__proto__',
      ]) {
        final l = _list('sort=$bad', defaultSort: '-created');
        expect(l.sort, 'created', reason: bad);
        expect(l.descending, isTrue, reason: bad);
        expect(_list('sort=$bad').sort, isNull, reason: bad);
      }
    });

    test('no sorts allowed: sort is always null', () {
      expect(_list('sort=name', sorts: const {}).sort, isNull);
    });
  });

  group('filters', () {
    test('only the declared ones, non-empty', () {
      final l = _list('status=open&secret=1&status=closed');
      expect(l.filters, {'status': 'open'});
      expect(l.filter('status'), 'open');
      expect(_list('status=').filters, isEmpty);
    });

    test('a filter that is not declared is a mistake', () {
      expect(() => _list('').filter('nope'), throwsArgumentError);
    });
  });

  group('links', () {
    test('withPage keeps every other parameter, in order', () {
      final l = _list('q=caf%C3%A9&status=open&page=2&utm=a%26b&sort=-name');
      expect(
        l.withPage(3),
        '/orders?q=caf%C3%A9&status=open&page=3&utm=a%26b&sort=-name',
      );
    });

    test('page 1 leaves `page` out', () {
      expect(_list('q=a&page=4').withPage(1), '/orders?q=a');
      expect(_list('page=4').withPage(1), '/orders');
    });

    test('a page number is clamped to 1..maxPage', () {
      expect(_list('').withPage(0), '/orders');
      expect(_list('').withPage(-5), '/orders');
      expect(_list('').withPage(1 << 40), '/orders?page=${ListQuery.maxPage}');
    });

    test('the action key of a failed POST never travels', () {
      final l = _list('tab=a&/save&%2Fdrop&page=2');
      expect(l.withPage(3), '/orders?tab=a&page=3');
    });

    test('a new search or filter goes back to page 1', () {
      final l = _list('q=a&page=4&status=open');
      expect(l.withSearch('ñ &'), '/orders?q=%C3%B1+%26&status=open');
      expect(l.withSearch(''), '/orders?status=open');
      expect(l.withFilter('status', 'closed'), '/orders?q=a&status=closed');
      expect(l.withFilter('status', null), '/orders?q=a');
    });

    test('a sort can be set, flipped or cleared', () {
      final l = _list('q=a');
      expect(l.withSort('name', descending: true), '/orders?q=a&sort=-name');
      expect(l.withSort('name'), '/orders?q=a&sort=name');
      expect(l.withSort(null), '/orders?q=a');
    });

    test('a sort the page does not allow is refused', () {
      expect(() => _list('').withSort('password'), throwsArgumentError);
    });

    test('toggleSort flips the direction of the current column', () {
      expect(_list('sort=name').toggleSort('name'), '/orders?sort=-name');
      expect(_list('sort=-name').toggleSort('name'), '/orders?sort=name');
      expect(_list('sort=created').toggleSort('name'), '/orders?sort=name');
    });

    test('the default sort is not written into the links', () {
      final l = _list('page=2', defaultSort: '-created');
      expect(l.sort, 'created');
      expect(l.withPage(3), '/orders?page=3');
      expect(l.withPage(1), '/orders');
      expect(l.withSearch('a'), '/orders?q=a');
      // Another column is written; back to the default is not.
      expect(l.withSort('name'), '/orders?sort=name');
      expect(
        _list(
          'sort=name',
          defaultSort: '-created',
        ).withSort('created', descending: true),
        '/orders',
      );
      expect(
        _list('sort=name', defaultSort: '-created').withPage(2),
        '/orders?sort=name&page=2',
      );
    });

    test('a list with no sorts leaves `sort` alone', () {
      final l = _list('sort=-name&page=2', sorts: const {});
      expect(l.withPage(3), '/orders?sort=-name&page=3');
    });

    test('the path keeps its own escapes', () {
      final l = PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://s.test/caf%C3%A9/lista?page=2'),
      ).listQuery(pageSize: 10);
      expect(l.withPage(3), '/caf%C3%A9/lista?page=3');
    });
  });
}
