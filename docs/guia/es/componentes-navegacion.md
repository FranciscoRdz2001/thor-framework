# Navegación

Barras, pestañas, menús laterales y enlaces para moverse por la app.

## AppBar

:::flutter Flutter: `AppBar` · Thor: el mismo, fijo dentro de `Scaffold`

:::bench cat-app-bar
:::

La barra superior, con `leading`, `title` y `actions`. Dentro de `Scaffold(appBar:)` queda fija mientras el contenido se desplaza.

| Parámetro | Qué hace |
| --- | --- |
| `leading`, `title`, `actions` | el inicio, el título y los botones del final |
| `bottom` | un widget debajo de la barra, como un `TabBar` |
| `centerTitle`, `titleSpacing`, `toolbarHeight` | la posición del título y el alto de la barra |
| `backgroundColor`, `foregroundColor`, `shape` | el fondo, el color del texto y los íconos, y la forma |
| `elevation`, `scrolledUnderElevation` | la sombra, y la sombra cuando el contenido pasa por debajo |
| `flexibleSpace` | un widget detrás de toda la barra, como una imagen o un degradado |

```dart
AppBar(
  title: const Text('Sales'),
  elevation: 0,
  scrolledUnderElevation: 3,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
  ),
)
```

## Scaffold

La estructura de una pantalla. Incluye un enlace «Saltar al contenido», visible solo con el foco del teclado; `skipLink: false` lo quita.

```dart
Scaffold(
  appBar: AppBar(title: const Text('Sales')),
  body: ListView(children: rows),
  floatingActionButton: FloatingActionButton(onPressed: add, child: const Icon(Icons.add)),
  floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
  bottomNavigationBar: NavigationBar(destinations: tabs),
)
```

| Parámetro | Qué hace |
| --- | --- |
| `appBar`, `body`, `drawer`, `endDrawer` | las regiones de la pantalla |
| `bottomNavigationBar`, `bottomSheet`, `persistentFooterButtons` | lo que queda fijo abajo |
| `floatingActionButton`, `floatingActionButtonLocation` | el botón flotante y su posición |
| `extendBody`, `extendBodyBehindAppBar` | el contenido continúa por debajo de las barras |
| `backgroundColor`, `drawerScrimColor` | el fondo y el velo detrás del cajón |

> **Diferencia con Flutter:** `resizeToAvoidBottomInset` no tiene efecto: el navegador decide cómo responde la página al teclado. `bottomSheet` está siempre visible; para una hoja que se abre, usa `ModalBottomSheet`.

## CustomScrollView

:::example nav-slivers
:::

Una región con scroll donde los slivers van uno tras otro: `SliverAppBar`, `SliverList`, `SliverGrid`, `SliverToBoxAdapter`, `SliverPadding` y `SliverFillRemaining`. `SliverAppBar(pinned: true, expandedHeight:)` se reduce hasta la barra mientras el contenido se desplaza, sin JavaScript.

```dart
CustomScrollView(
  slivers: [
    const SliverAppBar(pinned: true, expandedHeight: 160, title: Text('Sales')),
    SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid.extent(maxCrossAxisExtent: 240, children: cards),
    ),
    SliverList.builder(
      itemCount: rows.length,
      itemBuilder: (context, i) => ListTile(title: Text(rows[i])),
    ),
  ],
)
```

> **Diferencia con Flutter:** Solo hay scroll vertical y sin `reverse`. `floating` y `snap` no tienen efecto, y no existen `SliverPersistentHeader` ni los delegates propios de `SliverGrid`.

## TabBar y TabBarView

:::bench cat-tabs
:::

Pestañas con su contenido, que funcionan sin JavaScript. `DefaultTabController` las conecta, las flechas del teclado cambian de pestaña y `TabBar(onTap:)` avisa al ViewModel (`ThorState`) cuál se eligió.

> **Diferencia con Flutter:** Los paneles no se deslizan con el dedo.

## Drawer

:::bench cat-drawer
:::

Un menú que entra desde un lado. En `Scaffold(drawer:)`, el `AppBar` agrega el botón que lo abre; fuera de un `Scaffold`, `DialogTrigger` lo abre y `DialogClose` lo cierra. Se cierra con Esc, con un toque fuera o al pulsar un enlace interior.

> **Diferencia con Flutter:** No existe `Scaffold.of(context).openDrawer()`: desde un método, el ViewModel abre el cajón con un `DialogController` ([Avisos](componentes-avisos.md#dialog)).

## ModalBottomSheet

:::bench cat-bottom-sheet
:::

Una hoja que sube desde abajo. Se abre y se cierra igual que el `Drawer`, con `DialogTrigger` o un `DialogController`.

## NavigationBar

:::bench cat-navigation-bar
:::

La barra de destinos inferior. `onDestinationSelected` recibe el índice pulsado; con `NavigationDestination(href:)`, cada destino es un enlace a otra página y no hace falta estado.

## NavigationRail

:::bench cat-navigation-rail
:::

La barra de destinos lateral, para pantallas anchas. Va dentro de un `Row` y ocupa todo su alto.

| Parámetro | Qué hace |
| --- | --- |
| `labelType` | `none`, `selected` o `all`; un nombre oculto sigue siendo el nombre accesible |
| `extended` | un rail ancho, con el texto junto al ícono |
| `leading`, `trailing` | un widget antes o después de los destinos |
| `groupAlignment` | `-1` arriba, `0` al centro, `1` abajo |
| `NavigationRailDestination(href:)` | un destino que es un enlace, sin estado |

`NavigationRailTheme`, o `ThemeData(navigationRailTheme:)`, define los valores por omisión de los rails que contiene.

## Link

:::bench cat-link
:::

Convierte cualquier widget en un enlace sin agregar nada alrededor; `current: true` marca el enlace de la página actual. Los botones y los `ListTile` aceptan `href` directamente.

Un `Column` centra a sus hijos y cada enlace mide lo que su texto. Para una lista de enlaces alineados al inicio, usa `CrossAxisAlignment.stretch`:

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    Link(
      href: const RouteUrl('/coffee'),
      child: const Padding(
        padding: EdgeInsets.all(10),
        child: Text('Coffee', textAlign: TextAlign.start),
      ),
    ),
  ],
)
```
