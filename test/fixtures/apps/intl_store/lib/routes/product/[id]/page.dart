import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../catalog.dart';
import '../../../l10n/app_localizations.thor.dart';
import '../../../router.dart';

/// The page `/product/:id`.
class ProductPage extends ThorPage<Product> {
  /// The one instance the build shares between requests.
  const ProductPage();

  /// The product, or a 404.
  @override
  Product load(PageRequest request) =>
      productById(request.pathParameters['id']!) ?? (throw const NotFound());

  /// The product's name as the title.
  @override
  PageMeta meta(PageState<Product> state) => PageMeta(
    title: state.data.nameIn(state.request.locale?.languageCode ?? 'en'),
  );

  /// Name, price, stock and since when.
  @override
  Widget build(BuildContext context, PageState<Product> state) {
    final t = AppLocalizations.of(context);
    final p = state.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          p.nameIn(Localizations.localeOf(context).languageCode),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        Text(t.price(p.price)),
        Text(t.stock(p.stock)),
        Text(t.since(p.since)),
        Link(
          href: state.request.localizedPath(homeRoute.link()),
          child: Text(t.back),
        ),
      ],
    );
  }
}
