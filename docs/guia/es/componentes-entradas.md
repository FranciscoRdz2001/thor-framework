# Entradas

Campos donde el usuario escribe o elige un valor. Cada uno entrega su valor a un método del ViewModel (`ThorState`) con `onChanged` y, dentro de un `Form`, se envía con su `name`.

## TextField

:::flutter Flutter: `TextField` · Thor: el mismo, sobre el campo nativo

:::bench cat-text-field
:::

Un campo de texto con etiqueta, ayuda e ícono. Cada tecla llega a `onChanged`.

| Parámetro | Qué hace |
| --- | --- |
| `decoration` | `InputDecoration`: `labelText`, `hintText`, `helperText`, `errorText`, `prefixIcon`, `suffixIcon`, `prefixText`, `suffixText`, `counterText`, `filled`, `isDense` |
| `onChanged`, `onSubmitted` | el método que recibe el texto, en cada tecla o al pulsar Enter |
| `controller` | un `TextEditingController` del ViewModel, para leer o cambiar el texto desde un método |
| `keyboardType`, `obscureText` | el teclado del teléfono (`emailAddress`, `phone`, `number`) y el texto oculto de una contraseña |
| `maxLines`, `minLines` | varias líneas; `maxLines: null` crece mientras se escribe |
| `initialValue`, `enabled` | el valor inicial; `false` bloquea el campo |

Los demás atributos (`readOnly`, `maxLength`, `textInputAction`, `autofillHints`) están en [Formularios](formularios.md#atributos-del-campo).

### Estados del campo

:::bench cat-text-field-states
:::

`errorText` marca el campo con el mensaje debajo, `maxLines` le da varias líneas y `enabled: false` lo bloquea.

## TextFormField

:::bench cat-text-form-field
:::

El campo de un formulario: valida con sus reglas y muestra el mensaje de la primera que falla. `Validator` incluye `required`, `email`, `minLength`, `maxLength`, `pattern`, `min`, `max` y `custom`.

Con un campo de un `FormSchema` (`TextFormField(field: SignUp.email)`), el servidor revisa las mismas reglas al enviar ([Formularios](formularios.md)).

## DropdownButton

:::bench cat-dropdown
:::

Una lista de opciones. En el teléfono abre el selector del sistema.

`isDense: true` la deja en 36 px en lugar de 48 e `itemHeight` fija el alto mínimo exacto. En `DropdownButtonFormField`, `isDense`, `itemHeight` y el `contentPadding` de la decoración (con espacio vertical) fijan el alto del `<select>`.

### DropdownButtonFormField

:::bench cat-dropdown-form-field
:::

La lista con etiqueta, ayuda y error, como un `TextFormField`. Para una lista con búsqueda e íconos por opción, usa `DropdownMenu`.

## Autocomplete

:::bench cat-autocomplete
:::

Un campo que sugiere opciones mientras el usuario escribe, en un panel que queda por encima del resto de la página. Las flechas mueven el resaltado, Enter elige y Esc cierra; sin JavaScript es un campo de texto.

Un lector de pantalla anuncia cuántas opciones hay cada vez que cambian. Estos textos se traducen con tres parámetros:

```dart
Autocomplete<String>(
  resultsLabel: '{count} results',
  oneResultLabel: '1 result',
  noResultsLabel: 'No results',
  optionsBuilder: (value) =>
      fruits.where((f) => f.contains(value.text.toLowerCase())),
)
```

| Parámetro | Qué hace |
| --- | --- |
| `optionsBuilder` | las opciones; se llama una vez, al construir la página |
| `displayStringForOption` | el texto de una opción: lo que se muestra y lo que se compara |
| `onSelected` | el método que recibe la opción (`String`, número, `bool` o `enum`) |
| `optionsViewOpenDirection`, `optionsMaxHeight` | hacia dónde abre el panel y su alto máximo |
| `semanticLabel`, `menuStyle` | el nombre accesible del campo y el aspecto del panel |

> **Diferencia con Flutter:** `optionsBuilder` no puede ser `async`, y ninguna opción queda resaltada hasta que el usuario mueve el resaltado, así Enter envía lo escrito.

### Sugerencias del servidor

Para opciones que busca el servidor, `RawAutocomplete` muestra en el panel una lista del ViewModel:

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

### Paleta de comandos (en línea)

Para una paleta ⌘K dentro de un `dialog`, la lista va en el flujo, junto al campo, y no en un panel flotante:

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

Con `inline`, Esc no lo toma la lista: el `dialog` se cierra con una sola pulsación. Teclas: ↑/↓ dan la vuelta, AvPág/RePág mueven una página, y Ctrl o ⌘ con Inicio/Fin van a la primera o última opción (Inicio/Fin sin modificador siguen moviendo el cursor del campo, como en el patrón combobox de la WAI-ARIA). `highlightFirst` también sirve sin `inline`.

> **Diferencia con Flutter:** `inline` y `highlightFirst` no existen allí (`RawAutocomplete` siempre resalta la primera opción y la muestra en un overlay).

## Fechas

:::bench cat-date-field
:::

`InputDatePickerFormField` es el campo de fecha del navegador. `DatePickerFormField` le agrega un botón que abre un calendario y entrega la fecha al ViewModel con `onDateChanged`.

El calendario usa el idioma de la página: nombres, primer día de la semana, dígitos y dirección ([Idiomas](idiomas.md#el-calendario-en-cada-idioma)).

> **Diferencia con Flutter:** No existe `showDatePicker(context)`: el calendario está en la página. Usa `DatePickerFormField`, o un `DatePickerDialog` que se abre con `DialogTrigger` ([Avisos](componentes-avisos.md#dialog)).

## Slider

:::bench cat-slider
:::

Un valor entre `min` y `max`; `divisions` lo hace avanzar por pasos. `onChanged` llega mientras se arrastra y `onChangeEnd`, una vez al soltar.

### Burbuja con el valor

`SliderThemeData(showValueIndicator:)` dibuja una burbuja sobre el pulgar que lo sigue al arrastrar. `label` es su texto: un `{}` se reemplaza por el valor en vivo.

:::example slider-bubble
:::

| `ShowValueIndicator` | La burbuja se ve |
| --- | --- |
| `alwaysVisible` | siempre |
| `onDrag` | al arrastrar o con el foco del teclado |
| `onlyForDiscrete`, `onlyForContinuous` | como `onDrag`, solo con o sin `divisions` |
| `never` | nunca |

`valueIndicatorColor` y `valueIndicatorTextStyle` le dan color y tipografía.

> **Diferencia con Flutter:** la burbuja es CSS que sigue al pulgar: no hay `valueIndicatorShape`. Sin `showValueIndicator` en el tema, `label` es solo el tooltip.

> **Diferencia con Flutter:** `value` es el valor con el que el servidor renderizó la página. Después, el control se mueve solo y avisa al ViewModel con `onChanged`; para mostrar el valor en otro lugar, léelo con `Watch`.
