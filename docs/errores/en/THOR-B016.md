# THOR-B016 · A language is missing messages

**Where:** `thor build` · the messages in `lib/l10n/`.

## What happened

An ARB file in `lib/l10n/` does not have all the keys of the template (`template_arb_file`, `app_en.arb` by default). A regional file (`app_es_MX.arb`) inherits whatever is missing from its language (`app_es.arb`) and only counts what neither of the two has.

## Why

That language's page would show the template's text, in another language, in the middle of the page. By default it is a warning and the class uses the template's message; with `missing_translations: error` the build fails and generates nothing.

## How to fix it

```json
// WRONG: app_es.arb without "cartItems", which app_en.arb does have
{"@@locale": "es", "storeTitle": "La tiendita"}
```

```json
// RIGHT
{
  "@@locale": "es",
  "storeTitle": "La tiendita",
  "cartItems": "{count, plural, =0{Tu carrito está vacío} one{# artículo} other{# artículos}}"
}
```

To make the build fail in CI:

```yaml
# the app's build.yaml
targets:
  $default:
    builders:
      thor_builder:thor_l10n:
        options:
          missing_translations: error
```

[All codes](README.md)
