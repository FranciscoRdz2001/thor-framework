@TestOn('vm')
library;

// `confirm:` without JavaScript: a POST that carries the question
// (`thor-ask`) and not the answer (`thor-confirmed`) is answered with a
// confirmation page, and the action does not run until a second POST says
// yes. Same-origin like every form post; nothing it echoes is unescaped.
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

class _CountingRenderer implements PageRenderer<String> {
  _CountingRenderer(this.onRender);

  final void Function() onRender;

  @override
  List<int> render(String page, RenderContext context) {
    onRender();
    return utf8.encode(page);
  }

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

String _ask({
  String t = 'Delete this order?',
  String? m,
  String? o,
  String? n,
}) => jsonEncode({'t': t, 'm': ?m, 'o': ?o, 'n': ?n});

void main() {
  late List<String> ran;
  late RouteHandler<String> handler;

  setUp(() {
    ran = [];
    handler = RouteHandler<String>(
      renderer: _Renderer(),
      onError: (request, error, stack) {},
      routes: [
        PageRoute<String, void>(
          path: 'orders',
          build: (s) => 'orders',
          actions: {
            'default': (r) async {
              ran.add('default ${(await r.form()).toMap()}');
              return const Redirect(RouteUrl('/orders'));
            },
            'delete': (r) async {
              ran.add('delete ${(await r.form()).toMap()}');
              return const Redirect(RouteUrl('/orders'));
            },
          },
        ),
        PageRoute<String, void>(path: 'plain', build: (s) => 'plain'),
      ],
    );
  });

  PageRequest post(
    String url,
    Map<String, String> fields, {
    Map<HttpHeader, String> headers = const {},
    String? body,
    String? type = 'application/x-www-form-urlencoded',
  }) => PageRequest(
    method: HttpMethod.post,
    uri: Uri.parse('http://site.test$url'),
    headers: {
      HttpHeader.host: 'site.test',
      HttpHeader.origin: 'http://site.test',
      HttpHeader.contentType: ?type,
      ...headers,
    },
    body: Stream.value(
      utf8.encode(
        body ??
            fields.entries
                .map(
                  (e) =>
                      '${Uri.encodeQueryComponent(e.key)}='
                      '${Uri.encodeQueryComponent(e.value)}',
                )
                .join('&'),
      ),
    ),
  );

  Future<String> page(ThorResponse r) async => utf8.decode(r.body);

  group('an unconfirmed destructive post', () {
    test('answers the question and does not run the action', () async {
      final r = await handler.handle(
        post('/orders?/delete', {'note': 'late', askField: _ask()}),
      );
      expect(r.status, 200);
      expect(r.headers['content-type'], startsWith('text/html'));
      expect(r.headers['cache-control'], contains('no-store'));
      expect(ran, isEmpty);
      final html = await page(r);
      expect(html, contains('Delete this order?'));
      // The yes posts the same URL again, with the fields and the answer.
      expect(html, contains('<form method="post" action="/orders?/delete"'));
      expect(html, contains('<input type="hidden" name="note" value="late">'));
      expect(
        html,
        contains('<input type="hidden" name="$confirmedField" value="1">'),
      );
      // The question itself is not posted back.
      expect(html, isNot(contains('name="$askField"')));
      expect(html, contains('noindex'));
    });

    test('the second post, with the answer, runs the action', () async {
      final r = await handler.handle(
        post('/orders?/delete', {
          'note': 'late',
          askField: _ask(),
          confirmedField: '1',
        }),
      );
      expect(r.status, 303);
      expect(ran, hasLength(1));
      expect(ran.single, contains('note: late'));
    });

    test('a post without a question runs as before', () async {
      final r = await handler.handle(post('/orders?/delete', {'id': '4'}));
      expect(r.status, 303);
      expect(ran, hasLength(1));
    });

    test('the default action asks too', () async {
      final r = await handler.handle(post('/orders', {askField: _ask()}));
      expect(r.status, 200);
      expect(ran, isEmpty);
    });

    test('a button with an argument carries the question in the URL', () async {
      final url =
          '/orders?q=a&/delete&${Uri.encodeQueryComponent(askQueryKey)}='
          '${Uri.encodeQueryComponent(_ask(t: 'Delete #7?'))}';
      final first = await handler.handle(post(url, {'thor-arg': '7'}));
      expect(first.status, 200);
      expect(ran, isEmpty);
      final html = await page(first);
      expect(html, contains('Delete #7?'));
      expect(html, contains('<input type="hidden" name="thor-arg" value="7">'));
      // The URL goes back as it came: the action name and the question.
      final action = RegExp(r'action="([^"]*)"').firstMatch(html)![1]!;
      expect(action, startsWith('/orders?q=a&amp;/delete&amp;'));
      final second = await handler.handle(
        post(action.replaceAll('&amp;', '&'), {
          'thor-arg': '7',
          confirmedField: '1',
        }),
      );
      expect(second.status, 303);
      expect(ran.single, contains('thor-arg: 7'));
    });

    test('the labels are the question\'s, or the app\'s', () async {
      final own = await page(
        await handler.handle(
          post('/orders', {
            askField: _ask(
              m: 'It cannot be undone.',
              o: 'Delete it',
              n: 'Keep it',
            ),
          }),
        ),
      );
      expect(own, contains('It cannot be undone.'));
      expect(own, contains('>Delete it</button>'));
      expect(own, contains('>Keep it</a>'));
      final plain = await page(
        await handler.handle(post('/orders', {askField: _ask()})),
      );
      const messages = ServerMessages();
      expect(plain, contains('>${messages.ok}</button>'));
      expect(plain, contains('>${messages.cancel}</a>'));
    });
  });

  group('nothing the visitor typed is echoed unescaped', () {
    test('the question, its labels and every replayed field', () async {
      const hostile = '<script>alert(1)</script>"\'&';
      final html = await page(
        await handler.handle(
          post('/orders', {
            'note': hostile,
            '"><b>': 'x',
            askField: _ask(t: hostile, m: hostile, o: hostile, n: hostile),
          }),
        ),
      );
      expect(html, isNot(contains('<script>')));
      expect(html, isNot(contains('<b>')));
      expect(html, isNot(contains('alert(1)</')));
      expect(html, contains('&lt;script&gt;'));
      expect(html, contains('&quot;'));
    });

    test('a hostile URL stays an attribute value', () async {
      final r = await handler.handle(
        post('/orders?/default&x=%22%3E%3Cscript%3E', {askField: _ask()}),
      );
      final html = await page(r);
      expect(html, isNot(contains('<script>')));
      expect(html, contains('%22%3E%3Cscript%3E'));
    });

    test('the way back is this site\'s page, never another', () async {
      Future<String> back(String? referer) async {
        final html = await page(
          await handler.handle(
            post(
              '/orders?x=1&/delete',
              {askField: _ask()},
              headers: {HttpHeader.referer: ?referer},
            ),
          ),
        );
        return RegExp(r'<a href="([^"]*)"').firstMatch(html)![1]!;
      }

      expect(await back(null), '/orders?x=1');
      expect(await back('http://site.test/orders?page=2'), '/orders?page=2');
      expect(await back('http://evil.test/phish'), '/orders?x=1');
      expect(await back('javascript:alert(1)'), '/orders?x=1');
      expect(await back('//evil.test/x'), '/orders?x=1');
    });

    test('a malformed or empty question is no question', () async {
      for (final ask in ['not json', '[]', '{"t":""}', '{"t":5}', '{}']) {
        ran.clear();
        final r = await handler.handle(post('/orders', {askField: ask}));
        expect(r.status, 303, reason: ask);
        expect(ran, hasLength(1), reason: ask);
      }
    });

    test('a huge question is cut, not rejected', () async {
      final html = await page(
        await handler.handle(
          post('/orders', {askField: _ask(t: 'x' * 5000, m: 'y' * 5000)}),
        ),
      );
      expect(html.length, lessThan(4000));
    });
  });

  group('the protection of every form post stays', () {
    test('another origin never reaches the question', () async {
      final r = await handler.handle(
        post(
          '/orders',
          {askField: _ask()},
          headers: {HttpHeader.origin: 'http://evil.test'},
        ),
      );
      expect(r.status, 403);
      expect(ran, isEmpty);
    });

    test('a form post with no origin is refused too', () async {
      final request = PageRequest(
        method: HttpMethod.post,
        uri: Uri.parse('http://site.test/orders'),
        headers: const {
          HttpHeader.host: 'site.test',
          HttpHeader.contentType: 'application/x-www-form-urlencoded',
        },
        body: Stream.value(utf8.encode('$askField=%7B%22t%22%3A%22q%22%7D')),
      );
      expect((await handler.handle(request)).status, 403);
      expect(ran, isEmpty);
    });

    test('a page with no actions answers its 405, not a question', () async {
      final r = await handler.handle(post('/plain', {askField: _ask()}));
      expect(r.status, 405);
    });

    test('an action that does not exist is a 404, not a question', () async {
      final r = await handler.handle(post('/orders?/nope', {askField: _ask()}));
      expect(r.status, 404);
    });
  });

  test('a question does not clear the page cache (nothing changed)', () async {
    var renders = 0;
    final cached = RouteHandler<String>(
      renderer: _CountingRenderer(() => renders++),
      routes: [
        PageRoute<String, void>(
          path: 'orders',
          cache: const Duration(minutes: 1),
          build: (s) => 'orders',
          actions: {'default': (r) => const Redirect(RouteUrl('/orders'))},
        ),
      ],
    );
    PageRequest get() => PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://site.test/orders'),
      headers: const {HttpHeader.host: 'site.test'},
    );
    await cached.handle(get());
    await cached.handle(get());
    expect(renders, 1, reason: 'the second visit is the cached page');
    final asked = await cached.handle(post('/orders', {askField: _ask()}));
    expect(asked.status, 200);
    await cached.handle(get());
    expect(renders, 1, reason: 'asking changed nothing');
    final done = await cached.handle(
      post('/orders', {askField: _ask(), confirmedField: '1'}),
    );
    expect(done.status, 303);
    await cached.handle(get());
    expect(renders, 2, reason: 'the confirmed action did change data');
  });

