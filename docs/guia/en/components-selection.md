# Selection

Controls to turn something on or off, or to choose between options. They notify the ViewModel (`ThorState`) with `onChanged`, or with `onSelected` on chips; without that callback they are disabled.

## Checkbox

:::bench cat-checkbox
:::

A checkbox. With `tristate: true` it accepts `null`, the mixed state.

| Parameter | What it does |
| --- | --- |
| `value` | checked, unchecked or `null` (mixed, with `tristate`) |
| `onChanged` | the method that receives the new value; `null` disables it |
| `activeColor` | the color when it's checked |
| `semanticLabel` | its name for screen readers |
| `name` | the name it's submitted under in a `Form` |

## Switch

:::bench cat-switch
:::

An on/off switch. Its `onChanged` receives a `bool`.

## RadioGroup and Radio

:::flutter Flutter: `RadioGroup` · Thor: the same, on top of native radios

:::bench cat-radio
:::

`RadioGroup` holds the selected value and reports changes; each `Radio` declares only its `value`. It also groups `RadioListTile`.

| `RadioGroup` parameter | What it does |
| --- | --- |
| `groupValue` | the selected value: the `Radio` with that `value` is checked |
| `onChanged` | the method that receives the value; `null` disables the group |
| `name` | the name it's submitted under in a `Form` |

It works the same without JavaScript: the browser keeps one radio checked, the arrow keys move through them and a `Form` submits the value. An `enum` is submitted as its `name`.

> **Note:** `Radio(groupValue:, onChanged:)` and `RadioListTile(groupValue:, onChanged:)` are `@Deprecated`, as in Flutter: use `RadioGroup`.

## SegmentedButton

:::flutter Flutter: `SegmentedButton` · Thor: the same, on top of native radios or checkboxes

:::bench cat-segmented-button
:::

A row of segments to choose one value, or several with `multiSelectionEnabled: true`. `onSelectionChanged` receives the new set: a method with a `Set<T>` parameter.

| Parameter | What it does |
| --- | --- |
| `segments` | the `ButtonSegment(value:, label:, icon:, tooltip:, enabled:)` |
| `selected` | the set selected when the page is rendered |
| `onSelectionChanged` | the method that receives the `Set<T>`; `null` disables it |
| `multiSelectionEnabled` | allows selecting several segments |
| `showSelectedIcon`, `selectedIcon` | the mark on the selected segment |
| `style`, `direction`, `expandedInsets` | the look, the orientation and full width |

### Pill toggle

With `StadiumBorder` in `style.shape`, the group and the selected segment are fully rounded. `groupPadding` and `groupColor` make the rail; `selectedStyle` paints the selected segment.

:::example segmented-pill
:::

> **Difference from Flutter:** Without `multiSelectionEnabled`, a selected segment can't be deselected: `emptySelectionAllowed` only allows starting with no selection.

## Selection chips

`ChoiceChip` picks one option and `FilterChip`, several.

### ChoiceChip

:::bench cat-choice-chip
:::

Chips to pick a single option. `selected` is read from the ViewModel with `Watch`, and `withArg` tells the method which chip was pressed.

### FilterChip

:::bench cat-filter-chip
:::

Chips to pick several options at once; the selected ones show a checkmark.

| Parameter | What it does |
| --- | --- |
| `selected`, `onSelected` | whether it's selected and the method that receives the change |
| `selectedColor`, `backgroundColor` | the selected and unselected background |
| `showCheckmark` | shows or hides the checkmark |
| `shape`, `side`, `labelStyle`, `padding` | shape, border, text and padding |

## Input chips and links

`InputChip` shows a value that can be removed, and any chip can be a link.

### InputChip

:::bench cat-input-chip
:::

A value the user already picked or typed, with an X to remove it. `onDeleted` takes a ViewModel method and `deleteButtonTooltipMessage` changes the X's accessible name.

With `onPressed` it can be pressed and with `onSelected` it toggles, as in Flutter; with neither, it's a label like `Chip`.

### Chips as links

:::bench cat-link-chip
:::

`Chip`, `InputChip`, `FilterChip`, `ChoiceChip` and `ActionChip` accept `href`: the chip is a link and works without JavaScript, useful for filters that change the URL. On an `InputChip` or a `Chip`, `deleteHref` makes the X another link, to the page without that filter.

> **Difference from Flutter:** `href` and `deleteHref` don't exist in Flutter. The X is a button next to the chip, not inside it.

## CheckboxListTile, SwitchListTile and RadioListTile

:::bench cat-list-tiles
:::

A control with its title in a row that responds to a tap anywhere on it. `subtitle` adds a second line and `controlAffinity` places the control on the left or the right.
