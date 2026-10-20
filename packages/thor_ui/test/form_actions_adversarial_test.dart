// Fixture: fields without a label on purpose (focus, state and form behavior).
// ignore_for_file: thor_lints/text_field_without_label
// Adversarial tests on buttons and forms that post page actions: a field
// that collides with the button's argument, several submit buttons, an action
// of another page behind a guard, localized and grouped routes, routers built
// more than once, hostile HiddenField values.
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

final _calls = <String>[];
final _guarded = <String>[];

final class ContactForm extends FormSchema {
  const ContactForm._() : super(const [email]);
  static const schema = ContactForm._();
  static const email = TextSchemaField('email');
}

class CartPage extends ThorPage<void> {
  const CartPage();

  Future<ActionResult?> add(PageRequest request, String sku) async {
    _calls.add('add $sku');
    return null;
  }

  Future<ActionResult?> clear(PageRequest request) async {
    _calls.add('clear');
    return null;
  }

  Future<ActionResult?> send(
    PageRequest request,
    FormValues<ContactForm> values,
  ) async {
    _calls.add('send ${values.of(ContactForm.email)}');
    return null;
  }

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    children: [
      Form(
        child: Column(
          children: [
            const TextField(name: 'thor-arg'),
            FilledButton(
              onPost: const CartPage().add.withArg('real'),
              child: const Text('collide'),
            ),
          ],
        ),
      ),
      Form(
        onPost: const CartPage().clear,
        child: Column(
          children: [
            FilledButton(
              onPost: const CartPage().add.withArg('one'),
              child: const Text('first'),
            ),
            FilledButton(
              onPost: const CartPage().add.withArg('two'),
              child: const Text('second'),
            ),
          ],
        ),
      ),
      Form(
        schema: ContactForm.schema,
        onValid: const CartPage().send,
        child: Column(
          children: [
            const TextField(name: 'email'),
            FilledButton(
              onPost: const CartPage().add.withArg('x'),
              child: const Text('schema button'),
            ),
          ],
        ),
      ),
    ],
  );
}

class AdminPage extends ThorPage<void> {
  const AdminPage();

  Future<ActionResult?> delete(PageRequest request, int id) async {
    _guarded.add('delete $id');
    return null;
  }

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      const Text('admin');
}

class HomePage extends ThorPage<void> {
  const HomePage();

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    children: [
      Form(
        // A Form of this page, a button of another one.
        onPost: const CartPage().clear,
        child: FilledButton(
          onPost: const AdminPage().delete.withArg(1),
          child: const Text('admin button'),
        ),
      ),
      FilledButton(
        onPost: const CartPage().add.withArg('x'),
        child: const Text('cart button'),
      ),
      Form(
        child: Column(
          children: [
            const HiddenField(
              name: 'q"><script>',
              value:
                  '"><script>alert(1)</script> </script> é\u{1F600} &amp; \'',
            ),
            FilledButton(
              onPost: const CartPage().add.withArg('h'),
              child: const Text('hidden'),
            ),
          ],
        ),
      ),
    ],
  );
}

PageActionMethod _add() =>
    PageActionMethod.args('add', (p) => (p as CartPage).add, 1, (x) => [x[0]]);

void _register() => registerPageActions({
  CartPage: [
    _add(),
    PageActionMethod.request('clear', (p) => (p as CartPage).clear),
    PageActionMethod.valid<ContactForm>(
      'send',
      (p) => (p as CartPage).send,
      ContactForm.schema,
    ),
  ],
  AdminPage: [
    PageActionMethod.args(
      'delete',
      (p) => (p as AdminPage).delete,
      1,
      (x) => [int.parse(x[0])],
    ),
  ],
});

Middleware _requireAdmin = (request, next) async {
  if (request.headers['cookie'] != 'admin=1') {
    throw const HttpError(403, 'admins only');
  }
  return next();
};