  group('files are never replayed', () {
    String multipart({bool file = false}) =>
        '--b\r\nContent-Disposition: form-data; name="title"\r\n\r\nInforme\r\n'
        '--b\r\nContent-Disposition: form-data; name="$askField"\r\n\r\n'
        '${_ask()}\r\n'
        '${file ? '--b\r\nContent-Disposition: form-data; name="doc"; filename="r.pdf"\r\nContent-Type: application/pdf\r\n\r\n%PDF\r\n' : ''}'
        '--b--\r\n';

    test('a form with a file explains it needs JavaScript', () async {
      final r = await handler.handle(
        post(
          '/orders',
          const {},
          type: 'multipart/form-data; boundary=b',
          body: multipart(file: true),
        ),
      );
      expect(r.status, 400);
      expect(ran, isEmpty);
      final html = await page(r);
      expect(html, contains('JavaScript'));
      expect(html, isNot(contains(confirmedField)));
    });

    test('a multipart form without files is asked like any other', () async {
      final r = await handler.handle(
        post(
          '/orders',
          const {},
          type: 'multipart/form-data; boundary=b',
          body: multipart(),
        ),
      );
      expect(r.status, 200);
      expect(ran, isEmpty);
      expect(
        await page(r),
        contains('<input type="hidden" name="title" value="Informe">'),
      );
    });

    test('a JSON or other body is never asked', () async {
      final r = await handler.handle(
        post(
          '/orders',
          const {},
          type: 'application/json',
          body: jsonEncode({askField: _ask()}),
        ),
      );
      // The action's own answer (it reads a form and gets none).
      expect(r.status, 415);
      expect(await page(r), isNot(contains('Delete this order?')));
      expect(ran, isEmpty);
    });
  });

