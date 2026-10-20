// A text field emits only the DOM its decoration needs: one accessible
// name (the `<label for>` or an `aria-label`, never both), one `<label>`, a
// message line only when something may write in it, no empty placeholder.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _body(Widget w) async =>
    bodyOfPage(await renderDocument(ThorApp(child: w)));

String _control(String html) =>
    RegExp(r'<(?:input|textarea)\b[^>]*>').firstMatch(html)![0]!;

int _count(String html, String pattern) =>
    RegExp(pattern).allMatches(html).length;

void main() {
  setUpAll(initializeThorTests);

  group('accessible name', () {
    test(
      'a labelText names the control through its <label for> only',
      () async {
        final html = await _body(
          const TextField(
            id: 'n',
            decoration: InputDecoration(labelText: 'Name', hintText: 'Ann'),
          ),
        );
        expect(html, contains('for="n"'));
        expect(_control(html), isNot(contains('aria-label')));
        expect(_control(html), contains('placeholder="Ann"'));
      },
    );

    test('a label widget names the control through its <label for>', () async {
      final html = await _body(
        const TextField(
          id: 'n',
          decoration: InputDecoration(label: Text('Name')),
        ),
      );
      expect(html, contains('for="n"'));
      expect(_control(html), isNot(contains('aria-label')));
    });

    test(
      'FloatingLabelBehavior.never keeps the labelText as aria-label',
      () async {
        final html = await _body(
          const TextField(
            decoration: InputDecoration(
              labelText: 'Search',
              floatingLabelBehavior: FloatingLabelBehavior.never,
            ),
          ),
        );
        expect(html, isNot(contains('for="')));
        expect(_control(html), contains('aria-label="Search"'));
      },
    );

    test('a hint-only field is named by its hint', () async {
      final html = await _body(
        const TextField(decoration: InputDecoration(hintText: 'Search')),
      );
      expect(_control(html), contains('aria-label="Search"'));
    });

    test('a TextFormField with a labelText has no aria-label', () async {
      final html = await _body(
        const TextFormField(
          name: 'email',
          decoration: InputDecoration(labelText: 'Email'),
          validator: Validator.required('Required'),
        ),
      );
      expect(html, contains('for="f-email"'));
      expect(_control(html), isNot(contains('aria-label')));
    });
  });

  group('one <label>', () {
    test(
      'a labelled field does not wrap its input in a second label',
      () async {
        final html = await _body(
          const TextField(
            id: 'n',
            decoration: InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        );
        expect(_count(html, '<label\\b'), 1);
      },
    );

    test('an unlabelled field keeps its row as the label', () async {
      final html = await _body(
        const TextField(decoration: InputDecoration(hintText: 'Search')),
      );
      expect(_count(html, '<label\\b'), 1);
    });
  });

  group('message line', () {
    test('a labelled TextField with no messages has no live region', () async {
      final html = await _body(
        const TextField(decoration: InputDecoration(labelText: 'Name')),
      );
      expect(html, isNot(contains('aria-live')));
      expect(_control(html), isNot(contains('aria-describedby')));
    });

    test('a TextFormField without rules nor messages has none', () async {
      final html = await _body(
        const TextFormField(
          name: 'nick',
          decoration: InputDecoration(labelText: 'Nick'),
        ),
      );
      expect(html, isNot(contains('aria-live')));
      expect(_control(html), isNot(contains('aria-describedby')));
    });

    test(
      'a TextFormField with rules keeps the line the engine writes',
      () async {
        final html = await _body(
          const TextFormField(
            name: 'email',
            decoration: InputDecoration(labelText: 'Email'),
            validator: Validator.required('Required'),
          ),
        );
        expect(html, contains('id="f-email-msg"'));
        expect(html, contains('aria-live="polite"'));
        expect(_control(html), contains('aria-describedby="f-email-msg"'));
        expect(_control(html), contains('data-t-validate'));
      },
    );

    test('helperText keeps the line, with its data-helper', () async {
      final html = await _body(
        const TextField(
          id: 'n',
          decoration: InputDecoration(labelText: 'Name', helperText: 'Full'),
        ),
      );
      expect(html, contains('id="n-msg"'));
      expect(html, contains('data-helper="Full"'));
    });

    test('errorText keeps the line', () async {
      final html = await _body(
        const TextFormField(
          name: 'nick',
          decoration: InputDecoration(labelText: 'Nick', errorText: 'Taken'),
        ),
      );
      expect(html, contains('id="f-nick-msg"'));
      expect(_control(html), contains('aria-describedby="f-nick-msg"'));
      expect(_control(html), contains('aria-invalid="true"'));
    });

    test('a TextFormField counter is described with its message', () async {
      final html = await _body(
        const TextFormField(
          name: 'bio',
          maxLength: 20,
          decoration: InputDecoration(labelText: 'Bio'),
          validator: Validator.required('Required'),
        ),
      );
      expect(
        _control(html),
        contains('aria-describedby="f-bio-msg f-bio-cnt"'),
      );
    });

    test('no empty data-helper without a helperText', () async {
      final html = await _body(
        const TextFormField(
          name: 'email',
          decoration: InputDecoration(labelText: 'Email'),
          validator: Validator.required('Required'),
        ),
      );
      final line = RegExp(
        r'<span[^>]*id="f-email-msg"[^>]*>',
      ).firstMatch(html)![0]!;
      expect(line, isNot(contains('data-helper')));
    });
  });

  test('an empty hintText emits no placeholder', () async {
    final html = await _body(
      const TextField(
        decoration: InputDecoration(labelText: 'Name', hintText: ''),
      ),
    );
    expect(_control(html), isNot(contains('placeholder')));
  });
}
