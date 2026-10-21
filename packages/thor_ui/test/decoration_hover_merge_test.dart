@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

/// The hover rule of the page's `<style>`.
Future<String> _hover(BoxDecoration decoration) async {
  final html = await renderDocument(
    ThorApp(
      child: Container(decoration: decoration, child: const Text('x')),
    ),
  );
  final start = html.indexOf('id="thor-styles">');
  final css = html.substring(start, html.indexOf('</style>', start));
  final at = css.indexOf(':hover{');
  return css.substring(at, css.indexOf('}', at));
}

void main() {
  setUpAll(() => initializeThorTests(compactHtml: false));

  // A variant replaces the whole decoration, as in Flutter; to change one
  // field on hover, copy the base with that field.
  final base = BoxDecoration(
    color: const Color(0xFFFFFFFF),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: const Color(0xFFCCCCCC)),
  );
  const black = Color(0xFF000000);

  test('a bare variant resets what it does not name', () async {
    final rule = await _hover(
      base.when(
        hover: BoxDecoration(border: Border.all(color: black)),
      ),
    );
    expect(rule, contains('border-radius: 0'));
  });

  test('copyWith on the base changes one field and keeps the rest', () async {
    final rule = await _hover(
      base.when(
        hover: base.copyWith(border: Border.all(color: black)),
      ),
    );
    expect(rule, contains('border: 1px solid #000000'));
    // What the variant shares with the base is not repeated (and not reset).
    expect(rule, isNot(contains('border-radius')));
    expect(rule, isNot(contains('background-color')));
  });
}
