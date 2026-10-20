// Fixture: fields without a label on purpose (focus, state and form behavior).
// ignore_for_file: thor_lints/text_field_without_label
// The parameters of Flutter's TextField / TextFormField /
// InputDecoration that are HTML attributes, and a Form that stretches its
// fields like Flutter.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _page(Widget w) => renderDocument(ThorApp(child: w));
Future<String> _body(Widget w) async => bodyOfPage(await _page(w));

/// The opening tag of the first `<input>` or `<textarea>`.
String _control(String html) =>
    RegExp(r'<(?:input|textarea)\b[^>]*>').firstMatch(html)![0]!;

/// The page's stylesheet, without spaces.
Future<String> _css(Widget w) async => RegExp(
  r'<style[^>]*>([\s\S]*?)</style>',
).allMatches(await _page(w)).map((m) => m[1]).join().replaceAll(' ', '');

/// The CSS rule (body) of the class of the element that matches [tag].
String _ruleOf(String html, String css, RegExp tag) {
  final cls = RegExp(
    r'class="([^"]+)"',
  ).firstMatch(tag.firstMatch(html)![0]!)![1]!;
  return RegExp('\\.$cls\\{([^}]*)\\}').firstMatch(css)![1]!;
}

void main() {
  setUpAll(initializeThorTests);

  group('attributes of the control', () {
    test('readOnly is readonly, and keeps its validation rules', () async {
      final html = await _body(
        const TextFormField(
          name: 'code',
          readOnly: true,
          validator: Validator.required('Required'),
        ),
      );
      final tag = _control(html);
      expect(tag, contains('readonly'));
      // web: the browser skips its checks on a read-only field; the rules
      // are still on the element for the server's schema and for a form
      // that clears `readonly`.
      expect(tag, contains('required'));
      expect(tag, isNot(contains('disabled')));
      expect(
        _control(await _body(const TextField(name: 'a'))),
        isNot(contains('readonly')),
      );
    });

    test('readOnly on a multi-line field', () async {
      final tag = _control(
        await _body(const TextField(name: 'a', maxLines: 3, readOnly: true)),
      );
      expect(tag, startsWith('<textarea'));
      expect(tag, contains('readonly'));
    });

    test('textInputAction is enterkeyhint', () async {
      Future<String> hint(TextInputAction a) async =>
          _control(await _body(TextField(name: 'a', textInputAction: a)));
      expect(
        await hint(TextInputAction.search),
        contains('enterkeyhint="search"'),
      );
      expect(await hint(TextInputAction.next), contains('enterkeyhint="next"'));
      expect(await hint(TextInputAction.done), contains('enterkeyhint="done"'));
      expect(await hint(TextInputAction.go), contains('enterkeyhint="go"'));
      expect(await hint(TextInputAction.send), contains('enterkeyhint="send"'));
      expect(
        await hint(TextInputAction.previous),
        contains('enterkeyhint="previous"'),
      );
      expect(
        await hint(TextInputAction.newline),
        contains('enterkeyhint="enter"'),
      );
      // No equivalent: the browser's own key.
      expect(await hint(TextInputAction.none), isNot(contains('enterkeyhint')));
      expect(
        await hint(TextInputAction.unspecified),
        isNot(contains('enterkeyhint')),
      );
      expect(
        await hint(TextInputAction.emergencyCall),
        isNot(contains('enterkeyhint')),
      );
    });

    test(
      'textCapitalization is autocapitalize; the default adds nothing',
      () async {
        Future<String> cap(TextCapitalization c) async =>
            _control(await _body(TextField(name: 'a', textCapitalization: c)));
        expect(
          await cap(TextCapitalization.words),
          contains('autocapitalize="words"'),
        );
        expect(
          await cap(TextCapitalization.sentences),
          contains('autocapitalize="sentences"'),
        );
        expect(
          await cap(TextCapitalization.characters),
          contains('autocapitalize="characters"'),
        );
        expect(
          await cap(TextCapitalization.none),
          contains('autocapitalize="off"'),
        );
        expect(
          _control(await _body(const TextField(name: 'a'))),
          isNot(contains('autocapitalize')),
        );
      },
    );

    test(
      'autofillHints are autocomplete tokens (Flutter names mapped)',
      () async {
        Future<String> hints(List<String> h) async =>
            _control(await _body(TextField(name: 'a', autofillHints: h)));
        expect(
          await hints([AutofillHints.email]),
          contains('autocomplete="email"'),
        );
        expect(
          await hints([AutofillHints.newPassword]),
          contains('autocomplete="new-password"'),
        );
        expect(
          await hints([AutofillHints.password]),
          contains('autocomplete="current-password"'),
        );
        expect(
          await hints([AutofillHints.telephoneNumber]),
          contains('autocomplete="tel"'),
        );
        expect(
          await hints([AutofillHints.oneTimeCode]),
          contains('autocomplete="one-time-code"'),
        );
        expect(
          await hints([AutofillHints.givenName, AutofillHints.familyName]),
          contains('autocomplete="given-name family-name"'),
        );
        // An HTML token that is not a Flutter name goes as it is.
        expect(
          await hints(['shipping', 'postal-code']),
          contains('autocomplete="shipping postal-code"'),
        );
        expect(await hints(const []), isNot(contains('autocomplete')));
      },
    );

    test('TextFormField takes them too', () async {
      final tag = _control(
        await _body(
          const TextFormField(
            name: 'mail',
            readOnly: true,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.none,
            autofillHints: [AutofillHints.email],
          ),
        ),
      );
      expect(tag, contains('readonly'));
      expect(tag, contains('enterkeyhint="next"'));
      expect(tag, contains('autocapitalize="off"'));
      expect(tag, contains('autocomplete="email"'));
    });

    test(
      'a field inside a Form keeps them (fieldInForm copies every one)',
      () async {
        final tag = _control(
          await _body(
            const Form(
              child: TextField(
                name: 'a',
                readOnly: true,
                maxLength: 5,
                textInputAction: TextInputAction.go,
                textCapitalization: TextCapitalization.words,
                autofillHints: [AutofillHints.name],
                textAlign: TextAlign.center,
                initialValue: 'x',
              ),
            ),
          ),
        );
        expect(tag, contains('readonly'));
        expect(tag, contains('maxlength="5"'));
        expect(tag, contains('enterkeyhint="go"'));
        expect(tag, contains('autocapitalize="words"'));
        expect(tag, contains('autocomplete="name"'));
      },
    );

    test('textAlign is text-align of the input', () async {
      final css = await _css(
        const TextField(name: 'a', textAlign: TextAlign.center),
      );
      expect(css, contains('text-align:center'));
      expect(
        await _css(const TextField(name: 'a')),
        isNot(contains('text-align')),
      );
    });

    test(
      'obscuringCharacter is accepted (the browser draws its own dots)',
      () async {
        final tag = _control(
          await _body(
            const TextField(
              name: 'p',
              obscureText: true,
              obscuringCharacter: '*',
            ),
          ),
        );
        expect(tag, contains('type="password"'));
        expect(
          () => TextField(obscuringCharacter: '**'),
          throwsA(isA<AssertionError>()),
        );
      },
    );

    test('expands is a textarea that fills the height it is given', () async {
      const w = SizedBox(
        height: 200,
        child: TextField(
          name: 'a',
          expands: true,
          maxLines: 1,
          decoration: InputDecoration(hintText: 'Write'),
        ),
      );
      final html = await _body(w);
      expect(html, contains('<textarea'));
      expect(_control(html), isNot(contains('rows=')));
      final css = await _css(w);
      expect(css, contains('resize:none'));
      expect(css, contains('height:100%'));
    });
  });

  group('maxLength and the counter', () {
    test('maxlength on the control and a counter below', () async {
      final html = await _body(const TextField(name: 'bio', maxLength: 20));
      expect(_control(html), contains('maxlength="20"'));
      expect(html, contains('>0/20<'));
      expect(html, contains('id="f-bio-cnt"'));
      // Live: an inline handler, no script file.
      expect(_control(html), contains('oninput='));
      expect(html, isNot(contains('<script src')));
    });

    test('the counter counts what Flutter counts: grapheme clusters', () async {
      // Family emoji: 1 grapheme, 8 UTF-16 units. Flag: 1 and 4. e + accent: 1 and 2.
      for (final (text, count) in [
        ('hello', 5),
        ('\u{1F468}‍\u{1F469}‍\u{1F467}', 1),
        ('\u{1F1F2}\u{1F1FD}', 1),
        ('é', 1),
        ('\u{1F44D}\u{1F3FD}ok', 3),
        ('a\r\nb', 3),
        ('', 0),
      ]) {
        final html = await _body(
          TextField(name: 'a', maxLength: 30, initialValue: text),
        );
        expect(
          html,
          contains('>$count/30<'),
          reason: 'text ${text.runes.toList()}',
        );
      }
    });

    test(
      'the control is described by its counter, which is not live',
      () async {
        final html = await _body(const TextField(name: 'bio', maxLength: 20));
        expect(_control(html), contains('aria-describedby="f-bio-cnt"'));
        // A polite region that updates on every key would talk over the typing.
        final counter = RegExp(
          r'<[^>]*id="f-bio-cnt"[^>]*>',
        ).firstMatch(html)![0]!;
        expect(counter, isNot(contains('aria-live')));
        final both = await _body(
          const TextField(
            name: 'bio',
            maxLength: 20,
            decoration: InputDecoration(helperText: 'Short'),
          ),
        );
        expect(
          _control(both),
          contains('aria-describedby="f-bio-msg f-bio-cnt"'),
        );
      },
    );

    test('a prefilled value longer than maxLength renders as it is', () async {
      final html = await _body(
        const TextField(name: 'a', maxLength: 3, initialValue: 'abcdef'),
      );
      expect(html, contains('>6/3<'));
      expect(_control(html), contains('value="abcdef"'));
    });

    test('the live handler counts with Intl.Segmenter', () async {
      final tag = _control(
        await _body(const TextField(name: 'a', maxLength: 30)),
      );
      expect(tag, contains('Intl.Segmenter'));
      // The same text for every field: it reads the control's own id and
      // maxlength, so one CSP hash covers them all.
      expect(tag, contains('this.id+&quot;-cnt&quot;'));
      final other = _control(
        await _body(const TextField(name: 'b', maxLength: 5)),
      );
      expect(
        RegExp(r'oninput="[^"]*"').firstMatch(other)![0],
        RegExp(r'oninput="[^"]*"').firstMatch(tag)![0],
      );
    });

    test('counterText replaces the counter; empty removes it', () async {
      final custom = await _body(
        const TextField(
          name: 'a',
          maxLength: 10,
          decoration: InputDecoration(counterText: 'Max 10'),
        ),
      );
      expect(custom, contains('>Max 10<'));
      expect(custom, isNot(contains('>0/10<')));
      // A fixed text is not a live count.
      expect(_control(custom), isNot(contains('oninput')));
      final none = await _body(
        const TextField(
          name: 'a',
          maxLength: 10,
          decoration: InputDecoration(counterText: ''),
        ),
      );
      expect(none, isNot(contains('f-a-cnt')));
      expect(_control(none), contains('maxlength="10"'));
    });

    test('counterText without maxLength is shown as it is', () async {
      final html = await _body(
        const TextField(
          name: 'a',
          decoration: InputDecoration(counterText: '3 words'),
        ),
      );
      expect(html, contains('>3 words<'));
    });

    test('noMaxLength counts without limiting', () async {
      final html = await _body(
        const TextField(
          name: 'a',
          maxLength: TextField.noMaxLength,
          initialValue: 'abc',
        ),
      );
      expect(_control(html), isNot(contains('maxlength')));
      expect(html, contains('>3<'));
    });

    test('a bad maxLength fails at build time', () {
      expect(() => TextField(maxLength: 0), throwsA(isA<AssertionError>()));
      expect(() => TextField(maxLength: -2), throwsA(isA<AssertionError>()));
    });

    test('counter sits with the helper text, on the same line', () async {
      final html = await _body(
        const TextField(
          name: 'a',
          maxLength: 10,
          decoration: InputDecoration(labelText: 'Bio', helperText: 'Short'),
        ),
      );
      expect(html, contains('>Short<'));
      expect(html, contains('>0/10<'));
      // Helper and counter are siblings in one row.
      expect(html, matches(RegExp(r'>Short</[a-z]+><[a-z]+[^>]*id="f-a-cnt"')));
    });

    test('TextFormField shows the counter with its message line', () async {
      final html = await _body(
        const TextFormField(
          name: 'bio',
          maxLength: 140,
          initialValue: 'hey',
          validator: Validator.required('Required'),
        ),
      );
      expect(_control(html), contains('maxlength="140"'));
      expect(html, contains('>3/140<'));
      expect(html, contains('id="f-bio-msg"'));
      expect(
        _control(html),
        contains('aria-describedby="f-bio-msg f-bio-cnt"'),
      );
    });

    test('a TextFormField with no rules has the counter alone', () async {
      final html = await _body(
        const TextFormField(name: 'bio', maxLength: 140, initialValue: 'hey'),
      );
      expect(html, contains('>3/140<'));
      expect(html, isNot(contains('id="f-bio-msg"')));
      expect(_control(html), contains('aria-describedby="f-bio-cnt"'));
    });
  });

  group('InputDecoration', () {
    test(
      'prefixText and suffixText sit inside the field, around the input',
      () async {
        final html = await _body(
          const TextField(
            name: 'price',
            decoration: InputDecoration(prefixText: r'$ ', suffixText: 'USD'),
          ),
        );
        final pre = html.indexOf(r'$ ');
        final input = html.indexOf('<input');
        final suf = html.indexOf('USD');
        expect(pre, greaterThan(0));
        expect(pre, lessThan(input));
        expect(suf, greaterThan(input));
        // Inside the bordered row (the label), not below it.
        expect(html.indexOf('</label>'), greaterThan(suf));
        expect(
          await _css(
            const TextField(decoration: InputDecoration(prefixText: r'$ ')),
          ),
          contains('white-space:pre'),
        );
      },
    );

    test('prefix and suffix widgets go where the texts do', () async {
      final html = await _body(
        const TextField(
          name: 'a',
          decoration: InputDecoration(prefix: Text('PRE'), suffix: Text('SUF')),
        ),
      );
      expect(html.indexOf('PRE'), lessThan(html.indexOf('<input')));
      expect(html.indexOf('SUF'), greaterThan(html.indexOf('<input')));
    });

    test('a widget wins over the text', () async {
      final html = await _body(
        const TextField(
          name: 'a',
          decoration: InputDecoration(prefix: Text('W'), prefixText: 'T'),
        ),
      );
      expect(html, contains('>W<'));
      expect(html, isNot(contains('>T<')));
    });

    test(
      'icon sits outside the container, before the label and the field',
      () async {
        final html = await _body(
          const TextField(
            name: 'a',
            decoration: InputDecoration(icon: Text('ICO'), labelText: 'Phone'),
          ),
        );
        expect(html.indexOf('ICO'), lessThan(html.indexOf('Phone')));
        expect(html.indexOf('ICO'), lessThan(html.indexOf('<input')));
      },
    );

    test(
      'floatingLabelBehavior.never turns the label into the placeholder',
      () async {
        final html = await _body(
          const TextField(
            name: 'a',
            decoration: InputDecoration(
              labelText: 'Email',
              floatingLabelBehavior: FloatingLabelBehavior.never,
            ),
          ),
        );
        expect(_control(html), contains('placeholder="Email"'));
        expect(html, isNot(contains('<label for')));
        // Still its accessible name.
        expect(_control(html), contains('aria-label="Email"'));
        final always = await _body(
          const TextField(
            name: 'a',
            decoration: InputDecoration(
              labelText: 'Email',
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
          ),
        );
        expect(always, contains('<label'));
        expect(_control(always), isNot(contains('placeholder')));
      },
    );

    test('errorMaxLines clamps the error text', () async {
      const w = TextField(
        name: 'a',
        decoration: InputDecoration(
          errorText: 'A very long error',
          errorMaxLines: 2,
        ),
      );
      final css = await _css(w);
      expect(css, contains('-webkit-line-clamp:2'));
      expect(
        await _css(
          const TextField(
            name: 'a',
            decoration: InputDecoration(errorText: 'x'),
          ),
        ),
        isNot(contains('line-clamp')),
      );
    });

    test('isCollapsed drops the content padding', () async {
      final css = await _css(
        const TextField(
          name: 'a',
          decoration: InputDecoration(isCollapsed: true),
        ),
      );
      expect(css, contains('padding:0px'));
      expect(css, isNot(contains('padding:16px12px')));
    });

    test('copyWith keeps the new fields', () {
      const d = InputDecoration(
        prefixText: 'a',
        suffixText: 'b',
        counterText: 'c',
        errorMaxLines: 3,
        isCollapsed: true,
        floatingLabelBehavior: FloatingLabelBehavior.never,
      );
      final c = d.copyWith(hintText: 'h');
      expect(c.prefixText, 'a');
      expect(c.suffixText, 'b');
      expect(c.counterText, 'c');
      expect(c.errorMaxLines, 3);
      expect(c.isCollapsed, isTrue);
      expect(c.floatingLabelBehavior, FloatingLabelBehavior.never);
    });
  });

  group('Form stretches its fields like Flutter', () {
    const field = TextFormField(name: 'a');

    test('Form > Column(stretch) under a Center fills the width', () async {
      const w = Center(
        child: Form(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [field],
          ),
        ),
      );
      final html = await _body(w);
      final rule = _ruleOf(html, await _css(w), RegExp(r'<form[^>]*>'));
      expect(rule, contains('align-self:stretch'));
      expect(rule, isNot(contains('margin-left:auto')));
    });

    test('a Form around a field that fills does too', () async {
      const w = Center(child: Form(child: field));
      final html = await _body(w);
      final rule = _ruleOf(html, await _css(w), RegExp(r'<form[^>]*>'));
      expect(rule, contains('align-self:stretch'));
    });

    test('a Form around content that shrinks keeps shrinking', () async {
      const w = Center(child: Form(child: Text('hi')));
      final html = await _body(w);
      final rule = _ruleOf(html, await _css(w), RegExp(r'<form[^>]*>'));
      expect(rule, isNot(contains('align-self:stretch')));
    });

    test('the message line reserves its height: no growth on error', () async {
      const w = Form(
        child: TextFormField(
          name: 'a',
          validator: Validator.required('Required'),
        ),
      );
      final css = await _css(w);
      expect(css, contains('min-height:16px'));
    });
  });

  test('visiblePassword is plain text, masked only by obscureText', () async {
    final shown = _control(
      await _body(
        const TextField(
          name: 'p',
          obscureText: false,
          keyboardType: TextInputType.visiblePassword,
        ),
      ),
    );
    expect(shown, contains('type="text"'));
    expect(shown, contains('autocapitalize="off"'));
    expect(shown, contains('autocorrect="off"'));
    expect(shown, contains('spellcheck="false"'));
    final hidden = _control(
      await _body(
        const TextField(
          name: 'p',
          obscureText: true,
          keyboardType: TextInputType.visiblePassword,
        ),
      ),
    );
    expect(hidden, contains('type="password"'));
  });

  test(
    'number is digits only; numberWithOptions(decimal) is decimal',
    () async {
      Future<String> tagOf(TextInputType t) async =>
          _control(await _body(TextField(name: 'n', keyboardType: t)));
      expect(
        await tagOf(TextInputType.number),
        contains('inputmode="numeric"'),
      );
      expect(
        await tagOf(const TextInputType.numberWithOptions(signed: true)),
        contains('inputmode="numeric"'),
      );
      expect(
        await tagOf(const TextInputType.numberWithOptions(decimal: true)),
        contains('inputmode="decimal"'),
      );
      expect(TextInputType.number, const TextInputType.numberWithOptions());
      expect(
        TextInputType.number,
        isNot(const TextInputType.numberWithOptions(decimal: true)),
      );
    },
  );

  test('the keyboard types of Flutter that are plain text compile', () async {
    for (final t in [
      TextInputType.multiline,
      TextInputType.datetime,
      TextInputType.name,
      TextInputType.streetAddress,
    ]) {
      final tag = _control(await _body(TextField(name: 'n', keyboardType: t)));
      expect(tag, contains('type="text"'), reason: '$t');
      expect(tag, isNot(contains('inputmode')), reason: '$t');
    }
    final none = _control(
      await _body(const TextField(name: 'n', keyboardType: TextInputType.none)),
    );
    expect(none, contains('inputmode="none"'));
    final area = await _body(
      const TextField(
        name: 'n',
        keyboardType: TextInputType.multiline,
        maxLines: null,
      ),
    );
    expect(area, contains('<textarea'));
  });
}
