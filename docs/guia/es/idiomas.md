# Idiomas

Traduce tu app como en Flutter, con archivos ARB y `AppLocalizations`; en la web, la URL decide el idioma de cada página.

:::flutter Flutter: `gen-l10n` y `AppLocalizations` · Thor: los mismos ARB y `AppLocalizations`

## Mensajes en archivos ARB

Los mensajes se escriben en archivos ARB, como en Flutter. La plantilla tiene todos los mensajes; cada traducción, los suyos; una región, solo lo que cambia.

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

`thor dev` y `thor build` generan `lib/l10n/app_localizations.thor.dart` en cada compilación: una clase con un getter por mensaje y un método con un parámetro tipado por cada placeholder.

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

Los textos de un ARB son datos, nunca código: `$`, `'` y los saltos de línea llegan tal cual. Los plurales y los formatos usan `package:intl`, así que declara `intl: ^0.20.2` en el `pubspec.yaml`.

| Caso | Resultado |
|---|---|
| a un idioma le falta un mensaje | aviso THOR-B016; usa el del idioma base o, si no, el de la plantilla |
| `missing_translations: error` en `build.yaml` | ese aviso es un error |
| un placeholder que la plantilla no declara, o un ICU mal formado | error con el archivo, la clave y la posición |
| `app_pt_BR.arb` sin `app_pt.arb` | error: la región no tendría idioma base |

### Sintaxis ICU

| Escribes | Qué es |
|---|---|
| `Hello {name}` | un placeholder |
| `{count, plural, =0{…} one{…} few{…} other{…}}` | un plural: primero los valores exactos, después la categoría del idioma; `other` es obligatorio |
| `#` dentro de un plural | el número |
| `{gender, select, female{…} other{…}}` | una selección; `other` es obligatorio |
| `'{name}'`, `''` | llaves como texto; un apóstrofo |

> **Diferencia con Flutter:** `=0` significa exactamente cero en cualquier idioma; `zero` es la categoría CLDR, que existe en árabe pero no en inglés.

### Tipos y formatos

| `type` | `format` |
|---|---|
| `String`, `Object` | ninguno |
| `int`, `double`, `num` | un constructor de `NumberFormat` (`decimalPattern`, `percentPattern`, `simpleCurrency`, `compact`…) con `optionalParameters` |
| `DateTime` | un esqueleto de `DateFormat` (`yMd`, `yMMMd`, `jm`…) |

## Mensajes en los widgets

`ThorApp` recibe los delegados y los idiomas con los mismos nombres que `MaterialApp`, y un widget lee sus mensajes con `AppLocalizations.of(context)`.

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

Cada idioma de este ejemplo es un `Localizations` sobre la misma tarjeta: cambian el texto, el plural (el árabe tiene seis categorías), el dinero, la fecha y la dirección de lectura.

:::bench bench-locale
:::

El idioma se resuelve como en Flutter: `locale:` si lo das; si no, los idiomas preferidos del usuario contra `supportedLocales` (`localeListResolutionCallback`, `localeResolutionCallback`, `basicLocaleListResolution`). `ThorApp` pone el `lang` y la dirección del documento. Donde no hay `BuildContext`, como en el `meta` de una página, busca los mensajes por idioma:

```dart
final t = lookupAppLocalizations(request.locale!);
```

> **Diferencia con Flutter:** `LocalizationsDelegate.load` debe devolver un `SynchronousFuture`, como hacen los delegados generados: el servidor renderiza la página en una sola pasada.

## El idioma viene de la URL

Cada petición resuelve su idioma, busca la ruta y renderiza la página en ese idioma. El orden es: prefijo de la URL, cookie, `Accept-Language` e idioma por omisión.

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

Las rutas no cambian: `ThorRoute('/product/:id', …)` responde en todos los idiomas.

| Estrategia | URLs | Úsala para |
|---|---|---|
| `prefix` | `/es/product/mug`, `/en/product/mug`; sin prefijo, `302` al idioma del usuario | un sitio nuevo en varios idiomas |
| `prefixExceptDefault` | `/product/mug` en el idioma por omisión, `/en/product/mug` en los demás | agregar idiomas sin cambiar las URLs existentes |
| `negotiate` | una sola URL; el idioma sale de la cookie o de `Accept-Language` (`Vary: Accept-Language, Cookie`) | una app detrás de una sesión; no se puede exportar |

