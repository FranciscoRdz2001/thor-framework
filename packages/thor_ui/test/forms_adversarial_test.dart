// Fixture: fields without a label on purpose (focus, state and form behavior).
// ignore_for_file: thor_lints/text_field_without_label
// Adversarial tests for the form scope and the schema fields: what a
// hostile or unusual form
// submission and page can do to the schema fields and the form scope.
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
        : [e.value as String],
});

Future<String> _body(Widget c) async =>
    bodyOfPage(await renderDocument(ThorApp(child: c)));

String _tag(String html, String name) => RegExp(
  '<(?:input|select|textarea)[^>]*name="$name"[^>]*>',
).firstMatch(html)![0]!;

bool _never(FormData d) => false;

class _Model {
  const _Model(this.json);
  final Map<String, Object?> json;
  Map<String, Object?> toJson() => json;
}

void main() {
  setUpAll(initializeThorTests);

  group('a repeated field keeps its item\'s promises', () {
    test('the secret of the item is the secret of the list', () {
      const pins = ListSchemaField(TextSchemaField('pins', secret: true));
      const schema = FormSchema([pins]);
      final r = schema.validate(
        _data({
          'pins': ['1234', '5678'],
        }),
      );
      // A valid parse has nothing to refill; the failure path must not echo.
      final failed = (r as FormValid).fail('no');
      expect(failed.values, isEmpty);
      expect(failed.valueLists, isEmpty);
      expect(pins.secret, isTrue);
    });

    test('the `when` of the item is the `when` of the list', () {
      const tags = ListSchemaField(
        TextSchemaField(
          'tags',
          when: _never,
          validators: [Validator.maxLength(2, 'too long')],
        ),
      );
      const schema = FormSchema([tags]);
      final r = schema.validate(
        _data({
          'tags': ['way too long'],
        }),
      );
      expect(r, isA<FormValid>());
      expect((r as FormValid).of(tags), isEmpty);
    });
  });

  group('an optional list', () {
    test('a blank first entry does not drop the ones after it', () {
      const tags = OptionalSchemaField(
        ListSchemaField(TextSchemaField('tags')),
      );
      const schema = FormSchema([tags]);
      final r = schema.validate(
        _data({
          'tags': ['', 'a', 'b'],
        }),
      );
      expect((r as FormValid).of(tags), ['a', 'b']);
    });
  });

  group('the scope in the page', () {
    test('a NaN or infinite slider value is not written to the DOM', () async {
      for (final bad in ['NaN', 'Infinity', '-Infinity', '1e999', 'abc']) {
        final html = await _body(
          Form(
            failed: FormInvalid(values: {'v': bad}),
            child: Slider(
              name: 'v',
              value: 5,
              min: 0,
              max: 10,
              onChanged: (_) {},
            ),
          ),
        );
        expect(_tag(html, 'v'), isNot(contains('NaN')), reason: bad);
        expect(_tag(html, 'v'), isNot(contains('Infinity')), reason: bad);
      }
    });

    test(
      'a date default that is an ISO date-time fills a date input',
      () async {
        final html = await _body(
          Form(
            defaults: const _Model({'born': '1990-05-03T10:20:30.000Z'}),
            child: TextFormField(
              name: 'born',
              inputAttributes: HtmlAttributes.custom({'type': 'date'}),
            ),
          ),
        );
        expect(_tag(html, 'born'), contains('value="1990-05-03"'));
      },
    );

    test('a password is never echoed, from failed or from defaults', () async {
      final html = await _body(
        Form(
          failed: FormInvalid(values: const {'password': 'hunter2'}),
          defaults: const {'password': 'hunter3', 'confirm': 'hunter4'},
          child: const Column(
            children: [
              TextFormField(name: 'password', obscureText: true),
              TextFormField(name: 'confirm', obscureText: true),
            ],
          ),
        ),
      );
      expect(html, isNot(contains('hunter')));
    });

    test(
      'a field the schema calls secret is hidden and never refilled',
      () async {
        const pw = TextSchemaField('password', secret: true);
        final html = await _body(
          const Form(
            schema: FormSchema([pw]),
            defaults: {'password': 'hunter2'},
            child: TextFormField(name: 'password'),
          ),
        );
        expect(html, isNot(contains('hunter2')));
        expect(_tag(html, 'password'), contains('type="password"'));
      },
    );

    test('a plain TextField the schema calls secret is not refilled', () async {
      const pw = TextSchemaField('password', secret: true);
      final html = await _body(
        const Form(
          schema: FormSchema([pw]),
          defaults: {'password': 'hunter2'},
          child: TextField(name: 'password'),
        ),
      );
      expect(html, isNot(contains('hunter2')));
    });

    test('an ISO date-time default fills a datetime-local input', () async {
      final html = await _body(
        Form(
          defaults: const _Model({'at': '1990-05-03T10:20:30.000Z'}),
          child: TextFormField(
            name: 'at',
            inputAttributes: HtmlAttributes.custom({'type': 'datetime-local'}),
          ),
        ),
      );
      expect(_tag(html, 'at'), contains('value="1990-05-03T10:20"'));
    });

    test(
      'hostile messages and names are escaped in attributes and text',
      () async {
        const evil = '"><img src=x onerror=alert(1)>';
        final html = await _body(
          Form(
            failed: FormInvalid(
              fieldErrors: const {
                'a': [evil],
              },
              values: const {'a': evil},
              formErrors: const [evil],
            ),
            child: const Column(
              children: [
                TextFormField(name: 'a', validator: Validator.required(evil)),
                FormFieldError('a'),
              ],
            ),
          ),
        );
        expect(html, isNot(contains('<img src=x')));
        expect(html, isNot(contains('"><img')));
      },
    );

    test('defaults with nested values do not crash the page', () async {
      final html = await _body(
        Form(
          defaults: {
            'a': {'x': 1},
            'b': [1, 2],
            'c': double.nan,
            'd': double.infinity,
            'e': DateTime.utc(2024, 1, 2, 3),
            'f': null,
          },
          child: const Column(
            children: [
              TextField(name: 'a'),
              TextField(name: 'b'),
              TextField(name: 'c'),
              TextField(name: 'd'),
              TextField(name: 'e'),
              TextField(name: 'f'),
            ],
          ),
        ),
      );
      expect(html, contains('name="e"'));
    });

    test('two forms: the failed of one does not refill the other', () async {
      final html = await _body(
        Column(
          children: [
            Form(
              failed: FormInvalid(
                fieldErrors: const {
                  'email': ['bad'],
                },
                values: const {'email': 'a@b'},
              ),
              child: const TextFormField(
                name: 'email',
                decoration: InputDecoration(labelText: 'A'),
              ),
            ),
            const Form(
              child: TextFormField(
                name: 'email',
                decoration: InputDecoration(labelText: 'B'),
                validator: Validator.required('Required'),
              ),
            ),
          ],
        ),
      );
      expect('a@b'.allMatches(html), hasLength(1));
      expect('aria-invalid="true"'.allMatches(html), hasLength(1));
      // Two fields of one name on a page: one id each (label for, describedby).
      final ids = [
        for (final m in RegExp(r' id="([^"]+)"').allMatches(html)) m[1]!,
      ];
      expect(ids.toSet().length, ids.length, reason: '$ids');
      expect(html, contains('for="f-email-2"'));
      expect(html, contains('aria-describedby="f-email-2-msg"'));
    });

    test('two failing forms: one field takes the focus', () async {
      final f = FormInvalid(
        fieldErrors: const {
          'email': ['bad'],
        },
        values: const {'email': ''},
      );
      final html = await _body(
        Column(
          children: [
            Form(
              failed: f,
              child: const TextFormField(name: 'email'),
            ),
            Form(
              failed: f,
              child: const TextFormField(name: 'email'),
            ),
          ],
        ),
      );
      expect('autofocus'.allMatches(html), hasLength(1));
    });
  });

  group('parsing hostile values', () {
    test(
      'a double is not fooled by rounding, negative zero or huge values',
      () {
        const n = DoubleSchemaField('n');
        const schema = FormSchema([n]);
        for (final (text, ok) in [
          ('-0', true),
          ('1e308', true),
          ('1e309', false),
          ('0.1', true),
          ('1.234,5', false),
          ('1 000', false),
          ('+.5e+1', true),
          ('٣', false),
        ]) {
          final r = schema.validate(_data({'n': text}));
          expect(r is FormValid, ok, reason: text);
        }
      },
    );

    test('a date at the edges', () {
      const d = DateSchemaField('d');
      const schema = FormSchema([d]);
      for (final (text, ok) in [
        ('0000-01-01', false),
        ('0001-01-01', true),
        ('9999-12-31', true),
        ('2024-02-29', true),
        ('2024-13-01', false),
        ('2024-01-01T00:00:00+02:00', false),
        ('2016-12-31T23:59:60Z', false),
        ('2024-01-32', false),
        ('2024-01-01\n', false),
      ]) {
        final r = schema.validate(_data({'d': text}));
        expect(r is FormValid, ok, reason: text);
      }
    });

    test('a huge value is a field error, not a crash', () {
      const n = IntSchemaField('n');
      const t = TextSchemaField(
        't',
        validators: [Validator.maxLength(10, 'long')],
      );
      const schema = FormSchema([n, t]);
      final r = schema.validate(_data({'n': '9' * 100000, 't': 'x' * 1000000}));
      expect(r, isA<FormInvalid>());
      expect((r as FormInvalid).errors.keys, containsAll(['n', 't']));
    });

    test('a closure rule the schema field also has is not a P031', () async {
      const f = TextSchemaField(
        'name',
        validators: [Validator.custom(_noAdmin)],
      );
      final html = await _body(
        const Form(
          schema: FormSchema([f]),
          child: TextFormField(
            name: 'name',
            validator: Validator.custom(_noAdmin),
          ),
        ),
      );
      expect(html, contains('name="name"'));
    });

    test('a closure rule the schema field lacks is still a P031', () async {
      const f = TextSchemaField('name');
      expect(
        () => _body(
          const Form(
            schema: FormSchema([f]),
            child: TextFormField(
              name: 'name',
              validator: Validator.custom(_noAdmin),
            ),
          ),
        ),
        throwsA(predicate((e) => '$e'.contains('THOR-P031'))),
      );
    });

    test('a custom validator that throws is not swallowed as a pass', () {
      const t = TextSchemaField('t', validators: [Validator.custom(_boom)]);
      expect(
        () => const FormSchema([t]).validate(_data({'t': 'x'})),
        throwsA(anything),
      );
    });
  });
}

String? _boom(String v) => throw StateError('boom');

String? _noAdmin(String v) => v == 'admin' ? 'reserved' : null;
