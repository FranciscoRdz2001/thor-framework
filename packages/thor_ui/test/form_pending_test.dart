// Fixture: fields without a label on purpose (focus, state and form behavior).
// ignore_for_file: thor_lints/text_field_without_label
// What a page with a Form ships so a submit shows «sending» (no double
// submit) and a server error takes the focus. The browser side is checked
// by `tool/thor e2e forms`.
@TestOn('vm')
library;

import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:thor_engine/src/js_minify.dart';
import 'package:thor_engine/src/js_rename.dart';
import 'package:thor_ui/src/engine/form_script.dart';
import 'package:thor_ui/src/engine/upload_script.dart';
import 'package:thor_ui/src/foundation/style_registry.dart'
    show SharedStylesScope;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> page(Widget body) => renderDocument(ThorApp(child: body));

/// [body] as the answer of a failed action (`POST` re-rendered with a
/// `422`): the only page whose first error takes the focus.
Future<String> failed(Widget body) => renderDocument(
  SharedStylesScope(errorFocus: true, child: ThorApp(child: body)),
);

/// The page's elements: without its scripts (they name the attributes).
String markup(String html) => html
    .substring(html.indexOf('<body'))
    .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>'), '');

int scripts(String html) =>
    formScript.isEmpty ? 0 : formScript.allMatches(html).length;

const _submit = FilledButton(
  buttonType: ButtonType.submit,
  onPressed: _noop,
  child: Text('Send'),
);
void _noop() {}

Widget _field(String name, {String? error}) => TextFormField(
  name: name,
  decoration: InputDecoration(labelText: name, errorText: error),
  validators: const [Validator.required('Falta.')],
);

