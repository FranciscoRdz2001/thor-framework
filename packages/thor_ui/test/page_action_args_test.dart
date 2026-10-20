// Fixture: fields without a label on purpose (focus, state and form behavior).
// ignore_for_file: thor_lints/text_field_without_label
// These tests are about the button's wiring, not its name.
// ignore_for_file: thor_lints/icon_button_without_name
// An action of a page with arguments (`delete(PageRequest, int id)`),
// bound by a button (`onPost: page.delete.withArg(id)`): a real submit button
// with name/value that works without JS, and the method gets the typed
// argument.
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

enum Role { admin, guest }

final _calls = <String>[];

class OrdersPage extends ThorPage<void> {
  const OrdersPage();

  Future<ActionResult?> delete(PageRequest request, int id) async {
    _calls.add('delete $id');
    return null;
  }

  Future<ActionResult?> grant(PageRequest request, Role role, bool on) async {
    _calls.add('grant ${role.name} $on');
    return const Redirect(RouteUrl('/done'));
  }

  ActionResult? tag(PageRequest request, String who, String tag) {
    _calls.add('tag $who|$tag');
    return null;
  }

  Future<ActionResult?> plain(PageRequest request) async {
    _calls.add('plain');
    return null;
  }

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    children: [
      for (final id in const [7, 8])
        FilledButton(onPost: delete.withArg(id), child: Text('delete $id')),
      IconButton(
        onPost: grant.withArgs(Role.guest, true),
        icon: const Icon(IconData.svg('x', '<path d="M0 0"/>')),
      ),
      TextButton(
        onPost: tag.withArgs('a~b"><i>', '100%'),
        child: const Text('tag'),
      ),
      FilledButton(onPost: plain, child: const Text('plain')),
    ],
  );
}

class FormWithArgPage extends ThorPage<void> {
  const FormWithArgPage();

  Future<ActionResult?> save(PageRequest request, int id) async => null;

  @override
  Widget build(BuildContext context, PageState<void> state) => Form(
    onPost: save.withArg(9),
    child: const TextField(name: 'title'),
  );
}

class BareBuildPage extends ThorPage<void> {
  const BareBuildPage();

  @override
  Widget build(BuildContext context, PageState<void> state) => Form(
    onPost: plain,
    child: FilledButton(
      buttonType: ButtonType.submit,
      onPressed: () {},
      onPost: plain,
      child: const Text('no args'),
    ),
  );

  Future<ActionResult?> plain(PageRequest request) async => null;
}

ActionResult? _syncAction(PageRequest request, int id) => null;
Future<Redirect> _redirectAction(PageRequest request, int id) async =>
    const Redirect(RouteUrl('/x'));
Future<ActionResult> _nonNullAction(PageRequest request, int id) async =>
    const Redirect(RouteUrl('/x'));
ActionResult? _syncAction2(PageRequest request, int id, String s) => null;
Future<Redirect> _redirectAction3(
  PageRequest request,
  int id,
  String s,
  bool b,
) async => const Redirect(RouteUrl('/x'));

void registerActions() => registerPageActions({
  OrdersPage: [
    PageActionMethod.args(
      'delete',
      (p) => (p as OrdersPage).delete,
      1,
      (x) => [int.parse(x[0])],
    ),
    PageActionMethod.args(
      'grant',
      (p) => (p as OrdersPage).grant,
      2,
      (x) => [Role.values.byName(x[0]), x[1] == 'true'],
    ),
    PageActionMethod.args(
      'tag',
      (p) => (p as OrdersPage).tag,
      2,
      (x) => [x[0], x[1]],
    ),
    PageActionMethod.request('plain', (p) => (p as OrdersPage).plain),
  ],
  FormWithArgPage: [
    PageActionMethod.args(
      'save',
      (p) => (p as FormWithArgPage).save,
      1,
      (x) => [int.parse(x[0])],
    ),
  ],
  BareBuildPage: [
    PageActionMethod.request('plain', (p) => (p as BareBuildPage).plain),
  ],
});

