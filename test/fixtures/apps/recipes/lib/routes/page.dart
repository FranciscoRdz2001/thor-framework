import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../l10n/app_localizations.thor.dart';
import '../ui/page_title.dart';

/// The page `/`.
class HomePage extends ThorPage<void> {
  /// The one instance the build shares between requests.
  const HomePage();

  /// `/` (and `/en`).
  @override
  PageMeta meta(PageState<void> state) =>
      PageMeta(title: _messages(state.request).homeMeta);

  /// What the recipes are.
  @override
  Widget build(BuildContext context, PageState<void> state) {
    final t = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        PageTitle(t.homeTitle, description: t.homeDescription),
        Text(t.homeHint),
      ],
    );
  }
}

AppLocalizations _messages(PageRequest request) =>
    lookupAppLocalizations(request.locale ?? const Locale('es'));
