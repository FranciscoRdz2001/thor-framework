import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../middleware/session.dart';

/// `/login`: a form that starts the session.
class LoginPage extends ThorPage<void> {
  const LoginPage();

  @override
  PageMeta meta(PageState<void> state) => const PageMeta(title: 'Entrar');

  /// Starts the session and goes to the profile.
  Future<ActionResult?> signIn(PageRequest request) async {
    final form = await request.form();
    request.response.setCookie(sessionCookie, form['login'] ?? '');
    return const Redirect(RouteUrl('/profile'));
  }

  @override
  Widget build(BuildContext context, PageState<void> state) => Form(
    onPost: signIn,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        const Text('Entrar'),
        const TextFormField(
          name: 'login',
          initialValue: 'ana',
          decoration: InputDecoration(labelText: 'Usuario'),
        ),
        FilledButton(
          buttonType: ButtonType.submit,
          onPressed: () {},
          child: const Text('Entrar'),
        ),
      ],
    ),
  );
}
