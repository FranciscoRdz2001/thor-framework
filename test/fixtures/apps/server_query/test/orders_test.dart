// The lists and forms lab (`/orders`, `/edit`): lists in the URL, a query with a
// class argument, forms that refill and keep the query.
import 'package:server_query/app.dart';
import 'package:server_query/core/repositories/orders_repository.dart';
import 'package:server_query/modules/orders/pages/edit_page.dart';
import 'package:server_query/modules/orders/state/orders_state.dart';
import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';

void main() {
  setUp(() {
    ordersRepository.touched.clear();
    savedRecord['name'] = 'Saved name';
  });

  group('the class argument of a query', () {
    test('the server decodes it and runs the query with it', () async {
      final app = appHandler().client();
      await app.get('/orders');
      final r = await app.query(
        ordersList.found,
        const OrdersFilter(q: 'ana', page: 1, tags: ['a', 'b']),
      );
      expect(r, hasStatus(200));
      expect(r.data, isA<List<Object?>>());
      expect((r.data! as List).every((e) => '$e'.contains('Ana')), isTrue);
    });

    test('a hostile argument is a 400, not a 500', () async {
      final app = appHandler().client();
      await app.get('/orders');
      for (final bad in <Object?>[
        'ana',
        3,
        <String, Object?>{},
        {'q': 1, 'page': 1, 'tags': <String>[]},
        {
          'q': '',
          'page': 1,
          'tags': [1],
        },
        {'q': '', 'page': 'x', 'tags': <String>[]},
      ]) {
        final r = await app.callQuery('OrdersListState.found', arg: bad);
        expect(r, hasStatus(400), reason: '$bad');
      }
    });
  });

  group('/orders', () {
    test('the URL is the list state, links keep it', () async {
      final app = appHandler().client();
      final r = await app.get('/orders?q=a&page=2&status=open&sort=-total');
      expect(r, hasStatus(200));
      expect(r.text, contains('aria-current="page"'));
      expect(
        r.text,
        contains('href="/orders?q=a&amp;status=open&amp;sort=-total"'),
      );
      expect(r.text, contains('page=3'));
    });

    test('hand-made pages are 1 or the last, never an error', () async {
      final app = appHandler().client();
      for (final bad in ['0', '-1', 'abc']) {
        final r = await app.get('/orders?page=$bad');
        expect(r, hasStatus(200), reason: bad);
      }
      // Past the end: the last page (with its rows), not an empty one.
      final far = await app.get('/orders?q=&page=99999999999999999999');
      expect(far, hasStatus(302));
      expect(far.location, '/orders?page=5');
      final last = await app.get('/orders?page=5');
      expect(last, hasStatus(200));
    });

    test('an action keeps the query and goes back without it', () async {
      final app = appHandler().client();
      final page = await app.get('/orders?q=a&page=2');
      expect(page.text, contains('action="?q=a&amp;page=2&amp;/touch"'));
      final r = await app.post(
        '/orders?q=a&page=2&/touch',
        form: {'note': 'x'},
      );
      expect(r, hasStatus(303));
      expect(r.location, '/orders?q=a&page=2');
      expect(ordersRepository.touched, ['q=a&page=2&/touch']);
    });
  });

  group('/edit', () {
    test('shows the saved record', () async {
      final app = appHandler().client();
      final r = await app.get('/edit');
      expect(r.text, contains('value="Saved name"'));
      expect(r.text, contains('value="9.5"'));
      expect(r.text, contains('value="1990-05-03"'));
      expect(r.text, contains('novalidate'));
    });

    test('a failed post refills what was sent, with every message', () async {
      final app = appHandler().client();
      final r = await app.post(
        '/edit?/save',
        form: {
          'id': '7',
          'name': 'taken',
          'price': 'abc',
          'born': '2023-02-29',
          'nick': 'ab',
          'tags': ['toolong1', 'ok'],
          'plan': 'pro',
        },
      );
      expect(r, hasStatus(422));
      expect(r.text, contains('value="taken"'));
      expect(r.text, contains('That name is taken.'));
      expect(r.text, contains('Price is a number.'));
      expect(r.text, contains('Not a real date.'));
      expect(r.text, contains('Nick is short.'));
      expect(r.text, contains('Tag too long.'));
      expect(r.text, contains('Accept the terms.'));
      // The unchecked box stays unchecked whatever the record says.
      expect(
        RegExp(r'<input[^>]*name="terms"[^>]*>').firstMatch(r.text)![0],
        isNot(contains('checked')),
      );
    });

    test('a valid post saves and goes back', () async {
      final app = appHandler().client();
      final r = await app.post(
        '/edit?/save',
        form: {
          'id': '7',
          'name': 'New name',
          'price': '12.25',
          'born': '2000-02-29',
          'plan': 'free',
          'terms': 'on',
        },
      );
      expect(r, hasStatus(303));
      expect(r.location, '/edit');
      expect(savedRecord['name'], 'New name');
      expect(savedRecord['price'], 12.25);
    });

    test(
      'what a browser sends for a form left mostly empty is valid',
      () async {
        final app = appHandler().client();
        final r = await app.post(
          '/edit?/save',
          form: {
            'id': '7',
            'name': 'Nuevo nombre',
            'price': '12.25',
            'born': '1990-05-03',
            'nick': '',
            'tags': '',
            'plan': 'pro',
            'terms': 'on',
          },
        );
        expect(r, hasStatus(303), reason: r.text);
      },
    );

    test('the secret is required only when creating', () async {
      final app = appHandler().client();
      final ok = await app.post(
        '/edit?/save',
        form: {'id': '7', 'name': 'a', 'plan': 'free', 'terms': 'on'},
      );
      expect(ok, hasStatus(303));
      final creating = await app.post(
        '/edit?new=1&/save',
        form: {'id': '', 'name': 'a', 'plan': 'free', 'terms': 'on'},
      );
      expect(creating, hasStatus(422));
      expect(creating.text, contains('A secret is needed to create.'));
    });
  });
}
