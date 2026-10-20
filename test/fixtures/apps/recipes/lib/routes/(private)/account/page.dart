import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../router.dart';
import '../../../session.dart';
import '../../../ui/page_title.dart';

/// The page `/account`.
class AccountPage extends ThorPage<void> {
  /// The one instance the build shares between requests.
  const AccountPage();

  /// `/account`: only with a session (the folder's middleware).
  @override
  PageMeta meta(PageState<void> state) => const PageMeta(title: 'Mi cuenta');

  /// Sign out: delete the cookie and go home.
  Future<ActionResult?> signOut(PageRequest request) async {
    request.response.deleteCookie(sessionCookie);
    return Redirect(homeRoute.link());
  }

  /// Who is signed in.
  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 16,
    children: [
      PageTitle(
        'Mi cuenta',
        description: 'Hola, ${state.request.context.get(currentUser)}.',
      ),
      Form(
        onPost: signOut,
        child: OutlinedButton(
          buttonType: ButtonType.submit,
          onPressed: () {},
          child: const Text('Cerrar sesión'),
        ),
      ),
    ],
  );
}
