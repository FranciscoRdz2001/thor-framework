# Tema y estilos

Define colores, tipografía y temas de componente una vez en `ThemeData`, y
varía cualquier valor por ancho, estado o modo oscuro con `.when()`.

:::flutter Flutter: `ThemeData`, `ColorScheme`, `TextTheme` · Thor: los mismos, más variantes con `.when()`

## Colores del tema

Los widgets leen el tema con `ThemeColor` o `Theme.of(context)`, sin repetir
ningún color: al cambiar el tema, todo lo que lo lee se actualiza.

:::bench bench-theme-colors
:::

:::flutter
@flutter
```dart no-check
final theme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
  textTheme: textTheme,
);

MaterialApp(theme: theme, darkTheme: darkTheme, home: page);
```
@thor
```dart
final theme = ThemeData(
  colorScheme: const ColorScheme.light(primary: Color(0xFF0F766E)),
  textTheme: TextTheme(),
);

ThorApp(theme: theme, darkTheme: darkTheme, child: page);
```
:::

| Parte de `ThemeData` | Se lee con |
|---|---|
| `colorScheme` | `ThemeColor.primary` o `Theme.of(context).colorScheme.primary` |
| `tokens`, `colorTokens` | el token mismo (`AppColors.band`) o `ThemeColor.token('brand')` |
| `textTheme` | `ThemeText.headlineLarge`, `ThemeText.bodyMedium`… |
| `breakpoints` | cada `.when(medium: …)` y `ResponsiveVisibility` |
| `extensions` | `Theme.of(context).extension<BrandShape>()` |
| `fonts`, `fontFamily` | todo `Text` de la app |
| `scaffoldBackgroundColor` | el `body` de la página y todo `Scaffold` (sin él, `surface`) |
| `scrollbarTheme` | toda barra de desplazamiento: `ScrollbarThemeData(thickness: WidgetStatePropertyAll(6), thumbColor: …)` |

> **Diferencia con Flutter:** `ColorScheme.fromSeed` no existe. Escribe los
> roles que cambian (`ColorScheme.light(primary: …)`); el resto toma los
> valores de Material 3.

### Roles de color

Cada rol del `colorScheme` tiene un valor en el tema claro y otro en el
oscuro. Estos son los que más se usan:

| Rol | Uso |
|---|---|
| `primary` | acciones principales, enlaces y foco |
| `onPrimary` | texto e íconos sobre `primary` |
| `surface` | el fondo de la página |
| `onSurface` | el texto de la página |
| `surfaceContainer` | tarjetas y paneles |
| `error` | errores y acciones destructivas |

