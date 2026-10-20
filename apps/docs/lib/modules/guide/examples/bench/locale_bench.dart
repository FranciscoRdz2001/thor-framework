/// `:::bench bench-locale`: the i18n reference example. A Switch picks the
/// language of a small shop card and a Level how many items the cart holds:
/// the text, the plural, the money, the date and the reading direction all
/// follow the locale.
///
/// The card is one widget that reads `ShopMessages.of(context)` and
/// `LocaleFormat.of(context)`; each language is a `Localizations` the server
/// compiled as a `Watch.field` variant, so the browser only swaps one for
/// another. `ShopMessages` is written by hand here, in the shape
/// `thor_builder` generates from an ARB file: this site ships one language,
/// so a second ARB would add one to the site itself.
library;

import 'package:thor_ui/intl.dart';
import 'package:thor_ui/thor_ui.dart';

import 'bench_example.dart';

/// The languages of the Switch.
enum ShopLanguage {
  /// English.
  en,

  /// Spanish.
  es,

  /// German.
  de,

  /// Arabic (right to left).
  ar,
}

/// The messages of the shop card in one language, as the generated
/// `AppLocalizations` has them: a getter per message, a method when it takes
/// a placeholder.
class ShopMessages {
  const ShopMessages._(this._language);

  /// The messages in [language].
  const ShopMessages.of(ShopLanguage language) : this._(language);

  /// The messages for the `Localizations` above [context].
  static ShopMessages read(BuildContext context) =>
      Localizations.of<ShopMessages>(context, ShopMessages)!;

  final ShopLanguage _language;

  /// The shop's name.
  String get title => switch (_language) {
    ShopLanguage.en => 'Corner shop',
    ShopLanguage.es => 'Tienda de la esquina',
    ShopLanguage.de => 'Laden an der Ecke',
    ShopLanguage.ar => 'متجر الزاوية',
  };

  /// "Since" with the date already formatted.
  String since(String date) => switch (_language) {
    ShopLanguage.en => 'Open since $date',
    ShopLanguage.es => 'Abierta desde $date',
    ShopLanguage.de => 'Geöffnet seit $date',
    ShopLanguage.ar => 'مفتوح منذ $date',
  };

  /// The cart line: a plural over [count].
  String cartItems(int count) => switch (_language) {
    ShopLanguage.en =>
      count == 0
          ? 'Your cart is empty'
          : count == 1
          ? '1 item'
          : '$count items',
    ShopLanguage.es =>
      count == 0
          ? 'Tu carrito está vacío'
          : count == 1
          ? '1 artículo'
          : '$count artículos',
    ShopLanguage.de =>
      count == 0
          ? 'Dein Warenkorb ist leer'
          : count == 1
          ? '1 Artikel'
          : '$count Artikel',
    ShopLanguage.ar => switch (count) {
      0 => 'سلتك فارغة',
      1 => 'عنصر واحد',
      2 => 'عنصران',
      _ when count <= 10 => '$count عناصر',
      _ => '$count عنصرًا',
    },
  };
}

/// Loads [ShopMessages] for a [Locale]: what a generated delegate does.
class ShopDelegate extends LocalizationsDelegate<ShopMessages> {
  /// The delegate of the example.
  const ShopDelegate();

  @override
  bool isSupported(Locale locale) =>
      ShopLanguage.values.any((l) => l.name == locale.languageCode);

  @override
  Future<ShopMessages> load(Locale locale) => SynchronousFuture(
    ShopMessages.of(
      ShopLanguage.values.firstWhere((l) => l.name == locale.languageCode),
    ),
  );

  @override
  bool shouldReload(ShopDelegate old) => false;
}

/// What the panel controls and the stage reads.
class LocaleBenchViewModel extends ThorState {
  /// The language of the card.
  final language = state(ShopLanguage.en);

  /// How many items the cart holds.
  final items = state(3);

  /// The `locale` line of the Code view.
  String localeCode() => "locale: Locale('${language.value.name}'),";

