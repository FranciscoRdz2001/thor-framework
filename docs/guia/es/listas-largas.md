# Listas largas

Muestra miles de filas sin que la página se vuelva lenta: altura fija por fila, layout diferido y una ventana de filas para las listas que cambian.

:::flutter Flutter: `ListView.builder` · Thor: `ListView.builder` y `Watch.list`

## Una lista que no cambia

`ListView.builder` es el de Flutter. `itemExtent` fija la altura de cada fila, de modo que la barra de desplazamiento es exacta desde el principio, y `lazyLayout: true` hace que el navegador no calcule el layout de las filas que están fuera de la pantalla.

:::flutter
@flutter
```dart no-check
ListView.builder(
  itemExtent: 56,
  itemCount: orders.length,
  itemBuilder: (context, i) => ListTile(title: Text(orders[i].customer)),
)
```
@thor
```dart
ListView.builder(
  itemExtent: 56,
  lazyLayout: true, // web: the browser skips off-screen rows
  itemCount: orders.length,
  itemBuilder: (context, i) => ListTile(title: Text(orders[i].customer)),
)
```
:::

Todas las filas siguen en la página: la búsqueda del navegador (Ctrl+F) las encuentra y Tab llega a ellas.

> **Importante:** En los navegadores basados en Chromium, `lazyLayout` saca las filas lejanas del árbol de accesibilidad hasta que se acercan, y recorta lo que una fila dibuja fuera de su caja (una sombra, el anillo de foco).

## Una lista que cambia

Una lista que sale de un ViewModel (`ThorState`), como un tablero de pedidos o un mercado, es un `Watch.list`: el navegador agrega, mueve y quita filas por su clave, y actualiza solo las que cambiaron. Con `virtual: true`, la página conserva solo las filas cercanas a la pantalla.

:::bench bench-long-list
:::

```dart
// lib/market_view_model.dart
class Quote {
  const Quote(this.id, this.symbol, this.price);
  final int id;
  final String symbol;
  final int price; // in cents

  factory Quote.fromJson(Map<String, Object?> json) => Quote(
    json['id']! as int,
    json['symbol']! as String,
    json['price']! as int,
  );

  Map<String, Object?> toJson() => {'id': id, 'symbol': symbol, 'price': price};
}

List<Quote> seed() => [for (var i = 1; i <= 700; i++) Quote(i, 'S$i', 1000 + i)];

class MarketViewModel extends ThorState {
  final quotes = state<List<Quote>>(seed());

  List<Quote> rows() => quotes.value;
  String keyOf(Quote q) => 'q${q.id}';
  String symbol(Quote q) => q.symbol;
  String price(Quote q) => '${q.price ~/ 100}.${(q.price % 100).toString().padLeft(2, '0')}';
}

final market = MarketViewModel();
```

```dart
// lib/market_page.dart
Watch.list(
  market.rows,
  itemKey: market.keyOf,
  itemExtent: 34, // the height of each row, in px
  lazyLayout: true, // the browser skips off-screen rows
  virtual: true, // and the page keeps only the rows near the screen
  each: (row) => Row(children: [
    Expanded(child: row.text(market.symbol)),
    row.text(market.price),
  ]),
)
```

| Opción | Qué cambia | Qué cuesta |
|---|---|---|
| `itemExtent: 34` | cada fila mide 34 px, como en Flutter | lo que no cabe en esa altura se recorta |
| `lazyLayout: true` | el navegador no calcula lo que está fuera de la pantalla | las filas lejanas salen del árbol de accesibilidad |
| `virtual: true` | la página conserva solo las filas cercanas a la pantalla | Ctrl+F y Tab solo llegan a las filas presentes |

`virtual` requiere `itemExtent` ([THOR-S040](../../errores/THOR-S040.md)): el navegador calcula qué filas se ven dividiendo la posición del desplazamiento entre la altura, sin medir ninguna. La lista no lleva `gap`; separa las filas con un borde dentro de su altura.

Sin JavaScript, la página es la lista completa. Cada fila indica su posición en la lista entera al lector de pantalla, y la fila con el foco se conserva aunque salga de la ventana. Las filas que salen no se guardan: las que entran se crean de nuevo, y son elementos de lista, no filas de una tabla de datos.

## Una página larga

`LazyLayout` aplica la misma idea a una sección entera: el navegador no calcula su layout hasta que se acerca a la pantalla, y `extentEstimate` reserva su altura mientras tanto.

```dart
Column(children: [
  const HeroSection(), // the first screen: never lazy
  LazyLayout(extentEstimate: 640, child: const ProductGrid()),
  LazyLayout(extentEstimate: 480, child: const Results()),
  LazyLayout(extentEstimate: 320, child: const Content()),
])
```

