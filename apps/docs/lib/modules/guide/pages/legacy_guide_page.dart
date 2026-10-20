import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../core/content/redirects.dart';
import '../../../core/i18n/docs_locale.dart';

/// The page `/guia/:slug`, where the guide used to live: every old address
/// redirects (permanently) to its page, or to the nearest one.
class LegacyGuidePage extends ThorPage<String> {
  /// Never renders: it only redirects.
  const LegacyGuidePage();

  /// `/guia/<slug>` → the page that replaced it, in the reader's language
  /// (a slug the guide never had is a 404).
  @override
  String load(PageRequest request) {
    final target = legacyGuidePath(request.pathParameters['slug']!);
    if (target == null) throw NotFound(messagesOf(request).notFoundGuide);
    throw Redirect.permanent(
      target.startsWith('http')
          ? RouteUrl.external(target)
          : request.localizedPath(localizeAnchor(localeTagOf(request), target)),
    );
  }

  @override
  Widget build(BuildContext context, PageState<String> state) =>
      const SizedBox.shrink();
}
