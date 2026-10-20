import 'package:thor_ui/intl.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../cart_state.dart';
import '../catalog.dart';
import '../l10n/app_localizations.thor.dart';
import '../router.dart';

/// The page `/`.
class HomePage extends ThorPage<void> {
  /// Shared by every visitor for 30 s, once per language.
  const HomePage() : super(cache: const Duration(seconds: 30));

  /// The product list.
  @override
  Widget build(BuildContext context, PageState<void> state) {
    final t = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final name = state.request.queryParameters['name'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        if (name != null && name.isNotEmpty) Text(t.welcome(name)),
        for (final p in catalog)
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Link(
                      href: state.request.localizedPath(
                        productRoute.link({'id': p.id}),
                      ),
                      child: Text(
                        p.nameIn(language),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text('${t.price(p.price)} · ${t.stock(p.stock)}'),
                    Text(LocaleFormat.of(context).date(p.since)),
                  ],
                ),
              ),
              FilledButton(
                onPressed: p.stock == 0 ? null : cart.add,
                child: Text(t.addToCart),
              ),
            ],
          ),
      ],
    );
  }
}