> **Importante:** `LazyLayout` recorta lo que la sección dibuja fuera de su caja (una sombra, un brillo). No lo uses en la primera pantalla.

## Cuándo usar cuál

| Tu lista | Usa |
|---|---|
| menos de 100 filas | nada especial |
| 100 a 1 000 filas que se buscan o se leen con lector de pantalla | `itemExtent` y [`Pagination`](red-y-servidor.md#listas-paginadas-en-la-url) |
| cientos de filas que cambian en vivo | `Watch.list` con `itemExtent` y `virtual: true` |
| contenido largo que se lee de corrido (artículos, tarjetas) | `lazyLayout: true` o `LazyLayout` |

## Actualizaciones en vivo

El navegador actualiza una fila solo si su elemento ya no es el mismo objeto que antes. Al recibir un mensaje, crea un objeto nuevo por cada fila que cambió y conserva el resto.

```dart
// lib/live_market_view_model.dart
import 'market_view_model.dart';

class LiveMarketViewModel extends MarketViewModel {
  // One message: only the quotes that changed, and the pairs of positions that swap.
  void onMessage(List<Quote> changed, List<int> swaps) {
    final byId = {for (final q in changed) q.id: q};
    final r = [for (final q in quotes.value) byId[q.id] ?? q]; // the rest keep their object
    for (var i = 0; i + 1 < swaps.length; i += 2) {
      final t = r[swaps[i]];
      r[swaps[i]] = r[swaps[i + 1]];
      r[swaps[i + 1]] = t;
    }
    quotes.value = r;
  }
}
```

No hace falta agrupar los mensajes que llegan juntos: el navegador actualiza la pantalla una vez por cuadro.

## Seleccionar una fila

`row.selected` hace que una parte de la fila dependa de si su clave es el valor de un campo de estado. Al cambiar el campo, solo se actualizan la fila que estaba elegida y la nueva.

```dart no-check
class OrdersViewModel extends ThorState {
  final items = state(const <Order>[]);
  final selected = state<int>(0); // the key of the chosen row

  List<Order> rows() => items.value;
  int keyOf(Order o) => o.id;
  String title(Order o) => o.title;
  void select(int id) => selected.value = id;
}

Watch.list(orders.rows, itemKey: orders.keyOf, each: (row) =>
    row.selected(orders.selected, builder: (on) =>
        ListTile(selected: on, title: row.text(orders.title))));
```

El campo guarda una sola clave (`int` o `String`, del mismo tipo que `itemKey`). Para varias filas marcadas a la vez, usa `row.watch` con un método.

## Valores por fila

`row.length` convierte un número de cada elemento en un `Length` que el navegador mantiene al día, como `BoundLength` fuera de una lista. Sirve en el `each` y en el `build` de un componente de la fila; fuera de ella falla con [THOR-S042](../../errores/THOR-S042.md).

```dart
// lib/circles_view_model.dart
class Circle {
  const Circle(this.id, this.x, this.diameter);
  final int id;
  final double x;
  final double diameter;

  factory Circle.fromJson(Map<String, Object?> json) => Circle(
    json['id']! as int,
    (json['x']! as num).toDouble(),
    (json['diameter']! as num).toDouble(),
  );

  Map<String, Object?> toJson() => {'id': id, 'x': x, 'diameter': diameter};
}

class CirclesViewModel extends ThorState {
  final items = state<List<Circle>>(const [Circle(1, 10, 24), Circle(2, 60, 40)]);

  List<Circle> rows() => items.value;
  int keyOf(Circle c) => c.id;
  double left(Circle c) => c.x;
  double diameter(Circle c) => c.diameter;
}

final circles = CirclesViewModel();
```

```dart
// lib/circles_page.dart
Watch.list(
  circles.rows,
  itemKey: circles.keyOf,
  container: (rows) => Stack(children: rows),
  each: (row) {
    final x = row.length(circles.left);
    final d = row.length(circles.diameter);
    return Styled(
      style: StyleProps(position: BoxPosition.absolute(left: x), minWidth: d, minHeight: d),
      child: const DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, color: ThemeColor.primary),
      ),
    );
  },
)
```

Los métodos reciben el elemento y devuelven píxeles (`double` o `int`). El ejemplo completo está en [Círculos con deshacer](ejemplos/circulos.md).

## Siguientes pasos

:::cards
- [Estado](estado.md#listas) — `Watch.list`, filas y métodos con `withArg`
- [Layout](layout.md) — `ListView`, `GridView` y la altura de las filas
- [Accesibilidad](accesibilidad.md) — qué lee un lector de pantalla en una lista
:::
