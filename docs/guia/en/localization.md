# Localization

Translate your app as in Flutter, with ARB files and `AppLocalizations`; on the web, the URL decides the language of each page.

:::flutter Flutter: `gen-l10n` and `AppLocalizations` · Thor: the same ARB files and `AppLocalizations`

## Messages in ARB files

Messages are written in ARB files, as in Flutter. The template has every message; each translation, its own; a region, only what changes.

```text
lib/l10n/
  app_en.arb     the template: every message, with its placeholders
  app_es.arb     a translation
  app_es_MX.arb  a region: only what differs from es
```

```json
{
  "@@locale": "en",
  "storeTitle": "Corner shop",
  "welcome": "Welcome, {name}!",
  "cartItems": "{count, plural, =0{Your cart is empty} one{# item} other{# items}}",
  "@cartItems": {"placeholders": {"count": {"type": "int"}}},
  "price": "{amount}",
  "@price": {
    "placeholders": {
      "amount": {"type": "double", "format": "simpleCurrency", "optionalParameters": {"name": "EUR"}}
    }
  },
  "since": "In the shop since {date}",
  "@since": {"placeholders": {"date": {"type": "DateTime", "format": "yMMMd"}}}
}
```

`thor dev` and `thor build` generate `lib/l10n/app_localizations.thor.dart` on every build: a class with one getter per message and one method with a typed parameter for each placeholder.

```dart no-check
abstract class AppLocalizations {
  static AppLocalizations of(BuildContext context);
  static const localizationsDelegates = [delegate];
  static const supportedLocales = [Locale('en'), Locale('es'), Locale('es', 'MX')];

  String get storeTitle;
  String welcome(Object name);
  String cartItems(int count);
  String price(double amount);
  String since(DateTime date);
}
AppLocalizations lookupAppLocalizations(Locale locale);
```

The texts in an ARB file are data, never code: `$`, `'` and line breaks arrive as they are. Plurals and formats use `package:intl`, so declare `intl: ^0.20.2` in `pubspec.yaml`.

| Case | Result |
|---|---|
| a language is missing a message | warning THOR-B016; it uses the base language's message or, failing that, the template's |
| `missing_translations: error` in `build.yaml` | that warning becomes an error |
| a placeholder the template doesn't declare, or malformed ICU | error with the file, the key and the position |
| `app_pt_BR.arb` without `app_pt.arb` | error: the region would have no base language |

### ICU syntax

| You write | What it is |
|---|---|
| `Hello {name}` | a placeholder |
| `{count, plural, =0{…} one{…} few{…} other{…}}` | a plural: exact values first, then the language's category; `other` is required |
| `#` inside a plural | the number |
| `{gender, select, female{…} other{…}}` | a select; `other` is required |
| `'{name}'`, `''` | braces as text; an apostrophe |

> **Difference from Flutter:** `=0` means exactly zero in any language; `zero` is the CLDR category, which exists in Arabic but not in English.

### Types and formats

| `type` | `format` |
|---|---|
| `String`, `Object` | none |
| `int`, `double`, `num` | a `NumberFormat` constructor (`decimalPattern`, `percentPattern`, `simpleCurrency`, `compact`…) with `optionalParameters` |
| `DateTime` | a `DateFormat` skeleton (`yMd`, `yMMMd`, `jm`…) |

## Messages in widgets

`ThorApp` takes the delegates and the locales with the same names as `MaterialApp`, and a widget reads its messages with `AppLocalizations.of(context)`.

:::flutter
@flutter
```dart no-check
MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: const ShopPage(),
)
```
@thor
```dart
ThorApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  child: page,
)
```
:::

```dart
Widget build(BuildContext context) {
  final t = AppLocalizations.of(context);
  return Column(children: [
    Text(t.storeTitle),
    Text(t.welcome(name)), // name is text: <script> arrives escaped
    Text(t.cartItems(count)),
  ]);
}
```

Each language in this example is a `Localizations` around the same card: the text, the plural (Arabic has six categories), the money, the date and the reading direction all change.

:::bench bench-locale
:::

The locale is resolved as in Flutter: `locale:` if you provide it; otherwise, the user's preferred languages against `supportedLocales` (`localeListResolutionCallback`, `localeResolutionCallback`, `basicLocaleListResolution`). `ThorApp` sets the document's `lang` and direction. Where there is no `BuildContext`, as in a page's `meta`, look up the messages by locale:

```dart
final t = lookupAppLocalizations(request.locale!);
```

> **Difference from Flutter:** `LocalizationsDelegate.load` must return a `SynchronousFuture`, as the generated delegates do: the server renders the page in a single pass.

## The language comes from the URL

Each request resolves its locale, finds the route and renders the page in that language. The order is: URL prefix, cookie, `Accept-Language` and default locale.

