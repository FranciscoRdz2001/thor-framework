# Content

Widgets for displaying information: text, icons, images, cards, lists, tables and carousels.

## Text

:::flutter Flutter: `Text`, `TextStyle` · Thor: the same

:::bench cat-text
:::

`TextStyle` sets size, weight, color and line height; `maxLines` and `overflow` clip the text as in Flutter: without `overflow` the text is cut with no dots (`TextOverflow.clip`); ask for `TextOverflow.ellipsis` to draw them. A `DefaultTextStyle(maxLines:, overflow:, softWrap:)` gives them as defaults to the `Text` widgets below. Wrap a title in `Semantics(headingLevel: 2)` so screen readers and search engines read it as a heading.

### RichText and SelectableText

:::bench cat-rich-text
:::

`RichText(text: TextSpan(…))` is `Text.rich` under Flutter's name. `SelectableText` can be selected even inside a card or a button.

## Icon

:::flutter Flutter: `Icon(Icons.search)` · Thor: the same code

:::bench cat-icon
:::

`Icons` includes Flutter's names as SVG icons. The page includes only the icons it renders, once each.

| Parameter | What it does |
| --- | --- |
| `size` | the side of the box; 24 by default |
| `color` | the color; without it, the color of the surrounding text, like Flutter's `IconTheme` |
| `semanticLabel` | the text a screen reader announces; without it, the icon is decorative |

### Variants

:::bench bench-icons
:::

Each name has its `_outlined`, `_rounded` and `_sharp` variants, as in Flutter. The icons Flutter mirrors (`arrow_back`, `arrow_forward`, `send`, `chevron_left`) flip automatically in right-to-left languages.

### Names and custom icons

:::example cat-icons
:::

