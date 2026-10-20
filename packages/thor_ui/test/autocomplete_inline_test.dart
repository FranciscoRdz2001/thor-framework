// ignore_for_file: thor_lints/text_field_without_label
// RawAutocomplete(inline:, highlightFirst:): the markup the engine reads.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _body({
  bool inline = false,
  bool highlightFirst = false,
  bool matchWords = false,
}) async => bodyOfPage(
  await renderDocument(
    ThorApp(
      child: RawAutocomplete<String>(
        inline: inline,
        highlightFirst: highlightFirst,
        matchWords: matchWords,
        optionsBuilder: (v) => const <String>[],
        fieldViewBuilder: (context, controller, focus, submit) =>
            TextField(controller: controller, focusNode: focus),
        optionsViewBuilder: (context, onSelected, options) =>
            const Semantics(role: SemanticsRole.option, child: Text('x')),
      ),
    ),
  ),
);

String _tagOf(String html, String needle) =>
    RegExp('<[^>]*$needle[^>]*>').firstMatch(html)![0]!;

void main() {
  setUpAll(initializeThorTests);

  test('default: a popover panel, flags empty', () async {
    final html = await _body();
    expect(html, contains('popover="manual"'));
    expect(html, isNot(contains('data-t-inl')));
    expect(html, isNot(contains('data-t-ac="')));
  });

  test('inline: a listbox in the flow, no popover', () async {
    final html = await _body(inline: true);
    expect(html, isNot(contains('popover')));
    expect(_tagOf(html, 'data-t-inl'), contains('role="listbox"'));
    expect(_tagOf(html, 'data-t-ac='), contains('data-t-ac="i"'));
    // The status region stays before the panel.
    expect(
      html.indexOf('data-t-ac-status'),
      lessThan(html.indexOf('data-t-inl')),
    );
  });

  test('highlightFirst adds h to the root flags', () async {
    final html = await _body(inline: true, highlightFirst: true);
    expect(_tagOf(html, 'data-t-ac='), contains('data-t-ac="ih"'));
    final popover = await _body(highlightFirst: true);
    expect(_tagOf(popover, 'data-t-ac='), contains('data-t-ac="h"'));
  });

  test('matchWords adds w to the root flags', () async {
    final html = await _body(matchWords: true);
    expect(_tagOf(html, 'data-t-ac='), contains('data-t-ac="w"'));
  });
}