```dart
// lib/app.dart
final app = ThorApp.router(
  routerConfig: router, // lib/router.dart: only routes
  supportedLocales: AppLocalizations.supportedLocales, // [Locale('es'), Locale('en')]
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  localeStrategy: LocaleStrategy.prefixExceptDefault, // prefix | prefixExceptDefault | negotiate
  // defaultLocale: Locale('es'), // the first one if missing
  // localeCookieName: 'locale', // the cookie that remembers a choice
  theme: appTheme,
);

void main() => runApp(app);
```

Routes don't change: `ThorRoute('/product/:id', …)` responds in every language.

| Strategy | URLs | Use it for |
|---|---|---|
| `prefix` | `/es/product/mug`, `/en/product/mug`; without a prefix, `302` to the user's language | a new multilingual site |
| `prefixExceptDefault` | `/product/mug` in the default language, `/en/product/mug` in the others | adding languages without changing existing URLs |
| `negotiate` | a single URL; the language comes from the cookie or from `Accept-Language` (`Vary: Accept-Language, Cookie`) | an app behind a session; it can't be exported |

> **Difference from Flutter:** The preferred language is the request's, not the device's, and the URL's language takes priority: the URL identifies the page.

A page knows its locale through `request.locale` and its unprefixed path through `request.routePath`. Links are written in the page's language:

```dart
Link(
  href: state.request.localizedPath(productRoute.link({'id': p.id})),
  child: Text(p.name),
)
// another language: request.localizedPath(path, locale: Locale('en'))
```

A page at `/en/…` gets `lang="en"`, an `hreflang` for each language and `x-default`. A malformed `Accept-Language` or an unknown cookie is ignored and the default locale is used.

### Language switcher

`LocaleSwitcher` shows one link per language and marks the current one; it works without JavaScript. Each link carries `?set-locale=en`: the server stores the choice in the cookie and responds with the page in that language.

```dart
LocaleSwitcher(labels: {Locale('es'): 'Español', Locale('en'): 'English'})
```

### Exporting a multilingual site

`thor export` writes each route once per language (`en/about.html`, `es/about.html`). `/` is a minimal page that sends the user to their language, and the sitemap lists the pages of each language. A static app without routes (`runApp(Document(...))`) with two or more ARB files is rendered once per language into `build/site/<locale>.html`; in development, pick the language with `THOR_LOCALE=es thor dev`.

## Numbers, money and dates

`LocaleFormat.of(context)` formats according to the page's language.

```dart
import 'package:thor_ui/intl.dart';

final f = LocaleFormat.of(context);
f.decimal(1234.5); // en: 1,234.5 · es: 1.234,5
f.currency(1234.5, name: 'EUR'); // es: 1.234,50 €
f.percent(0.25); // 25%
f.compact(1200000); // 1.2M
f.date(DateTime(2026, 9, 25)); // Sep 25, 2026 · 25 sept 2026
f.time(now); // 3:05 PM · 15:05
```

A language without data in `intl` formats like its base language and, failing that, like English: it never throws. `NumberFormat` and `DateFormat` with `AppLocalizations.of(context).localeName` work too.

## The calendar in each language

`CalendarDatePicker`, `DatePickerDialog` and `DatePickerFormField` read `MaterialLocalizations.of(context)`: the names of months and days, the order of month and year and the first day of the week. `ThorApp` includes English and Spanish; for other languages, add the CLDR delegates, just as a Flutter app adds `flutter_localizations`:

```dart
ThorApp(
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar', 'EG')],
  child: const Text('Booking'),
)
```

In French, the calendar starts on Monday and says "octobre 2026"; in Egyptian Arabic it uses its own digits (`٢٠٢٦`) and reads right to left. The server sends the names and digits already resolved, so the browser doesn't download any locale data. Button labels stay in English for languages other than English and Spanish, until the app adds its own `MaterialLocalizations`.

## Translated text that changes in the browser

A `Watch` with translated text that changes, like the cart counter, uses the generated messages without a `BuildContext`. The layout passes the page's locale to the ViewModel (`ThorState`) from the server.

```dart
class CartViewModel extends ThorState {
  final count = state(0);
  final locale = state('en');

  String label() => lookupAppLocalizations(
    Locale.tryParse(locale.value) ?? const Locale('en'),
  ).cartItems(count.value);
}

// in a layout (server): the page's locale reaches the browser
cart.locale.value = Localizations.localeOf(context).toLanguageTag();
```

Inside a ViewModel, don't use `NumberFormat`, `DateFormat` or `LocaleFormat` ([THOR-B012](../../errores/en/THOR-B012.md)): format on the server and pass the text. Whatever doesn't change in the browser (titles, buttons, prices) is rendered on the server.

## Right to left

A right-to-left language (`ar`, `he`, `fa`, `ur`…) changes the direction of the whole document. The browser mirrors whatever depends on it: the order of a `Row`, text alignment and the scroll side. As in Flutter, `EdgeInsets.only(left: …)` is physical and isn't mirrored; `Locale.textDirection` gives a language's direction.

## Next steps

:::cards
- [Accessibility](accessibility.md) — language, direction and translated names
- [Build and deploy](build-and-deploy.md) — export one site per language
- [SEO](seo.md) — `hreflang` and `x-default`
:::
