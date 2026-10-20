// A schema field without a decoration: the label is not what these tests check.
// ignore_for_file: thor_lints/text_field_without_label
@TestOn('vm')
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

String? _noAdmin(String value) =>
    value.toLowerCase() == 'admin' ? 'that name is taken' : null;

abstract final class _SignUp {
  static const name = TextSchemaField(
    'name',
    validators: [
      Validator.required('name is required'),
      Validator.minLength(3, 'name is too short'),
      Validator.maxLength(8, 'name is too long'),
      Validator.custom(_noAdmin),
    ],
  );
  static const email = TextSchemaField(
    'email',
    validators: [
      Validator.required('email is required'),
      Validator.email('email is invalid'),
    ],
  );
  static const password = TextSchemaField(
    'password',
    secret: true,
    validators: [Validator.required('password is required')],
  );
  static const code = TextSchemaField(
    'code',
    validators: [Validator.pattern('[a-z]{2}\\d', 'code is ab1')],
  );
  static const age = IntSchemaField(
    'age',
    validators: [Validator.min(18, 'too young'), Validator.max(120, 'too old')],
    invalid: 'age is a number',
  );
  static const terms = CheckboxSchemaField(
    'terms',
    validators: [Validator.required('accept the terms')],
  );
  static const plan = ChoiceSchemaField(
    'plan',
    choices: ['free', 'pro'],
    invalid: 'pick a plan',
  );
  static const schema = FormSchema([
    name,
    email,
    password,
    code,
    age,
    terms,
    plan,
  ]);
}

FormData _data(Map<String, String> fields) => FormData({
  for (final e in fields.entries) e.key: [e.value],
});

const _ok = {
  'name': 'ana',
  'email': 'ana@example.com',
  'password': 'secret',
  'terms': 'on',
  'plan': 'pro',
};

FormResult _check(Map<String, String> changes, {Set<String> drop = const {}}) =>
    _SignUp.schema.validate(
      _data({
        for (final e in {..._ok, ...changes}.entries)
          if (!drop.contains(e.key)) e.key: e.value,
      }),
    );

String? _error(FormResult r, SchemaField<Object?> f) =>
    r is FormInvalid ? r.errors[f.name] : null;

