// Fixture: fields without a label on purpose.
// ignore_for_file: thor_lints/text_field_without_label
// ThemeData.inputDecorationTheme: helperStyle, errorStyle, hoverColor and
// errorBorder reach the fields, and the field's own decoration wins.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _css(Widget w, {InputDecorationTheme? theme}) async {
  final html = await renderDocument(
    ThorApp(
      theme: ThemeData(inputDecorationTheme: theme),
      child: w,
    ),
  );
  return RegExp(
    r'<style[^>]*>([\s\S]*?)</style>',
  ).allMatches(html).map((m) => m[1]).join().replaceAll(' ', '');
}

const _theme = InputDecorationTheme(
  helperStyle: TextStyle(fontSize: 11, color: Color(0xFF123456)),
  errorStyle: TextStyle(fontSize: 13, color: Color(0xFF654321)),
  hoverColor: Color(0xFFABCDEF),
  errorBorder: OutlineInputBorder(
    borderSide: BorderSide(color: Color(0xFFFF0000), width: 3),
  ),
);

void main() {
  setUpAll(initializeThorTests);

  test(
    'a field whose border gives no color takes the scheme, not black',
    () async {
      // The border itself is Flutter's: `BorderSide()`; the field decides.
      expect(const OutlineInputBorder().borderSide, const BorderSide());
      final css = await _css(const TextField());
      expect(css, contains('var(--t-on-surface-variant'));
      expect(css, isNot(contains('rgb(0')));
      // An explicit color still wins.
      expect(
        const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF123456)),
        ).shadow!.toLowerCase(),
        contains('#123456'),
      );
    },
  );

  test('helperStyle styles the helper line', () async {
    final css = await _css(
      const TextField(decoration: InputDecoration(helperText: 'Help')),
      theme: _theme,
    );
    expect(css, contains('font-size:11px'));
    expect(css.toLowerCase(), contains('#123456'));
  });

  test(
    'errorStyle styles the error line, with a server error or not',
    () async {
      for (final e in ['Bad', null]) {
        final css = await _css(
          TextField(
            decoration: InputDecoration(helperText: 'h', errorText: e),
          ),
          theme: _theme,
        );
        expect(css, contains('font-size:13px'), reason: 'errorText: $e');
        expect(css.toLowerCase(), contains('#654321'));
      }
    },
  );

  test('the decoration own helperStyle/errorStyle win', () async {
    final css = await _css(
      const TextField(
        decoration: InputDecoration(
          helperText: 'h',
          helperStyle: TextStyle(fontSize: 19),
        ),
      ),
      theme: _theme,
    );
    expect(css, contains('font-size:19px'));
    expect(css, isNot(contains('font-size:11px')));
  });

  test('hoverColor paints the field on hover', () async {
    final css = await _css(const TextField(), theme: _theme);
    expect(css.toLowerCase(), contains('#abcdef'));
    expect(css, contains(':hover'));
    final none = await _css(const TextField());
    expect(none, isNot(contains(':hover')));
  });

  test('errorBorder draws an invalid field', () async {
    final css = await _css(const TextField(), theme: _theme);
    expect(css.toLowerCase(), contains('inset000'));
    expect(css, contains('3px'));
    final own = await _css(
      const TextField(
        decoration: InputDecoration(
          errorBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF00FF00), width: 5),
          ),
        ),
      ),
      theme: _theme,
    );
    expect(own, contains('5px'));
    expect(own.toLowerCase(), contains('#00ff00'));
  });

  test('applyDefaults merges the four, null keeps the theme', () {
    final d = const InputDecoration().applyDefaults(_theme);
    expect(d.helperStyle, _theme.helperStyle);
    expect(d.errorStyle, _theme.errorStyle);
    expect(d.hoverColor, _theme.hoverColor);
    expect(d.errorBorder, _theme.errorBorder);
  });
}
