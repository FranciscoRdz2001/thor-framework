@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

const _plus = IconData.svg('plus', '<path d="M0 0"/>');

void main() {
  setUpAll(initializeThorTests);

  group('ExpansionTile icon colors', () {
    test('a trailing Icon takes collapsedIconColor and iconColor', () async {
      final html = await renderHtml(
        const ExpansionTile(
          title: Text('What is included?'),
          trailing: Icon(_plus),
          iconColor: Color(0xff111111),
          collapsedIconColor: Color(0xff6b7280),
          children: [Text('Todo')],
        ),
      );
      expect(html, contains('color: #6b7280'));
      // While its <details> is open (not a nested one).
      expect(
        html,
        matches(
          RegExp(r'@scope \(details\[open\]\)[^{]*\{[^}]*color: #111111'),
        ),
      );
    });

    test('a leading Icon too; an Icon with its own color keeps it', () async {
      final html = await renderHtml(
        const ExpansionTile(
          title: Text('A'),
          leading: Icon(_plus),
          trailing: Icon(_plus, color: Color(0xffff0000)),
          collapsedIconColor: Color(0xff6b7280),
          children: [Text('B')],
        ),
      );
      expect(html, contains('color: #6b7280'));
      expect(html, contains('color: #ff0000'));
    });
  });

  group('InputDecoration.label', () {
    test('a widget label is the <label for> and names the field', () async {
      final html = await renderHtml(
        const TextFormField(
          name: 'company',
          decoration: InputDecoration(
            label: Text.rich(
              TextSpan(
                text: 'Company ',
                children: [
                  TextSpan(
                    text: 'optional',
                    style: TextStyle(color: Color(0xff9ca3af)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final label = RegExp(
        r'<label[^>]*for="([^"]+)"[^>]*>([\s\S]*?)</label>',
      ).firstMatch(html);
      expect(label, isNotNull);
      expect(label![2], contains('Company'));
      expect(label[2], contains('optional'));
      expect(html, contains('id="${label[1]}"'));
      // The <label> names it; no aria-label overrides it.
      final input = RegExp(r'<input[^>]*>').firstMatch(html)![0]!;
      expect(input, isNot(contains('aria-label')));
    });

    test('label and labelText are exclusive', () {
      expect(
        () => InputDecoration(label: const Text('a'), labelText: 'b'),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('Form enctype', () {
    test('a mailto: action posts as text/plain', () async {
      final html = await renderHtml(
        const Form(action: 'mailto:hello@example.com', child: Text('x')),
      );
      expect(html, contains('enctype="text/plain"'));
      final plain = await renderHtml(
        const Form(action: '/send', child: Text('x')),
      );
      expect(plain, isNot(contains('enctype')));
    });

    test('an explicit encoding wins over mailto', () async {
      final html = await renderHtml(
        const Form(
          action: 'mailto:hello@example.com',
          encoding: FormEncoding.multipart,
          child: Text('x'),
        ),
      );
      expect(html, contains('enctype="multipart/form-data"'));
    });
  });
}
