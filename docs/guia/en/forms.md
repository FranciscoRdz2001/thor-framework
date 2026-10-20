# Forms

Build forms with Flutter's controls: they arrive as native browser controls, and a `FormSchema` validates in the browser and on the server.

:::flutter Flutter: `Form`, `TextFormField` and `validator` · Thor: `Form`, `TextFormField(validators:)` and `FormSchema`

## Controls

A control is controlled, as in Flutter: `onChanged` is a method of your ViewModel (`ThorState`) and, without it, the control is disabled. The exception is a field with a `name` inside a `Form`: it stays enabled without `onChanged` and the form submits it. To disable it, write `onChanged: null`.

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

| Widget | Arrives as | `onChanged` receives |
|---|---|---|
| `TextField`, `TextFormField` | a text field (multi-line with `maxLines > 1`) | `String` |
| `Checkbox`, `Switch` and their `*ListTile` | a checkbox | `bool` |
| `Radio<T>`, `RadioListTile<T>` | a radio button | the chosen value |
| `Slider` | a slider | `double` |
| `DropdownButton<T>` | the system dropdown list | the chosen value |
| `DropdownMenu<T>` | a styled list with filtering | the chosen value (`onSelected`) |

Each control has its example in [Inputs](components-inputs.md) and [Selection](components-selection.md).

> **Note:** `value:` is the initial value: the server renders whatever the ViewModel holds at that moment and, from then on, the control keeps its own value and `onChanged` notifies the ViewModel. That is why `build` reads `.value`, and whatever must update on screen goes in a `Watch`.

A field's name is its `labelText` (or `hintText`): a `Text('Email')` next to it does not name it, and the screen reader only says "text field". Without one, the editor warns with `text_field_without_label` and `thor dev` with [THOR-L004](../../errores/en/THOR-L004.md). If the design does not show the label, use `Semantics(label: 'Email', child: TextField(…))`.

## Field attributes

`keyboardType` picks the field type and, on a phone, the keyboard. The other parameters of `TextField` and `TextFormField` become field attributes the browser understands.

```dart
TextFormField(
  name: 'email',
  keyboardType: TextInputType.emailAddress, // the email keyboard
  textInputAction: TextInputAction.next, // the Enter key of the phone
  autofillHints: [AutofillHints.email], // the browser offers saved values
  decoration: InputDecoration(labelText: 'Email'),
)
```

`TextInputType.number` is the digits keyboard (`inputmode="numeric"`); for amounts use `TextInputType.numberWithOptions(decimal: true)` (`inputmode="decimal"`).

:::example form-field-params
:::

| Parameter | In the browser |
|---|---|
| `keyboardType` | `number`, `phone`, `emailAddress`, `url` and `webSearch` pick the keyboard; `visiblePassword` and `obscureText: true` hide the text |
| `autofillHints` | the browser's autofill; Flutter's `AutofillHints` names (`newPassword`, `email`…) |
| `textInputAction` | the phone's Enter key: `done`, `go`, `next`, `previous`, `search`, `send` |
| `textCapitalization` | automatic capitalization: `words`, `sentences`, `characters` |
| `maxLength` | a cap and a counter below the field; `TextField.noMaxLength` only counts |
| `readOnly` | not editable, but submitted with the form (`enabled: false` is not submitted) |

`InputDecoration` supports `prefixText`, `suffixText`, `prefix`, `suffix`, `icon`, `counterText` (`''` removes the counter), `errorMaxLines` and `isCollapsed`. The label always goes on top. `expands: true` fills the available height and `textAlign` aligns the text.

Anything without a Flutter parameter goes in `inputAttributes`, typed: `HtmlAttributes` accepts `aria-*` attributes (`AriaAttribute`), `data-*`, `id`, `title`, `tabIndex` and the boolean ones, and `HtmlAttributes.custom({'type': 'time'})` any other valid name, never an event handler.

```dart
TextField(
  name: 'q',
  inputAttributes: HtmlAttributes(
    aria: {AriaAttribute.label: 'Search'},
    flags: {BooleanAttribute.autofocus},
  ),
)
```

> **Important:** `maxLength` counts like Flutter, by visible characters (a composite emoji is one), while the browser's cap counts UTF-16 units: with emojis, the field can fill up before the counter reaches the limit.

## Validate

Rules are written once and the browser applies them with its native validation. With JavaScript, your message shows below the field; without it, the browser's.

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

