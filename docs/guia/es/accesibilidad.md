# Accesibilidad

Thor genera controles nativos con teclado y foco ya resueltos; tú das
nombres, títulos y contraste con `Semantics` y el tema.

:::flutter Flutter: `Semantics`, `ExcludeSemantics` · Thor: los mismos, que eligen el elemento HTML

## Lo que Thor resuelve

Cada widget llega al navegador como el control nativo equivalente, con su
manejo de teclado. El orden de Tab es el del árbol de widgets.

| Widget | Resultado | Teclado |
|---|---|---|
| `FilledButton`, `IconButton`, `Link` | botón nativo, o enlace con `href:` | Tab, Enter y Espacio |
| `TextField`, `Checkbox`, `Switch`, `Slider` | campo nativo | las teclas del control |
| `AlertDialog`, `Drawer`, `ModalBottomSheet` | diálogo modal | el foco queda dentro; Esc cierra y el foco vuelve al botón |
| `PopupMenuButton`, `MenuAnchor`, `Popover` | botón y panel | Enter abre, Esc cierra; flechas, Inicio y Fin |
| `ExpansionTile` | sección desplegable nativa | Enter y Espacio |
| `TabBar` | grupo de pestañas | flechas, Inicio y Fin; una sola parada de Tab |

## `Semantics`

`Semantics` no dibuja nada: dice qué es su hijo, y Thor lo escribe como el
elemento o el atributo que lee un lector de pantalla.

:::bench bench-semantics
:::

:::flutter
@flutter
```dart no-check
Semantics(
  header: true,
  child: Text('Orders', style: Theme.of(context).textTheme.headlineMedium),
)
```
@thor
```dart
Semantics(
  headingLevel: 2,      // web: <h2>, as in Flutter's headingLevel
  child: const Text('Orders'),
)
```
:::

Los títulos permiten saltar por la página: un `h1` por página y los demás en
orden. `headingLevel` solo da el nivel; el tamaño lo pone el `TextStyle`.

> **Diferencia con Flutter:** `Semantics(header: true)` marca un título sin
> nivel; usa `headingLevel` para el nivel real. `obscured`,
> `explicitChildNodes` y `sortKey` se aceptan sin efecto, y `MergeSemantics`
> no hace falta: el lector de pantalla ya lee el elemento entero. No existe
> `SemanticsService.announce`: usa `liveRegion` o `toast()`.

### Nombres, títulos y regiones

```dart
Column(children: [
  // A name for what has no text
  Semantics(
    label: 'Order shipped',
    image: true,
    child: const Icon(Icons.local_shipping),
  ),
  // Announced when its text changes, without moving the focus
  Semantics(liveRegion: true, child: Watch(cart.summary)),
  // The page's landmarks
  Semantics(role: SemanticsRole.navigation, child: const Nav()),
  Semantics(role: SemanticsRole.main, child: const Content()),
  // Decoration a screen reader should skip
  const ExcludeSemantics(child: Text('★ ★ ★')),
])
```

| Necesitas | Escribe |
|---|---|
| un título | `Semantics(headingLevel: 2, …)` |
| un nombre que no se ve | `Semantics(label: '…', …)`; `tooltip:` en un `IconButton` |
| un aviso que se lee al cambiar | `Semantics(liveRegion: true, …)` |
| una región de la página | `Semantics(role: SemanticsRole.navigation, …)`, también `main`, `complementary` (`<aside>`) y `region` (`<section>`) |
| una lista de pasos, o con viñetas | `role: SemanticsRole.orderedList` (`<ol>`) o `list` (`<ul>`) con `listItem`; la sangría y el marcador, `StyleProps(listStyleType:, padding:)` |
| texto importante o con énfasis | `role: SemanticsRole.strong` (`<strong>`), `emphasis` (`<em>`) |
| una figura con pie | `role: SemanticsRole.figure` y `figureCaption`; un icono o gráfico con nombre, `role: SemanticsRole.image` (`role="img"`) |
| el elemento actual de un conjunto | `Semantics(current: SemanticsCurrent.page, …)` (`aria-current`), también `step`, `location` y `date` |
| un `data-*` o un `aria-*` sin elemento extra | `ElementAttributes(HtmlAttributes(data: {'track': 'cta'}), child: …)` |
| ocultar algo decorativo | `ExcludeSemantics`, o `Semantics(hidden: true, …)` |
| un destino de enlace (`#section`) | `Semantics(identifier: 'section', …)` |

### Estados y valores

| Necesitas | Escribe |
|---|---|
| un botón o un interruptor | `Semantics(button: true, …)`, `Semantics(toggled: …, …)` |
| un valor o una ayuda | `Semantics(value: '50%', hint: '…', …)` |
| un estado | `checked:`, `expanded:`, `readOnly:`, `selected:` |
| un control sin etiqueta propia | `textField: true`, `slider: true`, `container: true` |
| que solo cuente su etiqueta | `Semantics(excludeSemantics: true, label: '…', …)` |
| que lo de atrás no se lea (un modal) | `BlockSemantics(…)` |

## Foco y teclado

`focusColor` del tema colorea el anillo de foco de todo lo que alcanza el
teclado. El anillo aparece al navegar con el teclado, no al hacer clic.

