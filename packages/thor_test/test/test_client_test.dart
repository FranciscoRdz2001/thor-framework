// The HTTP test client (`handler.client()`): cookie jar, same-origin
// headers, forms, redirects, matchers. Each test runs against a real
// RouteHandler, so what the client sends is what the server checks.
@TestOn('vm')
library;

import 'dart:async';

import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

/// `/echo` shows the `Cookie` header it received (so a test sees exactly
/// what the jar sent), `/login` and `/set` are the actions.
class _EchoPage extends ThorPage<String> {
  const _EchoPage();

  @override
  String load(PageRequest request) => request.headers['cookie'] ?? '(none)';

  @override
  Widget build(BuildContext context, PageState<String> state) =>
      Column(children: [Text('cookies ${state.data}'), const Text('echo')]);
}

class _SetPage extends ThorPage<void> {
  const _SetPage();

  /// Sets the cookie the form describes: name, value, path, max-age
  /// (seconds), expires (an HTTP date) and secure.
  Future<ActionResult?> cookie(PageRequest request) async {
    final form = await request.form();
    request.response.setCookie(
      form['name']!,
      form['value'] ?? '',
      path: form['path'] ?? '/',
      maxAge: form['max_age'] == null
          ? null
          : Duration(seconds: int.parse(form['max_age']!)),
      secure: form['secure'] == '1' ? true : null,
    );
    return Redirect(RouteUrl(form['to'] ?? '/echo'));
  }

  Future<ActionResult?> raw(PageRequest request) async {
    final form = await request.form();
    request.response.cookies.add(_Verbatim(form['line']!));
    return const Redirect(RouteUrl('/echo'));
  }

  Future<ActionResult?> reject(PageRequest request) async {
    final form = await request.form();
    return ActionResult.fail(422, 'rejected ${form['name']}');
  }

  Future<ActionResult?> body(PageRequest request) async => ActionResult.success(
    '${request.headers['content-type']}|${await request.text()}',
  );

  Future<ActionResult?> temporary(PageRequest request) async =>
      const Redirect.temporary(RouteUrl('/echo'));

  Future<ActionResult?> away(PageRequest request) async =>
      const Redirect(RouteUrl('https://elsewhere.test/x'));

  @override
  Widget build(BuildContext context, PageState<void> state) => Text(
    'set ${state.form is ActionResult ? (state.form! as ActionResult).data : state.form ?? ''}',
  );
}

/// A `Set-Cookie` line written as is (the jar must read what the wire has).
class _Verbatim extends SetCookie {
  _Verbatim(this.line) : super('x', 'x');
  final String line;

  @override
  String toHeader({bool secureByDefault = false}) => line;
}

class _LoopPage extends ThorPage<void> {
  const _LoopPage(this.to);
  final String to;

  @override
  RouteUrl? redirect(PageRequest request) => RouteUrl(to);

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      const Text('never');
}

class _HomePage extends ThorPage<void> {
  const _HomePage();

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      const Column(children: [Heading('Welcome'), Text('home page')]);
}

