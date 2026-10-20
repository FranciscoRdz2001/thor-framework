// Fixture: fields without a label on purpose (focus, state and form behavior).
// ignore_for_file: thor_lints/text_field_without_label
// Adversarial tests of action arguments and buttons: tampered arguments,
// buttons in user forms, disabled buttons, the flash across other requests.
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

enum Kind { a, b }

final _calls = <String>[];

class ActsPage extends ThorPage<void> {
  const ActsPage() : super(cache: const Duration(minutes: 5));

  Future<ActionResult?> del(PageRequest request, int id) async {
    _calls.add('del $id');
    return null;
  }

  Future<ActionResult?> price(PageRequest request, double p) async {
    _calls.add('price $p');
    return null;
  }

  Future<ActionResult?> when(PageRequest request, DateTime d) async {
    _calls.add('when ${d.toIso8601String()}');
    return null;
  }

  Future<ActionResult?> kind(PageRequest request, Kind k) async {
    _calls.add('kind ${k.name}');
    return null;
  }

  Future<ActionResult?> flag(PageRequest request, bool b) async {
    _calls.add('flag $b');
    return null;
  }

  Future<ActionResult?> three(
    PageRequest request,
    int a,
    String b,
    int c,
  ) async {
    _calls.add('three $a|$b|$c');
    return null;
  }

  Future<ActionResult?> opt(PageRequest request, String? s) async {
    _calls.add('opt ${s == null ? 'null' : '"$s"'}');
    return null;
  }

  Future<ActionResult?> plain(PageRequest request) async {
    _calls.add('plain');
    return null;
  }

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    children: [
      Form(
        child: Column(
          children: [
            const TextField(name: 'title'),
            FilledButton(onPost: del.withArg(3), child: const Text('inform')),
            const FilledButton(
              buttonType: ButtonType.submit,
              child: Text('bare submit'),
            ),
            FilledButton(
              onPost: plain,
              confirm: const ConfirmSpec(
                '"><script>alert(1)</script>',
                message: "<img src=x onerror=alert(2)> & 'q'",
                confirmLabel: '</button>',
              ),
              child: const Text('hostile confirm'),
            ),
            const FilledButton(child: Text('nothing')),
          ],
        ),
      ),
    ],
  );
}