```dart
final light = ThemeData(
  colorScheme: const ColorScheme.light(),
  focusColor: const Color(0xFF3F3AB0),
);
```

Un `GestureDetector(onTap:)` sobre algo que no es un control recibe el rol de
botón, foco y Enter o Espacio (`semanticButton: true`, por defecto). Aun así,
prefiere un `TextButton` o un `Link`: traen estado, foco y nombre.

> **Importante:** `semanticButton: false` quita el rol y el foco. Úsalo solo
> si el hijo ya es un control.

### Atajos de teclado

`Shortcuts`, `Actions` e `Intent` de Flutter, con un método del view model
como acción:

```dart
class SaveIntent extends Intent {
  const SaveIntent();
}

Shortcuts(
  shortcuts: const {
    SingleActivator(LogicalKeyboardKey.keyS, meta: true): SaveIntent(),
  },
  child: Actions(
    actions: {SaveIntent: CallbackAction<SaveIntent>(onInvoke: editor.save)},
    child: Focus(child: form),
  ),
)
// in EditorViewModel: void save(SaveIntent intent) { … }
```

Gana el `Actions` más cercano al foco. Un campo de texto se queda con sus
letras y flechas; ⌘S sí llega al atajo. Un intent no lleva campos al
navegador: una clase por significado. `CallbackShortcuts(bindings: {activador:
editor.save})` es la forma corta.

Un atajo que toma una tecla que el navegador usa con la selección (⌘C) puede
hacerse a un lado mientras la página tiene texto seleccionado:
`SingleActivator(LogicalKeyboardKey.keyC, meta: true, skipWithTextSelection:
true)`. Flutter no tiene esta opción; su selección vive en los widgets, y la
del navegador es una sola para toda la página.

Un campo de texto se queda con sus flechas, Inicio y Fin. Para que una paleta mueva su resaltado con ↑/↓ mientras el cursor sigue en el campo, el atajo lo pide con `overrideTextInput: true`
(`SingleActivator(LogicalKeyboardKey.arrowDown, overrideTextInput: true)`): solo ese atajo gana al campo, y el cursor no se mueve. Lo respetan `CallbackShortcuts` y `Shortcuts`, no `Focus(onKeyEvent:)` ni `onCharacter`. Flutter no lo necesita: allí el campo maneja esas teclas con sus propias `Actions`.

`Focus(onKeyEvent: grid.onKey)` recibe cada tecla pulsada adentro, con la
firma de Flutter (`KeyEventResult onKey(FocusNode node, KeyEvent event)`):
`KeyEventResult.handled` la detiene.

## Contraste y movimiento

Los colores del tema vienen en pares (`primary` con `onPrimary`, `surface`
con `onSurface`): úsalos juntos y el texto cumple el contraste. Con colores
propios, el texto necesita 4.5:1 sobre su fondo, y los íconos y el anillo de
foco, 3:1, en claro y en oscuro.

```dart
Text(
  'Overdue',
  style: TextStyle(color: ThemeColor.onSurface),   // paired with ThemeColor.surface
)
```

`expectThemeContrast` de `thor_test` mide cada par del tema y nombra los que
fallan:

```dart
test('the app themes read at AA', () {
  expectThemeContrast(appTheme);
  expectThemeContrast(appDarkTheme);
});
```

El usuario que pide más contraste en su sistema recibe `highContrastTheme:` (y
`highContrastDarkTheme:`); `ColorScheme.highContrastLight()` y
`highContrastDark()` son el punto de partida.

```dart
ThorApp(
  theme: appTheme,
  highContrastTheme: ThemeData(colorScheme: const ColorScheme.highContrastLight()),
  child: const Text('Home'),
)
```

Con colores forzados (alto contraste de Windows), el sistema reemplaza los
colores y quita las sombras; Thor conserva un subrayado en la pestaña elegida,
un borde en los menús y el aspecto nativo de `Checkbox`, `Radio` y `Switch`.
Con movimiento reducido, las animaciones terminan al instante y el carrusel no
avanza solo ([Animaciones](animaciones.md#movimiento-reducido)).

## Cómo probarlo

:::steps
### Recorre la página con el teclado
Tab, Mayús + Tab, Enter, Espacio y Esc. Cada control se alcanza, el foco se
ve y un diálogo devuelve el foco al botón que lo abrió.

### Amplía al 200 %
Con el zoom del navegador al 200 % y 390 px de ancho, nada se corta ni se
sale de la pantalla.

### Prueba con un lector de pantalla
VoiceOver en macOS o iOS, NVDA en Windows, TalkBack en Android. Cada control
dice qué es y cómo se llama, y los títulos permiten saltar de sección.

### Audita con Lighthouse
El panel Accessibility de Chrome DevTools y Lighthouse señalan contraste
insuficiente, nombres que faltan y títulos fuera de orden.
:::

## Siguientes pasos

:::cards
- [Diálogos y menús](dialogos-y-menus.md) — el foco y el teclado de cada overlay
- [Tema y estilos](tema-y-estilos.md) — `ThemeData`, `focusColor` y colores en pares
- [Idiomas](idiomas.md) — idioma y dirección de cada página
:::
