import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../api.dart';
import '../env.dart';
import '../forms.dart';
import '../session.dart';
import '../ui.dart';
import 'fields.dart';

/// A failed form: the API's messages and the values to re-fill.
class FormFailure {
  /// Messages and [values].
  const FormFailure(this.messages, [this.values = const {}]);

  /// "email is invalid"…
  final List<String> messages;

  /// Field → submitted value (never passwords).
  final Map<String, String> values;
}

/// Only same-site paths (no open redirect).
RouteUrl? safeRedirect(String? to) =>
    to != null &&
        to.startsWith('/') &&
        !to.startsWith('//') &&
        !to.startsWith('/\\')
    ? RouteUrl(to)
    : null;

/// Sign-in attempts: 20 per IP and 10 per account every 15 minutes (a
/// password guesser, or one password tried on many accounts); the
/// `REALWORLD_LOGIN_LIMIT` per account (twice that per IP) when set. In this
/// isolate's memory: several instances need a shared `RateLimitStore`.
final _loginByIp = RateLimit(
  max: (env.of(RealworldEnv.loginLimit) ?? 10) * 2,
  window: const Duration(minutes: 15),
);
final _loginByAccount = RateLimit(
  max: env.of(RealworldEnv.loginLimit) ?? 10,
  window: const Duration(minutes: 15),
);

/// What sign in and sign up do once their form is valid: call the API,
/// start the session and go back to where sign-in was asked (or home).
Future<ActionResult?> authenticate(
  PageRequest request,
  FormValues<FormSchema> values, {
  required bool register,
}) async {
  final email = values.of(AuthForm.email);
  final password = values.of(AuthForm.password);
  if (!register) {
    final byIp = await _loginByIp.attempt(RateLimit.clientIp(request));
    final byAccount = await _loginByAccount.attempt(email.toLowerCase());
    if (!byIp.allowed || !byAccount.allowed) {
      final wait = [
        if (!byIp.allowed) byIp.retryAfter,
        if (!byAccount.allowed) byAccount.retryAfter,
      ].reduce((a, b) => a > b ? a : b);
      request.response.headers[HttpHeader.retryAfter] = '${wait.inSeconds}';
      return values
          .invalid()
          .withError('Too many sign-in attempts. Try again in a few minutes.')
          .fail(429);
    }
  }
  try {
    final user = register
        ? await api.register(values.of(AuthForm.username), email, password)
        : await api.login(email, password);
    startSession(request, user);
  } on ApiErrors catch (e) {
    return e.messages
        .fold(values.invalid(), (f, m) => f.withError(m))
        .fail(e.status == StatusCode.unauthorized ? 401 : 422);
  }
  return Redirect(
    safeRedirect(request.queryParameters['redirectTo']) ?? const RouteUrl('/'),
  );
}

/// Sign in / sign up.
class AuthPage<S extends FormSchema> extends StatelessWidget
    implements ThorElementWidget {
  /// The page; [register] = sign up.
  const AuthPage({
    super.key,
    required this.register,
    required this.schema,
    required this.onValid,
    required this.query,
    this.failure,
  });

  /// Sign up instead of sign in.
  final bool register;

  /// The form's fields.
  final S schema;

  /// The page's action method.
  final PageValidPost<S> onValid;

  /// The page's query (`redirectTo=…`), kept by the POST.
  final String query;

  /// A failed attempt (`state.form`).
  final Object? failure;

  @override
  Widget build(BuildContext context) {
    final failure = this.failure;
    return cls(
      'auth-page',
      PageContainer(
        classes: 'container page',
        child: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: GridRow(
            children: [
              Col(
                xs: 12,
                md: 6,
                offset: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    cls(
                      'text-xs-center',
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Semantics(
                          headingLevel: 1,
                          child: Text(
                            register ? 'Sign up' : 'Sign in',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w500,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text.rich(
                        textAlign: TextAlign.center,
                        TextSpan(
                          text: register
                              ? 'Have an account?'
                              : 'Need an account?',
                          href: register ? '/login' : '/register',
                          style: const TextStyle(color: brand),
                        ),
                      ),
                    ),
                    ErrorMessages(
                      failure is FormInvalid ? failure.messages : const [],
                    ),
                    Form(
                      action: '?$query',
                      schema: schema,
                      onValid: onValid,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (register)
                            formField(
                              name: AuthForm.username.name,
                              hint: 'Your Name',
                              large: true,
                              attributes: AuthForm.username.attributes,
                              initialValue: AuthForm.username.value(failure),
                            ),
                          formField(
                            name: AuthForm.email.name,
                            hint: 'Email',
                            large: true,
                            attributes: AuthForm.email.attributes,
                            keyboard: TextInputType.emailAddress,
                            initialValue: AuthForm.email.value(failure),
                          ),
                          formField(
                            name: AuthForm.password.name,
                            hint: 'Password',
                            large: true,
                            attributes: AuthForm.password.attributes,
                            obscure: true,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: submitButton(
                              register ? 'Sign up' : 'Sign in',
                              ButtonKind.primary,
                              size: ButtonSize.large,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
