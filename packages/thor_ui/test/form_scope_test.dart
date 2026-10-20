// Fixture: fields without a label on purpose (focus, state and form behavior).
// ignore_for_file: thor_lints/text_field_without_label
// A `Form(failed:, defaults:, noValidate:)` gives its named fields their
// value and their message; the fields read them from a `FormScope`, so the
// page writes no `_v(...)` per field.
@TestOn('vm')
library;

import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _body(Widget c) async =>
    bodyOfPage(await renderDocument(ThorApp(child: c)));

/// The opening tag of the control named [name] (`<input`, `<select`, …).
String _tag(String html, String name) => RegExp(
  '<(?:input|select|textarea)[^>]*name="$name"[^>]*>',
).firstMatch(html)![0]!;

class _Person {
  const _Person(this.name, this.age, this.admin, this.born);
  final String name;
  final int age;
  final bool admin;
  final DateTime born;
  Map<String, Object?> toJson() => {
    'name': name,
    'age': age,
    'admin': admin,
    'born': born,
  };
}

void main() {
  setUpAll(initializeThorTests);

  group('the value of a field', () {
    test('a failed form refills each named field with what was sent', () async {
      final failed = FormInvalid(values: {'name': 'Ana', 'bio': 'a\nb'});
      final html = await _body(
        Form(
          failed: failed,
          child: const Column(
            children: [
              TextField(name: 'name'),
              TextFormField(name: 'bio', maxLines: 3),
            ],
          ),
        ),
      );
      expect(_tag(html, 'name'), contains('value="Ana"'));
      expect(html, contains('>a\nb</textarea>'));
    });

    test('hostile and unicode values are escaped, not executed', () async {
      const evil = '"><script>alert(1)</script> ñandú 日本 \u{1F600}';
      final html = await _body(
        Form(
          failed: FormInvalid(values: const {'q': evil}),
          child: const TextField(name: 'q'),
        ),
      );
      expect(html, isNot(contains('<script>alert')));
      expect(html, contains('&lt;script&gt;alert(1)'));
      expect(html, contains('ñandú 日本 \u{1F600}'));
    });

    test('defaults fill an edit form (a Map)', () async {
      final html = await _body(
        const Form(
          defaults: {'name': 'Ana', 'age': 30},
          child: Column(
            children: [
              TextField(name: 'name'),
              TextFormField(name: 'age'),
            ],
          ),
        ),
      );
      expect(_tag(html, 'name'), contains('value="Ana"'));
      expect(_tag(html, 'age'), contains('value="30"'));
    });

    test(
      'a list default fills one input with its first value, not `[a, b]`',
      () async {
        final html = await _body(
          const Form(
            defaults: {
              'tags': ['x', 'y'],
              'none': <String>[],
            },
            child: Column(
              children: [
                TextField(name: 'tags'),
                TextField(name: 'none'),
              ],
            ),
          ),
        );
        expect(_tag(html, 'tags'), contains('value="x"'));
        expect(_tag(html, 'none'), isNot(contains('value=')));
      },
    );

    test('defaults can be a typed object with toJson', () async {
      final html = await _body(
        Form(
          defaults: _Person('Ana', 30, true, DateTime.utc(1990, 5, 3)),
          child: const Column(
            children: [
              TextField(name: 'name'),
              TextField(name: 'born'),
              Checkbox(name: 'admin', value: false, onChanged: _noop),
            ],
          ),
        ),
      );
      expect(_tag(html, 'name'), contains('value="Ana"'));
      // A date is what `<input type=date>` takes.
      expect(_tag(html, 'born'), contains('value="1990-05-03"'));
      expect(_tag(html, 'admin'), contains('checked'));
    });

    test('defaults that are not a Map nor have toJson fail loudly', () {
      expect(
        _body(const Form(defaults: 42, child: TextField(name: 'x'))),
        throwsA(predicate((e) => '$e'.contains('THOR-P030'))),
      );
    });

    test('what was typed wins over defaults, even when empty', () async {
      final html = await _body(
        Form(
          failed: FormInvalid(values: const {'name': ''}),
          defaults: const {'name': 'Ana'},
          child: const TextField(name: 'name'),
        ),
      );
      expect(html, isNot(contains('Ana')));
    });

    test('an unchecked box stays unchecked after a failure, whatever the '
        'defaults say', () async {
      final html = await _body(
        Form(
          failed: FormInvalid(values: const {'name': 'x'}),
          defaults: const {'terms': true},
          child: const Column(
            children: [
              TextField(name: 'name'),
              Checkbox(name: 'terms', value: true, onChanged: _noop),
              Switch(name: 'news', value: true, onChanged: _noop),
            ],
          ),
        ),
      );
      expect(_tag(html, 'terms'), isNot(contains('checked')));
      expect(_tag(html, 'news'), isNot(contains('checked')));
    });

    test('a box that was sent checked is checked again', () async {
      final html = await _body(
        Form(
          failed: FormInvalid(values: const {'terms': 'on', 'news': 'on'}),
          child: const Column(
            children: [
              Checkbox(name: 'terms', value: false, onChanged: _noop),
              Switch(name: 'news', value: false, onChanged: _noop),
            ],
          ),
        ),
      );
      expect(_tag(html, 'terms'), contains('checked'));
      expect(_tag(html, 'news'), contains('checked'));
    });

    test('radio, select and slider take their value too', () async {
      final html = await _body(
        Form(
          failed: FormInvalid(
            values: const {'plan': 'pro', 'size': 'm', 'volume': '0.5'},
          ),
          child: const Column(
            children: [
              Radio<String>(
                name: 'plan',
                value: 'free',
                groupValue: 'free',
                onChanged: _noop,
              ),
              Radio<String>(
                name: 'plan',
                value: 'pro',
                groupValue: 'free',
                onChanged: _noop,
              ),
              DropdownButton<String>(
                name: 'size',
                value: 's',
                onChanged: _noop,
                items: [
                  DropdownMenuItem(value: 's', child: Text('S')),
                  DropdownMenuItem(value: 'm', child: Text('M')),
                ],
              ),
              Slider(name: 'volume', value: 1, onChanged: _noop),
            ],
          ),
        ),
      );
      final radios = RegExp(
        r'<input[^>]*type="radio"[^>]*>',
      ).allMatches(html).map((m) => m[0]!).toList();
      expect(radios[0], isNot(contains('checked')));
      expect(radios[1], contains('checked'));
      expect(html, matches(RegExp(r'<option[^>]*value="m"[^>]*selected')));
      expect(
        html,
        isNot(matches(RegExp(r'<option[^>]*value="s"[^>]*selected'))),
      );
      expect(_tag(html, 'volume'), contains('value="0.5"'));
    });

    test('a value of a field the page did not name is ignored', () async {
      final html = await _body(
        Form(
          failed: FormInvalid(values: const {'other': 'x'}),
          child: const TextField(name: 'name'),
        ),
      );
      expect(html, isNot(contains('value="x"')));
    });

    test(
      'a secret is never refilled, from a failure or from defaults',
      () async {
        final html = await _body(
          Form(
            failed: FormInvalid(values: const {'password': 'hunter2'}),
            defaults: const {'pin': '1234'},
            child: const Column(
              children: [
                TextField(name: 'password', obscureText: true),
                TextFormField(name: 'pin', obscureText: true),
              ],
            ),
          ),
        );
        expect(html, isNot(contains('hunter2')));
        expect(html, isNot(contains('1234')));
      },
    );

    test(
      'an explicit initialValue loses to a failure but beats defaults',
      () async {
        Future<String> field({
          Object? failed,
          Map<String, Object?>? defaults,
        }) => _body(
          Form(
            failed: failed,
            defaults: defaults,
            child: const TextField(name: 'name', initialValue: 'own'),
          ),
        );
        expect(
          await field(failed: FormInvalid(values: const {'name': 'typed'})),
          contains('value="typed"'),
        );
        expect(
          await field(defaults: const {'name': 'saved'}),
          contains('value="own"'),
        );
        expect(await field(), contains('value="own"'));
      },
    );

    test(
      'the form of an action that is not a FormInvalid is ignored',
      () async {
        final html = await _body(
          const Form(
            failed: {'name': 'x'},
            child: TextField(name: 'name'),
          ),
        );
        expect(html, isNot(contains('value="x"')));
      },
    );
  });

  group('the message of a field', () {
    test('a named field shows its error and is marked invalid', () async {
      final html = await _body(
        Form(
          failed: FormInvalid(errors: const {'email': 'Taken'}),
          child: const Column(
            children: [
              TextFormField(name: 'email'),
              TextFormField(name: 'name'),
            ],
          ),
        ),
      );
      expect(_tag(html, 'email'), contains('aria-invalid="true"'));
      expect(html, matches(RegExp(r'id="f-email-msg"[^>]*>[^<]*Taken<')));
      expect(_tag(html, 'name'), isNot(contains('aria-invalid')));
    });

    test('several messages of one field are all shown, in order', () async {
      final failed = FormInvalid(
        fieldErrors: const {
          'password': ['Too short', 'Needs a digit'],
        },
      );
      expect(failed.errors, {'password': 'Too short'});
      expect(failed.errorsOf('password'), ['Too short', 'Needs a digit']);
      expect(failed.messages, ['Too short', 'Needs a digit']);
      final html = await _body(
        Form(
          failed: failed,
          child: const TextFormField(name: 'password'),
        ),
      );
      expect(html, contains('Too short'));
      expect(html, contains('Needs a digit'));
      expect(
        html.indexOf('Too short'),
        lessThan(html.indexOf('Needs a digit')),
      );
    });

    test('withError adds a message to the field', () {
      final f = FormInvalid(
        errors: const {'email': 'Invalid'},
      ).withError('Taken', field: const TextSchemaField('email'));
      expect(f.errorsOf('email'), ['Invalid', 'Taken']);
    });

    test('an explicit errorText wins over the form', () async {
      final html = await _body(
        Form(
          failed: FormInvalid(errors: const {'email': 'From form'}),
          child: const TextField(
            name: 'email',
            decoration: InputDecoration(errorText: 'Own'),
          ),
        ),
      );
      expect(html, contains('Own'));
      expect(html, isNot(contains('From form')));
    });

    test('a control without a message line is still marked invalid', () async {
      final html = await _body(
        Form(
          failed: FormInvalid(errors: const {'terms': 'Accept'}),
          child: const Checkbox(name: 'terms', value: false, onChanged: _noop),
        ),
      );
      expect(_tag(html, 'terms'), contains('aria-invalid="true"'));
    });

    test(
      'FormFieldError writes the messages of a field where you put it',
      () async {
        final html = await _body(
          Form(
            failed: FormInvalid(errors: const {'terms': 'Accept the terms'}),
            child: const Column(
              children: [
                Checkbox(name: 'terms', value: false, onChanged: _noop),
                FormFieldError('terms'),
                FormFieldError('other'),
              ],
            ),
          ),
        );
        expect(html, contains('Accept the terms'));
        expect(html, contains('role="alert"'));
        expect('role="alert"'.allMatches(html), hasLength(1));
      },
    );

    test('a hostile message is escaped', () async {
      final html = await _body(
        Form(
          failed: FormInvalid(errors: const {'email': '<img src=x onerror=1>'}),
          child: const TextFormField(name: 'email'),
        ),
      );
      expect(html, isNot(contains('<img src=x')));
      expect(html, contains('&lt;img src=x'));
    });
  });

  group('a page that answers a failed submit', () {
    registerPageActions({
      _EditPage: [
        PageActionMethod.valid(
          'save',
          (p) => (p as _EditPage).save,
          _Edit.schema,
        ),
      ],
    });
    final app = ThorApp.router(
      routerConfig: ThorRouter([ThorRoute('/edit', const _EditPage())]),
    );
    final handler = RouteHandler<Widget>(
      routes: app.routes,
      renderer: WidgetRenderer.router(app),
    );
    Future<ThorResponse> send(String method, String body) => handler.handle(
      PageRequest(
        method: HttpMethod.tryParse(method)!,
        uri: Uri.parse('http://s.test/edit${method == 'POST' ? '?/save' : ''}'),
        headers: const {
          HttpHeader.host: 's.test',
          HttpHeader.origin: 'http://s.test',
          HttpHeader.contentType: 'application/x-www-form-urlencoded',
        },
        body: Stream.value(utf8.encode(body)),
      ),
    );

    test('a GET shows the saved values', () async {
      final r = await send('GET', '');
      expect(r.status, 200);
      expect(_tag(r.text, 'name'), contains('value="Saved"'));
      expect(_tag(r.text, 'email'), contains('value="saved@x.test"'));
    });

    test(
      'a 422 shows what was typed, every message, and focuses the field',
      () async {
        final r = await send('POST', 'name=Ana&email=b%40x.test');
        expect(r.status, 422);
        expect(_tag(r.text, 'name'), contains('value="Ana"'));
        expect(_tag(r.text, 'email'), contains('value="b@x.test"'));
        expect(_tag(r.text, 'email'), contains('autofocus'));
        expect(_tag(r.text, 'name'), isNot(contains('autofocus')));
        expect(r.text, contains('Taken'));
        expect(r.text, contains('Try another'));
        expect(r.text, contains('novalidate'));
      },
    );

    test(
      'a field left empty stays empty (defaults do not come back)',
      () async {
        final r = await send('POST', 'name=&email=b%40x.test');
        expect(r.status, 422);
        expect(_tag(r.text, 'name'), isNot(contains('Saved')));
        expect(r.text, contains('Name is required'));
      },
    );
  });

  test(
    'the scope is invisible in the markup: same HTML with or without it',
    () async {
      const fields = Column(
        children: [
          TextField(name: 'a'),
          Row(
            children: [
              Text('x'),
              Expanded(child: TextField(name: 'b')),
            ],
          ),
        ],
      );
      final plain = await _body(const Form(child: fields));
      final scoped = await _body(Form(failed: FormInvalid(), child: fields));
      expect(scoped, plain);
    },
  );

  group('noValidate', () {
    test('adds the attribute so the browser bubbles do not hide the '
        'server messages', () async {
      final on = await _body(
        const Form(noValidate: true, child: TextFormField(name: 'a')),
      );
      expect(on, matches(RegExp(r'<form[^>]* novalidate')));
      final off = await _body(const Form(child: TextFormField(name: 'a')));
      expect(off, isNot(contains('novalidate')));
    });
  });

  group('the schema of the form', () {
    test('a TextFormField takes its rules from the schema by name', () async {
      final html = await _body(
        const Form(
          schema: _Schema.schema,
          child: TextFormField(name: 'email'),
        ),
      );
      expect(html, contains('required'));
      expect(html, contains('type="email"'));
      expect(html, contains('data-msg-valuemissing="Type your e-mail"'));
    });

    test('the rules of the field win when it has its own', () async {
      final html = await _body(
        const Form(
          schema: _Schema.schema,
          child: TextFormField(
            name: 'email',
            validators: [Validator.maxLength(5, 'short')],
          ),
        ),
      );
      expect(html, contains('maxlength="5"'));
      expect(html, isNot(contains('type="email"')));
    });
  });
}