RouteHandler<Widget> _handler(
  List<RouteTableNode> table, {
  LocaleRouting? locales,
}) {
  final app = ThorApp.router(routerConfig: ThorRouter(table));
  return RouteHandler<Widget>(
    routes: app.routes,
    renderer: WidgetRenderer.router(app),
    locales: locales,
    onError: (request, error, stack) {},
  );
}

PageRequest _get(String url) => PageRequest(
  method: HttpMethod.get,
  uri: Uri.parse('http://s.test$url'),
  headers: const {HttpHeader.host: 's.test'},
);

Future<ThorResponse> _post(
  RouteHandler<Widget> h,
  String url,
  String body, {
  String? cookie,
}) => h.handle(
  PageRequest(
    method: HttpMethod.post,
    uri: Uri.parse('http://s.test$url'),
    headers: {
      HttpHeader.host: 's.test',
      HttpHeader.origin: 'http://s.test',
      HttpHeader.contentType: 'application/x-www-form-urlencoded',
      HttpHeader.cookie: ?cookie,
    },
    body: Stream.value(utf8.encode(body)),
  ),
);

String _button(String html, String label) =>
    RegExp('<button[^>]*>$label').firstMatch(html)!.group(0)!;

void main() {
  _register();
  setUp(() {
    _calls.clear();
    _guarded.clear();
  });

  group('a field named thor-arg', () {
    final h = _handler([
      ThorRoute('/', const HomePage()),
      ThorRoute('/cart', const CartPage()),
      Group(
        middleware: [_requireAdmin],
        children: [ThorRoute('/admin', const AdminPage())],
      ),
    ]);

    test('cannot override the bound argument: the request is a 400', () async {
      // A Form field first, the button's own value after (tree order).
      final r = await _post(h, '/cart?/add', 'thor-arg=evil&thor-arg=real');
      expect(r.status, 400);
      expect(_calls, isEmpty);
    });

    test('the same the other way round', () async {
      final r = await _post(h, '/cart?/add', 'thor-arg=real&thor-arg=evil');
      expect(r.status, 400);
      expect(_calls, isEmpty);
    });

    test('one value is the argument', () async {
      final r = await _post(h, '/cart?/add', 'thor-arg=real');
      expect(r.status, 303);
      expect(_calls, ['add real']);
    });

    test('thor-action is a plain field with no meaning', () async {
      final r = await _post(h, '/cart?/add', 'thor-action=clear&thor-arg=real');
      expect(_calls, ['add real']);
      expect(r.status, 303);
    });
  });

  group('several submit buttons in one Form', () {
    final h = _handler([
      ThorRoute('/', const HomePage()),
      ThorRoute('/cart', const CartPage()),
    ]);

    test('each button carries its own argument and no shared form', () async {
      final html = (await h.handle(_get('/cart'))).text;
      final one = _button(html, 'first');
      final two = _button(html, 'second');
      expect(one, contains('value="one"'));
      expect(two, contains('value="two"'));
      expect(one, isNot(contains('form="')));
      expect(two, isNot(contains('form="')));
      expect(one, contains('formaction="?/add"'));
    });

    test('a Form with its own onPost keeps its action', () async {
      final html = (await h.handle(_get('/cart'))).text;
      expect(html, contains('action="?/clear"'));
    });

    test('a button of an onValid Form still carries its argument', () async {
      final html = (await h.handle(_get('/cart'))).text;
      final b = _button(html, 'schema button');
      expect(b, contains('name="thor-arg"'));
      expect(b, contains('formaction="?/add"'));
      expect(html, contains('action="?/send"'));
    });

    test('an onValid post with a valid form runs', () async {
      final r = await _post(h, '/cart?/send', 'email=a%40b.c');
      expect(r.status, 303);
      expect(_calls, ['send a@b.c']);
    });
  });

  group('an action of another page', () {
    final h = _handler([
      ThorRoute('/', const HomePage()),
      ThorRoute('/cart', const CartPage()),
      Group(
        middleware: [_requireAdmin],
        children: [ThorRoute('/admin', const AdminPage())],
      ),
    ]);

    test(
      'the Form is this page\'s and the button posts to the other',
      () async {
        final html = (await h.handle(_get('/'))).text;
        expect(html, contains('action="/cart?/clear"'));
        expect(
          _button(html, 'admin button'),
          // AdminPage has just that action: no key.
          contains('formaction="/admin"'),
        );
      },
    );

    test('the guard of the target page runs', () async {
      final denied = await _post(h, '/admin?/delete', 'thor-arg=1');
      expect(denied.status, 403);
      expect(_guarded, isEmpty);
      final ok = await _post(
        h,
        '/admin?/delete',
        'thor-arg=1',
        cookie: 'admin=1',
      );
      expect(ok.status, 303);
      expect(_guarded, ['delete 1']);
    });

    test('the query of this page does not travel to the other', () async {
      final html = (await h.handle(_get('/?q=x&tab=2'))).text;
      expect(_button(html, 'cart button'), contains('formaction="/cart?/add"'));
      expect(html, isNot(contains('/cart?q=x')));
      expect(html, isNot(contains('/admin?q=x')));
    });
  });

  group('routes', () {
    test(
      'a page on two routes: THOR-P020 for another page, relative for itself',
      () async {
        final h = _handler([
          ThorRoute('/', const HomePage()),
          Group(
            prefix: '/a',
            children: [ThorRoute('/a/cart', const CartPage())],
          ),
          Group(
            prefix: '/b',
            children: [ThorRoute('/b/cart', const CartPage())],
          ),
        ]);
        expect((await h.handle(_get('/'))).status, 500);
        for (final p in ['/a/cart', '/b/cart']) {
          final html = (await h.handle(_get(p))).text;
          expect(
            _button(html, 'first'),
            contains('formaction="?/add"'),
            reason: p,
          );
        }
      },
    );

    test('a router built again for the same page does not break it', () async {
      // A test file (or a hot reload) builds routers over and over; the page
      // is the same canonical instance, its route moved.
      _handler([
        ThorRoute('/', const HomePage()),
        ThorRoute('/old-cart', const CartPage()),
      ]);
      final h = _handler([
        ThorRoute('/', const HomePage()),
        ThorRoute('/cart', const CartPage()),
        Group(
          middleware: [_requireAdmin],
          children: [ThorRoute('/admin', const AdminPage())],
        ),
      ]);
      final r = await h.handle(_get('/'));
      expect(r.status, 200);
      expect(
        _button(r.text, 'cart button'),
        contains('formaction="/cart?/add"'),
      );
    });

    test('a locale prefix is not part of the page being rendered', () async {
      final h = _handler(
        [
          ThorRoute('/', const HomePage()),
          ThorRoute('/cart', const CartPage()),
        ],
        locales: LocaleRouting(
          supportedLocales: [const Locale('es'), const Locale('en')],
          strategy: LocaleStrategy.prefix,
        ),
      );
      final own = (await h.handle(_get('/en/cart'))).text;
      expect(_button(own, 'first'), contains('formaction="?/add"'));
      expect(own, contains('action="?/clear"'));
      final other = (await h.handle(_get('/en'))).text;
      // The other page's URL keeps the visitor's language.
      expect(
        _button(other, 'cart button'),
        contains('formaction="/en/cart?/add"'),
      );
    });
  });

  group('HiddenField', () {
    test('escapes quotes, tags and keeps unicode', () async {
      final h = _handler([
        ThorRoute('/', const HomePage()),
        ThorRoute('/cart', const CartPage()),
        Group(
          middleware: [_requireAdmin],
          children: [ThorRoute('/admin', const AdminPage())],
        ),
      ]);
      final html = (await h.handle(_get('/'))).text;
      expect(html, isNot(contains('<script>alert(1)')));
      expect(html, isNot(contains('name="q"><script>')));
      expect(html, contains('é\u{1F600}'));
      expect(html, contains('&amp;amp;'));
    });
  });
}