  group('adversarial', () {
    Future<String> asked(
      Map<String, String> f, {
      String url = '/orders',
    }) async => page(await handler.handle(post(url, f)));

    test('a huge question is cut and asked, never run', () async {
      final r = await handler.handle(
        post('/orders', {askField: _ask(t: 'x' * 5000, m: 'y' * 5000)}),
      );
      expect(r.status, 200, reason: 'oversized must not fail open');
      expect(ran, isEmpty);
      expect(await page(r), contains('x' * 200));
      expect(await page(r), isNot(contains('x' * 201)));
    });

    test('only the exact answer 1 runs the action', () async {
      for (final v in ['0', 'true', '', '1 ', 'yes']) {
        ran.clear();
        final r = await handler.handle(
          post('/orders', {askField: _ask(), confirmedField: v}),
        );
        expect(r.status, 200, reason: 'confirmed="$v"');
        expect(ran, isEmpty, reason: 'confirmed="$v"');
      }
    });

    test(
      'a forged answer on the first post skips the page (documented)',
      () async {
        final r = await handler.handle(
          post('/orders', {askField: _ask(), confirmedField: '1'}),
        );
        expect(r.status, 303);
        expect(ran, hasLength(1));
      },
    );

    test('repeated names are replayed in order', () async {
      final html = await page(
        await handler.handle(
          post(
            '/orders',
            const {},
            body:
                'a=1&b=2&a=3&a=&b=%F0%9F%98%80&${Uri.encodeQueryComponent(askField)}='
                '${Uri.encodeQueryComponent(_ask())}',
          ),
        ),
      );
      final inputs = RegExp(
        r'name="(\w+)" value="([^"]*)"',
      ).allMatches(html).map((m) => '${m[1]}=${m[2]}').toList();
      expect(inputs.where((i) => i.startsWith('a=')), ['a=1', 'a=3', 'a=']);
      expect(inputs.where((i) => i.startsWith('b=')), ['b=2', 'b=\u{1F600}']);
    });

    test('a form-level and a button-level question: the button\'s wins', () async {
      // DOM order: the Form's hidden input comes before the submitter's.
      final html = await page(
        await handler.handle(
          post(
            '/orders',
            const {},
            body:
                '$askField=${Uri.encodeQueryComponent(_ask(t: 'Whole form?'))}'
                '&$askField=${Uri.encodeQueryComponent(_ask(t: 'This button?'))}',
          ),
        ),
      );
      expect(html, contains('This button?'));
      expect(html, isNot(contains('Whole form?')));
    });

    test('a question in the URL of a GET is just a query', () async {
      final r = await handler.handle(
        PageRequest(
          method: HttpMethod.get,
          uri: Uri.parse(
            'http://site.test/orders?${Uri.encodeQueryComponent(askQueryKey)}='
            '${Uri.encodeQueryComponent(_ask())}',
          ),
          headers: const {HttpHeader.host: 'site.test'},
        ),
      );
      expect(r.status, 200);
      expect(await page(r), 'orders');
      expect(ran, isEmpty);
    });

    test('the page needs nothing inline (strict CSP)', () async {
      final html = await asked({
        'x': '1',
        askField: _ask(t: '</title><script>1</script>', m: '</p><img src=x>'),
      });
      expect(html, isNot(matches(RegExp(r'<script', caseSensitive: false))));
      expect(html, isNot(contains('<img')));
      expect(html, isNot(matches(RegExp(r'\son\w+='))));
      expect(html, isNot(contains(' style=')));
      expect(html, isNot(contains('<style')));
      expect(
        RegExp('<title>').allMatches(html).length +
            RegExp('</title>').allMatches(html).length,
        2,
      );
    });

    test('unicode and bidi controls in the question stay text', () async {
      final html = await asked({
        askField: _ask(
          t: '\u202Eevil \u{1F600} \u0000 \u2028',
          m: '\u0627\u0644',
        ),
      });
      expect(html, contains('\u{1F600}'));
      expect(html, contains('\u0627\u0644'));
    });

    test('an empty file input (no file chosen) is not a file', () async {
      const body =
          '--b\r\nContent-Disposition: form-data; name="title"\r\n\r\nInforme\r\n'
          '--b\r\nContent-Disposition: form-data; name="doc"; filename=""\r\n'
          'Content-Type: application/octet-stream\r\n\r\n\r\n'
          '--b\r\nContent-Disposition: form-data; name="$askField"\r\n\r\n';
      final r = await handler.handle(
        post(
          '/orders',
          const {},
          type: 'multipart/form-data; boundary=b',
          body: '$body${_ask()}\r\n--b--\r\n',
        ),
      );
      expect(r.status, 200, reason: 'an unchosen file is no file');
      expect(ran, isEmpty);
    });

    test('a multipart form with a file and the answer runs', () async {
      final r = await handler.handle(
        post(
          '/orders',
          const {},
          type: 'multipart/form-data; boundary=b',
          body:
              '--b\r\nContent-Disposition: form-data; name="$askField"\r\n\r\n${_ask()}\r\n'
              '--b\r\nContent-Disposition: form-data; name="$confirmedField"\r\n\r\n1\r\n'
              '--b\r\nContent-Disposition: form-data; name="doc"; filename="r.pdf"\r\n'
              'Content-Type: application/pdf\r\n\r\n%PDF\r\n--b--\r\n',
        ),
      );
      expect(r.status, 303);
      expect(ran, hasLength(1));
    });
  });
}