  /// The message of the ARB file, as it reads in this language.
  String arbCode() => switch (language.value) {
    ShopLanguage.en =>
      '"cartItems": "{count, plural, =0{Your cart is empty} one{# item} other{# items}}"',
    ShopLanguage.es =>
      '"cartItems": "{count, plural, =0{Tu carrito está vacío} one{# artículo} other{# artículos}}"',
    ShopLanguage.de =>
      '"cartItems": "{count, plural, =0{Dein Warenkorb ist leer} one{# Artikel} other{# Artikel}}"',
    ShopLanguage.ar =>
      '"cartItems": "{count, plural, =0{سلتك فارغة} one{عنصر واحد} two{عنصران} few{# عناصر} many{# عنصرًا} other{# عنصر}}"',
  };

  /// The `cartItems` line of the Code view.
  String itemsCode() => 'return Text(t.cartItems(${items.value}));';

  /// The number next to the Level's bar.
  String itemsText() => '${items.value}';

  /// What the Switch calls.
  void setLanguage(ShopLanguage? value) =>
      language.value = value ?? ShopLanguage.en;

  /// What the Level calls.
  void setItems(double value) => items.value = value.round();
}

/// One instance, at the top level: the browser boots with it.
final localeBench = LocaleBenchViewModel();

/// The example: a Switch, a Level, the stage and its code.
final localeBenchExample = BenchExample(
  title: (t) => t.exUiLocaleTitle,
  description: (t) => t.exUiLocaleDescription,
  stage: const LocaleBenchStage(),
  code: BenchCode([
    const BenchCodeLine('// lib/l10n/app_<locale>.arb'),
    BenchCodeLine.live(localeBench.arbCode),
    const BenchCodeLine(' '),
    const BenchCodeLine('Localizations('),
    BenchCodeLine.live(localeBench.localeCode, indent: 1),
    const BenchCodeLine(
      'delegates: AppLocalizations.localizationsDelegates,',
      indent: 1,
    ),
    const BenchCodeLine('child: Builder(builder: (context) {', indent: 1),
    const BenchCodeLine('final t = AppLocalizations.of(context);', indent: 2),
    BenchCodeLine.live(localeBench.itemsCode, indent: 2),
    const BenchCodeLine('}),', indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    BenchDropdown<ShopLanguage>(
      label: (t) => t.exUiLocaleLanguage,
      value: localeBench.language.value,
      onChanged: localeBench.setLanguage,
      items: [
        BenchSegment(ShopLanguage.en, label: (t) => t.exUiLocaleEn),
        BenchSegment(ShopLanguage.es, label: (t) => t.exUiLocaleEs),
        BenchSegment(ShopLanguage.de, label: (t) => t.exUiLocaleDe),
        BenchSegment(ShopLanguage.ar, label: (t) => t.exUiLocaleAr),
      ],
    ),
    BenchLevel(
      label: (t) => t.exUiLocaleItems,
      value: localeBench.items.value,
      max: 12,
      divisions: 12,
      onChanged: localeBench.setItems,
      valueText: localeBench.itemsText,
    ),
  ],
);

/// The stage: the shop card in the language the Switch chose.
class LocaleBenchStage extends StatelessWidget {
  /// The stage of the example.
  const LocaleBenchStage({super.key});

  @override
  Widget build(BuildContext context) => Watch.field(
    localeBench.language,
    builder: (language) => Watch.field(
      localeBench.items,
      count: 13,
      builder: (items) => Localizations(
        locale: Locale(language.name),
        delegates: const [ShopDelegate()],
        child: _Shop(items: items),
      ),
    ),
  );
}

class _Shop extends StatelessWidget {
  const _Shop({required this.items});

  final int items;

  @override
  Widget build(BuildContext context) {
    final t = ShopMessages.read(context);
    final f = LocaleFormat.of(context);
    // web: Flutter reads a `Directionality` here; Thor takes the direction
    // from the locale and each `Row` says it (`textDirection:`).
    final dir = Localizations.localeOf(context).textDirection;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ThemeColor.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Row(
            textDirection: dir,
            children: [
              Text(
                t.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Row(
            textDirection: dir,
            children: [
              Text(
                t.since(f.date(DateTime(2026, 9, 25))),
                style: const TextStyle(
                  fontSize: 15,
                  color: ThemeColor.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            textDirection: dir,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t.cartItems(items), style: const TextStyle(fontSize: 18)),
              Text(
                f.currency(items * 12.5, name: 'EUR'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
