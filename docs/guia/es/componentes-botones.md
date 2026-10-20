# Botones

Los botones de Material con la API de Flutter: `onPressed` recibe un método del ViewModel (`ThorState`) y, sin `onPressed`, el botón queda deshabilitado.

## FilledButton

:::flutter Flutter: `FilledButton` · Thor: el mismo, y `href:` lo vuelve enlace

:::bench cat-filled-button
:::

La acción principal de una pantalla. `FilledButton.tonal` tiene menos énfasis.

| Parámetro | Qué hace |
| --- | --- |
| `onPressed` | el método que corre al pulsarlo; `null` lo deshabilita |
| `child` | un `Text`, o un `Row` con ícono y texto |
| `style` | colores, tamaño y forma ([ButtonStyle](#buttonstyle)) |
| `href` | lo convierte en un enlace a otra página |
| `buttonType` | `ButtonType.submit` envía el `Form` que lo contiene; `ButtonType.button` no envía nada |

## ElevatedButton

:::bench cat-elevated-button
:::

Un botón elevado sobre la superficie, con un énfasis entre `FilledButton` y `OutlinedButton`. Acepta los mismos parámetros que `FilledButton`.

## Botones con ícono

:::bench cat-icon-labels
:::

Los constructores `.icon` reciben `icon` y `label` y siguen siendo un solo botón. `.tonal` y `.tonalIcon` existen solo en `FilledButton`.

> **Nota:** El espacio junto al ícono es el de Material 3 y se invierte en los idiomas de derecha a izquierda.

## OutlinedButton

:::bench cat-outlined-button
:::

Una acción secundaria, con borde y sin relleno. Con `href` es un enlace y navega sin estado ni JavaScript.

## TextButton

:::bench cat-text-button
:::

La acción de menor énfasis, para diálogos, tarjetas y barras. Acepta los mismos parámetros que `FilledButton`.

## IconButton

:::bench cat-icon-button
:::

Un botón de 48 × 48 con un ícono. `tooltip` es su nombre accesible y el texto que aparece al pasar el puntero.

| Parámetro | Qué hace |
| --- | --- |
| `icon` | el `Icon` que muestra |
| `tooltip` | el nombre accesible y la burbuja |
| `href` | lo convierte en enlace; requiere `tooltip` |
| `color`, `iconSize` | color y tamaño del ícono |
| `isSelected`, `selectedIcon` | un botón que alterna, con su ícono elegido |
| `visualDensity`, `padding`, `constraints` | el tamaño de la caja |

> **Importante:** Un ícono es decorativo: un `IconButton` sin `tooltip` se anuncia solo como «botón». El analizador lo señala con `icon_button_without_name`.

### Variantes

:::bench cat-icon-button-variants
:::

`IconButton.filled`, `.filledTonal` y `.outlined` son las variantes de Material 3. Los nombres de los íconos están en [Contenido](componentes-contenido.md#icon).

## FloatingActionButton

:::bench cat-fab
:::

La acción principal de la pantalla. Dentro de `Scaffold(floatingActionButton:)` queda fijo en la esquina.

| Parámetro | Qué hace |
| --- | --- |
| `child` | el ícono; con `FloatingActionButton.extended`, `icon` y `label` |
| `tooltip` | el nombre accesible de un botón con solo ícono |
| `backgroundColor`, `foregroundColor` | reemplazan los colores del tema |
| `href` | lo convierte en enlace; requiere `tooltip` |

> **Diferencia con Flutter:** Un `label` más ancho que la pantalla ocupa varias líneas en lugar de desbordarse.

## ButtonStyle

:::bench cat-button-style
:::

Todos los botones aceptan `style`. `FilledButton.styleFrom`, `OutlinedButton.styleFrom` y `TextButton.styleFrom` lo construyen con valores simples, como en Flutter; `ButtonStyle(animationDuration:)` anima el cambio entre estados.

| Parámetro de `styleFrom` | Qué cambia |
| --- | --- |
| `backgroundColor`, `foregroundColor` | fondo y texto |
| `overlayColor` | el fondo al pasar el puntero |
| `padding`, `minimumSize` | el tamaño |
| `shape`, `side` | la forma (`RoundedRectangleBorder`, `StadiumBorder`, `CircleBorder`) y el borde |
| `textStyle` | la tipografía |
| `disabledBackgroundColor` | el fondo sin `onPressed` |

### Estilo por estado

Los campos de `ButtonStyle` son `WidgetStateProperty`, como en Flutter: un valor puede depender de `hovered`, `focused`, `pressed`, `selected` o `disabled`. El servidor compila cada estado; el navegador no calcula nada.

```dart
FilledButton(
  onPressed: save,
  style: ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return Colors.grey;
      if (states.contains(WidgetState.hovered)) return Colors.teal;
      return null; // the variant's color
    }),
  ),
  child: const Text('Save'),
)
```

> **Diferencia con Flutter:** Solo `backgroundColor`, `foregroundColor`, `side` y `overlayColor` cambian por estado. Un valor para una combinación de estados (`hovered` y `focused` a la vez) se resuelve con cada estado por separado.

`disabled` vale para un botón sin `onPressed` (`disabled`) y para uno con `aria-disabled="true"`, que sigue enfocable: los dos se ven deshabilitados y ninguno recibe el hover.
