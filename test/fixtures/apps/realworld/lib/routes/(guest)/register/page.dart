import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../forms.dart';
import '../../../session.dart';
import '../../../widgets/auth.dart';

/// The page `/register`.
class RegisterPage extends ThorPage<void> {
  /// Shared by every visitor without a session ([publicPageCache]).
  const RegisterPage() : super(cache: publicPageCache);

  /// Create the account and sign in.
  Future<ActionResult?> signUp(
    PageRequest request,
    FormValues<SignUpForm> values,
  ) => authenticate(request, values, register: true);

  /// Title.
  @override
  PageMeta meta(PageState<void> state) =>
      const PageMeta(title: 'Sign up • Conduit');

  /// The form.
  @override
  Widget build(BuildContext context, PageState<void> state) => AuthPage(
    register: true,
    schema: SignUpForm.schema,
    onValid: signUp,
    query: state.request.uri.query,
    failure: state.form,
  );
}
