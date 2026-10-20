# THOR-B016 · A un idioma le faltan mensajes

**Dónde:** `thor build` · los mensajes de `lib/l10n/`.

## Qué pasó

Un archivo ARB de `lib/l10n/` no tiene todas las claves de la plantilla (`template_arb_file`, `app_en.arb` por defecto). Un archivo regional (`app_es_MX.arb`) hereda lo que falte de su idioma (`app_es.arb`) y solo cuenta lo que ninguno de los dos tiene.

## Por qué

La página de ese idioma mostraría el texto de la plantilla, en otro idioma, en medio de la página. Por defecto es un aviso y la clase usa el mensaje de la plantilla; con `missing_translations: error` el build falla y no genera nada.

## Cómo se arregla

```json
// WRONG: app_es.arb sin "cartItems", que app_en.arb sí tiene
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

Para que falle el build en CI:

```yaml
# build.yaml de la app
targets:
  $default:
    builders:
      thor_builder:thor_l10n:
        options:
          missing_translations: error
```

[Todos los códigos](README.md)
