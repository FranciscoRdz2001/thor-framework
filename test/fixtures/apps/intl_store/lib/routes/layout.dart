import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../cart_state.dart';
import '../l10n/app_localizations.thor.dart';
import '../messages.dart';
import '../router.dart';

/// The layout of `/` and the pages below it.
class RootLayout extends ThorLayout<void> {
  /// The one instance the build shares between requests.
  const RootLayout();

  /// The shop's name as the title of every page.
  @override
  PageMeta meta(PageState<void> state) =>
      PageMeta(title: messagesFor(state.request).storeTitle);

  /// Header (name, languages, cart) around every page.
  @override
  Widget build(BuildContext context, PageState<void> state, Widget child) {
    final t = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    // The browser computes the cart label in the page's language.
    cart.locale.value = locale.toLanguageTag();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          Semantics(
            role: SemanticsRole.navigation,
            child: Row(
              spacing: 16,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Link(
                        href: state.request.localizedPath(homeRoute.link()),
                        child: Text(
                          t.storeTitle,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(t.tagline),
                    ],
                  ),
                ),
                LocaleSwitcher(
                  labels: {
                    const Locale('en'): 'English',
                    const Locale('es'): 'Español',
                  },
                  semanticsLabel: t.language,
                ),
              ],
            ),
          ),
          Row(
            spacing: 12,
            children: [
              Watch(cart.label),
              Watch(
                cart.isEmpty,
                builder: (empty) => TextButton(
                  onPressed: empty ? null : cart.clear,
                  child: Text(t.emptyCart),
                ),
              ),
            ],
          ),
          Semantics(role: SemanticsRole.main, child: child),
        ],
      ),
    );
  }
}
