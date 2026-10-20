# Navigation

Bars, tabs, side menus and links for moving around the app.

## AppBar

:::flutter Flutter: `AppBar` · Thor: the same, fixed inside `Scaffold`

:::bench cat-app-bar
:::

The top bar, with `leading`, `title` and `actions`. Inside `Scaffold(appBar:)` it stays fixed while the content scrolls.

| Parameter | What it does |
| --- | --- |
| `leading`, `title`, `actions` | the start, the title and the trailing buttons |
| `bottom` | a widget below the bar, such as a `TabBar` |
| `centerTitle`, `titleSpacing`, `toolbarHeight` | the title's position and the bar's height |
| `backgroundColor`, `foregroundColor`, `shape` | the background, the color of text and icons, and the shape |
| `elevation`, `scrolledUnderElevation` | the shadow, and the shadow when content scrolls underneath |
| `flexibleSpace` | a widget behind the whole bar, such as an image or a gradient |

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

The structure of a screen. It includes a "Skip to content" link, visible only with keyboard focus; `skipLink: false` removes it.

```dart
Scaffold(
  appBar: AppBar(title: const Text('Sales')),
  body: ListView(children: rows),
  floatingActionButton: FloatingActionButton(onPressed: add, child: const Icon(Icons.add)),
  floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
  bottomNavigationBar: NavigationBar(destinations: tabs),
)
```

| Parameter | What it does |
| --- | --- |
| `appBar`, `body`, `drawer`, `endDrawer` | the regions of the screen |
| `bottomNavigationBar`, `bottomSheet`, `persistentFooterButtons` | what stays fixed at the bottom |
| `floatingActionButton`, `floatingActionButtonLocation` | the floating button and its position |
| `extendBody`, `extendBodyBehindAppBar` | the content continues underneath the bars |
| `backgroundColor`, `drawerScrimColor` | the background and the scrim behind the drawer |

> **Difference from Flutter:** `resizeToAvoidBottomInset` has no effect: the browser decides how the page responds to the keyboard. `bottomSheet` is always visible; for a sheet that opens, use `ModalBottomSheet`.

## CustomScrollView

:::example nav-slivers
:::

A scrolling region where slivers go one after another: `SliverAppBar`, `SliverList`, `SliverGrid`, `SliverToBoxAdapter`, `SliverPadding` and `SliverFillRemaining`. `SliverAppBar(pinned: true, expandedHeight:)` shrinks down to the bar while the content scrolls, without JavaScript.

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

> **Difference from Flutter:** There is only vertical scrolling, without `reverse`. `floating` and `snap` have no effect, and there is no `SliverPersistentHeader` nor custom `SliverGrid` delegates.

## TabBar and TabBarView

:::bench cat-tabs
:::

Tabs with their content, working without JavaScript. `DefaultTabController` connects them, the arrow keys switch tabs and `TabBar(onTap:)` tells the ViewModel (`ThorState`) which one was chosen.

> **Difference from Flutter:** The panels don't swipe with a finger.

## Drawer

:::bench cat-drawer
:::

A menu that slides in from one side. In `Scaffold(drawer:)`, the `AppBar` adds the button that opens it; outside a `Scaffold`, `DialogTrigger` opens it and `DialogClose` closes it. It closes with Esc, a tap outside or a tap on a link inside.

> **Difference from Flutter:** There is no `Scaffold.of(context).openDrawer()`: from a method, the ViewModel opens the drawer with a `DialogController` ([Feedback](components-feedback.md#dialog)).

## ModalBottomSheet

:::bench cat-bottom-sheet
:::

A sheet that slides up from the bottom. It opens and closes just like the `Drawer`, with `DialogTrigger` or a `DialogController`.

## NavigationBar

:::bench cat-navigation-bar
:::

The bottom destination bar. `onDestinationSelected` receives the tapped index; with `NavigationDestination(href:)`, each destination is a link to another page and no state is needed.

## NavigationRail

:::bench cat-navigation-rail
:::

The side destination bar, for wide screens. It goes inside a `Row` and takes its full height.

| Parameter | What it does |
| --- | --- |
| `labelType` | `none`, `selected` or `all`; a hidden label is still the accessible name |
| `extended` | a wide rail, with the text next to the icon |
| `leading`, `trailing` | a widget before or after the destinations |
| `groupAlignment` | `-1` top, `0` center, `1` bottom |
| `NavigationRailDestination(href:)` | a destination that is a link, without state |

`NavigationRailTheme`, or `ThemeData(navigationRailTheme:)`, sets the defaults for the rails it contains.

## Link

:::bench cat-link
:::

Turns any widget into a link without adding anything around it; `current: true` marks the link to the current page. Buttons and `ListTile` accept `href` directly.

A `Column` centers its children and each link is as wide as its text. For a list of start-aligned links, use `CrossAxisAlignment.stretch`:

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
