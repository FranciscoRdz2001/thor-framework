import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import 'l10n/app_localizations.thor.dart';

/// The messages of [request]'s locale, where there is no `BuildContext`
/// (a page's `meta`).
AppLocalizations messagesFor(PageRequest request) =>
    lookupAppLocalizations(request.locale ?? const Locale('en'));
