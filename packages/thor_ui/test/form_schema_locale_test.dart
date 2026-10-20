@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  const schema = FormSchema([
    IntSchemaField('age'),
    ChoiceSchemaField('kind', choices: ['a']),
    IntSchemaField('own', invalid: 'Mine'),
  ]);
  const bad = FormData({
    'age': ['x'],
    'kind': ['z'],
    'own': ['y'],
  });

  Map<String, String> messages(Locale? locale) =>
      (schema.validate(bad, locale: locale) as FormInvalid).errors;

  test('default messages follow the locale at validation time', () {
    expect(messages(null)['age'], 'Enter a whole number.');
    expect(messages(const Locale('es'))['age'], 'Introduce un número entero.');
    expect(messages(const Locale('es'))['kind'], 'Elige una de las opciones.');
    expect(messages(const Locale('fr'))['kind'], 'Choose one of the options.');
  });

  test('an explicit invalid: message is kept', () {
    expect(messages(const Locale('es'))['own'], 'Mine');
  });
}
