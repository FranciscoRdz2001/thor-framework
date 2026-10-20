import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

/// The saved record of `/edit`, in memory.
final Map<String, Object?> savedRecord = {
  'id': '7',
  'name': 'Saved name',
  'price': 9.5,
  'born': DateTime.utc(1990, 5, 3),
  'plan': 'pro',
  'terms': true,
  'tags': ['x', 'y'],
};

bool _creating(FormData data) => (data['id'] ?? '').isEmpty;

/// The wide schema: double, date, optional, list, conditional.
final class RecordForm extends FormSchema {
  const RecordForm._()
    : super(const [id, name, price, born, nick, tags, plan, terms, secret]);

  static const schema = RecordForm._();

  static const id = TextSchemaField('id');
  static const name = TextSchemaField(
    'name',
    validators: [
      Validator.required('Name is required.'),
      Validator.custom(_notTaken),
    ],
  );
  static const price = DoubleSchemaField(
    'price',
    validators: [Validator.min(0, 'No negatives.')],
    invalid: 'Price is a number.',
  );
  static const born = DateSchemaField(
    'born',
    invalid: 'Not a real date.',
    validators: [Validator.minDate('1900-01-01', 'Too old.')],
  );
  static const nick = OptionalSchemaField(
    TextSchemaField(
      'nick',
      validators: [Validator.minLength(3, 'Nick is short.')],
    ),
  );
  static const tags = ListSchemaField(
    TextSchemaField(
      'tags',
      validators: [Validator.maxLength(5, 'Tag too long.')],
    ),
    max: 3,
    tooMany: 'At most three tags.',
  );
  static const plan = ChoiceSchemaField('plan', choices: ['free', 'pro']);
  static const terms = CheckboxSchemaField(
    'terms',
    validators: [Validator.required('Accept the terms.')],
  );
  // Only when creating.
  static const secret = TextSchemaField(
    'secret',
    when: _creating,
    validators: [Validator.required('A secret is needed to create.')],
  );
}

String? _notTaken(String v) => v == 'taken' ? 'That name is taken.' : null;

/// `/edit`: an edit form that refills from the record, then from what
/// was sent.
class RecordEditPage extends ThorPage<void> {
  const RecordEditPage();

  @override
  PageMeta meta(PageState<void> state) => const PageMeta(title: 'Editar');

  Future<ActionResult?> save(
    PageRequest request,
    FormValues<RecordForm> values,
  ) async {
    savedRecord
      ..['name'] = values.of(RecordForm.name)
      ..['price'] = values.of(RecordForm.price)
      ..['born'] = values.of(RecordForm.born)
      ..['plan'] = values.of(RecordForm.plan)
      ..['terms'] = values.of(RecordForm.terms)
      ..['tags'] = values.of(RecordForm.tags);
    return null;
  }

  @override
  Widget build(BuildContext context, PageState<void> state) {
    final creating = state.request.queryParameters['new'] == '1';
    return Form(
      schema: RecordForm.schema,
      onValid: save,
      failed: state.form,
      defaults: creating ? const <String, Object?>{} : savedRecord,
      noValidate: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          HiddenField(name: 'id', value: creating ? '' : '7'),
          const TextFormField(
            name: 'name',
            decoration: InputDecoration(labelText: 'Nombre'),
          ),
          const TextFormField(
            name: 'price',
            decoration: InputDecoration(labelText: 'Precio'),
          ),
          TextFormField(
            name: 'born',
            decoration: const InputDecoration(labelText: 'Nacimiento'),
            inputAttributes: HtmlAttributes.custom({'type': 'date'}),
          ),
          const TextFormField(
            name: 'nick',
            decoration: InputDecoration(labelText: 'Apodo'),
          ),
          const TextFormField(
            name: 'tags',
            decoration: InputDecoration(labelText: 'Etiqueta 1'),
          ),
          const DropdownButton<String>(
            name: 'plan',
            value: 'free',
            items: [
              DropdownMenuItem(value: 'free', child: Text('free')),
              DropdownMenuItem(value: 'pro', child: Text('pro')),
            ],
          ),
          const Checkbox(name: 'terms', value: false),
          const FormFieldError('terms'),
          if (creating)
            const TextFormField(
              name: 'secret',
              decoration: InputDecoration(labelText: 'Secreto'),
              validators: [],
            ),
          FilledButton(
            buttonType: ButtonType.submit,
            onPressed: () {},
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
