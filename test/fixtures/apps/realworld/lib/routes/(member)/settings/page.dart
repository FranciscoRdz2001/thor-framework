import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../api.dart';
import '../../../router.dart';
import '../../../session.dart';
import '../../../ui.dart';
import '../../../widgets/auth.dart';
import '../../../widgets/fields.dart';

/// The page `/settings`.
class SettingsPage extends ThorPage<void> {
  /// The one instance the build shares between requests.
  const SettingsPage();

  /// Save the profile (then to it).
  Future<ActionResult?> save(PageRequest request) async {
    final user = request.signedIn;
    final form = await request.form();
    final changes = <String, Object?>{
      'image': form['image'] ?? '',
      'username': form['username'] ?? '',
      'bio': form['bio'] ?? '',
      'email': form['email'] ?? '',
      // An empty password field means "keep it" (the API rejects "").
      if ((form['password'] ?? '').isNotEmpty) 'password': form['password'],
    };
    try {
      final updated = await api.updateUser(user.token, changes);
      startSession(request, updated);
      return Redirect(profileRoute.link({'user': updated.username}));
    } on ApiErrors catch (e) {
      return ActionResult.fail(
        422,
        FormFailure(e.messages, {
          for (final k in ['image', 'username', 'bio', 'email'])
            k: form[k] ?? '',
        }),
      );
    }
  }

  /// Sign out (then home).
  ActionResult? logout(PageRequest request) {
    endSession(request);
    return Redirect(homeRoute.link());
  }

  /// Title.
  @override
  PageMeta meta(PageState<void> state) => const PageMeta(
    title: 'Settings • Conduit',
    robotsMeta: RobotsMeta.noindex,
  );

  /// The settings form, filled with the user (or the failed values).
  @override
  Widget build(BuildContext context, PageState<void> state) {
    final user = state.request.signedIn;
    final failure = state.form as FormFailure?;
    final v =
        failure?.values ??
        {
          'image': user.image ?? '',
          'username': user.username,
          'bio': user.bio ?? '',
          'email': user.email,
        };
    return cls(
      'settings-page',
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
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Semantics(
                        headingLevel: 1,
                        child: Text(
                          'Your Settings',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w500,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                    ErrorMessages(failure?.messages ?? const []),
                    Form(
                      onPost: save,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          formField(
                            name: 'image',
                            hint: 'URL of profile picture',
                            initialValue: v['image'],
                          ),
                          formField(
                            name: 'username',
                            hint: 'Username',
                            large: true,
                            initialValue: v['username'],
                          ),
                          formField(
                            name: 'bio',
                            hint: 'Short bio about you',
                            large: true,
                            lines: 8,
                            initialValue: v['bio'],
                          ),
                          formField(
                            name: 'email',
                            hint: 'Email',
                            large: true,
                            keyboard: TextInputType.emailAddress,
                            initialValue: v['email'],
                          ),
                          formField(
                            name: 'password',
                            hint: 'New Password',
                            large: true,
                            obscure: true,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: submitButton(
                              'Update Settings',
                              ButtonKind.primary,
                              size: ButtonSize.large,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(color: hairline, height: 1),
                    ),
                    Form(
                      onPost: logout,
                      child: submitButton(
                        'Or click here to logout.',
                        ButtonKind.outlineDanger,
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