La [referencia de la API](../../api/thor_ui.md#estilos) lista el resto de los
roles de `ColorScheme`.

### Colores propios

Declara cada color de tu marca con `ColorToken`: es un `Color` `const` que
lleva su valor claro y su valor oscuro.

```dart
abstract final class AppColors {
  static const band = ColorToken('band',
      light: Color(0xFFF7F6F2), dark: Color(0xFF22252A));
  static const muted = ColorToken('muted',
      light: Color(0xFF697077), dark: Color(0xFFA6ACB3));
  static const values = [band, muted];
}

final light = ThemeData(tokens: AppColors.values);
final dark = ThemeData(
    colorScheme: const ColorScheme.dark(), tokens: AppColors.values);

Container(color: AppColors.band)       // follows the theme
```

Dos tokens con el mismo nombre son el error
[THOR-R021](../../errores/THOR-R021.md). Para escalas de 50 a 950 existe
`ColorScale`, y `Colors.blue.shade700` funciona como en Flutter.

## Modo oscuro

Con `darkTheme` y `themeMode: ThemeMode.system` (el valor por defecto), la
página sigue la preferencia del sistema. `ThemeToggle` agrega el control para
cambiarlo:

```dart
ThemeToggle(light: Icon(Icons.light_mode), dark: Icon(Icons.dark_mode))
```

:::example theme-follows-switch
:::

La elección del usuario se guarda en el navegador y se aplica antes de mostrar
la página: al recargar no hay parpadeo. Requiere navegadores de 2024 (Chrome
123, Safari 17.5, Firefox 120).

> **Importante:** Un `Color` literal es el mismo en los dos temas. Para que un
> color siga al modo oscuro, léelo del tema (`ThemeColor.primary`) o declara
> un `ColorToken`.

### Leer el tema en código

`Theme.of(context).colorScheme` devuelve colores que siguen al modo oscuro,
también con `withValues(alpha:)`.

```dart
final scheme = Theme.of(context).colorScheme;
Container(
  color: scheme.primary.withValues(alpha: 0.15),
  child: Text('x', style: TextStyle(color: scheme.onSurface)),
)
```

| Expresión | Resultado |
|---|---|
| `scheme.primary` en un color, borde o texto | sigue al modo oscuro |
| `scheme.primary.withValues(alpha: .15)` | sigue al modo oscuro |
| `.value`, `.red`, `.opacity`, `Color.alphaBlend` (también en `Color.css` y colores con `.when()`; `hasChannels` lo dice) | error [THOR-R023](../../errores/THOR-R023.md) |
| `scheme.primary.fallback!.value` | el color de un solo modo |
| `scheme.brightness` | el del tema |

> **Diferencia con Flutter:** El servidor renderiza la página una vez y no
> conoce el modo del usuario, así que `Theme.of` no devuelve un color fijo.
> Para elegir entre dos colores usa `.when(dark: …)`.

## Tipografía

Un `TextStyle` del `TextTheme` conserva su rol: si cambias un valor
(`ThemeText.labelLarge.copyWith(color: ThemeColor.primary)`), el resto sigue
al tema.

:::bench bench-text-style
:::

Para que un rol crezca en pantallas anchas, da una variante al `TextTheme`
entero:

```dart
textTheme: textTheme.when(
  medium: textTheme.copyWith(displayLarge: const TextStyle(fontSize: 60)),
),
```

Para un tamaño que crece con la ventana, `TextStyle` acepta además un
`Length` ([Unidades](estilos-avanzados.md#unidades)):

```dart
const TextStyle(
  fontSize: 40,                                   // the number Dart reads
  fontSizeLength: Length.clamp(Length.px(40), Length.vw(5), Length.px(72)),
  letterSpacingLength: Length.em(-0.02),
)
```

### Fuentes

Cada `FontFace` es un archivo de fuente de la app: el equivalente de la
sección `fonts:` del `pubspec.yaml` de Flutter.

```dart
fonts: [
  // A variable font: every weight in one file.
  FontFace('Inter', url: '/fonts/inter.woff2',
      weight: FontWeight.w100, maxWeight: FontWeight.w900, preload: true),
  // One file per weight or style.
  FontFace('Mono', url: '/fonts/mono-400.woff2'),
  FontFace('Mono', url: '/fonts/mono-500.woff2', weight: FontWeight.w500),
],
```

| Opción | Efecto |
|---|---|
| `display:` | qué se ve mientras carga; `FontDisplay.swap` (por defecto) nunca oculta el texto |
| `preload: true` | descarga el archivo antes; úsalo solo en la fuente de la primera pantalla |
| `thor fonts subset` | recorta la fuente a los caracteres que usa la app |
| `thor fonts metrics` | mide un `FontFallback` con las mismas proporciones, para que el texto no salte |

Los archivos van en `web/` de la app. Si vienen de un paquete, el paquete los
declara y [`thor dev`](cli.md) los copia.

## Temas por componente

Lo que se repite en todas las páginas (tarjetas, botones, chips) va una vez en
el `ThemeData`, como en Flutter.

```dart
ThemeData(
  cardTheme: CardThemeData(elevation: 0, shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16), side: BorderSide(color: line))),
  chipTheme: ChipThemeData(shape: StadiumBorder()),
  filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(backgroundColor: WidgetStatePropertyAll(ThemeColor.primary))),
)
```

:::example component-themes
:::

Existen los temas de Flutter para tarjetas, chips, botones, campos, divisores,
diálogos, barras, listas, avisos, menús, pestañas y controles de selección:
`cardTheme`, `chipTheme`, `filledButtonTheme`, `iconButtonTheme`,
`inputDecorationTheme`, `dialogTheme`, `appBarTheme`, `listTileTheme`,
`snackBarTheme`, `tabBarTheme`, `checkboxTheme`, `switchTheme` y los demás.
Gana el parámetro del widget, después el tema y al final el valor por
defecto.

Cada `XThemeData` lleva los campos de Flutter que el navegador puede aplicar;
la documentación de cada clase lista los que faltan. `Theme.provide(data:)`
cambia el tema de un subárbol, y un `ThemeExtension` guarda valores propios de
tu marca.

## Variantes con `.when()`

Lo que cambia por ancho, estado o tema es un valor con `.when()`. La variante
solo lleva lo que cambia; el resto se hereda del valor base.

```dart
Container(padding: const EdgeInsets.all(24).when(medium: EdgeInsets.all(32)))

BoxDecoration(color: ThemeColor.surface.when(hover: ThemeColor.surfaceContainer))

Text('Pricing', style: ThemeText.titleMedium.when(medium: ThemeText.titleLarge))

Grid(layout: GridLayout(columns: 1, gap: 16).when(expanded: GridLayout(columns: 3, gap: 32)))
```

:::example variants
:::

| Variante | Se aplica |
|---|---|
| `medium`, `expanded`, `large`, `extraLarge` | desde 600, 840, 1200 y 1600 px de ancho de ventana (las clases de tamaño de Material 3) |
| `dark` | con el tema oscuro |
| `hover`, `focused`, `pressed` | al pasar el puntero, con foco de teclado, mientras se presiona |
| `open` | con el `<details>` más cercano abierto (un `ExpansionTile`: su cabecera y su contenido); uno anidado decide por lo suyo |
| `groupHover` | al pasar el puntero sobre el `HoverGroup` más cercano |
| `groupHovers: {'card': …}` | lo mismo, para el `HoverGroup(name: 'card')` más cercano |
| `container: {400: …}` | cuando el `LayoutScope` más cercano mide al menos 400 px |

Aceptan `.when()`: `EdgeInsets`, `BorderRadius`, `BoxConstraints`,
`BoxDecoration`, `TextStyle`, `Color`, `TextTheme`, `GridLayout`,
`FlexLayout`, `CarouselLayout` y `StyleProps`. Un número suelto (`double`,
`int`) no admite variantes: va en un `StyleProps` dentro de `Styled`
([Estilos avanzados](estilos-avanzados.md)). Los anchos se cambian con
`ThemeData(breakpoints: Breakpoints(medium: 640))`, y una variante admite las
suyas: `color.when(hover: hover.when(medium: other))`.

La aritmética (`padding * 2`, `padding + extra`) y `copyWith` sobre uno de estos
valores se aplican a la base y a cada variante, así que las variantes se conservan.

> **Nota:** `hover` y `groupHover` solo se aplican con un puntero que puede
> flotar (mouse, trackpad). En un teléfono, repite el efecto en `pressed:`.

### Hover en grupo

`HoverGroup` hace que sus descendientes reaccionen al pasar el puntero sobre
el grupo entero, no sobre cada uno.

```dart
HoverGroup(
  child: Card(
    child: Column(children: [
      Styled(
        style: StyleProps().when(groupHover: StyleProps(scale: 1.05)),
        duration: const Duration(milliseconds: 200),
        child: Image.network(photo),
      ),
      Text(name),
    ]),
  ),
)
```

:::example hover-group
:::

Con grupos anidados, `HoverGroup(name: 'card')` nombra cada uno y
`groupHovers: {'card': …}` elige a cuál responde la variante.

### Según el ancho del contenedor

Un breakpoint mide la ventana; `container:` mide la caja del `LayoutScope` más
cercano. La misma tarjeta sirve en una columna angosta y en una ancha: es el
`LayoutBuilder` de Flutter, sin código en el navegador.

:::example responsive-card
:::

## Mostrar u ocultar

`ResponsiveVisibility` muestra u oculta un widget según la clase de tamaño, y
`ResponsiveLayout` elige uno de tres.

```dart
ResponsiveVisibility(hiddenFrom: WindowSizeClass.medium, child: MobileMenu())
ResponsiveVisibility(visibleFrom: WindowSizeClass.medium, child: DesktopMenu())
ResponsiveLayout(mobile: Compact(), tablet: Medium(), desktop: Wide())
```

## Radio y espacio

Un valor que cambia en el navegador, como un campo de estado que mueve un
`Slider`, se escribe como `BoundLength`: el campo seguido de `.px`.

:::bench bench-card-style
:::

Los widgets lo reciben en sus variantes `Length`: `EdgeInsetsGeometry.allLength`
(también `symmetricLength` y `onlyLength`), `BorderRadius.circularLength`,
`SizedBox(widthLength:)` y `Positioned(leftLength:)`.

```dart
Container(
  padding: EdgeInsetsGeometry.allLength(card.padding.px),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circularLength(card.radius.px),
  ),
)

SizedBox(widthLength: card.width.px, child: content)
Positioned(leftLength: drag.x.px, top: 0, child: handle)
```

> **Importante:** Un `EdgeInsetsGeometry` no es un `EdgeInsets`: no tiene
> `left` ni `horizontal`. Los parámetros que piden `EdgeInsets`
> (`TextField.contentPadding`, `Dialog.insetPadding`) no aceptan un `Length`.

`EdgeInsetsDirectional(start:, end:)`, `BorderRadiusDirectional` y
`AlignmentDirectional` siguen la dirección del texto, como en Flutter.

## Siguientes pasos

:::cards
- [Estilos avanzados](estilos-avanzados.md) — `StyleProps`, unidades y HTML sin widgets
- [Animaciones](animaciones.md) — transiciones, curvas y movimiento reducido
- [Layout](layout.md) — `Row`, `Column`, `Grid` y el espacio
:::