| Rule | What it requires |
|---|---|
| `Validator.required(msg)` | that it is not empty (`'   '` passes, as in the browser) |
| `Validator.notBlank(msg)` | that it is neither empty nor blank, like `value.trim().isEmpty` |
| `Validator.email(msg)` | an email address |
| `minLength`, `maxLength`, `min`, `max` | a length or a number within range; an empty field passes |
| `Validator.pattern(String, msg)` | that the whole value matches the pattern; with a `RegExp`, a match anywhere |
| `Validator.custom((v) => …)` | runs only on the server, after submitting; requires a schema ([THOR-P031](../../errores/en/THOR-P031.md)) |

`Validator.all([…])` combines several rules into a single `validator:`. A Flutter closure (`(v) => …`) does not run in the browser: its equivalent is `Validator.custom`. A `RegExp` does not support `caseSensitive: false`, `multiLine` or `dotAll` ([THOR-P035](../../errores/en/THOR-P035.md)) and is not `const`: in a `static const` schema, use the `String`.

## Submit without reloading

`Form(onSubmit:)` calls a ViewModel method only if everything is valid, and the page does not navigate.

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

> **Difference from Flutter:** In Flutter, a button without `onPressed` is disabled. In Thor, a `buttonType: ButtonType.submit` button inside a `Form` is active without a handler: its action is to submit the form.

To disable a submit button from state and keep it working without JavaScript, bind `disabled` with `clientOnly`: the server does not write it and the engine sets it at start.

```dart
WatchAttributes(
  {AttributeName.disabled: create.invalid},
  clientOnly: {AttributeName.disabled},
  child: FilledButton(buttonType: ButtonType.submit, child: Text('Create')),
)
```

A form whose controls apply on their own with JavaScript still needs its submit button as the baseline. Wrap it in `NoScript` and it shows only when the page runs without JavaScript; with JavaScript it is gone from the layout and from the accessibility tree.

```dart
NoScript(child: FilledButton(buttonType: ButtonType.submit, child: Text('Apply')))
```

## Submit to the server