> **Diferencia con Flutter:** El idioma preferido es el de la petición, no el del dispositivo, y el de la URL tiene prioridad: la URL identifica la página.

Una página conoce su idioma con `request.locale` y su ruta sin prefijo con `request.routePath`. Los enlaces se escriben en el idioma de la página:

```dart
Link(
  href: state.request.localizedPath(productRoute.link({'id': p.id})),
  child: Text(p.name),
)
// another language: request.localizedPath(path, locale: Locale('en'))
```

Una página en `/en/…` lleva `lang="en"`, un `hreflang` a cada idioma y `x-default`. Un `Accept-Language` mal formado o una cookie desconocida se ignoran y se usa el idioma por omisión.

### Selector de idioma

`LocaleSwitcher` muestra un enlace por idioma y marca el actual; funciona sin JavaScript. Cada enlace lleva `?set-locale=en`: el servidor guarda la elección en la cookie y responde con la página en ese idioma.

```dart
LocaleSwitcher(labels: {Locale('es'): 'Español', Locale('en'): 'English'})
```

### Exportar un sitio en varios idiomas

`thor export` escribe cada ruta una vez por idioma (`en/about.html`, `es/about.html`). `/` es una página mínima que lleva al usuario a su idioma, y el sitemap lista las páginas de cada idioma. Una app estática sin rutas (`runApp(Document(...))`) con dos o más ARB se renderiza una vez por idioma en `build/site/<locale>.html`; en desarrollo, elige el idioma con `THOR_LOCALE=es thor dev`.

## Números, dinero y fechas

`LocaleFormat.of(context)` formatea según el idioma de la página.

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

Un idioma sin datos en `intl` formatea como su idioma base y, si no, como inglés: nunca lanza una excepción. También sirven `NumberFormat` y `DateFormat` con `AppLocalizations.of(context).localeName`.

## El calendario en cada idioma

`CalendarDatePicker`, `DatePickerDialog` y `DatePickerFormField` leen `MaterialLocalizations.of(context)`: los nombres de meses y días, el orden de mes y año y el primer día de la semana. `ThorApp` incluye inglés y español; para otros idiomas, agrega los delegados de CLDR, como una app de Flutter agrega `flutter_localizations`:

```dart
ThorApp(
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar', 'EG')],
  child: const Text('Booking'),
)
```

En francés, el calendario empieza en lunes y dice «octobre 2026»; en árabe de Egipto usa sus dígitos (`٢٠٢٦`) y se lee de derecha a izquierda. El servidor envía los nombres y los dígitos ya resueltos, así que el navegador no descarga datos de idioma. Los textos de los botones siguen en inglés en los idiomas distintos de inglés y español, hasta que la app agregue su propio `MaterialLocalizations`.

## Texto traducido que cambia en el navegador

Un `Watch` con un texto traducido que cambia, como el contador del carrito, usa los mensajes generados sin `BuildContext`. El layout pasa el idioma de la página al ViewModel (`ThorState`) desde el servidor.

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

Dentro de un ViewModel no uses `NumberFormat`, `DateFormat` ni `LocaleFormat` ([THOR-B012](../../errores/THOR-B012.md)): formatea en el servidor y pasa el texto. Lo que no cambia en el navegador (títulos, botones, precios) se renderiza en el servidor.

## Derecha a izquierda

Un idioma de derecha a izquierda (`ar`, `he`, `fa`, `ur`…) cambia la dirección de todo el documento. El navegador invierte lo que depende de ella: el orden de un `Row`, la alineación del texto y el lado del desplazamiento. Como en Flutter, `EdgeInsets.only(left: …)` es físico y no se invierte; `Locale.textDirection` da la dirección de un idioma.

## Siguientes pasos

:::cards
- [Accesibilidad](accesibilidad.md) — idioma, dirección y nombres traducidos
- [Compilar y publicar](publicar.md) — exportar un sitio por idioma
- [SEO](seo.md) — `hreflang` y `x-default`
:::
