# Selección

Controles para activar, desactivar o elegir entre opciones. Avisan al ViewModel (`ThorState`) con `onChanged`, o con `onSelected` en los chips; sin ese callback quedan deshabilitados.

## Checkbox

:::bench cat-checkbox
:::

Una casilla. Con `tristate: true` acepta `null`, el estado mixto.

| Parámetro | Qué hace |
| --- | --- |
| `value` | marcada, sin marcar o `null` (mixta, con `tristate`) |
| `onChanged` | el método que recibe el valor nuevo; `null` la deshabilita |
| `activeColor` | el color cuando está marcada |
| `semanticLabel` | su nombre para los lectores de pantalla |
| `name` | el nombre con el que se envía en un `Form` |

## Switch

:::bench cat-switch
:::

Un interruptor de encendido y apagado. Su `onChanged` recibe un `bool`.

## RadioGroup y Radio

:::flutter Flutter: `RadioGroup` · Thor: el mismo, sobre radios nativos

:::bench cat-radio
:::

`RadioGroup` guarda el valor elegido y avisa del cambio; cada `Radio` declara solo su `value`. También agrupa `RadioListTile`.

| Parámetro de `RadioGroup` | Qué hace |
| --- | --- |
| `groupValue` | el valor elegido: se marca el `Radio` con ese `value` |
| `onChanged` | el método que recibe el valor; `null` deshabilita el grupo |
| `name` | el nombre con el que se envía en un `Form` |

Sin JavaScript funciona igual: el navegador mantiene un radio marcado, las flechas los recorren y un `Form` envía el valor. Un `enum` se envía como su `name`.

> **Nota:** `Radio(groupValue:, onChanged:)` y `RadioListTile(groupValue:, onChanged:)` están `@Deprecated`, como en Flutter: usa `RadioGroup`.

## SegmentedButton

:::flutter Flutter: `SegmentedButton` · Thor: el mismo, sobre radios o casillas nativos

:::bench cat-segmented-button
:::

Una fila de segmentos para elegir un valor, o varios con `multiSelectionEnabled: true`. `onSelectionChanged` recibe el conjunto nuevo: un método con un parámetro `Set<T>`.

| Parámetro | Qué hace |
| --- | --- |
| `segments` | los `ButtonSegment(value:, label:, icon:, tooltip:, enabled:)` |
| `selected` | el conjunto elegido al renderizar la página |
| `onSelectionChanged` | el método que recibe el `Set<T>`; `null` lo deshabilita |
| `multiSelectionEnabled` | permite elegir varios segmentos |
| `showSelectedIcon`, `selectedIcon` | la marca del segmento elegido |
| `style`, `direction`, `expandedInsets` | el aspecto, la orientación y el ancho completo |

### Selector en píldora

Con `StadiumBorder` en `style.shape`, el grupo y el segmento elegido quedan redondos. `groupPadding` y `groupColor` forman el riel; `selectedStyle` pinta el segmento elegido.

:::example segmented-pill
:::

> **Diferencia con Flutter:** Sin `multiSelectionEnabled`, un segmento elegido no se puede desmarcar: `emptySelectionAllowed` solo permite empezar sin elección.

## Chips de selección

`ChoiceChip` elige una opción y `FilterChip`, varias.

### ChoiceChip

:::bench cat-choice-chip
:::

Chips para elegir una sola opción. `selected` se lee del ViewModel con `Watch`, y `withArg` indica al método qué chip se pulsó.

### FilterChip

:::bench cat-filter-chip
:::

Chips para elegir varias opciones a la vez; el elegido muestra una marca.

| Parámetro | Qué hace |
| --- | --- |
| `selected`, `onSelected` | si está elegido y el método que recibe el cambio |
| `selectedColor`, `backgroundColor` | el fondo elegido y sin elegir |
| `showCheckmark` | muestra u oculta la marca |
| `shape`, `side`, `labelStyle`, `padding` | forma, borde, texto y relleno |

## Chips de entrada y enlaces

`InputChip` muestra un valor que se puede quitar, y cualquier chip puede ser un enlace.

### InputChip

:::bench cat-input-chip
:::

Un valor que el usuario ya eligió o escribió, con una equis para quitarlo. `onDeleted` recibe un método del ViewModel y `deleteButtonTooltipMessage` cambia el nombre accesible de la equis.

Con `onPressed` se pulsa y con `onSelected` se alterna, como en Flutter; sin ninguno de los dos es una etiqueta como `Chip`.

### Chips como enlaces

:::bench cat-link-chip
:::

`Chip`, `InputChip`, `FilterChip`, `ChoiceChip` y `ActionChip` aceptan `href`: el chip es un enlace y funciona sin JavaScript, útil para filtros que cambian la URL. En un `InputChip` o un `Chip`, `deleteHref` hace de la equis otro enlace, a la página sin ese filtro.

> **Diferencia con Flutter:** `href` y `deleteHref` no existen en Flutter. La equis es un botón junto al chip, no dentro de él.

## CheckboxListTile, SwitchListTile y RadioListTile

:::bench cat-list-tiles
:::

Un control con su título en una fila que responde entera al toque. `subtitle` agrega una segunda línea y `controlAffinity` coloca el control a la izquierda o a la derecha.
