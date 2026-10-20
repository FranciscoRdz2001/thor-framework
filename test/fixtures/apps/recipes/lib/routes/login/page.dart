// Recipe: sign in. The action checks the credentials, sets the signed
// cookie and goes back to where the visitor was sent from (only a path of
// this site: never an open redirect).
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../session.dart';
import '../../ui/page_title.dart';
import '../../ui/tokens.dart';

/// The page `/login`.
class LoginPage extends ThorPage<void> {
  /// The one instance the build shares between requests.
  const LoginPage();

  /// `/login`.
  @override
  PageMeta meta(PageState<void> state) => const PageMeta(title: 'Entrar');

  /// Sign in. Demo account: ana@example.com / recipes123.
  Future<ActionResult?> signIn(PageRequest request) async {
    final form = await request.form();
    final email = (form['email'] ?? '').trim();
    if (email != 'ana@example.com' || form['password'] != 'recipes123') {
      return ActionResult.fail(401, email);
    }
    request.response.setCookie(
      sessionCookie,
      cookies.sign('Ana'),
      maxAge: sessionLifetime,
    );
    return Redirect(_back(request.queryParameters['back']));
  }

  /// The form; after a wrong attempt, the email stays and a message shows.
  @override
  Widget build(BuildContext context, PageState<void> state) {
    final failedEmail = state.form as String?;
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          const PageTitle(
            'Entrar',
            description: 'ana@example.com / recipes123',
          ),
          if (failedEmail != null)
            const Semantics(
              role: SemanticsRole.alert,
              child: Text(
                'El correo o la contraseña no coinciden.',
                style: TextStyle(color: danger),
              ),
            ),
          Form(
            // The page's own query (`?back=…`) travels with the POST.
            action: '?${state.request.uri.query}',
            onPost: signIn,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                TextFormField(
                  name: 'email',
                  initialValue: failedEmail,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: [AutofillHints.username],
                  decoration: const InputDecoration(labelText: 'Correo'),
                  validators: const [Validator.required('Escribe tu correo.')],
                ),
                const TextFormField(
                  name: 'password',
                  obscureText: true,
                  autofillHints: [AutofillHints.password],
                  decoration: InputDecoration(labelText: 'Contraseña'),
                  validators: [Validator.required('Escribe tu contraseña.')],
                ),
                FilledButton(
                  buttonType: ButtonType.submit,
                  onPressed: () {},
                  child: const Text('Entrar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Only a path of this site.
RouteUrl _back(String? to) =>
    to != null && to.startsWith('/') && !to.startsWith('//')
    ? RouteUrl(to)
    : const RouteUrl('/account');
