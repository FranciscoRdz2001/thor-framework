// A schema field without a decoration: the label is not what these tests check.
// ignore_for_file: thor_lints/text_field_without_label
// A page with exactly one action posts to its own path with no `?/name` key,
// and the server routes the keyless POST to that action. A page
// with several keeps `?/name`.
@TestOn('vm')
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

final class _LoginForm extends FormSchema {
  const _LoginForm._() : super(const [email]);

  static const schema = _LoginForm._();

  static const email = TextSchemaField(
    'email',
    validators: [Validator.required('Enter your e-mail')],
  );
}

final _calls = <String>[];

class _LoginPage extends ThorPage<void> {
  const _LoginPage();

  Future<ActionResult?> signIn(
    PageRequest request,
    FormValues<_LoginForm> values,
  ) async {
    _calls.add('signIn');
    return values.fail('Wrong password');
  }

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    children: [
      Form(
        schema: _LoginForm.schema,
        onValid: signIn,
        child: TextFormField(field: _LoginForm.email, form: state.form),
      ),
      if (state.form case final FormInvalid f) Text('errors ${f.messages}'),
    ],
  );
}

class _TwoPage extends ThorPage<void> {
  const _TwoPage();

  Future<ActionResult?> save(PageRequest request) async => null;
  Future<ActionResult?> drop(PageRequest request) async => null;

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    children: [
      Form(onPost: save, child: const Text('save')),
      Form(onPost: drop, child: const Text('drop')),
    ],
  );
}

/// One action, on a route with a parameter, and a button that posts an
/// argument: still one action.
class _ItemPage extends ThorPage<void> {
  const _ItemPage();

  Future<ActionResult?> remove(PageRequest request, int id) async {
    _calls.add('remove $id');
    return Redirect.back(request);
  }

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    children: [
      FilledButton(
        onPressed: null,
        onPost: remove.withArg(7),
        child: const Text('remove 7'),
      ),
      FilledButton(
        onPressed: null,
        onPost: remove.withArg(8),
        child: const Text('remove 8'),
      ),
    ],
  );
}

class _ShopPage extends ThorPage<void> {
  const _ShopPage();

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    children: [
      // The action of another page that has only that one.
      Form(onPost: const _CartPage().add, child: const Text('add')),
      Form(
        action: '/cart?from=shop',
        onPost: const _CartPage().add,
        child: const Text('add (query)'),
      ),
    ],
  );
}

class _CartPage extends ThorPage<void> {
  const _CartPage();

  Future<ActionResult?> add(PageRequest request) async {
    _calls.add('add');
    return null;
  }

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      const Text('cart');
}

/// One action with an argument behind a `confirm:` and another that is the
/// page's form with its own question.
class _AskPage extends ThorPage<void> {
  const _AskPage();

  Future<ActionResult?> drop(PageRequest request, int id) async {
    _calls.add('drop $id');
    return Redirect.back(request);
  }

  @override
  Widget build(BuildContext context, PageState<void> state) => FilledButton(
    onPressed: null,
    onPost: drop.withArg(3),
    confirm: const ConfirmSpec('Drop it?'),
    child: const Text('drop'),
  );
}

class _NoQueryPage extends ThorPage<void> {
  const _NoQueryPage();

  Future<ActionResult?> reset(PageRequest request) async => null;

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      Form(preserveQuery: false, onPost: reset, child: const Text('reset'));
}

class _SearchPage extends ThorPage<void> {
  const _SearchPage();

  Future<ActionResult?> save(PageRequest request) async => null;

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    children: [
      const Form(formMethod: FormMethod.get, child: Text('find')),
      Form(onPost: save, child: const Text('save')),
    ],
  );
}

/// What a browser reads from an attribute value.
String _unescape(String v) => v
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&');