void main() {
  setUpAll(initializeThorTests);

  group('the sending state script', () {
    test('is the source file, minified', () async {
      final uri = await Isolate.resolvePackageUri(
        Uri.parse('package:thor_engine/lite/form_submit.js'),
      );
      final source = File.fromUri(uri!).readAsStringSync();
      expect(formScript, isNotEmpty);
      expect(formScript, minifyJs(renameLocals(source)));
    });

    test('a button is the same one on the next page: action key or path, '
        'not the query', () async {
      final uri = await Isolate.resolvePackageUri(
        Uri.parse('package:thor_engine/lite/form_submit.js'),
      );
      final source = File.fromUri(uri!).readAsStringSync();
      // The pattern `Z` strips the query with (a JavaScript literal whose
      // syntax Dart's RegExp reads the same).
      final literal = RegExp(
        r"const Z = \(b\) => b\.getAttribute\('formaction'\)\?\.replace\(/(.*)/, '\?'\)",
      ).firstMatch(source);
      expect(literal, isNotNull, reason: 'the Z of form_submit.js');
      final strip = RegExp(literal![1]!);
      String z(String action) => action.replaceFirst(strip, '?');
      // A key (several actions): the query before it goes.
      expect(z('/p?x=1&/save'), '/p?/save');
      expect(z('?a=1&b=2&/save'), '?/save');
      expect(z('/p?/save'), '/p?/save');
      expect(z('/p?next=/a&/save'), '/p?/save');
      // No key (the page's only action): the whole query goes, whatever the
      // answer's query says: `?qty=4` and `?qty=5` are one button.
      expect(z('/item/shirt?qty=4'), z('/item/shirt?qty=5'));
      expect(z('/item/shirt?qty=4'), '/item/shirt?');
      expect(z('/p?next=/a'), '/p?');
      expect(z('/login'), '/login');
      // Two buttons of different pages stay different.
      expect(z('/a?x=1'), isNot(z('/b?x=1')));
    });

    test('keeps the place of a post answered by the same page (small)', () {
      // Saved by a POST only, in sessionStorage (guarded: it can throw),
      // applied by a `navigate` load of the page it came from.
      expect(formScript, contains("'thor:keep'"));
      expect(formScript, contains('sessionStorage'));
      expect(formScript, contains("==='post'"));
      expect(formScript, contains("type==='navigate'"));
      expect(formScript, contains('location.hash'));
      // The whole script stays small: it travels on every page with a Form.
      expect(formScript.length, lessThan(3100));
    });

    test('a page with a posting Form ships it once, after the form', () async {
      final html = await page(
        const Column(
          children: [
            Form(action: '/a', child: _submit),
            Form(action: '/b', child: _submit),
          ],
        ),
      );
      expect(scripts(html), 1);
      expect(
        html.indexOf(formScript),
        greaterThan(html.lastIndexOf('</form>')),
      );
    });

    test('a page without a Form ships nothing (0 new bytes)', () async {
      final html = await page(const Text('hello'));
      expect(formScript, isNotEmpty);
      expect(html, isNot(contains(formScript)));
    });

    test('a Form that runs onSubmit in the engine does not need it', () async {
      final html = await page(Form(onSubmit: () {}, child: _submit));
      expect(html, isNot(contains(formScript)));
    });

    test(
      'disableOnSubmit: false opts the form out and ships no script',
      () async {
        final html = await page(
          const Form(action: '/x', disableOnSubmit: false, child: _submit),
        );
        expect(markup(html), contains('data-t-nopending'));
        expect(html, isNot(contains(formScript)));
      },
    );

    test('one form opted out does not opt the other out', () async {
      final html = await page(
        const Column(
          children: [
            Form(action: '/a', disableOnSubmit: false, child: _submit),
            Form(action: '/b', child: _submit),
          ],
        ),
      );
      expect(scripts(html), 1);
      expect('data-t-nopending'.allMatches(markup(html)), hasLength(1));
    });

    test(
      'the engine does not replace it: it ships with the engine too',
      () async {
        final html = await page(
          const Form(action: '/x', child: _WithEngine(_submit)),
        );
        expect(scripts(html), 1);
      },
    );

    test('a pending form shows a progress cursor (CSS, no JS)', () async {
      final html = await page(const Form(action: '/x', child: _submit));
      expect(html, contains('[data-pending]'));
      expect(html, contains('[data-pending]{cursor: progress}'));
    });
  });

  group('upload progress', () {
    test('LinearProgressIndicator.upload is a hidden <progress> the form '
        'script fills (the browser side: forms_upload_check.mjs)', () async {
      final html = await page(
        const Form(
          action: '/videos',
          encoding: FormEncoding.multipart,
          child: Column(
            children: [
              FileField(name: 'video'),
              LinearProgressIndicator.upload(),
              _submit,
            ],
          ),
        ),
      );
      final bar = RegExp(r'<progress[^>]*>').firstMatch(markup(html))![0]!;
      expect(bar, contains('data-t-upload'));
      expect(bar, contains('hidden'));
      expect(bar, contains('max="1"'));
      expect(bar, isNot(contains('value=')));
      expect(bar, contains('aria-label="Upload progress"'));
      // `display: block` of the bar's class must not beat `hidden`.
      expect(html, contains('[hidden]{display: none}'));
      // The form script is untouched; the upload one comes before it (it puts
      // a kept result's address back before the form script keeps the place).
      expect(scripts(html), 1);
      expect(formScript, isNot(contains('XMLHttpRequest')));
      expect(html.indexOf(uploadScript), lessThan(html.indexOf(formScript)));
      expect(uploadScript, contains('progress[data-t-upload]'));
      expect(uploadScript, contains('x-thor-upload'));
    });

    test('the upload script is its source file, minified', () async {
      final uri = await Isolate.resolvePackageUri(
        Uri.parse('package:thor_engine/lite/form_upload.js'),
      );
      final source = File.fromUri(uri!).readAsStringSync();
      expect(uploadScript, minifyJs(renameLocals(source)));
    });

    test('a page with a Form and no upload bar ships no upload script '
        '(0 bytes more)', () async {
      final html = await page(const Form(action: '/a', child: _submit));
      expect(html, contains(formScript));
      expect(html, isNot(contains(uploadScript)));
      expect(html, isNot(contains('XMLHttpRequest')));
    });

    test('a plain LinearProgressIndicator is not an upload bar', () async {
      final html = markup(await page(const LinearProgressIndicator()));
      expect(html, isNot(contains('data-t-upload')));
      expect(html, isNot(contains('hidden')));
    });
  });

  group('the first error takes the focus', () {
    test(
      'only the first field with an error is autofocus (3rd of 4)',
      () async {
        final html = await failed(
          Form(
            action: '/x',
            child: Column(
              children: [
                _field('a'),
                _field('b'),
                _field('c', error: 'Wrong c.'),
                _field('d', error: 'Wrong d.'),
              ],
            ),
          ),
        );
        expect('autofocus'.allMatches(markup(html)), hasLength(1));
        final tag = RegExp(r'<input[^>]*id="f-c"[^>]*>').firstMatch(html)![0]!;
        expect(tag, contains('autofocus'));
        expect(tag, contains('aria-invalid="true"'));
        expect(tag, contains('aria-describedby="f-c-msg"'));
        expect(html, contains('id="f-c-msg"'));
      },
    );

    test(
      'a page that only shows an error (a GET, a demo) takes no focus',
      () async {
        final html = await page(
          Form(
            action: '/x',
            child: Column(children: [_field('a', error: 'Wrong a.')]),
          ),
        );
        expect(markup(html), isNot(contains('autofocus')));
        expect(markup(html), contains('aria-invalid="true"'));
        final bare = await page(
          const TextField(
            name: 'q',
            decoration: InputDecoration(errorText: 'Wrong.'),
          ),
        );
        expect(markup(bare), isNot(contains('autofocus')));
        expect(bare, isNot(contains(formScript)));
      },
    );

    test('no error, no autofocus', () async {
      final html = await failed(Form(action: '/x', child: _field('a')));
      expect(markup(html), isNot(contains('autofocus')));
    });

    test(
      'a plain TextField with an error also takes it (and the script)',
      () async {
        final html = await failed(
          const TextField(
            name: 'q',
            decoration: InputDecoration(errorText: 'Wrong.'),
          ),
        );
        expect(markup(html), contains('autofocus'));
        expect(html, contains(formScript));
      },
    );

    test(
      'a field the author already made autofocus stays the only one',
      () async {
        final html = await failed(
          Form(
            action: '/x',
            child: Column(
              children: [
                const TextField(name: 'q', autofocus: true),
                _field('c', error: 'Wrong.'),
              ],
            ),
          ),
        );
        // The page's own choice is honored by the browser; the script picks
        // the invalid one explicitly.
        expect(
          'autofocus'.allMatches(markup(html)).length,
          greaterThanOrEqualTo(1),
        );
        expect(html, contains('aria-invalid="true"'));
      },
    );

    test('a disabled field with an error does not swallow the focus', () async {
      final html = await failed(
        const Form(
          action: '/x',
          child: Column(
            children: [
              TextFormField(
                name: 'a',
                enabled: false,
                decoration: InputDecoration(errorText: 'Wrong a.'),
              ),
              _FieldB(),
            ],
          ),
        ),
      );
      final a = RegExp(r'<input[^>]*id="f-a"[^>]*>').firstMatch(html)![0]!;
      final b = RegExp(r'<input[^>]*id="f-b"[^>]*>').firstMatch(html)![0]!;
      expect(a, isNot(contains('autofocus')));
      expect(a, contains('aria-invalid="true"'));
      expect(b, contains('autofocus'));
    });

    test('error text and field names with markup are escaped', () async {
      final html = await failed(
        const Form(
          action: '/x',
          child: TextFormField(
            name: 'a"><script>window.pwned=1</script>',
            decoration: InputDecoration(
              errorText: '<script>window.pwned=2</script>',
            ),
          ),
        ),
      );
      expect(markup(html), isNot(contains('<script')));
      expect(markup(html), contains('&lt;script&gt;window.pwned=2'));
    });

    test('two renders do not share the claim (per page)', () async {
      final a = await failed(
        Form(
          action: '/x',
          child: _field('a', error: 'x'),
        ),
      );
      final b = await failed(
        Form(
          action: '/x',
          child: _field('a', error: 'x'),
        ),
      );
      expect(markup(a), contains('autofocus'));
      expect(markup(b), contains('autofocus'));
    });
  });
}

class _FieldB extends StatelessWidget {
  const _FieldB();

  @override
  Widget build(BuildContext context) => _field('b', error: 'Wrong b.');
}

class _WithEngine extends StatelessWidget {
  const _WithEngine(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    ThorStyleRegistry.active(context)?.useEngine();
    return child;
  }
}