void _noop(Object? _) {}

abstract final class _Edit {
  static const name = TextSchemaField(
    'name',
    validators: [Validator.required('Name is required')],
  );
  static const email = TextSchemaField(
    'email',
    validators: [Validator.required('E-mail is required')],
  );
  static const schema = FormSchema([name, email]);
}

class _EditPage extends ThorPage<void> {
  const _EditPage();

  Future<ActionResult?> save(
    PageRequest request,
    FormValues<FormSchema> values,
  ) async => values
      .invalid('Taken', _Edit.email)
      .withError('Try another', field: _Edit.email)
      .fail();

  @override
  Widget build(BuildContext context, PageState<void> state) => Form(
    schema: _Edit.schema,
    onValid: save,
    failed: state.form,
    defaults: const {'name': 'Saved', 'email': 'saved@x.test'},
    noValidate: true,
    child: const Column(
      children: [
        TextFormField(name: 'name'),
        TextFormField(name: 'email'),
        FilledButton(
          buttonType: ButtonType.submit,
          onPressed: _noopVoid,
          child: Text('Go'),
        ),
      ],
    ),
  );
}

void _noopVoid() {}

final class _Schema extends FormSchema {
  const _Schema._() : super(const [email]);
  static const schema = _Schema._();
  static const email = TextSchemaField(
    'email',
    validators: [
      Validator.required('Type your e-mail'),
      Validator.email('Not an e-mail'),
    ],
  );
}
