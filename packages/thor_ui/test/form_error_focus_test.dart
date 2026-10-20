// Fixture: fields without a label on purpose (focus, state and form behavior).
// ignore_for_file: thor_lints/text_field_without_label
// The first error takes the focus, end to end on the server: a POST that fails
// validation re-renders the page with `422` and the first wrong field (here the
// third) is the one marked `autofocus`, with its message linked
// (`aria-describedby`) and `aria-invalid`; a page that renders again clean has
// none.
@TestOn('vm')
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

final class SignUp extends FormSchema {
  const SignUp._() : super(const [name, email, password]);

  static const schema = SignUp._();
  static const name = TextSchemaField('name');
  static const email = TextSchemaField(
    'email',
    validators: [Validator.email('Not an e-mail')],
  );
  static const password = TextSchemaField(
    'password',
    secret: true,
    validators: [Validator.minLength(8, 'Too short')],
  );
}

class SignUpPage extends ThorPage<void> {
  const SignUpPage();

  Future<ActionResult?> send(
    PageRequest request,
    FormValues<SignUp> values,
  ) async => const Redirect(RouteUrl('/thanks'));

  @override
  Widget build(BuildContext context, PageState<void> state) => Form(
    schema: SignUp.schema,
    onValid: send,
    child: Column(
      children: [
        TextFormField(field: SignUp.name, form: state.form),
        TextFormField(field: SignUp.email, form: state.form),
        TextFormField(field: SignUp.password, form: state.form),
        FilledButton(
          buttonType: ButtonType.submit,
          onPressed: () {},
          child: const Text('Go'),
        ),
      ],
    ),
  );
}

/// A page whose action answers `200` with the failed form (a soft failure:
/// the e-mail is taken): the answer still shows field errors.
class SoftPage extends ThorPage<void> {
  const SoftPage();

  Future<ActionResult?> taken(PageRequest request) async =>
      FormInvalid(errors: {'email': 'Already taken'}).fail(200);

  Future<ActionResult?> taken2(PageRequest request) async =>
      ActionResult.success(FormInvalid(errors: {'email': 'Already taken'}));

  @override
  Widget build(BuildContext context, PageState<void> state) => Form(
    failed: state.form,
    child: const Column(
      children: [
        TextFormField(name: 'name'),
        TextFormField(name: 'email'),
      ],
    ),
  );
}

/// A page whose field carries a fixed error (a demo, a showcase): nothing
/// failed, so nothing may take the focus.
class DemoPage extends ThorPage<void> {
  const DemoPage();

  Future<ActionResult?> ok(PageRequest request) async =>
      const ActionResult.success();

  Future<ActionResult?> bad(PageRequest request) async =>
      const ActionResult.fail(422);

  @override
  Widget build(BuildContext context, PageState<void> state) => const Form(
    child: Column(
      children: [
        TextField(
          name: 'off',
          enabled: false,
          decoration: InputDecoration(errorText: 'Disabled'),
        ),
        TextField(
          name: 'code',
          decoration: InputDecoration(errorText: 'Wrong code'),
        ),
      ],
    ),
  );
}

/// Two forms: the failed one (an error on `email`) and a showcase field with
/// a fixed error, in either order.
class TwoFormsPage extends ThorPage<void> {
  const TwoFormsPage({this.demoFirst = false});

  final bool demoFirst;

  Future<ActionResult?> taken(PageRequest request) async =>
      FormInvalid(errors: {'email': 'Already taken'}).fail(200);

  Future<ActionResult?> formLevel(PageRequest request) async =>
      FormInvalid(formErrors: ['Try later']).fail(200);

  Future<ActionResult?> done(PageRequest request) async =>
      const Redirect(RouteUrl('/thanks'));

  @override
  Widget build(BuildContext context, PageState<void> state) {
    const demo = Form(
      child: TextField(
        name: 'demo',
        decoration: InputDecoration(errorText: 'Demo error'),
      ),
    );
    final failed = Form(
      failed: state.form,
      child: const Column(
        children: [
          TextFormField(name: 'name'),
          TextFormField(name: 'email'),
        ],
      ),
    );
    return Column(children: demoFirst ? [demo, failed] : [failed, demo]);
  }
}

