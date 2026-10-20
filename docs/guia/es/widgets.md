# Widgets

Escribe la interfaz como clases de widgets, con los mismos nombres y tipos de Flutter. Thor las renderiza en el servidor como HTML.

:::flutter Flutter: `StatelessWidget` con `build` · Thor: la misma clase, renderizada en el servidor

## Un widget es una clase

Un widget es un `StatelessWidget` con su `build`, como en Flutter. Thor ejecuta `build` una vez por petición y el navegador recibe la página ya renderizada.

:::example card
:::

Cada pieza de interfaz es una clase, nunca una función que devuelve un `Widget`: así admite `const`, se prueba por separado y tiene nombre en el árbol.

:::flutter
`LocaleFormat` envuelve a `NumberFormat` y toma el idioma de la página desde `context`.
@flutter
```dart no-check
class PriceTag extends StatelessWidget {
  const PriceTag({super.key, required this.price});

  final double price;

  @override
  Widget build(BuildContext context) => Text(
    NumberFormat.simpleCurrency(
      locale: Localizations.localeOf(context).toString(),
      name: 'USD',
    ).format(price),
  );
}
```
@thor
```dart
class PriceTag extends StatelessWidget {
  const PriceTag({super.key, required this.price});

  final double price;

  @override
  Widget build(BuildContext context) =>
      Text(LocaleFormat.of(context).currency(price, name: 'USD'));
}
```
:::

## Componer widgets

Una pantalla se arma anidando widgets pequeños. Los datos entran por el constructor; la clase `UserTile` no cambia aunque cambie la disposición.

:::bench bench-compose
:::

Crea un widget nuevo cuando algo se repite o tiene nombre propio en la pantalla, como `UserTile` o `PriceTag`.

## Un elemento por widget

`Padding`, `Expanded`, `Opacity` y `Center` no agregan un elemento a la página: se combinan con el de su hijo. Cada widget produce el elemento HTML que le corresponde (un botón es un `<button>`, un `Link` es un `<a>`), y el lector de pantalla lo anuncia como tal.

```dart
// A single element: the padding and the flex share belong to the Text.
Row(
  children: [
    Expanded(
      child: Padding(padding: EdgeInsets.all(8), child: Text('Hello')),
    ),
  ],
)
```

Los diálogos, los menús y los acordeones funcionan sin JavaScript porque usan los elementos nativos del navegador ([Diálogos y menús](dialogos-y-menus.md)).

## Lo que cambia en el navegador

Un `StatelessWidget` no cambia después de renderizarse. Lo que cambia sin recargar vive en un ViewModel (`ThorState`), que el widget lee con `Watch`; el contador completo está en [Interactividad](interactividad.md).

## Siguientes pasos

:::cards
- [Layout](layout.md) — `Row`, `Column`, `Stack`, cuadrículas y responsivo
- [Interactividad](interactividad.md) — ViewModels, `Watch` y callbacks
- [Componentes](componentes.md) — cada widget con su ejemplo, su código y sus parámetros
:::