All of Flutter's `Icons` names are there, about 8,700 with their variants, and a name that doesn't exist is a compile error. The shapes are those of [Flutter's catalog](https://api.flutter.dev/flutter/material/Icons-class.html), licensed under Apache-2.0.

An icon that isn't on the list, or a brand logo (`Icons.paypal`, `Icons.apple`), is declared with `IconData.svg`:

```dart
const bolt = IconData.svg('my-bolt', '<path d="M13 2 3 14h9l-1 8 10-12h-9z"/>');
```

## Images and HTML

`Image` shows an image from the app or from a URL; `HtmlWidget`, HTML that arrives as data.

### Image.asset

:::bench cat-image
:::

An image from the app's `web/` folder; `Image.network` takes a URL. Set `width` and `height` so the page doesn't shift when it loads; images in `web/images/` are also published in optimized sizes.

While the image loads, or if it fails, another widget is shown:

:::bench cat-image-builders
:::

`errorBuilder` and `loadingBuilder` have Flutter's signature. The server renders the replacement next to the image and the browser shows it if the image doesn't load.

> **Difference from Flutter:** `error` is an `ImageLoadError` with the URL, without a `stackTrace`, and `loadingBuilder` is called only once, without progress. Without JavaScript, the browser shows its broken image with the alt text.

### HtmlWidget

:::bench cat-html-widget
:::

Shows HTML you didn't write, such as a product description or a comment, as safe content. The server cleans it with an allowlist and renders it with the theme's typography; `sanitizeHtml(html, policy:)` does the same cleaning and returns a `String`.

| `HtmlPolicy` | What it does |
| --- | --- |
| `tags`, `attributes` | the allowlist: text, lists, links, images and tables by default |
| `schemes` | the schemes allowed in links: `http`, `https`, `mailto`, `tel` |
| `linkTarget`, `nofollow` | the target and `rel` of every link |
| `allowDataImages` | allows embedded images, never SVG |
| `maxLength`, `maxTags`, `maxDepth` | limits against hostile input |

> **Caution:** Scripts, styles, frames, event handlers and `javascript:` links are always removed. If you allow `class`, each class gets the `user-` prefix so the content can't use the app's classes.

## Surfaces

`Card` groups related content and `Divider` separates it.

### Card

:::bench cat-card
:::

A surface with a shadow that groups related content.

### Divider

:::bench cat-divider
:::

A horizontal line. `indent` and `endIndent` keep it away from the edges.

## Rows

`ListTile` is a list row and `ExpansionTile`, a row that expands.

### ListTile

:::bench cat-list-tile
:::

A row with `leading`, `title`, `subtitle` and `trailing`. With `href` it's a link and with `onTap`, a button; `selected` marks the current row.

`minTileHeight` sets the row's minimum height (instead of 48 or 56) and `minVerticalPadding`, the least space above and below; `ListTileThemeData` gives them to every row.

### ExpansionTile

:::bench cat-expansion-tile
:::

A row that expands to show more content. Several with the same `name`, or inside an `ExpansionPanelList(name:)`, form an accordion: opening one closes the others.

`controlAffinity: ListTileControlAffinity.leading` puts the arrow before the title; `showTrailingIcon: false` removes it (a `trailing:` too, as in Flutter) and `trailing:` puts another widget in its place. `dense` and `minTileHeight` shorten the header. `iconSize`, `iconTurns` and `collapsedIconTurns` change the arrow's size and how far it turns open and closed (a dense header that turns −90° closed: `iconSize: 13, iconTurns: 0, collapsedIconTurns: -0.25`). To make another piece change while the section is open, put `.when(open: …)` in its style (`Text('12', style: TextStyle(color: gray).when(open: blue))`).

## Chips and badges

Small labels that accompany other content.

### CircleAvatar and Badge

:::bench cat-avatar-badge
:::

`CircleAvatar` shows initials, an icon or a photo (`backgroundImage`). `Badge` adds a number or a dot in the corner of its child, and `Badge.count` shows `999+` from `maxCount` on.

| `Badge` parameter | What it does |
| --- | --- |
| `backgroundColor`, `textColor` | the colors; by default, the theme's error colors |
| `smallSize`, `largeSize` | the size of the dot and the height with a number |
| `alignment`, `offset` | the corner and the offset |
| `isLabelVisible` | `false` leaves only the child |

### Chip and ActionChip

:::bench cat-chip
:::

`Chip` is a label and `ActionChip`, a label you tap. `Chip(onDeleted:)` adds an X; selectable chips are in [Selection](components-selection.md#inputchip).

## Tooltip

:::bench cat-tooltip
:::

`Tooltip(message:, child:)` shows a bubble when the pointer hovers or the child gets keyboard focus, and screen readers read it as the child's description. It can be the root of a `Watch` state: the state mark sits on its box and the other states are its siblings. The bubble's id is the same in every state of a `Watch` (counted by position), so switching state doesn't rewrite it.

> **Difference from Flutter:** On a touch screen it doesn't appear on long press and it doesn't close with Esc. If the text matters, show it on the page.

## Tables and carousels

`DataTable` arranges data in rows and columns; `CarouselView` shows it one item after another.

### DataTable

:::bench cat-data-table
:::

A table with headers. `numeric` right-aligns a column and `sortColumnIndex` shows the sort arrow; `DataColumn(onSort:)` sorts from the ViewModel and `DataRow(onSelectChanged:)` adds a checkbox per row.

### CarouselView

:::example carousel
:::

A carousel that slides with a finger, the wheel, the trackpad or the keyboard, without JavaScript. Arrows and indicators are configured with parameters.

| Parameter | What it does |
| --- | --- |
| `showArrows`, `arrowStyle`, `arrowPosition` | the arrows: visible by default, inside or outside |
| `showIndicators`, `indicatorStyle` | one dot per item; with a larger `activeSize`, the active one is a pill |
| `layout` | items per view and the spacing between them, with variants per size class |
| `previousLabel`, `nextLabel`, `slideLabel` | the accessible names, so you can translate them |
| `autoPlay` | advances on its own; pauses on pointer or focus and doesn't run with reduced motion |