/// A failed form inside a closed `<details>` and a hand-made `failed:` on a
/// page that is not the answer of anything.
class HiddenPage extends ThorPage<void> {
  const HiddenPage();

  Future<ActionResult?> taken(PageRequest request) async =>
      FormInvalid(errors: {'email': 'Already taken'}).fail(200);

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    children: [
      ExpansionTile(
        title: const Text('More'),
        children: [
          Form(
            failed: state.form,
            child: const TextFormField(name: 'email'),
          ),
        ],
      ),
    ],
  );
}

class HandMadePage extends ThorPage<void> {
  const HandMadePage();

  @override
  Widget build(BuildContext context, PageState<void> state) => Form(
    failed: FormInvalid(errors: {'email': 'Fake'}),
    child: const TextFormField(name: 'email'),
  );
}

void main() {
  registerPageActions({
    DemoPage: [
      PageActionMethod.request('ok', (p) => (p as DemoPage).ok),
      PageActionMethod.request('bad', (p) => (p as DemoPage).bad),
    ],
    TwoFormsPage: [
      PageActionMethod.request('taken', (p) => (p as TwoFormsPage).taken),
      PageActionMethod.request(
        'formLevel',
        (p) => (p as TwoFormsPage).formLevel,
      ),
      PageActionMethod.request('done', (p) => (p as TwoFormsPage).done),
    ],
    HiddenPage: [
      PageActionMethod.request('taken', (p) => (p as HiddenPage).taken),
    ],
    SoftPage: [
      PageActionMethod.request('taken', (p) => (p as SoftPage).taken),
      PageActionMethod.request('taken2', (p) => (p as SoftPage).taken2),
    ],
    SignUpPage: [
      PageActionMethod.valid(
        'send',
        (p) => (p as SignUpPage).send,
        SignUp.schema,
      ),
    ],
  });
  final app = ThorApp.router(
    routerConfig: ThorRouter([
      ThorRoute('/signup', const SignUpPage()),
      ThorRoute('/demo', const DemoPage()),
      ThorRoute('/soft', const SoftPage()),
      ThorRoute('/two', const TwoFormsPage()),
      ThorRoute('/twoFirst', const TwoFormsPage(demoFirst: true)),
      ThorRoute('/hidden', const HiddenPage()),
      ThorRoute('/hand', const HandMadePage()),
    ]),
  );
  final handler = RouteHandler<Widget>(
    routes: app.routes,
    renderer: WidgetRenderer.router(app),
  );
  Future<ThorResponse> post(
    String body, {
    String path = '/signup',
    String action = 'send',
  }) => handler.handle(
    PageRequest(
      method: HttpMethod.post,
      uri: Uri.parse('http://s.test$path?/$action'),
      headers: const {
        HttpHeader.host: 's.test',
        HttpHeader.origin: 'http://s.test',
        HttpHeader.contentType: 'application/x-www-form-urlencoded',
      },
      body: Stream.value(utf8.encode(body)),
    ),
  );
  String markup(String html) => html
      .substring(html.indexOf('<body'))
      .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>'), '');
  String input(String html, String name) =>
      RegExp('<input[^>]*name="$name"[^>]*>').firstMatch(html)![0]!;

  test('a 422 with the error in the 3rd field focuses that one', () async {
    final r = await post('name=Ana&email=a%40x.test&password=short');
    expect(r.status, 422);
    final html = markup(r.text);
    expect('autofocus'.allMatches(html), hasLength(1));
    final third = input(html, 'password');
    expect(third, contains('autofocus'));
    expect(third, contains('aria-invalid="true"'));
    expect(third, contains('aria-describedby="f-password-msg"'));
    expect(html, contains('id="f-password-msg"'));
    expect(html, contains('Too short'));
    expect(input(html, 'email'), isNot(contains('autofocus')));
    expect(r.text, contains("querySelector('[autofocus][aria-invalid=true]')"));
  });

  test('two errors: only the first is autofocus', () async {
    final r = await post('name=Ana&email=nope&password=short');
    final html = markup(r.text);
    expect('autofocus'.allMatches(html), hasLength(1));
    expect(input(html, 'email'), contains('autofocus'));
    expect(input(html, 'password'), isNot(contains('autofocus')));
    expect(input(html, 'password'), contains('aria-invalid="true"'));
  });

  test('the form of a fresh GET has no autofocus', () async {
    final r = await handler.handle(
      PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://s.test/signup'),
        headers: const {HttpHeader.host: 's.test'},
      ),
    );
    expect(markup(r.text), isNot(contains('autofocus')));
  });

  test('a static error on a GET page takes no focus', () async {
    final r = await handler.handle(
      PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://s.test/demo'),
        headers: const {HttpHeader.host: 's.test'},
      ),
    );
    expect(r.status, 200);
    final html = markup(r.text);
    expect(html, contains('aria-invalid="true"'));
    expect(html, isNot(contains('autofocus')));
  });

  test(
    'a failed action (422) focuses the first enabled field with an error',
    () async {
      final r = await post('', path: '/demo', action: 'bad');
      expect(r.status, 422);
      final html = markup(r.text);
      expect('autofocus'.allMatches(html), hasLength(1));
      expect(input(html, 'code'), contains('autofocus'));
      expect(input(html, 'off'), isNot(contains('autofocus')));
      expect(
        r.text,
        contains("querySelector('[autofocus][aria-invalid=true]')"),
      );
    },
  );

  test('an action that worked (200) does not steal the focus', () async {
    final r = await post('', path: '/demo', action: 'ok');
    expect(r.status, 200);
    expect(markup(r.text), isNot(contains('autofocus')));
  });

  test('a failed form answered with 200 focuses its first error', () async {
    for (final action in ['taken', 'taken2']) {
      final r = await post('', path: '/soft', action: action);
      expect(r.status, 200, reason: action);
      final html = markup(r.text);
      expect('autofocus'.allMatches(html), hasLength(1), reason: action);
      expect(input(html, 'email'), contains('autofocus'), reason: action);
      expect(input(html, 'email'), contains('aria-invalid="true"'));
      expect(
        r.text,
        contains("querySelector('[autofocus][aria-invalid=true]')"),
      );
    }
  });

  test('the same page on a GET, with no failed form, takes no focus', () async {
    final r = await handler.handle(
      PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://s.test/soft'),
        headers: const {HttpHeader.host: 's.test'},
      ),
    );
    expect(markup(r.text), isNot(contains('autofocus')));
  });

  group('adversarial', () {
    test('two forms: the failed one is focused, the showcase is not', () async {
      for (final first in [false, true]) {
        final r = await post(
          '',
          path: first ? '/twoFirst' : '/two',
          action: 'taken',
        );
        final html = markup(r.text);
        expect('autofocus'.allMatches(html), hasLength(1), reason: '$first');
        expect(input(html, 'email'), contains('autofocus'), reason: '$first');
        expect(input(html, 'demo'), isNot(contains('autofocus')));
      }
    });

    test(
      'a failure with only form-level errors leaves a showcase alone',
      () async {
        final r = await post('', path: '/two', action: 'formLevel');
        expect(r.status, 200);
        expect(markup(r.text), isNot(contains('autofocus')));
      },
    );

    test('a redirect after success answers no page to focus', () async {
      final r = await post('', path: '/two', action: 'done');
      expect(r.status, inInclusiveRange(300, 399));
      expect(r.text, isNot(contains('autofocus')));
    });

    test('a failed form in a closed details still gets its script', () async {
      final r = await post('', path: '/hidden', action: 'taken');
      expect(markup(r.text), contains('autofocus'));
      // The form script opens the closed `<details>` before it focuses.
      expect(r.text, contains('details:not([open])'));
    });

    test(
      'a failed: made by hand on a GET (and a HEAD) claims nothing',
      () async {
        for (final method in ['GET', 'HEAD']) {
          final r = await handler.handle(
            PageRequest(
              method: HttpMethod.tryParse(method)!,
              uri: Uri.parse('http://s.test/hand'),
              headers: const {HttpHeader.host: 's.test'},
            ),
          );
          expect(markup(r.text), isNot(contains('autofocus')), reason: method);
        }
      },
    );
  });
}
