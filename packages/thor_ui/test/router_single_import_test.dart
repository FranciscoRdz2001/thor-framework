@TestOn('vm')
library;

// A schema file with `router.dart` alone, as in the forms guide
// (`lib/forms.dart`): its validators need no second import.
import 'package:test/test.dart';
import 'package:thor_ui/router.dart';

abstract final class _Deploy {
  static const command = TextSchemaField(
    'command',
    validators: [Validator.required('the command is required')],
  );
  static const schema = FormSchema([command]);
}

void main() {
  test('a schema with validators needs router.dart only', () {
    final result = _Deploy.schema.validate(const FormData({}));
    expect(result, isA<FormInvalid>());
    expect((result as FormInvalid).errors, {
      'command': 'the command is required',
    });
  });
}