void main() {
  registerPageActions({
    ActsPage: [
      PageActionMethod.args(
        'del',
        (p) => (p as ActsPage).del,
        1,
        (x) => [int.parse(x[0])],
      ),
      PageActionMethod.args(
        'price',
        (p) => (p as ActsPage).price,
        1,
        (x) => [double.parse(x[0])],
      ),
      PageActionMethod.args(
        'when',
        (p) => (p as ActsPage).when,
        1,
        (x) => [DateTime.parse(x[0])],
      ),
      PageActionMethod.args(
        'kind',
        (p) => (p as ActsPage).kind,
        1,
        (x) => [Kind.values.byName(x[0])],
      ),
      PageActionMethod.args(
        'flag',
        (p) => (p as ActsPage).flag,
        1,
        (x) => [x[0] == 'true'],
      ),
      PageActionMethod.args(
        'three',
        (p) => (p as ActsPage).three,
        3,
        (x) => [int.parse(x[0]), x[1], int.parse(x[2])],
      ),
      PageActionMethod.args(
        'opt',
        (p) => (p as ActsPage).opt,
        1,
        (x) => [x[0].isEmpty ? null : x[0]],
      ),
      PageActionMethod.request('plain', (p) => (p as ActsPage).plain),
    ],
  });
  final app = ThorApp.router(
    routerConfig: ThorRouter([ThorRoute('/acts', const ActsPage())]),
  );
  final handler = RouteHandler<Widget>(
    routes: app.routes,
    renderer: WidgetRenderer.router(app),
  );

  Future<ThorResponse> post(String url, String body) => handler.handle(
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
  Future<int> arg(String action, String v) async => (await post(
    '/acts?/$action',
    'thor-arg=${Uri.encodeQueryComponent(v)}',
  )).status;

  setUp(_calls.clear);

  group('tampered arguments never make a 500', () {
    test('int', () async {
      for (final v in [
        '1e3',
        'NaN',
        'Infinity',
        '٣',
        '1_000',
        '0x10',
        '+7',
        '-0',
        ' 7 ',
        '7\n',
        '9223372036854775808',
        '-9223372036854775809',
        '1.0',
        '--1',
      ]) {
        final s = await arg('del', v);
        expect(s, anyOf(303, 400), reason: 'int "$v"');
      }
    });
    test('double', () async {
      for (final v in ['NaN', '-0', '1e999', '', ' ', '1,5', '0x1']) {
        expect(await arg('price', v), anyOf(303, 400), reason: 'double "$v"');
      }
    });
    test('DateTime', () async {
      for (final v in [
        '2024-02-30',
        '2024-01-01T00:00:00+05:00',
        '+275760-09-13',
        '-271821-04-20',
        '99999-01-01',
        '',
        'now',
        '2024-13-01',
      ]) {
        expect(await arg('when', v), anyOf(303, 400), reason: 'date "$v"');
      }
    });
    test('enum by index or wrong case is a 400', () async {
      for (final v in ['0', '1', 'A', 'Kind.a', 'a ', '']) {
        expect(await arg('kind', v), 400, reason: 'enum "$v"');
      }
      expect(_calls, isEmpty);
    });
    test(
      'bool: only "true" is true, anything else is false (accepted)',
      () async {
        expect(await arg('flag', 'banana'), 303);
        expect(await arg('flag', 'TRUE'), 303);
        expect(await arg('flag', 'true'), 303);
        expect(_calls, ['flag false', 'flag false', 'flag true']);
      },
    );
    test('separators and a fourth argument', () async {
      expect(await arg('three', '1~x~2'), 303);
      expect(await arg('three', '1~x~2~4'), 400);
      expect(await arg('three', '1~x'), 400);
      expect(await arg('three', '~~'), 400);
      expect(_calls, ['three 1|x|2']);
    });
  });

  group('HTML', () {
    late String html;
    setUpAll(
      () async => html = (await handler.handle(
        PageRequest(
          method: HttpMethod.get,
          uri: Uri.parse('http://s.test/acts'),
          headers: const {HttpHeader.host: 's.test'},
        ),
      )).text,
    );
    test(
      'a bound button inside a Form submits that Form with its argument',
      () {
        final b = RegExp(
          '<button[^>]*>[^<]*inform',
        ).firstMatch(html)!.group(0)!;
        expect(b, isNot(contains('form="')));
        expect(b, contains('name="thor-arg"'));
      },
    );
    test(
      'a button with no handler and no action is disabled, as documented',
      () {
        final b = RegExp(
          '<button[^>]*>[^<]*nothing',
        ).firstMatch(html)!.group(0)!;
        expect(b, contains('disabled'));
      },
    );
    test('a submit button inside a Form needs no handler', () {
      final b = RegExp(
        '<button[^>]*>[^<]*bare submit',
      ).firstMatch(html)!.group(0)!;
      expect(b, isNot(contains('disabled')));
    });
  });

  group('the flash', () {
    Future<ThorResponse> req(
      String method,
      String path, {
      Map<HttpHeader, String> headers = const {},
    }) => handler.handle(
      PageRequest(
        method: HttpMethod.tryParse(method)!,
        uri: Uri.parse('http://s.test$path'),
        headers: {HttpHeader.host: 's.test', ...headers},
      ),
    );
    const cookie = <HttpHeader, String>{
      HttpHeader.cookie: 'thor-flash=info%3AHello',
    };
    test('a HEAD request keeps it for the visit', () async {
      final r = await req('HEAD', '/acts', headers: cookie);
      expect(r.cookies, isEmpty);
    });
    test(
      'a cached page never carries someone\'s flash, nor keeps it',
      () async {
        await req('GET', '/acts'); // fills the shared cache
        final mine = await req('GET', '/acts', headers: cookie);
        expect(mine.text, contains('Hello'));
        expect(mine.headers['cache-control'], contains('private'));
        final other = await req('GET', '/acts');
        expect(other.text, isNot(contains('Hello')));
        expect(other.cookies, isEmpty);
        expect(
          other.headers['cache-control'] ?? '',
          isNot(contains('private')),
        );
      },
    );

    test('a flash that was drawn first is not what the cache serves', () async {
      final first = await req('GET', '/acts', headers: cookie);
      expect(first.text, contains('Hello'));
      final again = await req('GET', '/acts');
      expect(again.text, isNot(contains('Hello')));
    });

    test('a GET shows it once and clears it', () async {
      final r = await req('GET', '/acts', headers: cookie);
      expect(r.text, contains('Hello'));
      expect(r.cookies.single, startsWith('thor-flash=;'));
    });
  });
}
