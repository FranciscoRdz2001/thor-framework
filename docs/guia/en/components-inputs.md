# Inputs

Fields where the user types or picks a value. Each one hands its value to a ViewModel method (`ThorState`) with `onChanged` and, inside a `Form`, is submitted under its `name`.

## TextField

:::flutter Flutter: `TextField` · Thor: the same, on top of the native field

:::bench cat-text-field
:::

A text field with a label, helper text and an icon. Every keystroke reaches `onChanged`.

| Parameter | What it does |
| --- | --- |
| `decoration` | `InputDecoration`: `labelText`, `hintText`, `helperText`, `errorText`, `prefixIcon`, `suffixIcon`, `prefixText`, `suffixText`, `counterText`, `filled`, `isDense` |
| `onChanged`, `onSubmitted` | the method that receives the text, on every keystroke or when Enter is pressed |
| `controller` | a `TextEditingController` from the ViewModel, to read or change the text from a method |
| `keyboardType`, `obscureText` | the phone keyboard (`emailAddress`, `phone`, `number`) and the hidden text of a password |
| `maxLines`, `minLines` | multiple lines; `maxLines: null` grows as you type |
| `initialValue`, `enabled` | the initial value; `false` disables the field |

The remaining attributes (`readOnly`, `maxLength`, `textInputAction`, `autofillHints`) are in [Forms](forms.md#field-attributes).

### Field states

:::bench cat-text-field-states
:::

`errorText` marks the field with the message below it, `maxLines` gives it multiple lines and `enabled: false` disables it.

## TextFormField

:::bench cat-text-form-field
:::

A form field: it validates with its rules and shows the message of the first one that fails. `Validator` includes `required`, `email`, `minLength`, `maxLength`, `pattern`, `min`, `max` and `custom`.

With a field from a `FormSchema` (`TextFormField(field: SignUp.email)`), the server checks the same rules on submit ([Forms](forms.md)).

## DropdownButton

:::bench cat-dropdown
:::

A list of options. On a phone it opens the system picker.

`isDense: true` makes it 36 px instead of 48 and `itemHeight` sets the exact minimum height. In `DropdownButtonFormField`, `isDense`, `itemHeight` and the decoration's `contentPadding` (with vertical space) set the `<select>` height.

### DropdownButtonFormField

:::bench cat-dropdown-form-field
:::

The list with a label, helper text and error, like a `TextFormField`. For a searchable list with an icon per option, use `DropdownMenu`.

## Autocomplete

:::bench cat-autocomplete
:::

A field that suggests options as the user types, in a panel that sits above the rest of the page. The arrow keys move the highlight, Enter picks and Esc closes; without JavaScript it is a plain text field.

A screen reader announces how many options there are every time they change. These texts are translated with three parameters:

```dart
Autocomplete<String>(
  resultsLabel: '{count} results',
  oneResultLabel: '1 result',
  noResultsLabel: 'No results',
  optionsBuilder: (value) =>
      fruits.where((f) => f.contains(value.text.toLowerCase())),
)
```

| Parameter | What it does |
| --- | --- |
| `optionsBuilder` | the options; called once, when the page is built |
| `displayStringForOption` | an option's text: what is shown and what is matched |
| `onSelected` | the method that receives the option (`String`, number, `bool` or `enum`) |
| `optionsViewOpenDirection`, `optionsMaxHeight` | which way the panel opens and its maximum height |
| `semanticLabel`, `menuStyle` | the field's accessible name and the panel's look |

> **Difference from Flutter:** `optionsBuilder` can't be `async`, and no option is highlighted until the user moves the highlight, so Enter submits what was typed.

### Suggestions from the server

For options the server looks up, `RawAutocomplete` shows a ViewModel list in the panel:

```dart
RawAutocomplete<String>(
  optionsBuilder: (v) => const [],
  textEditingController: search.box, // a TextEditingController of the view model
  focusNode: search.focus,
  fieldViewBuilder: (context, controller, focus, submit) =>
      TextField(controller: controller, focusNode: focus, onChanged: search.type),
  optionsViewBuilder: (context, onSelected, options) => Watch.list(
    search.names,
    itemKey: search.nameOf,
    each: (row) => Semantics(
      role: SemanticsRole.option,
      child: row.link(search.hrefOf, child: row.text(search.nameOf)),
    ),
  ),
)
```

### Command palette (inline)

For a ⌘K palette inside a `dialog`, the list sits in the flow next to the field instead of a floating panel:

```dart
RawAutocomplete<String>(
  inline: true,          // list in the flow, visible while there are options
  highlightFirst: true,  // the first option is active: Enter picks it
  optionsBuilder: (v) => const [],
  fieldViewBuilder: (context, controller, focus, submit) =>
      TextField(controller: controller, focusNode: focus),
  optionsViewBuilder: (context, onSelected, options) => Watch.list(
    palette.hits,
    itemKey: palette.idOf,
    each: (row) => Semantics(role: SemanticsRole.option, child: row.text(palette.nameOf)),
  ),
)
```

Inline, the list does not take Esc: the `dialog` closes with one press. Keys: Up/Down wrap, PageUp/PageDown move a page, and Ctrl or Cmd with Home/End jump to the first or last option (plain Home/End keep moving the field's caret, as in the WAI-ARIA combobox pattern). `highlightFirst` also works without `inline`.

## Dates

:::bench cat-date-field
:::

`InputDatePickerFormField` is the browser's date field. `DatePickerFormField` adds a button that opens a calendar and hands the date to the ViewModel with `onDateChanged`.

The calendar uses the page's language: names, first day of the week, digits and direction ([Languages](localization.md#the-calendar-in-each-language)).

> **Difference from Flutter:** There is no `showDatePicker(context)`: the calendar lives in the page. Use `DatePickerFormField`, or a `DatePickerDialog` opened with `DialogTrigger` ([Feedback](components-feedback.md#dialog)).

## Slider

:::bench cat-slider
:::

A value between `min` and `max`; `divisions` makes it move in steps. `onChanged` fires while dragging and `onChangeEnd` once on release.

### Value bubble

`SliderThemeData(showValueIndicator:)` draws a bubble over the thumb that follows it while dragging. `label` is its text: a `{}` is replaced by the live value.

:::example slider-bubble
:::

| `ShowValueIndicator` | The bubble shows |
| --- | --- |
| `alwaysVisible` | always |
| `onDrag` | while dragging or with keyboard focus |
| `onlyForDiscrete`, `onlyForContinuous` | like `onDrag`, only with or without `divisions` |
| `never` | never |

`valueIndicatorColor` and `valueIndicatorTextStyle` set its color and type.

> **Difference from Flutter:** the bubble is CSS that follows the thumb: there is no `valueIndicatorShape`. Without `showValueIndicator` in the theme, `label` is only the tooltip.

> **Difference from Flutter:** `value` is the value the server rendered the page with. After that, the control moves on its own and notifies the ViewModel with `onChanged`; to show the value somewhere else, read it with `Watch`.
