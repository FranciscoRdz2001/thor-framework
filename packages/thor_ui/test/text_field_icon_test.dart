// Fixture: fields without a label on purpose (focus, state and form behavior).
// ignore_for_file: thor_lints/text_field_without_label
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

const _x = IconData.svg('x', '<path d="M0 0"/>');

/// The icon slot of a `TextField` is 48x48 at least (Flutter's default), so
/// a dense field with an icon grows to 48 px; Flutter sizes the slot by its
/// icon with `prefixIconConstraints` / `suffixIconConstraints`.
void main() {
  setUpAll(() => initializeThorTests(compactHtml: false));

  /// Everything before / after the `<input`: the icon slots.
  Future<({String before, String after})> slots(InputDecoration d) async {
    final html = await renderHtml(TextField(decoration: d));
    final at = html.indexOf('<input');
    return (before: html.substring(0, at), after: html.substring(at));
  }

  test('the slot is 48x48 at least by default (Flutter)', () async {
    final s = await slots(const InputDecoration(prefixIcon: Icon(_x)));
    expect(s.before, contains('min-width: 48px'));
    expect(s.before, contains('min-height: 48px'));
  });

  test('prefixIconConstraints replaces the 48 px minimum', () async {
    final s = await slots(
      const InputDecoration(
        prefixIcon: Icon(_x),
        prefixIconConstraints: BoxConstraints(),
      ),
    );
    expect(s.before, isNot(contains('48px')));
    expect(s.before, contains('display: grid'));
  });

  test('a min size or a max size of the slot is written', () async {
    final s = await slots(
      const InputDecoration(
        prefixIcon: Icon(_x),
        prefixIconConstraints: BoxConstraints(
          minWidth: 32,
          maxWidth: 40,
          minHeight: 24,
        ),
      ),
    );
    expect(s.before, contains('min-width: 32px'));
    expect(s.before, contains('max-width: 40px'));
    expect(s.before, contains('min-height: 24px'));
    expect(s.before, isNot(contains('48px')));
  });

  test('each side has its own constraints', () async {
    final s = await slots(
      const InputDecoration(
        prefixIcon: Icon(_x),
        suffixIcon: Icon(_x),
        suffixIconConstraints: BoxConstraints(),
      ),
    );
    expect(s.before, contains('min-height: 48px'), reason: 'prefix keeps 48');
    expect(s.after, isNot(contains('48px')), reason: 'suffix is free');
  });

  test('constraints without an icon write nothing', () async {
    final html = await renderHtml(
      const TextField(
        decoration: InputDecoration(
          prefixIconConstraints: BoxConstraints(minWidth: 99),
          suffixIconConstraints: BoxConstraints(minWidth: 99),
        ),
      ),
    );
    expect(html, isNot(contains('99px')));
  });

  test('copyWith and the theme defaults keep them', () async {
    const d = InputDecoration(
      prefixIcon: Icon(_x),
      prefixIconConstraints: BoxConstraints(),
      suffixIconConstraints: BoxConstraints(minWidth: 10),
    );
    final copy = d.copyWith(hintText: 'x');
    expect(copy.prefixIconConstraints, isNotNull);
    expect(copy.suffixIconConstraints?.minWidth, 10);
    final themed = d.applyDefaults(const InputDecorationTheme());
    expect(themed.prefixIconConstraints, isNotNull);
    final s = await slots(themed);
    expect(s.before, isNot(contains('48px')));
  });

  test('tight constraints size the slot exactly', () async {
    final s = await slots(
      const InputDecoration(
        prefixIcon: Icon(_x),
        prefixIconConstraints: BoxConstraints.tightFor(width: 40, height: 30),
      ),
    );
    expect(s.before, contains('min-width: 40px'));
    expect(s.before, contains('max-width: 40px'));
    expect(s.before, contains('min-height: 30px'));
    expect(s.before, contains('max-height: 30px'));
  });

  test('constraints with variants adapt the slot per breakpoint', () async {
    final html = await renderDocument(
      ThorApp(
        child: TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(_x),
            prefixIconConstraints: const BoxConstraints().when(
              medium: const BoxConstraints(minWidth: 48, minHeight: 48),
            ),
          ),
        ),
      ),
    );
    final start = html.indexOf('id="thor-styles">');
    final css = html.substring(start, html.indexOf('</style>', start));
    expect(css, contains('@media'));
    expect(css, contains('min-width: 48px'));
  });

  test('a dense outlined filled field with error and both icons', () async {
    final html = await renderHtml(
      const TextField(
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          border: OutlineInputBorder(),
          errorText: 'bad',
          prefixIcon: Icon(_x),
          prefixIconConstraints: BoxConstraints(),
          suffixIcon: Icon(_x),
          suffixIconConstraints: BoxConstraints(),
        ),
      ),
    );
    expect(html, contains('bad'));
    expect(html, isNot(contains('48px')));
  });
}
