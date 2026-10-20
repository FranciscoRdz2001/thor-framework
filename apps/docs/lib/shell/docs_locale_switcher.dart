import 'package:thor_server/thor_server.dart' show PageRequest;
import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/router.dart' show LocaleSwitcher, RequestScope;
import 'package:thor_ui/thor_ui.dart';

import '../core/i18n/docs_locale.dart';

/// The language menu of the top bar: one link per language, each to the same
/// page in that language. Nothing while the site has a single language.
class DocsLocaleSwitcher extends StatelessWidget {
  /// The menu.
  const DocsLocaleSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final PageRequest? request = RequestScope.maybeOf(context);
    final routing = request?.localeRouting;
    if (request == null || routing == null || docsLocales.length < 2) {
      return const SizedBox.shrink();
    }
    return StudioLocaleSwitcher(
      selectedIndex: request.locale == null
          ? -1
          : routing.supportedLocales.indexOf(request.locale!),
      locales: [
        for (final locale in routing.supportedLocales)
          StudioLocaleOption(
            locale: locale,
            label: LocaleSwitcher.endonym(locale),
            // A plain link to the page in that language: it works on a
            // static host too.
            href: routing.pathFor(locale, request.routePath),
          ),
      ],
    );
  }
}
