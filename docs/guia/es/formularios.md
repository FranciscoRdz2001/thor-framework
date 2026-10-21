# Formularios

Construye formularios con los controles de Flutter: llegan como controles nativos del navegador y un `FormSchema` valida en el navegador y en el servidor.

:::flutter Flutter: `Form`, `TextFormField` y `validator` · Thor: `Form`, `TextFormField(validators:)` y `FormSchema`

## Controles

Un control es controlado, como en Flutter: `onChanged` es un método de tu ViewModel (`ThorState`) y, sin él, el control queda deshabilitado. La excepción es un campo con `name` dentro de un `Form`: queda habilitado sin `onChanged` y el formulario lo envía. Para deshabilitarlo, escribe `onChanged: null`.

```dart
class SoundSettingsViewModel extends ThorState {
  final sound = state(true);
  void setSound(bool on) => sound.value = on;
}
final soundSettings = SoundSettingsViewModel();

SwitchListTile(
  value: soundSettings.sound.value,
  onChanged: soundSettings.setSound,
  title: const Text('Sound'),
)
```

:::example form-controls
:::

| Widget | Llega como | `onChanged` recibe |
|---|---|---|
| `TextField`, `TextFormField` | un campo de texto (de varias líneas con `maxLines > 1`) | `String` |
| `Checkbox`, `Switch` y sus `*ListTile` | una casilla | `bool` |
| `Radio<T>`, `RadioListTile<T>` | un botón de opción | el valor elegido |
| `Slider` | un control deslizante | `double` |
| `DropdownButton<T>` | la lista desplegable del sistema | el valor elegido |
| `DropdownMenu<T>` | una lista con estilo y filtro | el valor elegido (`onSelected`) |

Cada control tiene su ejemplo en [Entradas](componentes-entradas.md) y [Selección](componentes-seleccion.md).

> **Nota:** `value:` es el valor inicial: el servidor renderiza el que tiene el ViewModel en ese momento y, desde entonces, el control guarda su valor y `onChanged` avisa al ViewModel. Por eso `build` lee `.value`, y lo que debe actualizarse en pantalla va en un `Watch`.

El nombre de un campo es su `labelText` (o `hintText`): un `Text('Email')` al lado no lo nombra, y el lector de pantalla dice solo «campo de texto». Sin él, el editor avisa con `text_field_without_label` y `thor dev` con [THOR-L004](../../errores/THOR-L004.md). Si el diseño no muestra la etiqueta, usa `Semantics(label: 'Email', child: TextField(…))`.

## Atributos del campo

`keyboardType` elige el tipo de campo y, en el teléfono, el teclado. Los demás parámetros de `TextField` y `TextFormField` se convierten en atributos del campo que el navegador entiende.

```dart
TextFormField(
  name: 'email',
  keyboardType: TextInputType.emailAddress, // the email keyboard
  textInputAction: TextInputAction.next, // the Enter key of the phone
  autofillHints: [AutofillHints.email], // the browser offers saved values
  decoration: InputDecoration(labelText: 'Email'),
)
```

`TextInputType.number` es el teclado de dígitos (`inputmode="numeric"`); para importes usa `TextInputType.numberWithOptions(decimal: true)` (`inputmode="decimal"`).

:::example form-field-params
:::

| Parámetro | En el navegador |
|---|---|
| `keyboardType` | `number`, `phone`, `emailAddress`, `url` y `webSearch` eligen el teclado; `visiblePassword` y `obscureText: true` ocultan el texto |
| `autofillHints` | el autocompletado del navegador; los nombres de `AutofillHints` de Flutter (`newPassword`, `email`…) |
| `textInputAction` | la tecla Enter del teléfono: `done`, `go`, `next`, `previous`, `search`, `send` |
| `textCapitalization` | mayúsculas automáticas: `words`, `sentences`, `characters` |
| `maxLength` | un tope y un contador bajo el campo; `TextField.noMaxLength` solo cuenta |
| `readOnly` | no editable, pero se envía con el formulario (`enabled: false` no se envía) |

`InputDecoration` admite `prefixText`, `suffixText`, `prefix`, `suffix`, `icon`, `counterText` (`''` quita el contador), `errorMaxLines` e `isCollapsed`. La etiqueta siempre va arriba. `expands: true` llena el alto disponible y `textAlign` alinea el texto.

