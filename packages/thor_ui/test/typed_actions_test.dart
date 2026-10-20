// A schema field without a decoration: the label is not what these tests check.
// ignore_for_file: thor_lints/text_field_without_label
// Form actions as methods of the page: dispatch by method name,
// the schema checked before the method runs, typed values, the tear-off
// named in the HTML.
import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

final class ContactForm extends FormSchema {
  const ContactForm._() : super(const [email, age]);

  static const schema = ContactForm._();

  static const email = TextSchemaField(
    'email',
    validators: [
      Validator.required('Enter your e-mail'),
      Validator.email('Not an e-mail'),
    ],
  );

  static const age = IntSchemaField('age');
}

final class OtherForm extends FormSchema {
  const OtherForm() : super(const [name]);

  static const name = TextSchemaField('name');
}

/// What the methods saw, per test.
final _calls = <String>[];

class ContactPage extends ThorPage<void> {
  const ContactPage();

  Future<ActionResult?> send(
    PageRequest request,
    FormValues<ContactForm> values,
  ) async {
    final String email = values.of(ContactForm.email);
    final int? age = values.of(ContactForm.age);
    _calls.add('send $email $age');
    if (email == 'taken@x.test') {
      return values.fail('That e-mail is taken', ContactForm.email);
    }
    return const Redirect(RouteUrl('/thanks'));
  }

  Future<ActionResult?> favorite(PageRequest request) async {
    _calls.add('favorite');
    return null;
  }

  ActionResult? remove(PageRequest request) {
    _calls.add('remove');
    return const ActionResult.success('removed');
  }

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    children: [
      Form(
        schema: ContactForm.schema,
        onValid: send,
        child: Column(
          children: [
            TextFormField(field: ContactForm.email, form: state.form),
            FilledButton(
              onPressed: null,
              onPost: remove,
              child: const Text('remove'),
            ),
          ],
        ),
      ),
      Form(onPost: favorite, child: const Text('fav')),
      Form(
        action: '/other',
        onPost: const OtherPage().save,
        child: const Text('elsewhere'),
      ),
      if (state.form case final ActionResult r) Text('result ${r.data}'),
      if (state.form case final String s) Text('result $s'),
      if (state.form case final FormInvalid f) Text('errors ${f.messages}'),
    ],
  );
}

class OtherPage extends ThorPage<void> {
  const OtherPage();

  Future<ActionResult?> save(PageRequest request) async => null;

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      const Text('other');
}

class GuardedPage extends ThorPage<void> {
  const GuardedPage();

  Future<ActionResult?> run(PageRequest request) async {
    _calls.add('guarded');
    return null;
  }

  @override
  FutureOr<RouteUrl?> redirect(PageRequest request) => const RouteUrl('/login');

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      const Text('never');
}

class ClosurePage extends ThorPage<void> {
  const ClosurePage();

  @override
  Widget build(BuildContext context, PageState<void> state) => Form(
    // The closure this test expects to fail (THOR-P020).
    // ignore: thor_lints/untyped_form_action
    onPost: (request) async => null,
    child: const Text('x'),
  );
}

/// What `.dart_tool/thor/actions.dart` registers for these pages.
void registerActions() => registerPageActions({
  ContactPage: [
    PageActionMethod.valid(
      'send',
      (p) => (p as ContactPage).send,
      ContactForm.schema,
    ),
    PageActionMethod.request('favorite', (p) => (p as ContactPage).favorite),
    PageActionMethod.request('remove', (p) => (p as ContactPage).remove),
  ],
  OtherPage: [PageActionMethod.request('save', (p) => (p as OtherPage).save)],
  GuardedPage: [PageActionMethod.request('run', (p) => (p as GuardedPage).run)],
});