In an app with routes, the form calls a page method that runs on the server (`onValid: send`). It works without JavaScript: the browser sends a `POST` and receives a `303` or the page again with the errors. Actions, per-button arguments and `confirm:` are covered in [Server and actions](server-and-actions.md#form-actions).

```dart
Form(
  child: Column(children: [
    const TextField(name: 'quantity', decoration: InputDecoration(labelText: 'Quantity')),
    const HiddenField(name: 'note', value: 'gift'),
    FilledButton(onPost: const CartPage().add.withArgs(sku, seller), child: const Text('Add')),
  ]),
)
```

`HiddenField` submits a value the user does not edit. A button with arguments inside a `Form` submits that form: the arguments and the fields arrive together. With several buttons only the pressed one's argument arrives, and Enter submits with the first one, so put the default first. `thor-arg` is a reserved name: a field with that name responds with a `400`.

### While submitting

A form that navigates (`onValid`, `onPost`, `action`) marks itself automatically when submitted: it visibly works and cannot be submitted twice.

:::bench bench-form-phase
:::

| On submit | What happens |
|---|---|
| the form | is marked busy (`aria-busy="true"`) and the pointer shows progress |
| its submit buttons | are disabled: a second click or Enter does not submit again |
| the pressed button | sends its `name` and `value` before being disabled |
| validation fails | nothing happens: the form stays editable |
| "back" | the form comes back as it was |
| a download or a new tab | the form releases itself after 15 s |

`Form(disableOnSubmit: false)` turns it off, for a response that does not change page, such as a download. Forms with `formMethod: FormMethod.dialog`, those that open another tab and `mailto:` ones are not marked. Without JavaScript, submission is the normal one, without the state.

### Stay where you were

If the action responds with the same page (a `422`, the rendered page or a `Redirect` to its route), the user stays where they were: the same scroll position and focus on the pressed button.

```dart
Future<ActionResult?> add(PageRequest request, int id) async {
  cart.add(id);
  return Redirect.back(request).flash('Added'); // the same page: the user stays
}
```

| The response | Where the page starts |
|---|---|
| the same route, with any query | where it was, with focus on the button |
| another route | at the top |
| the same route with `resetScroll` | at the top |
| an `#anchor` in the destination | the anchor |
| a `422` with errors | the first field with an error, which takes focus |
| without JavaScript | at the top: the browser loads a new page |

`Redirect.back(request)` is the page the form was submitted from, with its query. To go back to the top on the same route (when clearing filters, when going back to page 1), use `Redirect('/orders', resetScroll: true)` or `Form(resetScroll: true)`. The language prefix is part of the route: `/es/p` and `/p` are different routes.

## One schema for the browser and the server

Browser validation can be bypassed with a `curl` or a tampered form. A `FormSchema` declares the form once: the page takes each field's rules from it and the server checks them again before calling your method.

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

| Field | Your method receives | Also |
|---|---|---|
| `TextSchemaField` | `String` (`''` if it arrived empty) | `secret: true` is not refilled; `trim: true` strips leading and trailing spaces |
| `IntSchemaField`, `DoubleSchemaField` | `int?` or `double?` (`null` if it arrived empty) | anything that is not a number (`NaN`, `1,5`) fails with `invalid` |
| `DateSchemaField` | `DateTime?` (UTC, `yyyy-mm-dd`) | a nonexistent date fails; limits with `Validator.minDate` and `maxDate` |
| `CheckboxSchemaField` | `bool` | `Validator.required` requires it to arrive checked |
| `ChoiceSchemaField` | `String` | a value outside `choices` fails with `invalid` |
| `OptionalSchemaField`, `ListSchemaField` | `T?` or `List<T>` | rules apply only if there is a value; the list keeps the submitted order |

```dart
// only when creating: a top-level function, so the field stays const
bool _creating(FormData data) => (data['id'] ?? '').isEmpty;

static const password = TextSchemaField('password', when: _creating,
    validators: [Validator.required('Enter a password.')]);
```

`when:` decides on the server. The browser does not know about it, so its native rules are not applied unless the page says so: `TextFormField(field: …, applies: isNew)`. The server validates with the same semantics as the browser.

### When the server says no

If the action fails with `values.fail('That email already has an account.', SignUp.email)`, the page comes back with what the user typed and the message. The password (`secret: true`) never comes back, and the first field with an error takes focus, so the screen reader announces its label and the message.

:::example form-schema-failed
:::

`Form(failed: state.form)` refills each field that has a `name` and gives it its message, with no per-field `value:` or `errorText:`. `defaults:` fills the form when editing a saved record.

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

A field's value comes, in order of priority, from what was submitted (`failed`), from its `initialValue` and from `defaults` (a `Map` or an object with `toJson()`). Your own `errorText:` takes priority over the server's. `noValidate: true` removes the browser's warnings so the server's messages show; the rules still run on the server.

> **Difference from Flutter:** There is no `TextEditingController` or `FormState.validate()`. The value lives in the browser's field, and after a failed submission the server renders the page again with what was submitted.

## Upload files

A `FileField` goes inside a `Form(encoding: FormEncoding.multipart)`; the action reads the file with `form.file('cv')`.

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

A request body is limited to 1 MiB across the whole site; the page that receives files raises its own limit:

```dart
class AvatarPage extends ThorPage<void> {
  const AvatarPage() : super(maxBodyBytes: 5 << 20); // 5 MiB, only here
}
```

| Case | What happens |
|---|---|
| a body larger than the limit | `413` with the limit in the message; raise it with `ThorPage(maxBodyBytes:)` or `ThorServer(maxBodyBytes:)` |
| a body that takes more than 30 s to arrive | `408` and the connection is closed; the timeout is `ThorServer(bodyReadTimeout:)` |
| a malformed body | `400`, never a server error |

> **Caution:** `cv.filename` and `cv.contentType` are whatever the browser says: do not use them as a file path or as proof of the type.

### Upload progress

`LinearProgressIndicator.upload()` inside the `Form` is a bar that appears while the files upload and fills as the bytes go out.

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

When the upload finishes, the bar turns indeterminate while the server works, and then a normal navigation follows: a redirect goes to its destination, a page is shown and a file is downloaded. A `204` or a dropped connection releases the form and emits the `thor:upload-error` event. Without JavaScript, with no file chosen or with `disableOnSubmit: false`, the form submits the normal way and the bar does not appear.

### Large files

`form()` and `bytes()` keep the whole body in memory. For a large file, `saveBody` writes it to disk as it arrives, with the same limits:

```dart
class VideoPage extends ThorPage<void> {
  const VideoPage() : super(maxBodyBytes: 500 << 20);

  Future<ActionResult?> upload(PageRequest request) async {
    final bytes = await request.saveBody(File('uploads/${newId()}.mp4'));
    return null;
  }
}
```

It writes to a temporary file next to the destination and renames it when done: if something fails (the limit, the timeout, a full disk), no half-written file is left behind. `pipeBody(sink)` does the same into any `StreamSink`.

## Next steps

:::cards
- [Server and actions](server-and-actions.md) — actions, arguments and `confirm:`
- [Session and security](session-and-security.md) — CSRF, session and rate limiting
- [Inputs](components-inputs.md) — each control with its example
:::
