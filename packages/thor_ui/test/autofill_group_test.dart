// Fixture: fields without a label on purpose.
// ignore_for_file: thor_lints/text_field_without_label
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _body(Widget w) async =>
    bodyOfPage(await renderDocument(ThorApp(child: w)));

List<String> _controls(String html) => [
  for (final m in RegExp(r'<(?:input|textarea)\b[^>]*>').allMatches(html))
    m[0]!,
];

String _formTag(String html) => RegExp(r'<form\b[^>]*>').firstMatch(html)![0]!;

void main() {
  setUpAll(initializeThorTests);

  group('AutofillGroup', () {
    test('outside a Form it is a <form> that never navigates', () async {
      final html = await _body(
        const AutofillGroup(
          child: Column(
            children: [
              TextField(name: 'u', autofillHints: [AutofillHints.username]),
              TextField(
                name: 'p',
                obscureText: true,
                autofillHints: [AutofillHints.password],
              ),
            ],
          ),
        ),
      );
      final tag = _formTag(html);
      expect(tag, contains('autocomplete="on"'));
      // A submit would otherwise reload the page with the password in the URL.
      expect(tag, contains('method="dialog"'));
      expect(tag, isNot(contains('action=')));
      expect('<form'.allMatches(html), hasLength(1));
      expect(_controls(html).first, contains('autocomplete="username"'));
    });

    test('inside a Form it adds no element', () async {
      final html = await _body(
        const Form(
          child: AutofillGroup(
            child: TextField(name: 'u', autofillHints: [AutofillHints.email]),
          ),
        ),
      );
      expect('<form'.allMatches(html), hasLength(1));
      expect(_controls(html).single, contains('autocomplete="email"'));
    });

    test('onDisposeAction cancel asks the browser not to remember', () async {
      final html = await _body(
        const AutofillGroup(
          onDisposeAction: AutofillContextAction.cancel,
          child: TextField(name: 'u'),
        ),
      );
      expect(_formTag(html), contains('autocomplete="off"'));
    });

    test('section groups the fields for the browser', () async {
      final html = await _body(
        const Column(
          children: [
            AutofillGroup(
              section: 'shipping',
              child: Column(
                children: [
                  TextField(
                    name: 'a',
                    autofillHints: [
                      AutofillHints.givenName,
                      AutofillHints.familyName,
                    ],
                  ),
                  TextFormField(
                    name: 'b',
                    autofillHints: [AutofillHints.postalCode],
                  ),
                  TextField(name: 'c', autofillHints: ['off']),
                  TextField(name: 'd'),
                ],
              ),
            ),
            TextField(name: 'e', autofillHints: [AutofillHints.email]),
          ],
        ),
      );
      final c = _controls(html);
      expect(
        c[0],
        contains('autocomplete="section-shipping given-name family-name"'),
      );
      expect(c[1], contains('autocomplete="section-shipping postal-code"'));
      // `off` and a field with no hints say nothing about a section.
      expect(c[2], contains('autocomplete="off"'));
      expect(c[3], isNot(contains('autocomplete')));
      // Outside the group: untouched.
      expect(c[4], contains('autocomplete="email"'));
    });

    test('the nearest section wins; a hint that names one is kept', () async {
      final html = await _body(
        const AutofillGroup(
          section: 'outer',
          child: AutofillGroup(
            section: 'inner',
            child: Column(
              children: [
                TextField(name: 'a', autofillHints: [AutofillHints.email]),
                TextField(
                  name: 'b',
                  autofillHints: ['section-own', AutofillHints.email],
                ),
              ],
            ),
          ),
        ),
      );
      final c = _controls(html);
      expect(c[0], contains('autocomplete="section-inner email"'));
      expect(c[1], contains('autocomplete="section-own email"'));
      expect('<form'.allMatches(html), hasLength(1));
    });

    test('a hostile section cannot break out of the attribute', () async {
      final html = await _body(
        const AutofillGroup(
          section: '"><script>alert(1)</script>',
          child: TextField(name: 'a', autofillHints: [AutofillHints.email]),
        ),
      );
      expect(html, isNot(contains('<script>')));
    });

    test('sections are plain tokens: spaces are not allowed', () async {
      expect(
        () => AutofillGroup(section: '', child: const Text('x')),
        throwsA(isA<AssertionError>()),
      );
      await expectLater(
        _body(const AutofillGroup(section: 'a b', child: Text('x'))),
        throwsA(anything),
      );
    });
  });

  group('AutofillGroup never nests a <form>', () {
    test('a Form straight inside it is the group', () async {
      final html = await _body(
        const AutofillGroup(
          section: 'a',
          child: Form(
            action: '/x',
            child: TextField(name: 'm', autofillHints: [AutofillHints.email]),
          ),
        ),
      );
      expect('<form'.allMatches(html), hasLength(1));
      expect(_controls(html).single, contains('section-a email'));
    });

    test('a Form built by an app component is the group', () async {
      final html = await _body(const AutofillGroup(child: _LoginForm()));
      expect('<form'.allMatches(html), hasLength(1));
    });

    test('a Form deeper inside it is an error, not nested HTML', () async {
      await expectLater(
        _body(
          const AutofillGroup(
            child: Padding(
              padding: EdgeInsets.all(4),
              child: Form(
                action: '/x',
                child: TextField(name: 'm'),
              ),
            ),
          ),
        ),
        throwsA(predicate((e) => e.toString().contains('AutofillGroup'))),
      );
    });

    test('a Form from a layout above, through a Builder', () async {
      final html = await _body(
        Form(
          action: '/x',
          child: Builder(
            builder: (context) => const AutofillGroup(
              child: TextField(name: 'm', autofillHints: [AutofillHints.email]),
            ),
          ),
        ),
      );
      expect('<form'.allMatches(html), hasLength(1));
    });

    test(
      'inside a dialog Enter must not close it: no method=dialog form',
      () async {
        final html = await _body(
          const AlertDialog(
            content: AutofillGroup(
              child: TextField(
                name: 'u',
                autofillHints: [AutofillHints.username],
              ),
            ),
          ),
        );
        expect(html, isNot(contains('method="dialog"<')));
        for (final m in RegExp(r'<form\b[^>]*>').allMatches(html)) {
          expect(m[0], isNot(contains('method="dialog"')));
        }
      },
    );
  });

  test('TextFormField(autofillHints:) takes the group section', () async {
    final html = await _body(
      const AutofillGroup(
        section: 'billing',
        child: TextFormField(
          name: 'mail',
          autofillHints: [AutofillHints.email],
        ),
      ),
    );
    expect(
      _controls(html).single,
      contains('autocomplete="section-billing email"'),
    );
  });

  test('a schema field takes autofillHints', () async {
    const field = TextSchemaField('mail');
    final hints = await _body(
      const TextFormField(field: field, autofillHints: [AutofillHints.email]),
    );
    expect(_controls(hints).single, contains('autocomplete="email"'));
  });
}

class _LoginForm extends StatelessWidget {
  const _LoginForm();

  @override
  Widget build(BuildContext context) => const Form(
    action: '/x',
    child: TextField(name: 'm'),
  );
}
