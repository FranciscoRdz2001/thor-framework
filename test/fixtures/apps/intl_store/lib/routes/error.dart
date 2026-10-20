import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../l10n/app_localizations.thor.dart';
import '../router.dart';

/// Not found (or an error), in the page's language.
class AppErrorPage extends ErrorPage {
  /// The page.
  const AppErrorPage();

  @override
  Widget build(BuildContext context, ErrorState state) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          state.status == StatusCode.notFound
              ? t.notFound
              : 'Error ${state.status}',
        ),
        Link(
          href: state.request.localizedPath(homeRoute.link()),
          child: Text(t.back),
        ),
      ],
    );
  }
}
