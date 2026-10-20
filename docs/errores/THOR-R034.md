# THOR-R034 · Un `ResponsiveLayout` lleva lo mismo pesado en dos variantes

**Dónde:** `thor_ui` · `ResponsiveLayout(mobile:, tablet:, desktop:)` (aviso de `thor dev`, no falla).

## Qué pasó

Dos variantes de un `ResponsiveLayout` llevan cada una un `FutureBuilder`, un `Watch.list` o más de 16 KB de HTML. El mensaje dice cuál y en qué variantes.

## Por qué

`ResponsiveLayout` dibuja **todas** las variantes y el CSS oculta las que no tocan: así funciona con SSR y sin parpadeo. Lo que va en dos variantes se envía, se analiza y se guarda dos veces: una cuadrícula de 24 productos en `mobile` y en `desktop` es una cuadrícula de 24 productos en el HTML dos veces (256 KB en una tienda real). Un `FutureBuilder` o un `Watch.list` en las dos se pinta y se mantiene dos veces.

## Cómo se arregla

Si solo cambia la **disposición**, deja un solo árbol y cambia su layout por breakpoint con `.when()`.

```dart
// WRONG: la cuadrícula está dos veces en la página
ResponsiveLayout(
  mobile: ProductGrid(columns: 2, products: products),
  desktop: ProductGrid(columns: 4, products: products),
)
```

```dart
// RIGHT: una cuadrícula, sus columnas por breakpoint
Grid(
  layout: GridLayout(columns: 2, gap: 8).when(large: GridLayout(columns: 4)),
  children: [for (final p in products) ProductCard(p)],
)

// RIGHT: una columna que es fila desde lg
Column(
  layout: FlexLayout().when(large: FlexLayout(direction: Axis.horizontal)),
  children: [sidebar, Expanded(child: content)],
)
```

Si lo que cambia es de verdad distinto (un cajón en el teléfono, una barra arriba en escritorio), deja en el `ResponsiveLayout` solo eso y saca lo común de las variantes: lo pesado va una vez, fuera.

```dart
Column(children: [
  ResponsiveLayout(mobile: const MenuButton(), desktop: const TopBar()),
  ProductGrid(products: products), // una vez
])
```

[Todos los códigos](README.md)