void main() {
  registerPageActions({
    _SearchPage: [
      PageActionMethod.request('save', (p) => (p as _SearchPage).save),
    ],
    _LoginPage: [
      PageActionMethod.valid(
        'signIn',
        (p) => (p as _LoginPage).signIn,
        _LoginForm.schema,
      ),
    ],
    _TwoPage: [
      PageActionMethod.request('save', (p) => (p as _TwoPage).save),
      PageActionMethod.request('drop', (p) => (p as _TwoPage).drop),
    ],
    _ItemPage: [
      PageActionMethod.args(
        'remove',
        (p) => (p as _ItemPage).remove,
        1,
        (parts) => [int.parse(parts.single)],
      ),
    ],
    _CartPage: [PageActionMethod.request('add', (p) => (p as _CartPage).add)],
    _AskPage: [
      PageActionMethod.args(
        'drop',
        (p) => (p as _AskPage).drop,
        1,
        (parts) => [int.parse(parts.single)],
      ),
    ],
    _NoQueryPage: [
      PageActionMethod.request('reset', (p) => (p as _NoQueryPage).reset),
    ],
  });
  final app = ThorApp.router(
    routerConfig: ThorRouter([
      ThorRoute('/login', const _LoginPage()),
      ThorRoute('/two', const _TwoPage()),
      ThorRoute('/item/:slug', const _ItemPage()),
      ThorRoute('/shop', const _ShopPage()),
      ThorRoute('/cart', const _CartPage()),
      ThorRoute('/nq', const _NoQueryPage()),
      ThorRoute('/ask', const _AskPage()),
      ThorRoute('/ask/:slug', const _AskPage()),
      ThorRoute('/search', const _SearchPage()),
    ]),
  );
  final handler = RouteHandler<Widget>(
    routes: app.routes,
    renderer: WidgetRenderer.router(app),
  );

  Future<ThorResponse> get(String url) => handler.handle(
    PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://s.test$url'),
      headers: const {HttpHeader.host: 's.test'},
    ),
  );

  Future<ThorResponse> post(String url, [String body = '']) => handler.handle(
    PageRequest(
      method: HttpMethod.post,
      uri: Uri.parse('http://s.test$url'),
      headers: const {
        HttpHeader.host: 's.test',
        HttpHeader.origin: 'http://s.test',
        HttpHeader.contentType: 'application/x-www-form-urlencoded',
      },
      body: Stream.value(utf8.encode(body)),
    ),
  );

  List<String> attrs(String html, String name) => [
    for (final m in RegExp('\\s$name="([^"]*)"').allMatches(html)) m[1]!,
  ];

  setUp(_calls.clear);

  test('the only action posts to the page path, with no key', () async {
    final html = (await get('/login')).text;
    expect(attrs(html, 'action'), ['/login']);
    expect(html, isNot(contains('?/')));
  });

  test('a failed post leaves the URL at /login and re-posts there', () async {
    final r = await post('/login', 'email=a%40x.test');
    expect(_calls, ['signIn']);
    expect(r.status, 422);
    expect(r.text, contains('Wrong password'));
    expect(attrs(r.text, 'action'), ['/login']);
    // The schema still runs before the method (typed-action errors intact).
    final bad = await post('/login', 'email=');
    expect(bad.status, 422);
    expect(bad.text, contains('Enter your e-mail'));
    expect(_calls, ['signIn']);
    // The old URL still reaches it.
    await post('/login?/signIn', 'email=a%40x.test');
    expect(_calls, ['signIn', 'signIn']);
  });

  test('several actions keep ?/name and need it', () async {
    final html = (await get('/two')).text;
    expect(attrs(html, 'action'), ['?/save', '?/drop']);
    expect((await post('/two')).status, 404);
  });

  test('the page query goes along; preserveQuery: false drops it', () async {
    final html = (await get('/login?next=%2Fa')).text;
    expect(attrs(html, 'action'), ['/login?next=%2Fa']);
    // The action key of an old URL never travels.
    final old = (await get('/login?next=%2Fa&/signIn')).text;
    expect(attrs(old, 'action'), ['/login?next=%2Fa']);
  });

  test(
    'an argument button posts the path; Redirect.back lands on it',
    () async {
      final html = (await get('/item/shirt?qty=4')).text;
      expect(attrs(html, 'formaction'), [
        '/item/shirt?qty=4',
        '/item/shirt?qty=4',
      ]);
      expect(html, isNot(contains('?/remove')));
      final r = await post('/item/shirt?qty=4', 'thor-arg=7');
      expect(_calls, ['remove 7']);
      expect(r.status, 303);
      expect(r.headers['location'], '/item/shirt?qty=4');
    },
  );

  test("another page's only action posts to that page, no key", () async {
    final html = (await get('/shop')).text;
    expect(attrs(html, 'action').take(2), ['/cart', '/cart?from=shop']);
    await post('/cart');
    expect(_calls, ['add']);
  });

  test('preserveQuery: false posts the bare path', () async {
    expect(attrs((await get('/nq?a=1')).text, 'action'), ['/nq']);
  });

  test('a locale prefix stays on the path', () async {
    final localized = ThorApp.router(
      routerConfig: ThorRouter([ThorRoute('/login', const _LoginPage())]),
    );
    final h = RouteHandler<Widget>(
      routes: localized.routes,
      renderer: WidgetRenderer.router(localized),
      locales: LocaleRouting(
        supportedLocales: [const Locale('es'), const Locale('en')],
        strategy: LocaleStrategy.prefix,
      ),
    );
    final r = await h.handle(
      PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://s.test/en/login'),
        headers: const {HttpHeader.host: 's.test'},
      ),
    );
    expect(attrs(r.text, 'action'), ['/en/login']);
  });

  group('the path a form posts to is a path, whatever the URL held', () {
    // The request's path is decoded: put back in an attribute it must still
    // name the same page when the browser resolves it.
    for (final (url, slug) in [
      ('/item/a%3Fb', 'a?b'),
      ('/item/a%23b', 'a#b'),
      ('/item/100%25', '100%'),
      ('/item/a%20b', 'a b'),
      ('/item/a%22b%3Cc', 'a"b<c'),
      ('/item/a%2Fb', 'a/b'),
      ('/item/%C3%B1and%C3%BA', 'ñandú'),
    ]) {
      test('slug "$slug" posts back to the same page', () async {
        final html = (await get(url)).text;
        final action = attrs(html, 'formaction').first;
        // The attribute is HTML-decoded by the browser, then resolved as a
        // URL against the page: it must name the very same request.
        final posted = Uri.parse('http://s.test/').resolve(_unescape(action));
        expect(posted.query, isEmpty, reason: 'no query invented: $action');
        expect(posted.fragment, isEmpty, reason: 'no fragment: $action');
        final r = await post(posted.path, 'thor-arg=7');
        expect(r.status, 303, reason: '$action -> ${posted.path}');
        expect(_calls, ['remove 7']);
        // Back to the very same page.
        expect(Uri.parse(r.headers['location']!).path, posted.path);
        expect(Uri.decodeComponent(posted.path), '/item/$slug');
      });
    }
  });

  test(
    'a trailing slash is canonicalized with a 308 (the method stays)',
    () async {
      final r = await post('/login/', 'email=a%40x.test');
      expect(r.status, 308);
      expect(r.headers['location'], '/login');
      expect(_calls, isEmpty);
    },
  );

  test('a multipart upload reaches the default action', () async {
    const body =
        '--b\r\nContent-Disposition: form-data; name="email"\r\n\r\n'
        'a@x.test\r\n--b--\r\n';
    final r = await handler.handle(
      PageRequest(
        method: HttpMethod.post,
        uri: Uri.parse('http://s.test/login'),
        headers: const {
          HttpHeader.host: 's.test',
          HttpHeader.origin: 'http://s.test',
          HttpHeader.contentType: 'multipart/form-data; boundary=b',
        },
        body: Stream.value(utf8.encode(body)),
      ),
    );
    expect(_calls, ['signIn']);
    expect(r.status, 422);
    expect(r.text, contains('Wrong password'));
  });

  test('a GET form of the page keeps its own URL and method', () async {
    final html = (await get('/search?q=a')).text;
    final form = RegExp(r'<form[^>]*>').allMatches(html).map((m) => m[0]!);
    final get_ = form.firstWhere((f) => f.contains('method="get"'));
    expect(get_, isNot(contains('action="/search?')));
    expect(get_, isNot(contains('?/')));
    // The post form next to it posts keyless.
    expect(attrs(html, 'action'), contains('/search?q=a'));
  });

  test(
    'a POST with an unknown key is a 404 on a page with one action',
    () async {
      expect((await post('/login?/nope')).status, 404);
      expect(_calls, isEmpty);
    },
  );

  group('confirm: without JavaScript on the default action', () {
    test('the button keeps its question and the server asks first', () async {
      final html = (await get('/ask?x=1')).text;
      final formaction = _unescape(attrs(html, 'formaction').single);
      expect(formaction, startsWith('/ask?x=1&/thor-ask='));
      expect(html, isNot(contains('?/drop')));
      // Posted as the browser would: the path, the question, the argument.
      final asked = await post(formaction, 'thor-arg=3');
      expect(asked.status, 200);
      expect(asked.text, contains('Drop it?'));
      expect(_calls, isEmpty, reason: 'nothing runs before the yes');
      final yes = await post(formaction, 'thor-arg=3&thor-confirmed=1');
      expect(yes.status, 303);
      expect(_calls, ['drop 3']);
      expect(yes.headers['location'], '/ask?x=1');
    });

    test('still asks when the path is none a form should post to', () async {
      // A backslash in the (decoded) path: the action is left out (the form
      // posts to its own document), and the question must still travel.
      final html = (await get('/ask/a%5Cb')).text;
      final formaction = attrs(html, 'formaction');
      final name = attrs(html, 'name');
      final asked = [...formaction, ...name].any((v) => v.contains('thor-ask'));
      expect(asked, isTrue, reason: 'no question reaches the server: $html');
    });

    test('still asks outside a request, where no path is known', () async {
      // No request scope (a widget drawn on its own): the action is left out
      // and the question rides on the button's own formaction.
      final html = await renderDocument(
        ThorApp(
          child: FilledButton(
            onPressed: null,
            onPost: const _AskPage().drop.withArg(3),
            confirm: const ConfirmSpec('Drop it?'),
            child: const Text('drop'),
          ),
        ),
      );
      expect(html, contains('thor-ask'));
    });
  });
}
