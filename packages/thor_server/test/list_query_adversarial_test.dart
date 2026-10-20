// Adversarial tests for `listQuery`: the URL is hostile input to the list
// state and to the redirect that follows an action.
import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

PageRequest _post(String path, String body) => PageRequest(
  method: HttpMethod.post,
  uri: Uri.parse('http://site.test$path'),
  headers: {
    HttpHeader.host: 'site.test',
    HttpHeader.origin: 'http://site.test',
    HttpHeader.contentType: 'application/x-www-form-urlencoded',
  },
  body: Stream.value(utf8.encode(body)),
);

PageRequest _at(String path) =>
    PageRequest(method: HttpMethod.get, uri: Uri.parse('http://s.test$path'));

void main() {
  late RouteHandler<String> handler;

  setUp(() {
    handler = RouteHandler<String>(
      renderer: _Renderer(),
      routes: [
        PageRoute<String, void>(
          path: '[...rest]',
          build: (s) => 'catch-all',
          actions: {'save': (r) => null},
        ),
        PageRoute<String, void>(
          path: 'orders',
          build: (s) => 'orders',
          actions: {'save': (r) => null},
        ),
      ],
    );
  });

  group('the 303 after a successful action', () {
    test('keeps every other parameter, in order', () async {
      final r = await handler.handle(
        _post('/orders?tab=a&page=2&/save&q=x%20y', ''),
      );
      expect(r.status, 303);
      expect(r.headers['location'], '/orders?tab=a&page=2&q=x%20y');
    });

    test('drops every spelling of the action key', () async {
      for (final q in ['/save', '%2Fsave', '%2fsave', '/save=1']) {
        final r = await handler.handle(_post('/orders?page=2&$q', ''));
        expect(r.headers['location'], '/orders?page=2', reason: q);
      }
    });

    test('the trailing-slash redirect never leaves the site', () async {
      // Django's APPEND_SLASH had it (CVE-2018-14574): `//host/` → `//host`.
      final r = await handler.handle(_at('//evil.example/'));
      final to = r.headers['location'];
      if (to != null) expect(to, isNot(startsWith('//')));
    });

    test('a path with a leading double slash never leaves the site', () async {
      final r = await handler.handle(_post('//evil.example/orders?/save', ''));
      final to = r.headers['location'];
      if (to != null) {
        expect(to, isNot(startsWith('//')), reason: 'protocol-relative URL');
      }
    });
  });

  group('the list links', () {
    test('a path with a leading double slash stays on this site', () {
      final list = _at('//evil.example/orders?page=2').listQuery(pageSize: 10);
      expect(list.withPage(3), isNot(startsWith('//')));
      expect(list.withSearch('a'), isNot(startsWith('//')));
    });

    test('a repeated page keeps only the first', () {
      final list = _at('/orders?page=2&page=3&q=a&q=b').listQuery(pageSize: 10);
      expect(list.page, 2);
      expect(list.q, 'a');
      expect(list.withPage(4), '/orders?page=4&q=a');
    });

    test('a hostile sort never reaches the list', () {
      for (final bad in [
        'name;drop',
        '-name;drop',
        'name%00',
        '--name',
        '',
        '-',
        'NAME',
        'name ',
      ]) {
        final list = _at(
          '/orders?sort=${Uri.encodeQueryComponent(bad)}',
        ).listQuery(sorts: const {'name'});
        expect(list.sort, isNull, reason: bad);
      }
    });

    test('a filter with brackets or a value with a slash survives a link', () {
      final list = _at(
        '/orders?status=a%2Fb&x[]=1&x[]=2&page=2',
      ).listQuery(filters: const {'status'});
      expect(list.filter('status'), 'a/b');
      expect(
        list.withPage(3),
        '/orders?status=a%2Fb&x%5B%5D=1&x%5B%5D=2&page=3',
      );
    });

    test('a slash value in the query is not an action key', () {
      final list = _at('/orders?next=%2Fsave&page=2').listQuery();
      expect(list.withPage(3), '/orders?next=%2Fsave&page=3');
    });

    test('total 0 and a page beyond the last', () {
      final list = _at('/orders?page=9').listQuery(pageSize: 10);
      expect(list.pageCount(0), 1);
      expect(list.clampTo(0).page, 1);
      expect(list.clampTo(25).page, 3);
      expect(list.clampTo(25).offset, 20);
      expect(list.clampTo(1000).page, 9);
    });

    test('within sends a page past the end to the last one, query kept', () {
      final list = _at('/orders?q=a&page=9').listQuery(pageSize: 10);
      expect(list.within(90), same(list)); // page 9 exists
      expect(
        () => list.within(25),
        throwsA(
          isA<Redirect>()
              .having((r) => r.location, 'location', '/orders?q=a&page=3')
              .having((r) => r.status, 'status', 302),
        ),
      );
      expect(
        () => list.within(0),
        throwsA(
          isA<Redirect>().having((r) => r.location, 'location', '/orders?q=a'),
        ),
      );
    });

    test('a very long query keeps every link a bounded copy', () {
      final long = 'a=${'x' * 100000}';
      final list = _at('/orders?$long&page=2').listQuery();
      expect(list.withPage(3).length, lessThan(long.length + 50));
      expect(list.q.length, lessThanOrEqualTo(ListQuery.maxQueryLength));
    });
  });
}