void main() {
  registerActions();
  final app = ThorApp.router(
    routerConfig: ThorRouter([
      ThorRoute('/orders', const OrdersPage()),
      ThorRoute('/bare', const BareBuildPage()),
      ThorRoute('/form', const FormWithArgPage()),
    ]),
  );
  final handler = RouteHandler<Widget>(
    routes: app.routes,
    renderer: WidgetRenderer.router(app),
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

  Future<String> page(String url) async => (await handler.handle(
    PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://s.test$url'),
      headers: const {HttpHeader.host: 's.test'},
    ),
  )).text;

  setUp(_calls.clear);

  group('HTML (no JS needed)', () {
    late String html;
    setUpAll(() async => html = await page('/orders'));

    String buttonOf(String label) =>
        RegExp('<button[^>]*>[^<]*$label').firstMatch(html)!.group(0)!;

    test('an argument button is a submit button with name and value', () {
      final b = buttonOf('delete 7');
      expect(b, contains('type="submit"'));
      expect(b, contains('formaction="?/delete"'));
      expect(b, contains('name="thor-arg"'));
      expect(b, contains('value="7"'));
      expect(b, contains('form="thor-post"'));
      expect(b, isNot(contains('disabled')));
      expect(buttonOf('delete 8'), contains('value="8"'));
    });

    test('one shared POST form for every argument button of the page', () {
      expect('id="thor-post"'.allMatches(html), hasLength(1));
      expect(
        html,
        contains(RegExp('<form[^>]*id="thor-post"[^>]*method="post"[^>]*>')),
      );
    });

    test('two arguments travel in one escaped value, HTML-escaped', () {
      expect(html, isNot(contains('<i>')));
      expect(html, contains('value="a%7Eb&quot;&gt;&lt;i&gt;~100%"'));
      expect(html, contains('value="guest~true"'));
    });

    test('a Form carries the argument in a hidden field of its own', () async {
      final form = await page('/form');
      expect(form, contains('action="/form"'));
      expect(
        form,
        contains(RegExp('<input[^>]*name="thor-arg"[^>]*value="9"')),
      );
      expect(form, isNot(contains('thor-post')));
    });

    test('an onPost button outside a Form takes the shared form too', () {
      final b = RegExp('<button[^>]*>[^<]*plain').firstMatch(html)!.group(0)!;
      expect(b, contains('formaction="?/plain"'));
      expect(b, contains('form="thor-post"'));
      expect(b, isNot(contains('thor-arg')));
    });

    test('inside a Form it keeps that form (no form attribute)', () async {
      final bare = await page('/bare');
      final b = RegExp('<button[^>]*>').firstMatch(bare)!.group(0)!;
      expect(b, contains('formaction="/bare"'));
      expect(b, isNot(contains('form="')));
      expect(bare, isNot(contains('thor-post')));
    });

    test('a Form with an argument still needs no shared form', () async {
      expect(await page('/form'), isNot(contains('thor-post')));
    });
  });

  group('the method gets typed arguments', () {
    test('an int', () async {
      final r = await post('/orders?/delete', 'thor-arg=7');
      expect(_calls, ['delete 7']);
      expect(r.status, 303);
      expect(r.headers['location'], '/orders');
    });

    test('an enum and a bool; the method answers a redirect', () async {
      final r = await post('/orders?/grant', 'thor-arg=guest~true');
      expect(_calls, ['grant guest true']);
      expect(r.headers['location'], '/done');
    });

    test('two strings with the hostile characters of the HTML', () async {
      final value = Uri.encodeQueryComponent('a%7Eb"><i>~100%');
      final r = await post('/orders?/tag', 'thor-arg=$value');
      expect(r.status, 303);
      expect(_calls, ['tag a~b"><i>|100%']);
    });

    test('the last string may hold any character, even ~', () async {
      await post('/orders?/tag', 'thor-arg=x~y~z');
      expect(_calls, ['tag x|y~z']);
    });
  });

  group('non-happy paths', () {
    test('no argument: a 400, the method never runs', () async {
      final r = await post('/orders?/delete');
      expect(r.status, 400);
      expect(_calls, isEmpty);
    });

    test('an argument of another type: a 400, never a 500', () async {
      for (final v in ['abc', '', '7.5', '9' * 40, '../../etc', '%00']) {
        final r = await post(
          '/orders?/delete',
          'thor-arg=${Uri.encodeQueryComponent(v)}',
        );
        expect(r.status, 400, reason: 'value "$v"');
      }
      expect(_calls, isEmpty);
    });

    test('an enum name that does not exist is a 400', () async {
      expect((await post('/orders?/grant', 'thor-arg=root~true')).status, 400);
      expect(_calls, isEmpty);
    });

    test('a repeated field is ambiguous: a 400, nothing runs', () async {
      final r = await post('/orders?/delete', 'thor-arg=1&thor-arg=2');
      expect(r.status, 400);
      expect(_calls, isEmpty);
    });

    test('the argument does not reach an action that takes none', () async {
      await post('/orders?/plain', 'thor-arg=7');
      expect(_calls, ['plain']);
    });

    test('a cross-origin POST never runs it', () async {
      final r = await handler.handle(
        PageRequest(
          method: HttpMethod.post,
          uri: Uri.parse('http://s.test/orders?/delete'),
          headers: const {
            HttpHeader.host: 's.test',
            HttpHeader.origin: 'http://evil.test',
            HttpHeader.contentType: 'application/x-www-form-urlencoded',
          },
          body: Stream.value(utf8.encode('thor-arg=7')),
        ),
      );
      expect(r.status, 403);
      expect(_calls, isEmpty);
    });

    test('withArg on a method that is not a page action is THOR-P020', () {
      // Same `on` type as a state's two-parameter `withArg`, but it returns
      // an action result: the page extension is picked, and refuses a first
      // parameter that is not the request.
      expect(
        () => _notAnAction.withArg(1),
        throwsA(
          isA<StateError>().having((e) => '$e', 'error', contains('THOR-P020')),
        ),
      );
    });

    test('withArg accepts every return type an action may have', () async {
      // What the compiler must pick the page extension for (a `void` or a
      // `Future<void>` method is a state's, and `Future<void>` with a page
      // action's signature does not compile: no silent binding).
      final posts = <PagePost>[
        _syncAction.withArg(1),
        _redirectAction.withArg(1),
        _nonNullAction.withArg(1),
        _syncAction2.withArgs(1, 'a'),
        _redirectAction3.withArgs(1, 'a', true),
      ];
      final request = PageRequest(
        method: HttpMethod.post,
        uri: Uri.parse('/x'),
      );
      for (final post in posts) {
        expect(await post(request), anyOf(isNull, isA<ActionResult>()));
      }
    });

    test('a state method with two parameters keeps its own withArg', () {
      final fixed = _Counts().set.withArg(3);
      expect(fixed, isA<void Function(bool)>());
    });

    test('withArg / withArgs write the arguments into the value', () async {
      final html = await renderHtml(
        ThorApp(
          child: Column(
            children: [
              FilledButton(
                onPost: _order.delete.withArg(7),
                child: const Text('a'),
              ),
              FilledButton(
                onPost: _order.grant.withArgs(Role.guest, true),
                child: const Text('b'),
              ),
            ],
          ),
        ),
      );
      expect(html, contains('value="guest~true"'));
    });

    test('withArg on a method that is not registered is THOR-P020', () {
      expect(
        () => renderHtml(
          ThorApp(
            child: FilledButton(
              onPost: const _Lost().go.withArg(1),
              child: const Text('x'),
            ),
          ),
        ),
        throwsA(
          isA<Object>().having((e) => '$e', 'error', contains('THOR-P020')),
        ),
      );
    });
  });
}

const _order = OrdersPage();

// A method with the shape of a state's two-parameter method that returns an
// action result but takes no request.
Future<ActionResult?> _notAnAction(int a, int b) async => null;

class _Counts {
  void set(int i, bool on) {}
}

class _Lost extends ThorPage<void> {
  const _Lost();

  Future<ActionResult?> go(PageRequest request, int id) async => null;

  @override
  Widget build(BuildContext context, PageState<void> state) => const Text('x');
}