Lo que no tiene parámetro de Flutter va en `inputAttributes`, con tipo: `HtmlAttributes` acepta atributos `aria-*` (`AriaAttribute`), `data-*`, `id`, `title`, `tabIndex` y los booleanos, y `HtmlAttributes.custom({'type': 'time'})` cualquier otro nombre válido, nunca un manejador de eventos.

```dart
TextField(
  name: 'q',
  inputAttributes: HtmlAttributes(
    aria: {AriaAttribute.label: 'Search'},
    flags: {BooleanAttribute.autofocus},
  ),
)
```

> **Importante:** `maxLength` cuenta como Flutter, por caracteres visibles (un emoji compuesto es uno), y el tope del navegador cuenta unidades UTF-16: con emojis, el campo puede llenarse antes de que el contador llegue al límite.

## Validar

Las reglas se escriben una vez y el navegador las aplica con su validación nativa. Con JavaScript, debajo del campo sale tu mensaje; sin él, el del navegador.

:::bench bench-form-rule
:::

:::flutter
@flutter
```dart no-check
TextFormField(
  decoration: const InputDecoration(labelText: 'Email'),
  validator: (value) {
    if (value == null || value.isEmpty) return 'Enter your email.';
    if (!value.contains('@')) return 'That email does not look valid.';
    return null;
  },
)
```
@thor
```dart
TextFormField(
  name: 'email',
  decoration: const InputDecoration(labelText: 'Email'),
  validators: const [
    Validator.required('Enter your email.'),
    Validator.email('That email does not look valid.'),
  ],
)
```
:::

| Regla | Qué exige |
|---|---|
| `Validator.required(msg)` | que no esté vacío (`'   '` pasa, como en el navegador) |
| `Validator.notBlank(msg)` | que no esté vacío ni en blanco, como `value.trim().isEmpty` |
| `Validator.email(msg)` | una dirección de correo |
| `minLength`, `maxLength`, `min`, `max` | un largo o un número dentro del rango; un campo vacío pasa |
| `Validator.pattern(String, msg)` | que el valor completo cumpla el patrón; con un `RegExp`, una coincidencia en cualquier parte |
| `Validator.custom((v) => …)` | corre solo en el servidor, tras enviar; requiere un esquema ([THOR-P031](../../errores/THOR-P031.md)) |

`Validator.all([…])` combina varias reglas en un solo `validator:`. Un closure de Flutter (`(v) => …`) no corre en el navegador: su equivalente es `Validator.custom`. Un `RegExp` no admite `caseSensitive: false`, `multiLine` ni `dotAll` ([THOR-P035](../../errores/THOR-P035.md)) y no es `const`: en un esquema `static const`, usa el `String`.

## Enviar sin recargar

`Form(onSubmit:)` llama a un método del ViewModel solo si todo es válido, y la página no navega.

```dart
Form(
  onSubmit: newsletter.join,
  child: Column(children: [
    TextFormField(
      name: 'email',
      onChanged: newsletter.setEmail,
      decoration: const InputDecoration(labelText: 'Email'),
      validators: [Validator.email('That email does not look valid.')],
    ),
    FilledButton(buttonType: ButtonType.submit, child: const Text('Subscribe')),
  ]),
)
```

:::example form-submit
:::

> **Diferencia con Flutter:** En Flutter, un botón sin `onPressed` queda deshabilitado. En Thor, un botón `buttonType: ButtonType.submit` dentro de un `Form` está activo sin manejador: su acción es enviar el formulario.

Para deshabilitar un botón de envío según el estado y que siga sirviendo sin JavaScript, enlaza `disabled` con `clientOnly`: el servidor no lo escribe y el motor lo pone al arrancar.

```dart
WatchAttributes(
  {AttributeName.disabled: create.invalid},
  clientOnly: {AttributeName.disabled},
  child: FilledButton(buttonType: ButtonType.submit, child: Text('Create')),
)
```

Un formulario cuyos controles se aplican solos con JavaScript necesita igual su botón de envío como base. Envuélvelo en `NoScript` y solo se muestra cuando la página corre sin JavaScript; con JavaScript desaparece del layout y del árbol de accesibilidad.

```dart
NoScript(child: FilledButton(buttonType: ButtonType.submit, child: Text('Apply')))
```

## Enviar al servidor

