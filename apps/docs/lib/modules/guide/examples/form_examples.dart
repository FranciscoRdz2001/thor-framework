// ignore_for_file: public_member_api_docs
// (each example is named by its region; a doc comment would sit outside
// the code the site shows)
// The "Forms" guide (docs/guia/es/formularios.md, en/forms.md). Each
// example sits between `// region: <id>` and `// endregion`: the site
// shows that code and renders the same widget on the page.
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

// region: form-controls
class SoundSettingsViewModel extends ThorState {
  final sound = state(true);
  final remember = state(false);
  final volume = state(40.0);

  void setSound(bool on) => sound.value = on;
  void setRemember(bool? on) => remember.value = on ?? false;
  void setVolume(double v) => volume.value = v;

  String summary() =>
      sound.value ? 'Sound on, volume ${volume.value.round()}' : 'Sound off';
}

final soundSettings = SoundSettingsViewModel();

class FormControlsDemo extends StatelessWidget {
  const FormControlsDemo({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 320,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          value: soundSettings.sound.value,
          onChanged: soundSettings.setSound,
          title: const Text('Sound'),
        ),
        CheckboxListTile(
          value: soundSettings.remember.value,
          onChanged: soundSettings.setRemember,
          title: const Text('Remember me'),
        ),
        Slider(
          value: soundSettings.volume.value,
          max: 100,
          divisions: 10,
          semanticLabel: 'Volume',
          onChanged: soundSettings.setVolume,
        ),
        Watch(soundSettings.summary),
      ],
    ),
  );
}
// endregion

// region: form-submit
class NewsletterViewModel extends ThorState {
  final email = state('');
  final joined = state('');

  void setEmail(String value) => email.value = value;

  // Runs only when every field is valid; the page doesn't reload.
  void join() => joined.value = email.value;

  String message() =>
      joined.value.isEmpty ? '' : 'Done: we will email ${joined.value}.';
}

final newsletter = NewsletterViewModel();

class NewsletterDemo extends StatelessWidget {
  const NewsletterDemo({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 320,
    child: Form(
      onSubmit: newsletter.join,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          TextFormField(
            name: 'email',
            onChanged: newsletter.setEmail,
            decoration: const InputDecoration(labelText: 'Email'),
            validators: const [
              Validator.required('Enter your email.'),
              Validator.email('That email does not look valid.'),
            ],
          ),
          const FilledButton(
            buttonType: ButtonType.submit,
            child: Text('Subscribe'),
          ),
          Watch(newsletter.message),
        ],
      ),
    ),
  );
}
// endregion

// region: form-schema
final class SignUp extends FormSchema {
  const SignUp._() : super(const [email, password, age]);

  static const schema = SignUp._();

  static const email = TextSchemaField(
    'email',
    validators: [
      Validator.required('Enter your email.'),
      Validator.email('That email does not look valid.'),
    ],
  );
  static const password = TextSchemaField(
    'password',
    secret: true,
    validators: [Validator.minLength(8, 'Use at least 8 characters.')],
  );
  static const age = IntSchemaField('age', invalid: 'Age is a number.');
}

/// The page's form; [failed] is `state.form` after the server said no.
class SignUpView extends StatelessWidget {
  const SignUpView({super.key, this.failed});

  final Object? failed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 320,
    child: Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          TextFormField(
            field: SignUp.email,
            form: failed,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          TextFormField(
            field: SignUp.password,
            form: failed,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          TextFormField(
            field: SignUp.age,
            form: failed,
            decoration: const InputDecoration(labelText: 'Age (optional)'),
          ),
          const FilledButton(
            buttonType: ButtonType.submit,
            child: Text('Create account'),
          ),
        ],
      ),
    ),
  );
}
// endregion

// region: form-schema-failed
/// After `values.fail('That email already has an account.', SignUp.email)`: what
/// the person typed comes back (never the password) with the message.
class SignUpFailed extends StatelessWidget {
  const SignUpFailed({super.key});

  @override
  Widget build(BuildContext context) => SignUpView(
    failed: FormInvalid(
      errors: {'email': 'That email already has an account.'},
      values: {
        'email': 'ana@example.com',
        'password': 'secret123',
        'age': '31',
      },
    ),
  );
}
// endregion

// region: form-upload
class UploadDemo extends StatelessWidget {
  const UploadDemo({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 320,
    child: Form(
      encoding: FormEncoding.multipart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          TextField(
            name: 'name',
            decoration: InputDecoration(labelText: 'Name'),
          ),
          FileField(
            name: 'cv',
            label: 'CV (PDF)',
            accept: ['application/pdf'],
            required: true,
          ),
          FilledButton(buttonType: ButtonType.submit, child: Text('Submit')),
        ],
      ),
    ),
  );
}
// endregion

// region: form-field-params
class FieldParamsDemo extends StatelessWidget {
  const FieldParamsDemo({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 320,
    child: Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          TextFormField(
            name: 'email',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: [AutofillHints.email],
            decoration: InputDecoration(labelText: 'Email'),
          ),
          TextFormField(
            name: 'phone',
            keyboardType: TextInputType.phone,
            autofillHints: [AutofillHints.telephoneNumber],
            decoration: InputDecoration(labelText: 'Phone'),
          ),
          TextFormField(
            name: 'bio',
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Bio'),
          ),
          TextFormField(
            name: 'price',
            keyboardType: TextInputType.number,
            textAlign: TextAlign.end,
            decoration: InputDecoration(
              labelText: 'Price',
              prefixText: r'$ ',
              suffixText: 'USD',
            ),
          ),
          TextFormField(
            name: 'code',
            readOnly: true,
            initialValue: 'A-2041',
            decoration: InputDecoration(labelText: 'Code'),
          ),
        ],
      ),
    ),
  );
}

// endregion

// region: slider-bubble
class SliderBubbleDemo extends StatelessWidget {
  const SliderBubbleDemo({super.key});

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData(
      sliderTheme: const SliderThemeData(
        showValueIndicator: ShowValueIndicator.alwaysVisible,
      ),
    ),
    child: const SizedBox(
      width: 320,
      child: Slider(
        value: 50,
        min: 10,
        max: 100,
        divisions: 9,
        label: '{}k',
        semanticLabel: 'Visitas al mes',
      ),
    ),
  );
}
// endregion

// region: segmented-pill
class SegmentedPillDemo extends StatelessWidget {
  const SegmentedPillDemo({super.key});

  @override
  Widget build(BuildContext context) => const SegmentedButton<String>(
    segments: [
      ButtonSegment(value: 'monthly', label: Text('Mensual')),
      ButtonSegment(value: 'yearly', label: Text('Anual')),
    ],
    selected: {'monthly'},
    showSelectedIcon: false,
    groupPadding: EdgeInsets.all(4),
    groupColor: Color(0xFFF3F4F6),
    style: ButtonStyle(
      shape: WidgetStatePropertyAll(StadiumBorder()),
      side: WidgetStatePropertyAll(BorderSide.none),
    ),
    selectedStyle: ButtonStyle(
      backgroundColor: WidgetStatePropertyAll(Color(0xFF4F46E5)),
      foregroundColor: WidgetStatePropertyAll(Color(0xFFFFFFFF)),
    ),
  );
}

// endregion
