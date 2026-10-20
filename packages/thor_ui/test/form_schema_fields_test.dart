// Fixture: fields without a label on purpose (focus, state and form behavior).
// ignore_for_file: thor_lints/text_field_without_label
// The wide schema. `DoubleSchemaField`, `DateSchemaField`, `optional`,
// `ListSchemaField`, `when:` and `validator:`: server and browser validate
// from one definition, and a bad value is a field error, never a 500.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

FormData _data(Map<String, Object> fields) => FormData({
  for (final e in fields.entries)
    e.key: e.value is List
        ? List<String>.from(e.value as List)
        : ['${e.value}'],
});

FormResult _run(FormSchema schema, Map<String, Object> fields) =>
    schema.validate(_data(fields));

String? _error(FormResult r, SchemaField<Object?> f) =>
    r is FormInvalid ? r.errors[f.name] : null;

Future<String> _body(Widget c) async =>
    bodyOfPage(await renderDocument(ThorApp(child: c)));

bool _creating(FormData data) => (data['id'] ?? '').isEmpty;

abstract final class _F {
  static const price = DoubleSchemaField(
    'price',
    validators: [
      Validator.min(0, 'no negatives'),
      Validator.max(1000, 'too much'),
    ],
    invalid: 'price is a number',
  );
  static const born = DateSchemaField(
    'born',
    validators: [
      Validator.minDate('1900-01-01', 'too old'),
      Validator.maxDate('2100-12-31', 'too far'),
    ],
    invalid: 'a real date',
  );
  static const bio = OptionalSchemaField(TextSchemaField('bio'));
  static const nick = OptionalSchemaField(
    TextSchemaField(
      'nick',
      validators: [Validator.minLength(3, 'nick is short')],
    ),
  );
  static const size = OptionalSchemaField(
    ChoiceSchemaField('size', choices: ['s', 'm']),
  );
  static const tags = ListSchemaField(
    TextSchemaField(
      'tags',
      validators: [Validator.maxLength(5, 'tag is long')],
    ),
  );
  static const picks = ListSchemaField(
    IntSchemaField('picks', invalid: 'a number'),
    min: 1,
    max: 3,
    tooFew: 'pick one',
    tooMany: 'at most three',
  );
  static const password = TextSchemaField(
    'password',
    validators: [Validator.required('password is required')],
    when: _creating,
  );
  static const id = TextSchemaField('id');
  static const schema = FormSchema([
    price,
    born,
    bio,
    nick,
    size,
    tags,
    picks,
    password,
    id,
  ]);
}

const _ok = <String, Object>{
  'price': '9.5',
  'born': '1990-05-03',
  'picks': ['1'],
  'password': 'x',
};

FormResult _check([
  Map<String, Object> changes = const {},
  Set<String> drop = const {},
]) => _run(_F.schema, {
  for (final e in {..._ok, ...changes}.entries)
    if (!drop.contains(e.key)) e.key: e.value,
});

