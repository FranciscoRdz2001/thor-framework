// `Form(stay: true)` and `FileField(submitOnChange:)`: the attributes the
// script reads, the script only where they are, and its source file.
@TestOn('vm')
library;

import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:thor_engine/src/js_minify.dart';
import 'package:thor_engine/src/js_rename.dart';
import 'package:thor_ui/src/engine/form_script.dart';
import 'package:thor_ui/src/engine/stay_script.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> page(Widget body) => renderDocument(ThorApp(child: body));

const _submit = FilledButton(
  buttonType: ButtonType.submit,
  onPressed: _noop,
  child: Text('Send'),
);
void _noop() {}

void main() {
  test(
    'a stay form is marked, and the page ships the script and the bar',
    () async {
      final html = await page(
        const Form(action: '/a', stay: true, child: _submit),
      );
      expect(html, contains('data-t-stay'));
      expect(html, contains(stayScript));
      expect(html.indexOf(stayScript), lessThan(html.indexOf(formScript)));
      // The answer is a toast.
      expect(html, contains('id="thor-toast"'));
      expect(html, contains('thorToast'));
    },
  );

  test('a plain form ships none of it', () async {
    final html = await page(const Form(action: '/a', child: _submit));
    expect(html, isNot(contains(stayScript)));
    expect(html.replaceAll(stayScript, ''), isNot(contains('data-t-stay')));
  });

  test('a file field that submits on change names its button', () async {
    final html = await page(
      const Form(
        action: '/a',
        encoding: FormEncoding.multipart,
        child: Column(
          children: [
            FileField(name: 'f', submitOnChange: true, submitWith: 'store'),
            FileField(name: 'g', submitOnChange: true),
            FileField(name: 'h'),
            _submit,
          ],
        ),
      ),
    );
    expect(html, contains('data-t-submit-on-files="store"'));
    final markup = html.replaceAll(stayScript, '');
    expect('data-t-submit-on-files'.allMatches(markup).length, 2);
    expect(html, contains(stayScript));
    expect(markup, isNot(contains('data-t-stay')));
  });

  test('a plain file field is a normal file input', () async {
    final html = await page(
      const Form(
        action: '/a',
        child: FileField(name: 'f'),
      ),
    );
    expect(html, isNot(contains(stayScript)));
    expect(html, contains('type="file"'));
  });

  test('the script is its source file, minified', () async {
    final uri = await Isolate.resolvePackageUri(
      Uri.parse('package:thor_engine/lite/form_stay.js'),
    );
    final source = File.fromUri(uri!).readAsStringSync();
    expect(stayScript, minifyJs(renameLocals(source)));
  });
}
