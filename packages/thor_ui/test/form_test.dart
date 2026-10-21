// Fixture: fields without a label on purpose (focus, state and form behavior).
// ignore_for_file: thor_lints/text_field_without_label
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> bodyOf(Widget c) async {
  return bodyOfPage(await renderDocument(ThorApp(child: c)));
}

/// The page's stylesheet, without spaces.
Future<String> _cssOf(Widget c) async {
  final page = await renderDocument(ThorApp(child: c));
  return RegExp(
    r'<style[^>]*>([\s\S]*?)</style>',
  ).allMatches(page).map((m) => m[1]).join().replaceAll(' ', '');
}

// The member list thor generates for [_Auth], by hand.
abstract class _AuthMembers extends ThorState {
  @override
  String get $type => 'Auth';

  @override
  List<ThorMember> get $members {
    final s = this as _Auth;
    return [ThorMember('login', s.login, call: (_) => s.login())];
  }
}

class _Auth extends _AuthMembers {
  void login() {}
}

final _auth = _Auth();

void main() {
  setUpAll(initializeThorTests);

  group('multi-line and decorated fields', () {
    test(
      'TextFormField(maxLines:) is a textarea with that many rows',
      () async {
        final html = await bodyOf(
          const TextFormField(
            name: 'msg',
            maxLines: 4,
            decoration: InputDecoration(labelText: 'Message'),
            validators: [Validator.required('Write something')],
          ),
        );
        expect(html, contains('<textarea'));
        expect(html, contains('rows="4"'));
        expect(html, contains('id="f-msg"'));
        expect(html, contains('required'));
        expect(html, contains('aria-describedby="f-msg-msg"'));
        expect(html, isNot(contains('<input')));
      },
    );

    test(
      'minLines starts at that many rows and grows up to maxLines',
      () async {
        final html = await bodyOf(
          const TextFormField(name: 'msg', minLines: 2, maxLines: 6),
        );
        expect(html, contains('rows="2"'));
        final css = await _cssOf(
          const TextFormField(name: 'msg', minLines: 2, maxLines: 6),
        );
        expect(css, contains('field-sizing:content'));
        expect(css, contains('6lh'));
      },
    );

    test(
      'TextField shows its label and error, linked to the control',
      () async {
        final html = await bodyOf(
          const TextField(
            name: 'city',
            decoration: InputDecoration(
              labelText: 'City',
              errorText: 'Choose a city',
            ),
          ),
        );
        expect(
          html,
          matches(RegExp(r'<label[^>]*for="f-city"[^>]*>City</label>')),
        );
        expect(html, contains('id="f-city"'));
        expect(html, contains('aria-invalid="true"'));
        expect(html, contains('aria-describedby="f-city-msg"'));
        expect(html, matches(RegExp(r'id="f-city-msg"[^>]*>Choose a city<')));
        // The `<label for>` is the accessible name, once.
        expect(html, isNot(contains('aria-label=')));
      },
    );

    test(
      'TextField without a name gets a page-unique id for its label',
      () async {
        final html = await bodyOf(
          const Column(
            children: [
              TextField(decoration: InputDecoration(labelText: 'A')),
              TextField(decoration: InputDecoration(helperText: 'B')),
            ],
          ),
        );
        final ids = RegExp(
          r'<(?:input)[^>]* id="([^"]+)"',
        ).allMatches(html).map((m) => m[1]).toList();
        expect(ids, hasLength(2));
        expect(ids.toSet(), hasLength(2));
        expect(html, contains('for="${ids[0]}"'));
        expect(html, contains('aria-describedby="${ids[1]}-msg"'));
        expect(html, matches(RegExp('id="${ids[1]}-msg"[^>]*>B<')));
      },
    );

    test('a TextField with no label, helper or error is unchanged: one '
        '<label> row, no message line', () async {
      final html = await bodyOf(
        const TextField(decoration: InputDecoration(hintText: 'Search')),
      );
      expect(html, isNot(contains('-msg')));
      expect(html, isNot(contains('aria-describedby')));
      expect(RegExp('<label').allMatches(html), hasLength(1));
    });
  });

  test('validators compile to native constraints and messages', () async {
    final html = await bodyOf(
      const TextFormField(
        name: 'email',
        decoration: InputDecoration(
          labelText: 'Email',
          helperText: 'El de tu trabajo',
        ),
        validators: [
          Validator.required('Enter your email'),
          Validator.email('Invalid email'),
          Validator.maxLength(60, 'Too long'),
        ],
      ),
    );
    expect(html, contains('<label'));
    expect(html, contains('for="f-email"'));
    expect(html, contains('id="f-email"'));
    expect(html, contains('type="email"'));
    expect(html, contains('required'));
    expect(html, contains('maxlength="60"'));
    expect(html, contains('data-msg-valuemissing="Enter your email"'));
    expect(html, contains('data-msg-typemismatch="Invalid email"'));
    expect(html, contains('aria-describedby="f-email-msg"'));
    expect(html, isNot(contains('aria-label="Email"')));
    expect(html, matches(RegExp(r'id="f-email-msg"[^>]*>El de tu trabajo<')));
  });

  test('a server error is rendered invalid from the start', () async {
    final html = await bodyOf(
      const TextFormField(
        name: 'pin',
        decoration: InputDecoration(errorText: 'PIN incorrecto'),
      ),
    );
    expect(html, contains('aria-invalid="true"'));
    expect(html, matches(RegExp(r'data-invalid[^>]*>PIN incorrecto<')));
  });

  test('Form is a native <form> that posts without JS', () async {
    final html = await bodyOf(
      Form(
        action: '/login',
        onSubmit: _auth.login,
        child: const TextFormField(name: 'user'),
      ),
    );
    expect(html, contains('<form'));
    expect(html, contains('action="/login"'));
    expect(html, contains('method="post"'));
    expect(html, contains('data-t-on="submit:Auth.login"'));
  });

  group('files', () {
    test(
      'a Form sends files only when asked: enctype only for multipart',
      () async {
        final plain = await bodyOf(const Form(action: '/a', child: Text('x')));
        expect(plain, isNot(contains('enctype')));
        final files = await bodyOf(
          const Form(
            action: '/a',
            encoding: FormEncoding.multipart,
            child: Text('x'),
          ),
        );
        expect(files, contains('enctype="multipart/form-data"'));
      },
    );

    test('Datalist: a <datalist> of <option value>s with an id', () async {
      final html = await bodyOf(
        const Datalist(id: 'colors', options: ['red', 'a"b', 'c<d']),
      );
      expect(html, contains('<datalist id="colors"'));
      expect(html, contains('<option value="red"'));
      expect(html, contains('value="a&quot;b"'));
      expect(html, isNot(contains('c<d')));
    });

    test('TextField(datalist:) writes list on the input', () async {
      final html = await bodyOf(const TextField(name: 'c', datalist: 'colors'));
      expect(html, contains('list="colors"'));
      final without = await bodyOf(const TextField(name: 'c'));
      expect(without, isNot(contains('list=')));
    });

    test('TextFormField(datalist:) writes list on the input', () async {
      final html = await bodyOf(
        const Form(
          child: TextFormField(name: 'c', datalist: 'colors'),
        ),
      );
      expect(html, contains('list="colors"'));
    });

    test(
      'FileField: a native file input inside its label, with its rules',
      () async {
        final html = await bodyOf(
          const FileField(
            name: 'doc',
            label: 'Informe',
            accept: ['application/pdf', '.docx'],
            multiple: true,
            required: true,
          ),
        );
        expect(
          RegExp(r'<label[^>]*>.*<input[^>]*/>.*</label>').hasMatch(html),
          isTrue,
        );
        expect(html, contains('type="file"'));
        expect(html, contains('name="doc"'));
        expect(html, contains('accept="application/pdf,.docx"'));
        expect(html, contains(' multiple'));
        expect(html, contains(' required'));
        expect(html, contains('Informe'));
      },
    );

    test(
      'without accept, multiple or required: none of those attributes',
      () async {
        final html = await bodyOf(const FileField(name: 'f'));
        for (final attr in ['accept', 'multiple', 'required', 'disabled']) {
          expect(html, isNot(contains(attr)), reason: attr);
        }
      },
    );

    test('disabled is a disabled input, dimmed', () async {
      final page = await renderDocument(
        const ThorApp(child: FileField(name: 'f', enabled: false)),
      );
      expect(bodyOfPage(page), contains(' disabled'));
      expect(page, contains(':disabled'));
    });

    test("the picker's button is styled from the theme", () async {
      final page = await renderDocument(
        const ThorApp(child: FileField(name: 'f')),
      );
      expect(page, contains('::file-selector-button'));
      expect(page, contains('var(--t-primary'));
    });

    test('a name with quotes cannot break out of the attribute', () async {
      final html = await bodyOf(const FileField(name: '"><script>x'));
      expect(html, isNot(contains('<script>')));
    });
  });

  group('Form(formMethod:)', () {
    test('writes the method; post by default', () async {
      expect(
        await bodyOf(const Form(child: Text('x'))),
        contains('method="post"'),
      );
      expect(
        await bodyOf(const Form(formMethod: FormMethod.get, child: Text('x'))),
        contains('method="get"'),
      );
      expect(
        await bodyOf(
          const Form(formMethod: FormMethod.dialog, child: Text('x')),
        ),
        contains('method="dialog"'),
      );
    });
  });

  group('Form(id:) and a button\'s formId', () {
    test('the form has the id; a button outside it submits it', () async {
      final html = await bodyOf(
        const Column(
          children: [
            Form(id: 'filters', formMethod: FormMethod.get, child: Text('x')),
            FilledButton(formId: 'filters', child: Text('Apply')),
          ],
        ),
      );
      expect(html, contains(' id="filters" method="get"'));
      expect(
        html,
        matches(RegExp(r'<button[^>]*type="submit"[^>]*form="filters"')),
      );
      expect(html, isNot(contains('disabled=""')));
    });

    test('no id, no form attribute', () async {
      final html = await bodyOf(
        const Column(
          children: [
            Form(child: Text('x')),
            TextButton(child: Text('Go')),
          ],
        ),
      );
      expect(html, isNot(contains(' id="')));
      expect(html, isNot(contains('form="')));
    });
  });
}