void main() {
  setUpAll(initializeThorTests);

  group('DoubleSchemaField', () {
    test('parses decimals, exponents and negatives', () {
      for (final (text, value) in [
        ('3.5', 3.5),
        ('-2', -2.0),
        ('.5', 0.5),
        ('1e2', 100.0),
        ('1E-2', 0.01),
        ('  7 ', 7.0),
        ('5.', 5.0),
      ]) {
        const free = DoubleSchemaField('n');
        final r = _run(const FormSchema([free]), {'n': text}) as FormValid;
        expect(r.of(free), value, reason: text);
      }
    });

    test('empty is null, not an error', () {
      final r = _check({'price': ''}) as FormValid;
      expect(r.of(_F.price), isNull);
    });

    test(
      'what Dart parses but a number input never sends is a field error',
      () {
        for (final bad in [
          'abc',
          'NaN',
          'Infinity',
          '-Infinity',
          '0x10',
          '1_0',
          '1,5',
          '1e999',
          '--1',
          '1.2.3',
          '١٢', // Arabic-Indic digits
        ]) {
          expect(
            _error(_check({'price': bad}), _F.price),
            'price is a number',
            reason: bad,
          );
        }
      },
    );

    test('the range is checked after the type', () {
      expect(_error(_check({'price': '-0.1'}), _F.price), 'no negatives');
      expect(_error(_check({'price': '1000.5'}), _F.price), 'too much');
      expect(_error(_check({'price': '1000'}), _F.price), isNull);
    });

    test('its native attributes', () {
      expect(_F.price.attributes, {
        'type': 'number',
        'step': 'any',
        'min': '0',
        'max': '1000',
      });
    });
  });

  test('a whole number gets the digits keyboard, a decimal one the decimal '
      'keyboard', () async {
    final whole = await _body(
      const TextFormField(field: IntSchemaField('age')),
    );
    expect(whole, contains('inputmode="numeric"'));
    final decimal = await _body(const TextFormField(field: _F.price));
    expect(decimal, contains('inputmode="decimal"'));
  });

  group('IntSchemaField is as strict as the number input', () {
    test('hex and binary literals are not whole numbers', () {
      const age = IntSchemaField('age', invalid: 'a number');
      const schema = FormSchema([age]);
      for (final bad in ['0x1A', '0b1', '1_000', '9223372036854775808']) {
        expect(
          _error(_run(schema, {'age': bad}), age),
          'a number',
          reason: bad,
        );
      }
      expect((_run(schema, {'age': '-12'}) as FormValid).of(age), -12);
    });
  });

  group('DateSchemaField', () {
    test('a real date is a UTC DateTime', () {
      final r = _check({'born': '2024-02-29'}) as FormValid;
      expect(r.of(_F.born), DateTime.utc(2024, 2, 29));
    });

    test('empty is null', () {
      expect((_check({'born': ''}) as FormValid).of(_F.born), isNull);
    });

    test('an impossible or oddly written date is a field error, not a 500', () {
      for (final bad in [
        '2023-02-29',
        '2024-13-01',
        '2024-00-10',
        '2024-04-31',
        '2024-1-1',
        '20240101',
        '2024-01-01T10:00',
        'yesterday',
        '2024-01-01 ',
        '99999999-01-01',
        '2024/01/01',
      ]) {
        final r = _check({'born': bad});
        expect(r, isA<FormInvalid>(), reason: bad);
        expect(_error(r, _F.born), 'a real date', reason: bad);
      }
    });

    test('a leap day only exists in a leap year', () {
      expect(_check({'born': '2000-02-29'}), isA<FormValid>());
      expect(_check({'born': '1900-02-29'}), isA<FormInvalid>());
    });

    test('min and max compare dates', () {
      expect(_error(_check({'born': '1899-12-31'}), _F.born), 'too old');
      expect(_error(_check({'born': '2101-01-01'}), _F.born), 'too far');
      expect(_check({'born': '1900-01-01'}), isA<FormValid>());
    });

    test('its native attributes', () {
      expect(_F.born.attributes, {
        'type': 'date',
        'min': '1900-01-01',
        'max': '2100-12-31',
      });
    });
  });

  group('optional', () {
    test('empty is null; a value is the value', () {
      final empty = _check({'bio': '', 'size': ''}) as FormValid;
      expect(empty.of(_F.bio), isNull);
      expect(empty.of(_F.size), isNull);
      final absent = _check() as FormValid;
      expect(absent.of(_F.bio), isNull);
      final full = _check({'bio': 'hi', 'size': 'm'}) as FormValid;
      expect(full.of(_F.bio), 'hi');
      expect(full.of(_F.size), 'm');
    });

    test('its rules apply only when there is a value', () {
      expect(_check({'nick': ''}), isA<FormValid>());
      expect(_error(_check({'nick': 'ab'}), _F.nick), 'nick is short');
      expect(
        _error(_check({'size': 'xl'}), _F.size),
        'Choose one of the options.',
      );
    });

    test('an optional field can not also be required (THOR-P032)', () {
      const bad = OptionalSchemaField(
        TextSchemaField('x', validators: [Validator.required('r')]),
      );
      expect(
        () => _run(const FormSchema([bad]), {'x': ''}),
        throwsA(predicate((e) => '$e'.contains('THOR-P032'))),
      );
    });

    test('the browser does not require it', () {
      expect(_F.nick.attributes, {'minlength': '3'});
    });
  });

  group('ListSchemaField', () {
    test('every value, in the order they came, unicode included', () {
      final r =
          _check({
                'tags': ['b', 'a', 'ñu', '日本'],
              })
              as FormValid;
      expect(r.of(_F.tags), ['b', 'a', 'ñu', '日本']);
    });

    test('none is an empty list', () {
      expect((_check() as FormValid).of(_F.tags), isEmpty);
    });

    test('blank entries are skipped, not errors', () {
      final r =
          _check({
                'tags': ['a', '', 'b', ''],
              })
              as FormValid;
      expect(r.of(_F.tags), ['a', 'b']);
    });

    test('each item is checked with the item rules, all messages listed', () {
      final r = _check({
        'tags': ['ok', 'toolong1', 'fine', 'toolong2'],
      });
      final failed = r as FormInvalid;
      expect(failed.errorsOf('tags'), ['tag is long', 'tag is long']);
      expect(failed.valueLists['tags'], ['ok', 'toolong1', 'fine', 'toolong2']);
    });

    test('typed items', () {
      final r =
          _check({
                'picks': ['3', '1'],
              })
              as FormValid;
      expect(r.of(_F.picks), [3, 1]);
      final bad = _check({
        'picks': ['1', 'x'],
      });
      expect(_error(bad, _F.picks), 'a number');
    });

    test('min and max count the items', () {
      expect(_error(_check({}, {'picks'}), _F.picks), 'pick one');
      expect(
        _error(
          _check({
            'picks': ['1', '2', '3', '4'],
          }),
          _F.picks,
        ),
        'at most three',
      );
      expect(
        _check({
          'picks': ['1', '2', '3'],
        }),
        isA<FormValid>(),
      );
    });

    test('a very long list stays a list', () {
      final r =
          _check({
                'tags': [for (var i = 0; i < 10000; i++) 'a'],
              })
              as FormValid;
      expect(r.of(_F.tags), hasLength(10000));
    });

    test('a failed list refills every item', () async {
      final r =
          _check({
                'tags': ['a', 'toolong'],
                'price': 'x',
              })
              as FormInvalid;
      final scope = FormScope(failed: r, child: const SizedBox());
      expect(scope.valuesOf('tags'), ['a', 'toolong']);
    });
  });

  test(
    'a posted body keeps the order of repeated keys and decodes unicode',
    () {
      final data = FormData.parse(
        'tags=b&price=1&tags=a&tags=%C3%B1&tags=%E6%97%A5',
      );
      final r = _F.schema.validate(data);
      expect(r, isA<FormInvalid>()); // the other fields are missing: ok
      expect((r as FormInvalid).valueLists['tags'], ['b', 'a', 'ñ', '日']);
      final ok = FormData.parse(
        'price=2&born=2000-01-01&picks=1&password=x&tags=b&tags=a&tags=%C3%B1',
      );
      expect((_F.schema.validate(ok) as FormValid).of(_F.tags), [
        'b',
        'a',
        'ñ',
      ]);
    },
  );

  group('when:', () {
    test('the rules apply when the condition holds (creating)', () {
      expect(
        _error(_check({}, {'password'}), _F.password),
        'password is required',
      );
    });

    test('and not when it does not (editing)', () {
      final r = _check({'id': '7'}, {'password'}) as FormValid;
      expect(r.of(_F.password), '');
    });

    test('an inactive field yields its empty value, whatever was sent', () {
      const age = IntSchemaField('age', invalid: 'a number', when: _creating);
      const schema = FormSchema([age, _F.id]);
      final r = _run(schema, {'id': '5', 'age': 'garbage'});
      expect(r, isA<FormValid>());
      expect((r as FormValid).of(age), isNull);
      expect(_run(schema, {'age': 'garbage'}), isA<FormInvalid>());
    });

    test(
      'a conditional field is not required in the browser by default',
      () async {
        expect(_F.password.attributes, {'required': ''});
        final creating = await _body(
          const TextFormField(field: _F.password, applies: true),
        );
        final editing = await _body(const TextFormField(field: _F.password));
        expect(creating, contains('required'));
        expect(editing, isNot(contains('required')));
      },
    );
  });

  group('validator:', () {
    test('a single Validator sets the native rule', () async {
      final html = await _body(
        const TextFormField(name: 'e', validator: Validator.email('bad')),
      );
      expect(html, contains('type="email"'));
      expect(html, contains('data-msg-typemismatch="bad"'));
    });

    test('Validator.all is a list of rules, in order', () async {
      final html = await _body(
        const TextFormField(
          name: 'e',
          validator: Validator.all([
            Validator.required('need'),
            Validator.minLength(3, 'short'),
          ]),
        ),
      );
      expect(html, contains('required'));
      expect(html, contains('minlength="3"'));
      expect(html, contains('data-msg-valuemissing="need"'));
      expect(html, contains('data-msg-tooshort="short"'));
    });

    test('validator: and validators: add up', () async {
      final html = await _body(
        const TextFormField(
          name: 'e',
          validator: Validator.required('need'),
          validators: [Validator.maxLength(4, 'long')],
        ),
      );
      expect(html, contains('required'));
      expect(html, contains('maxlength="4"'));
    });

    test('Validator.all inside a schema field validates on the server', () {
      const f = TextSchemaField(
        'p',
        validators: [
          Validator.all([
            Validator.required('need'),
            Validator.minLength(3, 'short'),
          ]),
        ],
      );
      const s = FormSchema([f]);
      expect(_error(_run(s, {'p': ''}), f), 'need');
      expect(_error(_run(s, {'p': 'ab'}), f), 'short');
      expect(_run(s, {'p': 'abc'}), isA<FormValid>());
    });

    test('a closure rule outside a schema is an error, not a silent skip', () {
      expect(
        _body(
          TextFormField(
            name: 'x',
            validator: Validator.custom((v) => v == 'a' ? 'no' : null),
          ),
        ),
        throwsA(predicate((e) => '$e'.contains('THOR-P031'))),
      );
    });

    test(
      'a closure rule of a schema field is fine (the server runs it)',
      () async {
        const f = TextSchemaField(
          'name',
          validators: [Validator.custom(_noAdmin)],
        );
        final html = await _body(const TextFormField(field: f));
        expect(html, contains('name="name"'));
        expect(html, isNot(contains('data-msg-customerror')));
      },
    );

    test('a closure rule in a Form(schema:) that has it is fine', () async {
      const f = TextSchemaField(
        'name',
        validators: [Validator.custom(_noAdmin)],
      );
      final html = await _body(
        const Form(
          schema: FormSchema([f]),
          child: TextFormField(name: 'name'),
        ),
      );
      expect(html, contains('name="name"'));
    });
  });
}

String? _noAdmin(String v) => v == 'admin' ? 'taken' : null;
