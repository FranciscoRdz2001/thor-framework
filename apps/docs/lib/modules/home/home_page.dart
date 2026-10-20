import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../core/content/page_meta.dart';
import '../../core/i18n/docs_locale.dart';
import 'widgets/home.dart';

/// The page `/` (`/es`, `/en`…).
class HomePage extends ThorPage<void> {
  /// Rendered once per process; the site is static.
  const HomePage() : super(cache: const Duration(hours: 1));

  /// The home page: what Thor is, where to start.
  @override
  PageMeta meta(PageState<void> state) {
    final t = messagesOf(state.request);
    return docsMeta(
      state.request,
      title: t.homeMetaTitle,
      path: state.uri.path,
      type: 'website',
      bare: true,
      description: t.homeMetaDescription,
    );
  }

  /// Home.
  @override
  Widget build(BuildContext context, PageState<void> state) => const Home();
}
