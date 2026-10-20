@TestOn('vm')
library;

import 'package:realworld/router.dart';
import 'package:realworld/session.dart';
import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

/// Sign in and sign up check their schema (lib/forms.dart) before calling
/// the API: an invalid form never leaves the server, and the page comes
/// back with the messages and the values (never the password).
void main() {
  configureSessions('forms-test-session-secret-of-32-bytes!!');
  final handler = RouteHandler(
    routes: router.routes,
    renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
  );

  ThorTestClient visitor() => handler.client(origin: 'http://site.test');

  test('an empty sign-in is a 422 with the API messages', () async {
    final r = await visitor().post(
      '/login?/signIn',
      form: {'email': '', 'password': ''},
    );
    expect(r, hasStatus(422));
    expect(r.text, contains("email can't be blank"));
    expect(r.text, contains("password can't be blank"));
  });

  test('a bad e-mail comes back re-filled, the password does not', () async {
    final r = await visitor().post(
      '/register?/signUp',
      form: {'username': 'ana', 'email': 'nope', 'password': 'hunter2'},
    );
    expect(r, hasStatus(422));
    expect(r.text, contains('email is invalid'));
    expect(r.text, contains('value="nope"'));
    expect(r.text, contains('value="ana"'));
    expect(r.text, isNot(contains('hunter2')));
  });

  test('the fields carry the native rules of the schema', () async {
    final r = await visitor().get('/register');
    expect(RegExp('required').allMatches(r.text), hasLength(3));
    expect(r.text, contains('type="email"'));
    expect(r.text, contains('action="/register"'));
  });

  test('sign-in keeps the way back in its action', () async {
    final r = await visitor().get('/login?redirectTo=/editor');
    expect(r.text, contains('action="?redirectTo=/editor"'));
  });
}