En una app con rutas, el formulario llama a un método de la página que corre en el servidor (`onValid: send`). Funciona sin JavaScript: el navegador envía un `POST` y recibe un `303` o la página otra vez con los errores. Las acciones, los argumentos por botón y `confirm:` están en [Servidor y acciones](red-y-servidor.md#acciones-de-formulario).

```dart
Form(
  child: Column(children: [
    const TextField(name: 'quantity', decoration: InputDecoration(labelText: 'Quantity')),
    const HiddenField(name: 'note', value: 'gift'),
    FilledButton(onPost: const CartPage().add.withArgs(sku, seller), child: const Text('Add')),
  ]),
)
```

`HiddenField` envía un valor que el usuario no edita. Un botón con argumentos dentro de un `Form` envía ese formulario: llegan los argumentos y los campos juntos. Con varios botones llega solo el argumento del pulsado, y Enter envía con el primero, así que pon primero el predeterminado. `thor-arg` es un nombre reservado: un campo con ese nombre responde `400`.

### Mientras se envía

Un formulario que navega (`onValid`, `onPost`, `action`) se marca solo al enviarse: se ve que trabaja y no se puede enviar dos veces.

:::bench bench-form-phase
:::

| Al enviar | Qué pasa |
|---|---|
| el formulario | se marca ocupado (`aria-busy="true"`) y el puntero indica progreso |
| sus botones de envío | se deshabilitan: un segundo clic o Enter no envía otra vez |
| el botón pulsado | envía su `name` y su `value` antes de deshabilitarse |
| la validación falla | no pasa nada: el formulario sigue editable |
| «atrás» | el formulario vuelve como estaba |
| una descarga o una pestaña nueva | el formulario se libera solo a los 15 s |

`Form(disableOnSubmit: false)` lo desactiva, para una respuesta que no cambia de página, como una descarga. Los formularios `formMethod: FormMethod.dialog`, los que abren otra pestaña y los `mailto:` no se marcan. Sin JavaScript, el envío es el normal, sin el estado.

### Quedarte donde estabas

Si la acción responde con la misma página (un `422`, la página renderizada o un `Redirect` a su ruta), el usuario sigue donde estaba: la misma posición de desplazamiento y el foco en el botón pulsado.

```dart
Future<ActionResult?> add(PageRequest request, int id) async {
  cart.add(id);
  return Redirect.back(request).flash('Added'); // the same page: the user stays
}
```

| La respuesta | Dónde empieza la página |
|---|---|
| la misma ruta, con cualquier query | donde estaba, con el foco en el botón |
| otra ruta | arriba |
| la misma ruta con `resetScroll` | arriba |
| un `#ancla` en el destino | el ancla |
| un `422` con errores | el primer campo con error, que toma el foco |
| sin JavaScript | arriba: el navegador carga una página nueva |

`Redirect.back(request)` es la página desde la que se envió, con su query. Para volver arriba en la misma ruta (al quitar los filtros, al volver a la página 1), usa `Redirect('/orders', resetScroll: true)` o `Form(resetScroll: true)`. El prefijo de idioma forma parte de la ruta: `/es/p` y `/p` son rutas distintas.

### Guardar sin cambiar de página

`Form(stay: true)` guarda sin salir de la página. Con JavaScript el formulario se envía por `fetch` (con archivos si es `multipart`) y la página no navega: mientras va, el formulario queda ocupado y sus botones deshabilitados; al volver, el aviso de `Redirect.back(request).flash(…)` (o el mensaje de un `ActionResult.fail`) sale como toast, los archivos elegidos se limpian y las consultas del servidor (`query(fn)` de un `ThorState`) se piden otra vez. La acción es la misma de siempre.

```dart
Form(
  onPost: const SettingsPage().save,
  stay: true,
  child: Column(children: [
    TextFormField(name: 'name', label: 'Name'),
    FilledButton(buttonType: ButtonType.submit, child: const Text('Save')),
  ]),
)

// en la página
Future<Redirect> save(PageRequest request) async {
  await store(await request.form());
  return Redirect.back(request).flash('Saved', kind: FlashKind.success);
}
```

| La acción responde | Con `stay: true` |
|---|---|
| `Redirect.back(request)`, con o sin `flash` | la página se queda; el aviso sale como toast |
| `ActionResult.fail(…)` | toast de error con su mensaje (un `String`, `{'error': …}`, un `FormInvalid` o un `ActionMessage`); lo escrito se conserva |
| un `Redirect` a otra ruta | navega allí; el aviso llega con la página siguiente |

El formulario emite `thor:stay` (`detail`: `ok`, `status`, `kind`, `message`) tras cada respuesta, para quien quiera actualizar algo más. Solo las consultas se actualizan solas: lo que el servidor dibujó en el HTML no cambia hasta que la página se vuelve a cargar. Sin JavaScript el formulario envía, el navegador sigue el `303` y la página siguiente muestra el aviso, igual que siempre.

## Un esquema para el navegador y el servidor

La validación del navegador se puede saltar con un `curl` o un formulario alterado. Un `FormSchema` declara el formulario una vez: la página toma de él las reglas de cada campo y el servidor las comprueba otra vez antes de llamar a tu método.

```dart
final class SignUp extends FormSchema {
  const SignUp._() : super(const [email, password, age]);
  static const schema = SignUp._();

  static const email = TextSchemaField('email', validators: [
    Validator.required('Enter your email.'),
    Validator.email('That email does not look valid.'),
  ]);
  static const password = TextSchemaField('password', secret: true,
      validators: [Validator.minLength(8, 'Use at least 8 characters.')]);
  static const age = IntSchemaField('age', invalid: 'Age is a number.');
}

// in the page: each field from the schema
TextFormField(field: SignUp.email, form: state.form,
    decoration: const InputDecoration(labelText: 'Email'))
```

:::example form-schema
:::

| Campo | Tu método recibe | Además |
|---|---|---|
| `TextSchemaField` | `String` (`''` si llegó vacío) | `secret: true` no se rellena; `trim: true` quita los espacios de los extremos |
| `IntSchemaField`, `DoubleSchemaField` | `int?` o `double?` (`null` si llegó vacío) | lo que no es un número (`NaN`, `1,5`) falla con `invalid` |
| `DateSchemaField` | `DateTime?` (UTC, `yyyy-mm-dd`) | una fecha inexistente falla; límites con `Validator.minDate` y `maxDate` |
| `CheckboxSchemaField` | `bool` | `Validator.required` exige que llegue marcado |
| `ChoiceSchemaField` | `String` | un valor fuera de `choices` falla con `invalid` |
| `OptionalSchemaField`, `ListSchemaField` | `T?` o `List<T>` | las reglas cuentan solo si hay valor; la lista conserva el orden enviado |

```dart
// only when creating: a top-level function, so the field stays const
bool _creating(FormData data) => (data['id'] ?? '').isEmpty;

static const password = TextSchemaField('password', when: _creating,
    validators: [Validator.required('Enter a password.')]);
```

`when:` decide en el servidor. El navegador no lo conoce, así que sus reglas nativas no se aplican salvo que la página lo indique: `TextFormField(field: …, applies: isNew)`. El servidor valida con la misma semántica que el navegador.

### Cuando el servidor dice que no

Si la acción falla con `values.fail('That email already has an account.', SignUp.email)`, la página vuelve con lo que el usuario escribió y el mensaje. La contraseña (`secret: true`) nunca vuelve, y el primer campo con error toma el foco, de modo que el lector de pantalla anuncia su etiqueta y el mensaje.

:::example form-schema-failed
:::

`Form(failed: state.form)` rellena cada campo con `name` y le pone su mensaje, sin `value:` ni `errorText:` por campo. `defaults:` rellena el formulario al editar un registro guardado.

```dart
Form(
  schema: SignUp.schema,
  onValid: send,
  failed: state.form, // what the action returned (422)
  defaults: state.data, // the saved record (when editing)
  noValidate: true, // so the server's messages show
  child: Column(children: [
    TextFormField(name: 'email', decoration: const InputDecoration(labelText: 'Email')),
    Checkbox(name: 'terms', value: false),
    const FormFieldError('terms'), // the message of a control with no line of its own
    FilledButton(buttonType: ButtonType.submit, child: const Text('Save')),
  ]),
)
```

El valor de un campo sale, en orden de prioridad, de lo enviado (`failed`), de su `initialValue` y de `defaults` (un `Map` o un objeto con `toJson()`). Un `errorText:` propio tiene prioridad sobre el del servidor. `noValidate: true` quita los avisos del navegador para que se vean los mensajes del servidor; las reglas siguen corriendo en el servidor.

> **Diferencia con Flutter:** No hay `TextEditingController` ni `FormState.validate()`. El valor vive en el campo del navegador, y tras un envío fallido el servidor renderiza la página otra vez con lo enviado.

## Subir archivos

Un `FileField` va dentro de un `Form(encoding: FormEncoding.multipart)`; la acción lee el archivo con `form.file('cv')`.

```dart
Form(
  onPost: upload,
  encoding: FormEncoding.multipart,
  child: Column(children: [
    const FileField(name: 'cv', label: 'CV (PDF)', accept: ['application/pdf']),
    FilledButton(buttonType: ButtonType.submit, child: const Text('Submit')),
  ]),
)
```

:::example form-upload
:::

El cuerpo de una petición admite 1 MiB en todo el sitio; la página que recibe archivos sube su propio límite:

```dart
class AvatarPage extends ThorPage<void> {
  const AvatarPage() : super(maxBodyBytes: 5 << 20); // 5 MiB, only here
}
```

| Caso | Qué pasa |
|---|---|
| un cuerpo mayor que el límite | `413` con el límite en el mensaje; súbelo con `ThorPage(maxBodyBytes:)` o `ThorServer(maxBodyBytes:)` |
| un cuerpo que tarda más de 30 s en llegar | `408` y se cierra la conexión; el plazo es `ThorServer(bodyReadTimeout:)` |
| un cuerpo mal formado | `400`, nunca un error del servidor |

> **Cuidado:** `cv.filename` y `cv.contentType` son lo que dice el navegador: no los uses como ruta de archivo ni como prueba del tipo.

### El progreso de la subida

`LinearProgressIndicator.upload()` dentro del `Form` es una barra que aparece mientras se suben los archivos y se llena a medida que salen los bytes.

```dart
Form(
  onPost: upload,
  encoding: FormEncoding.multipart,
  child: Column(children: [
    const FileField(name: 'video', label: 'Video'),
    const LinearProgressIndicator.upload(),
    FilledButton(buttonType: ButtonType.submit, child: const Text('Upload')),
  ]),
)
```

Al terminar el envío, la barra queda indeterminada mientras el servidor trabaja, y después sigue una navegación normal: una redirección va a su destino, una página se muestra y un archivo se descarga. Un `204` o una conexión cortada libera el formulario y emite el evento `thor:upload-error`. Sin JavaScript, sin archivo elegido o con `disableOnSubmit: false`, el formulario envía de la forma normal y la barra no aparece.

### Enviar al elegir archivos

`FileField(submitOnChange: true)` envía el formulario en cuanto se eligen archivos. `submitWith` nombra el botón que lo envía (el de ese `name` o el de esa acción: `submitWith: 'store'` para el botón con `onPost: store`); sin él, el primero. Junto con `Form(stay: true)` la página no se mueve. Sin JavaScript, el campo es un campo de archivo normal junto a su botón.

```dart
Form(
  onPost: const PhotosPage().store,
  stay: true,
  encoding: FormEncoding.multipart,
  child: Column(children: [
    const FileField(name: 'photos', label: 'Photos', multiple: true,
        submitOnChange: true, submitWith: 'store'),
    FilledButton(buttonType: ButtonType.submit, child: const Text('Upload')),
  ]),
)
```

### Archivos grandes

`form()` y `bytes()` guardan el cuerpo entero en memoria. Para un archivo grande, `saveBody` lo escribe a disco a medida que llega, con los mismos límites:

```dart
class VideoPage extends ThorPage<void> {
  const VideoPage() : super(maxBodyBytes: 500 << 20);

  Future<ActionResult?> upload(PageRequest request) async {
    final bytes = await request.saveBody(File('uploads/${newId()}.mp4'));
    return null;
  }
}
```

Escribe en un archivo temporal junto al destino y lo renombra al terminar: si algo falla (el límite, el plazo, un disco lleno), no queda un archivo a medias. `pipeBody(sink)` hace lo mismo hacia cualquier `StreamSink`.

## Siguientes pasos

:::cards
- [Servidor y acciones](red-y-servidor.md) — acciones, argumentos y `confirm:`
- [Sesión y seguridad](sesion-y-seguridad.md) — CSRF, sesión y límite de intentos
- [Entradas](componentes-entradas.md) — cada control con su ejemplo
:::