void main() {
  setUpAll(initializeThorTests);

  group('the server checks what the browser checks', () {
    test('a valid form gives typed values', () {
      final r = _check({'age': '30', 'code': 'ab1'});
      expect(r, isA<FormValid>());
      final v = r as FormValid;
      expect(v.of(_SignUp.name), 'ana');
      expect(v.of(_SignUp.age), 30);
      expect(v.of(_SignUp.terms), isTrue);
      expect(v.of(_SignUp.plan), 'pro');
    });

    test('an absent field and an empty one are both missing', () {
      expect(
        _error(_check({}, drop: {'email'}), _SignUp.email),
        'email is required',
      );
      expect(_error(_check({'email': ''}), _SignUp.email), 'email is required');
    });

    test('only spaces is not missing (like `required` in the browser)', () {
      // The browser accepts it; the server must not disagree silently.
      expect(_error(_check({'name': '   '}), _SignUp.name), isNull);
    });

    test('an e-mail is trimmed like the browser does (type=email)', () {
      // curl, an autofill or a paste keeps the spaces; the browser's value
      // sanitization strips them from type=email.
      final r = _check({'email': '  ana@x.com \t'});
      expect(r, isA<FormValid>());
      expect((r as FormValid).of(_SignUp.email), 'ana@x.com');
    });

    test('trim: true trims any text before the rules and in the result', () {
      const field = TextSchemaField(
        'name',
        trim: true,
        validators: [
          Validator.required('name is required'),
          Validator.minLength(3, 'name is too short'),
        ],
      );
      const schema = FormSchema([field]);
      final ok = schema.validate(_data({'name': '  ana  '}));
      expect((ok as FormValid).of(field), 'ana');
      // The spaces don't count toward the length.
      expect((schema.validate(_data({'name': ' an '})) as FormInvalid).errors, {
        'name': 'name is too short',
      });
      // Only spaces is empty once trimmed.
      expect((schema.validate(_data({'name': '   '})) as FormInvalid).errors, {
        'name': 'name is required',
      });
    });

    test(
      'plain text keeps its spaces unless trim is set; trim: false wins',
      () {
        const keep = TextSchemaField('a');
        final kept = const FormSchema([keep]).validate(_data({'a': ' x '}));
        expect((kept as FormValid).of(keep), ' x ');
        const raw = TextSchemaField(
          'e',
          trim: false,
          validators: [Validator.email('bad')],
        );
        final bad = const FormSchema([raw]).validate(_data({'e': ' a@b.co'}));
        expect((bad as FormInvalid).errors, {'e': 'bad'});
      },
    );

    test('a secret is never trimmed by default', () {
      const pass = TextSchemaField('p', secret: true);
      final r = const FormSchema([pass]).validate(_data({'p': ' pw '}));
      expect((r as FormValid).of(pass), ' pw ');
    });

    test('trim handles unicode whitespace the way Dart does', () {
      const e = TextSchemaField('e', validators: [Validator.email('bad')]);
      const schema = FormSchema([e]);
      // NBSP, ideographic space and BOM are trimmed (the browser would keep
      // the NBSP; being kinder is harmless for an address).
      final ok = schema.validate(_data({'e': '\u00A0\u3000a@b.co\uFEFF'}));
      expect((ok as FormValid).of(e), 'a@b.co');
      // A zero-width space is not whitespace: it stays and fails the rule.
      expect(
        (schema.validate(_data({'e': '\u200Ba@b.co'})) as FormInvalid).errors,
        {'e': 'bad'},
      );
    });

    test('an optional e-mail of only spaces is null, not invalid', () {
      const e = OptionalSchemaField(
        TextSchemaField('e', validators: [Validator.email('bad')]),
      );
      final r = const FormSchema([e]).validate(_data({'e': '  \u00A0 '}));
      expect(r, isA<FormValid>());
      expect((r as FormValid).of(e), isNull);
    });

    test('trim: true on a secret trims it (asked for)', () {
      const p = TextSchemaField('p', secret: true, trim: true);
      final r = const FormSchema([p]).validate(_data({'p': ' pw '}));
      expect((r as FormValid).of(p), 'pw');
    });

    test('a list of e-mails skips entries that are blank once trimmed', () {
      const to = ListSchemaField(
        TextSchemaField('to', validators: [Validator.email('bad')]),
      );
      final r = const FormSchema([to]).validate(
        const FormData({
          'to': [' a@b.co ', '   ', '', 'c@d.co'],
        }),
      );
      expect(r, isA<FormValid>());
      expect((r as FormValid).of(to), ['a@b.co', 'c@d.co']);
    });

    test('an empty optional field passes its other rules', () {
      final r = _check({'code': '', 'age': ''});
      expect(r, isA<FormValid>());
      expect((r as FormValid).of(_SignUp.age), isNull);
    });

    test('lengths count a submitted line break as one character', () {
      expect(_error(_check({'name': 'ab\r\ncdefg'}), _SignUp.name), isNull);
      expect(
        _error(_check({'name': 'ab\r\ncdefgh'}), _SignUp.name),
        'name is too long',
      );
      expect(_error(_check({'name': 'ab'}), _SignUp.name), 'name is too short');
    });

    test('the first failing rule of a field is its message', () {
      // Too short and taken: the first rule in the list wins.
      expect(_error(_check({'name': 'ad'}), _SignUp.name), 'name is too short');
    });

    test('a pattern must match the whole value', () {
      expect(_error(_check({'code': 'ab1'}), _SignUp.code), isNull);
      expect(_error(_check({'code': 'xab1'}), _SignUp.code), 'code is ab1');
      expect(_error(_check({'code': 'ab12'}), _SignUp.code), 'code is ab1');
    });

    test("e-mail follows the HTML spec's rule", () {
      for (final ok in ['a@b', 'a.b+c@d-e.fg', "o'neil@x.io"]) {
        expect(
          _error(_check({'email': ok}), _SignUp.email),
          isNull,
          reason: ok,
        );
      }
      for (final bad in ['a@', '@b', 'a b@c', 'a@b..c', 'a@-b.c', 'a@b_c']) {
        expect(
          _error(_check({'email': bad}), _SignUp.email),
          'email is invalid',
          reason: bad,
        );
      }
    });

    test('a number: not a number is its own message, before the range', () {
      expect(_error(_check({'age': 'ten'}), _SignUp.age), 'age is a number');
      expect(_error(_check({'age': '1.5'}), _SignUp.age), 'age is a number');
      expect(_error(_check({'age': '17'}), _SignUp.age), 'too young');
      expect(_error(_check({'age': '121'}), _SignUp.age), 'too old');
      expect(_error(_check({'age': '18'}), _SignUp.age), isNull);
    });

    test('a required checkbox must be sent checked', () {
      expect(
        _error(_check({}, drop: {'terms'}), _SignUp.terms),
        'accept the terms',
      );
      expect((_check({}) as FormValid).of(_SignUp.terms), isTrue);
    });

    test('a choice outside the options is refused (a tampered form)', () {
      expect(
        _error(_check({'plan': 'enterprise'}), _SignUp.plan),
        'pick a plan',
      );
    });

    test('a custom rule runs only on the server', () {
      expect(
        _error(_check({'name': 'Admin'}), _SignUp.name),
        'that name is taken',
      );
    });
  });

  group('a failure', () {
    test('lists messages in schema order and never re-fills a secret', () {
      final r =
          _check({'email': 'nope', 'name': 'x'}, drop: {'terms'})
              as FormInvalid;
      expect(r.messages, [
        'name is too short',
        'email is invalid',
        'accept the terms',
      ]);
      expect(r.values['email'], 'nope');
      expect(r.values.containsKey('password'), isFalse);
      expect(_SignUp.password.value(r), isNull);
      expect(_SignUp.email.value(r), 'nope');
      expect(_SignUp.email.error(r), 'email is invalid');
    });

    test('a failed form returned as is from an action is a 422', () {
      // A plain `return values.fail('…');` used to answer 200 and dropped the
      // messages.
      final v = _check({}) as FormValid;
      final refused = v.fail('email is taken', _SignUp.email);
      final ActionOutcome outcome = refused;
      expect(outcome.actionResult.status, 422);
      expect(outcome.actionResult.data, same(refused));
    });

    test('the backend can refuse a valid form, keeping the values', () {
      final v = _check({}) as FormValid;
      expect(v.fail().messages, isEmpty);
      expect(v.fail().values['name'], 'ana');
      final general = v.fail('server is down');
      expect(general.formErrors, ['server is down']);
      expect(general.values['email'], 'ana@example.com');
      final field = v.fail('email is taken', _SignUp.email);
      expect(field.errors, {'email': 'email is taken'});
      expect(field.messages, ['email is taken']);
      final result = field.fail();
      expect(result.status, 422);
      expect(result.data, same(field));
    });

    test('reading a field of another schema is an error', () {
      final v = _check({}) as FormValid;
      expect(
        () => v.of(const TextSchemaField('other')),
        throwsA(
          isA<ArgumentError>().having(
            (e) => '${e.message}',
            'message',
            contains('THOR-P007'),
          ),
        ),
      );
    });

    test('anything else than a FormInvalid shows nothing', () {
      expect(_SignUp.email.value(null), isNull);
      expect(_SignUp.email.error({'email': 'x'}), isNull);
    });
  });

  test('parse reads the posted form of a request', () async {
    final request = PageRequest(
      method: HttpMethod.post,
      uri: Uri.parse('http://site.test/join'),
      headers: {HttpHeader.contentType: 'application/x-www-form-urlencoded'},
      body: Stream.value(
        utf8.encode('name=ana&email=bad&password=x&terms=on&plan=free'),
      ),
    );
    final r = await _SignUp.schema.parse(request);
    expect((r as FormInvalid).errors, {'email': 'email is invalid'});
  });

  group('render', () {
    test('fields give the native attributes of their rules', () {
      expect(_SignUp.email.attributes, {'required': '', 'type': 'email'});
      expect(_SignUp.age.attributes, {
        'type': 'number',
        'step': '1',
        'min': '18',
        'max': '120',
      });
      // A server-only rule adds nothing.
      expect(_SignUp.name.attributes, {
        'required': '',
        'minlength': '3',
        'maxlength': '8',
      });
    });

    test(
      'a TextFormField re-fills, shows the message and marks invalid',
      () async {
        final failure = _check({'email': 'nope'}) as FormInvalid;
        final html = bodyOfPage(
          await renderDocument(
            ThorApp(
              child: TextFormField(field: _SignUp.email, form: failure),
            ),
          ),
        );
        expect(html, contains('value="nope"'));
        expect(html, contains('type="email"'));
        expect(html, contains('required'));
        expect(html, contains('aria-invalid="true"'));
        expect(html, contains('email is invalid'));
      },
    );

    test('a multi-line field is a textarea with its text, rules and '
        'message', () async {
      final failure = _check({'name': 'ab\ncd efgh'}) as FormInvalid;
      final html = bodyOfPage(
        await renderDocument(
          ThorApp(
            child: TextFormField(
              field: _SignUp.name,
              form: failure,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Message'),
            ),
          ),
        ),
      );
      expect(html, contains('<textarea'));
      expect(html, isNot(contains('<input')));
      expect(html, contains('rows="5"'));
      expect(html, contains('>ab\ncd efgh</textarea>'));
      expect(html, contains('id="f-name"'));
      expect(html, contains('for="f-name"'));
      expect(html, contains('minlength="3"'));
      expect(html, contains('aria-invalid="true"'));
      expect(html, contains('aria-describedby="f-name-msg"'));
      expect(html, matches(RegExp(r'id="f-name-msg"[^>]*>[^<]*too long<')));
    });

    test('a secret field is never re-filled in the page', () async {
      final failure = FormInvalid(values: {'password': 'hunter2'});
      final html = bodyOfPage(
        await renderDocument(
          ThorApp(
            child: TextFormField(field: _SignUp.password, form: failure),
          ),
        ),
      );
      expect(html, isNot(contains('hunter2')));
      expect(html, contains('type="password"'));
    });

    test(
      'an edit form shows the saved value until a submission fails',
      () async {
        Future<String> field(SchemaField<Object?> f, {Object? form}) async =>
            bodyOfPage(
              await renderDocument(
                ThorApp(
                  child: TextFormField(
                    field: f,
                    form: form,
                    initialValue: 'saved',
                  ),
                ),
              ),
            );
        // GET: no submission, the saved value.
        expect(await field(_SignUp.email), contains('value="saved"'));
        // A 422: what was typed wins, even empty.
        final failure = _check({'email': 'nope'}) as FormInvalid;
        final refilled = await field(_SignUp.email, form: failure);
        expect(refilled, contains('value="nope"'));
        expect(refilled, isNot(contains('saved')));
        final emptied = _check({'email': ''}) as FormInvalid;
        expect(
          await field(_SignUp.email, form: emptied),
          isNot(contains('saved')),
        );
        // A secret is never pre-filled.
        expect(await field(_SignUp.password), isNot(contains('saved')));
      },
    );

    test('a server-only rule emits no browser message', () async {
      final html = bodyOfPage(
        await renderDocument(
          const ThorApp(child: TextFormField(field: _SignUp.name)),
        ),
      );
      expect(html, isNot(contains('data-msg-customerror')));
      expect(html, contains('data-msg-toolong="name is too long"'));
    });
  });
}
