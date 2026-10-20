import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../forms.dart';
import '../../../session.dart';
import '../../../widgets/auth.dart';

/// The page `/login`.
class LoginPage extends ThorPage<void> {
  /// Shared by every visitor without a session ([publicPageCache]).
  const LoginPage() : super(cache: publicPageCache);

  /// Sign in (then back to `?redirectTo` or home).
  Future<ActionResult?> signIn(
    PageRequest request,
    FormValues<SignInForm> values,
  ) => authenticate(request, values, register: false);

  /// Title.
  @override
  PageMeta meta(PageState<void> state) =>
      const PageMeta(title: 'Sign in • Conduit');

  /// The form (re-filled after a failed attempt).
  @override
  Widget build(BuildContext context, PageState<void> state) => AuthPage(
    register: false,
    schema: SignInForm.schema,
    onValid: signIn,
    query: state.request.uri.query,
    failure: state.form,
  );
}