void main() {
  registerActions();
  final app = ThorApp.router(
    routerConfig: ThorRouter([
      ThorRoute('/contact', const ContactPage()),
      ThorRoute('/other', const OtherPage()),
      ThorRoute('/guarded', const GuardedPage()),
      ThorRoute('/closure', const ClosurePage()),
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

  Future<ThorResponse> get(String url) => handler.handle(
    PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://s.test$url'),
      headers: const {HttpHeader.host: 's.test'},
    ),
  );

  setUp(_calls.clear);

  group('dispatch', () {
    test('a valid form runs the method with typed values', () async {
      final r = await post('/contact?/send', 'email=a%40x.test&age=7');
      expect(_calls, ['send a@x.test 7']);
      expect(r.status, 303);
      expect(r.headers['location'], '/thanks');
    });

    test('an invalid form is a 422 and the method never runs', () async {
      final r = await post('/contact?/send', 'email=nope&age=x');
      expect(_calls, isEmpty);
      expect(r.status, 422);
      expect(r.text, contains('Not an e-mail'));
      // The typed value re-fills the field.
      expect(r.text, contains('value="nope"'));
    });

    test('values.fail is a 422 with the values kept', () async {
      final r = await post('/contact?/send', 'email=taken%40x.test');
      expect(_calls, ['send taken@x.test null']);
      expect(r.status, 422);
      expect(r.text, contains('That e-mail is taken'));
      expect(r.text, contains('value="taken@x.test"'));
    });

    test('a method without fields returning null goes back (303)', () async {
      final r = await post('/contact?/favorite');
      expect(_calls, ['favorite']);
      expect(r.status, 303);
      expect(r.headers['location'], '/contact');
    });

    test('a synchronous method returning a result re-renders', () async {
      final r = await post('/contact?/remove');
      expect(_calls, ['remove']);
      expect(r.status, 200);
      expect(r.text, contains('result removed'));
    });

    test('an unknown action is a 404', () async {
      expect((await post('/contact?/nope')).status, 404);
    });

    test('the page guard runs before the method', () async {
      final r = await post('/guarded?/run');
      expect(_calls, isEmpty);
      expect(r.status, 303);
      expect(r.headers['location'], '/login');
    });

    test('a cross-origin POST never runs the method', () async {
      final r = await handler.handle(
        PageRequest(
          method: HttpMethod.post,
          uri: Uri.parse('http://s.test/contact?/favorite'),
          headers: const {
            HttpHeader.host: 's.test',
            HttpHeader.origin: 'http://evil.test',
            HttpHeader.contentType: 'application/x-www-form-urlencoded',
          },
          body: Stream.value(utf8.encode('')),
        ),
      );
      expect(r.status, 403);
      expect(_calls, isEmpty);
    });
  });

  group('HTML', () {
    test('the tear-offs become the action URLs', () async {
      final r = await get('/contact');
      expect(r.status, 200);
      expect(r.text, contains('action="?/send"'));
      expect(r.text, contains('action="?/favorite"'));
      // OtherPage has only `save`: its path, no key.
      expect(r.text, contains('action="/other"'));
    });

    test('a button with onPost submits to its method', () async {
      final html = (await get('/contact')).text;
      final button = RegExp(
        '<button[^>]*formaction="\\?/remove"[^>]*>',
      ).firstMatch(html)?.group(0);
      expect(button, isNotNull);
      expect(button, contains('type="submit"'));
      expect(button, isNot(contains('disabled')));
    });

    test('a closure is THOR-P020', () async {
      expect(
        renderLoneForm((PageRequest r) async => null),
        throwsA(
          isA<Object>().having((e) => '$e', 'error', contains('THOR-P020')),
        ),
      );
    });

    test('a method of a page outside the router is THOR-P020', () async {
      expect(
        renderLoneForm(const _Unrouted().go),
        throwsA(
          isA<Object>().having((e) => '$e', 'error', contains('THOR-P020')),
        ),
      );
    });

    test('a page whose form gets a closure fails to render', () async {
      expect((await get('/closure')).status, 500);
    });
  });
}

class _Unrouted extends ThorPage<void> {
  const _Unrouted();

  Future<ActionResult?> go(PageRequest request) async => null;

  @override
  Widget build(BuildContext context, PageState<void> state) => const Text('x');
}

/// Renders a lone form posting to [method].
Future<String> renderLoneForm(PagePost method) async => bodyOfPage(
  await renderDocument(
    ThorApp(
      child: Form(onPost: method, child: const Text('x')),
    ),
  ),
);