class Heading extends StatelessWidget {
  const Heading(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(text);
}

void registerActions() => registerPageActions({
  _SetPage: [
    PageActionMethod.request('cookie', (p) => (p as _SetPage).cookie),
    PageActionMethod.request('raw', (p) => (p as _SetPage).raw),
    PageActionMethod.request('reject', (p) => (p as _SetPage).reject),
    PageActionMethod.request('body', (p) => (p as _SetPage).body),
    PageActionMethod.request('temporary', (p) => (p as _SetPage).temporary),
    PageActionMethod.request('away', (p) => (p as _SetPage).away),
  ],
});

void main() {
  registerActions();
  final app = ThorApp.router(
    routerConfig: ThorRouter([
      ThorRoute('/', const _HomePage()),
      ThorRoute('/echo', const _EchoPage()),
      ThorRoute('/admin/echo', const _EchoPage()),
      ThorRoute('/set', const _SetPage()),
      ThorRoute('/loop-a', const _LoopPage('/loop-b')),
      ThorRoute('/loop-b', const _LoopPage('/loop-a')),
      ThorRoute('/guarded', const _LoopPage('/echo')),
    ]),
  );
  RouteHandler<Widget> handler() => RouteHandler<Widget>(
    routes: app.routes,
    renderer: WidgetRenderer.router(app),
  );

  setUpAll(initializeThorTests);

  Future<ThorTestResponse> setCookie(
    ThorTestClient client,
    String name,
    String value, {
    String path = '/',
    int? maxAge,
    bool secure = false,
    String to = '/echo',
  }) => client.post(
    '/set?/cookie',
    form: {
      'name': name,
      'value': value,
      'path': path,
      'max_age': ?maxAge?.toString(),
      if (secure) 'secure': '1',
      'to': to,
    },
  );

  group('requests', () {
    test('get answers the page: text, status, html', () async {
      final res = await handler().client().get('/');
      expect(res, hasStatus(200));
      expect(res.text, contains('home page'));
      expect(res.html.querySelector('[data-thor="Text"]')!.text, 'Welcome');
      expect(res.headers['content-type'], contains('text/html'));
    });

    test('an unknown route is a 404 and the matcher says what came', () async {
      final res = await handler().client().get('/missing');
      expect(res, hasStatus(404));
      expect(res, isNot(hasStatus(200)));
      expect(
        () => expect(res, hasStatus(200)),
        throwsA(
          isA<TestFailure>().having(
            (e) => e.message,
            'message',
            allOf(contains('404'), contains('GET /missing')),
          ),
        ),
      );
    });

    test('a POST carries the origin and host: never a CSRF 403', () async {
      final res = await handler().client().post(
        '/set?/reject',
        form: {'name': 'ana'},
      );
      expect(res, hasStatus(422));
    });

    test('headers of the call win, and a foreign origin is a 403', () async {
      final res = await handler().client().post(
        '/set?/reject',
        form: {'name': 'ana'},
        headers: {const HttpHeader('Origin'): 'http://evil.test'},
      );
      expect(res, hasStatus(403));
    });

    test('a null header takes the client\'s off: no Origin is a 403', () async {
      final res = await handler().client().post(
        '/set?/reject',
        form: {'name': 'ana'},
        headers: {HttpHeader.origin: null},
      );
      expect(res, hasStatus(403));
    });

    test('an https origin makes the server mark cookies Secure', () async {
      final client = handler().client(origin: 'https://site.test');
      final res = await setCookie(client, 'sid', 'a');
      expect(res.cookies.single, contains('Secure'));
      // The jar keeps it and sends it: Secure is never a reason to drop it.
      expect((await client.get('/echo')).text, contains('sid=a'));
    });

    test('put and delete are the server\'s 405', () async {
      final client = handler().client();
      expect(await client.send(HttpMethod.put, '/echo'), hasStatus(405));
      expect(await client.send(HttpMethod.delete, '/echo'), hasStatus(405));
    });

    test('form and json together are a mistake', () {
      expect(
        () => handler().client().post('/set', form: {'a': '1'}, json: {}),
        throwsArgumentError,
      );
    });
  });

  group('forms', () {
    test('urlencoded by default: hostile values arrive as written', () async {
      final client = handler().client();
      const nasty = 'a&b=c%20d\n<script>alert(1)</script> ñ 日本 😀';
      final res = await client.post('/set?/reject', form: {'name': nasty});
      expect(res, hasStatus(422));
      // The page shows the value escaped, never as markup.
      expect(res.text, contains('rejected a&amp;b=c%20d'));
      expect(res.text, isNot(contains('<script>alert(1)')));
      expect(
        res.html
            .querySelectorAll('script')
            .where((s) => s.text.contains('alert(1)')),
        isEmpty,
      );
    });

    test('a list value repeats the field', () async {
      final res = await handler().client().post(
        '/set?/reject',
        form: {
          'name': ['first', 'second'],
        },
      );
      expect(res.text, contains('rejected first'));
    });

    test('json sends the body and the content type', () async {
      final res = await handler().client().post('/set?/body', json: {'a': 1});
      expect(res, hasStatus(200));
      expect(res.text, contains('application/json'));
      expect(res.text, contains('{"a":1}'));
    });

    test('a 422 keeps the status and the page', () async {
      final res = await handler().client().post(
        '/set?/reject',
        form: {'name': 'ana'},
      );
      expect(res, hasStatus(422));
      expect(res.text, contains('rejected ana'));
    });
  });

  group('cookies', () {
    test('Set-Cookie is kept and sent back', () async {
      final client = handler().client();
      expect((await client.get('/echo')).text, contains('(none)'));
      await setCookie(client, 'sid', 'abc');
      expect(client.cookies, {'sid': 'abc'});
      expect((await client.get('/echo')).text, contains('sid=abc'));
    });

    test('a cookie of the same name and path is overwritten', () async {
      final client = handler().client();
      await setCookie(client, 'sid', 'one');
      await setCookie(client, 'sid', 'two');
      final echo = (await client.get('/echo')).text;
      expect(echo, contains('cookies sid=two'));
      expect(echo, isNot(contains('sid=one')));
    });

    test('Max-Age=0 deletes it', () async {
      final client = handler().client();
      await setCookie(client, 'sid', 'a');
      await setCookie(client, 'sid', '', maxAge: 0);
      expect(client.cookies, isEmpty);
      expect((await client.get('/echo')).text, contains('(none)'));
    });

    test('an Expires in the past deletes it', () async {
      final client = handler().client();
      await setCookie(client, 'sid', 'a');
      await client.post(
        '/set?/raw',
        form: {'line': 'sid=; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT'},
      );
      expect(client.cookies, isEmpty);
    });

    test('a cookie expires when its Max-Age passes', () async {
      var now = DateTime.utc(2030);
      final client = handler().client(now: () => now);
      await setCookie(client, 'sid', 'a', maxAge: 60);
      now = now.add(const Duration(seconds: 59));
      expect((await client.get('/echo')).text, contains('sid=a'));
      now = now.add(const Duration(seconds: 2));
      expect((await client.get('/echo')).text, contains('(none)'));
      expect(client.cookies, isEmpty);
    });

    test('Max-Age wins over Expires', () async {
      final client = handler().client();
      await client.post(
        '/set?/raw',
        form: {
          'line':
              'sid=a; Path=/; Max-Age=600; Expires=Thu, 01 Jan 1970 00:00:00 GMT',
        },
      );
      expect(client.cookies, {'sid': 'a'});
    });

    test('Path scopes it, and the longest path goes first', () async {
      final client = handler().client();
      await setCookie(client, 'k', 'root');
      await setCookie(client, 'k', 'admin', path: '/admin');
      await setCookie(client, 'only', 'admin', path: '/admin');
      final root = (await client.get('/echo')).text;
      expect(root, contains('k=root'));
      expect(root, isNot(contains('only')));
      final admin = (await client.get('/admin/echo')).text;
      expect(admin.indexOf('k=admin'), lessThan(admin.indexOf('k=root')));
      expect(admin, contains('only=admin'));
    });

    test('a path that only shares a prefix does not match', () async {
      final client = handler().client();
      await setCookie(client, 'k', 'v', path: '/adm');
      expect((await client.get('/admin/echo')).text, contains('(none)'));
    });

    test('values with ; = spaces and unicode survive the round trip', () async {
      final client = handler().client();
      const value = 'a;b=c d ñ 日本"';
      await setCookie(client, 'sid', value);
      expect(client.cookies['sid'], value);
      expect((await client.get('/echo')).text, contains('cookies sid='));
      expect(client.cookie('sid'), value);
    });

    test('a malformed Set-Cookie line is ignored, never a crash', () async {
      final client = handler().client();
      for (final line in [
        '',
        '=novalue',
        'noequals',
        ';;;',
        'a=b; Max-Age=x',
      ]) {
        await client.post('/set?/raw', form: {'line': line});
      }
      expect(client.cookies.keys, everyElement(anyOf('a')));
    });

    test('cookies the test seeds are sent, and can be cleared', () async {
      final client = handler().client()..setCookie('sid', 'seeded');
      expect((await client.get('/echo')).text, contains('sid=seeded'));
      client.clearCookies();
      expect((await client.get('/echo')).text, contains('(none)'));
      expect(() => client.setCookie('bad name', 'v'), throwsArgumentError);
    });

    test('two clients never share a jar', () async {
      final h = handler();
      final a = h.client(), b = h.client();
      await setCookie(a, 'sid', 'a');
      expect(b.cookies, isEmpty);
    });

    test('concurrent requests share one jar without losing a cookie', () async {
      final client = handler().client();
      await Future.wait([
        for (var i = 0; i < 10; i++) setCookie(client, 'c$i', '$i'),
        for (var i = 0; i < 10; i++) client.get('/echo'),
        for (var i = 0; i < 6; i++) setCookie(client, 'same', '$i'),
      ]);
      expect(
        client.cookies.keys,
        containsAll([for (var i = 0; i < 10; i++) 'c$i']),
      );
      expect(client.cookies['same'], isIn([for (var i = 0; i < 6; i++) '$i']));
      final echo = (await client.get('/echo')).text;
      expect(RegExp('same=').allMatches(echo), hasLength(1));
    });
  });

  group('redirects', () {
    test('a 303 is a response like any other until you follow it', () async {
      final client = handler().client();
      final res = await setCookie(client, 'sid', 'a');
      expect(res, redirectsTo('/echo'));
      expect(res, hasStatus(303));
      expect(res, isNot(redirectsTo('/elsewhere')));
      expect(await client.get('/echo'), isNot(redirectsTo('/echo')));
    });

    test(
      'follow: true goes to the page with the cookies it just got',
      () async {
        final client = handler().client();
        final res = await client.post(
          '/set?/cookie',
          form: {'name': 'sid', 'value': 'zz'},
          follow: true,
        );
        expect(res, hasStatus(200));
        expect(res.text, contains('sid=zz'));
        expect(res.redirects, ['/echo']);
      },
    );

    test('a guard\'s 302 is followed on a get', () async {
      final client = handler().client();
      final res = await client.get('/guarded');
      expect(res, hasStatus(302));
      expect(res, redirectsTo('/echo'));
      final followed = await client.get('/guarded', follow: true);
      expect(followed, hasStatus(200));
      expect(followed.uri.path, '/echo');
    });

    test('a redirect loop stops at maxRedirects and names the chain', () async {
      final client = handler().client(maxRedirects: 4);
      await expectLater(
        client.get('/loop-a', follow: true),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('4 redirects'),
              contains('/loop-a'),
              contains('/loop-b'),
            ),
          ),
        ),
      );
    });

    test('a 307 keeps the method: the follow is a POST again', () async {
      final client = handler().client();
      final res = await client.post('/set?/temporary', form: {'a': '1'});
      expect(res, hasStatus(307));
      // A POST to /echo has no action: the page answers it (307 kept POST).
      final followed = await client.follow(res);
      expect(followed.method, HttpMethod.post);
    });

    test('a redirect out of the app is returned, not followed', () async {
      final client = handler().client();
      final res = await client.post('/set?/away', follow: true);
      expect(res, redirectsTo('https://elsewhere.test/x'));
    });

    test('following a response that is no redirect is a mistake', () async {
      final client = handler().client();
      final res = await client.get('/');
      expect(() => client.follow(res), throwsStateError);
    });
  });

  group('helpers', () {
    test('json of an html page is a FormatException', () async {
      final res = await handler().client().get('/');
      expect(res.html.body, isNotNull);
      expect(() => res.json, throwsFormatException);
    });

    test('hasStatus takes a matcher', () async {
      final res = await handler().client().get('/');
      expect(res, hasStatus(inInclusiveRange(200, 299)));
      expect(res, isNot(hasStatus(greaterThan(299))));
    });
  });
}
