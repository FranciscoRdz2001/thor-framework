import 'package:thor_ui/thor_ui.dart';

import 'l10n/app_localizations.thor.dart';

/// The cart counter: the only code that runs in the browser. Its label is
/// a plural message, so the generated messages (and intl's plural rules)
/// come along; the server writes the page's locale into [locale].
class CartState extends ThorState {
  final count = state(0);
  final locale = state('en');

  String label() => lookupAppLocalizations(
    Locale.tryParse(locale.value) ?? const Locale('en'),
  ).cartItems(count.value);

  bool isEmpty() => count.value == 0;

  void add() => count.value++;
  void clear() => count.value = 0;
}

final cart = CartState();
