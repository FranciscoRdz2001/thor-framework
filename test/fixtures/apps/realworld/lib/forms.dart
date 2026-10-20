/// The forms of the app, declared once: the server checks them with the
/// rules the browser checks, and the pages take their attributes from them.
library;

import 'package:thor_ui/router.dart';

/// The fields of sign in and sign up. The messages are the API's (`email
/// can't be blank`), so a failure reads the same whoever catches it.
abstract final class AuthForm {
  /// Username (sign up).
  static const username = TextSchemaField(
    'username',
    validators: [Validator.required("username can't be blank")],
  );

  /// Email.
  static const email = TextSchemaField(
    'email',
    validators: [
      Validator.required("email can't be blank"),
      Validator.email('email is invalid'),
    ],
  );

  /// Password (never re-filled).
  static const password = TextSchemaField(
    'password',
    secret: true,
    validators: [Validator.required("password can't be blank")],
  );
}

/// Sign in: what `LoginPage.signIn` receives.
final class SignInForm extends FormSchema {
  const SignInForm._() : super(const [AuthForm.email, AuthForm.password]);

  /// The form.
  static const schema = SignInForm._();
}

/// Sign up: what `RegisterPage.signUp` receives.
final class SignUpForm extends FormSchema {
  const SignUpForm._()
    : super(const [AuthForm.username, AuthForm.email, AuthForm.password]);

  /// The form.
  static const schema = SignUpForm._();
}
