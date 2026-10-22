@TestOn('vm')
library;

// The first group pins the CSS the stylesheet API wrote before it was
// thor's: the same rules must keep writing the same CSS.
// ignore_for_file: thor_lints/avoid_raw_css
import 'package:test/test.dart';
import 'package:thor_ui/html.dart' show css;
import 'package:thor_ui/src/foundation/css_rules.dart'
    show renderStyleRules, resolveSelector, safeCssPrelude, uniqueStyleRules;
import 'package:thor_ui/thor_ui.dart';

void main() {
  group('the same CSS as before thor owned the stylesheet API', () {
    final cases = <String, (StyleRule, String)>{
      'a flat rule': (
        css('.a').styles(raw: {'color': 'red', 'margin': '0'}),
        '.a {\n  color: red;\n  margin: 0;\n}',
      ),
      'merged declarations keep the first key order': (
        css('.a').styles(raw: {'a': '1', 'b': '2'}).styles(raw: {'a': '3'}),
        '.a {\n  a: 3;\n  b: 2;\n}',
      ),
      '& and descendants, three levels': (
        css('.a', [
          css('&:hover').styles(raw: {'x': '1'}),
          css('.b', [
            css('&::before').styles(raw: {'content': '""'}),
            css('.c').styles(raw: {'y': '2'}),
          ]),
        ]),
        '.a:hover {\n  x: 1;\n}\n.a .b::before {\n  content: "";\n}\n.a .b .c {\n  y: 2;\n}',
      ),
      'media, layer and supports, nested in a rule': (
        css('.a', [
          css.media('(min-width: 900px)', [
            css('&').styles(raw: {'x': '1'}),
          ]),
          css.supports('(display: grid)', [
            css('.g').styles(raw: {'d': 'g'}),
          ]),
        ]),
        '@media (min-width: 900px) {\n  .a {\n    x: 1;\n  }\n}\n@supports (display: grid) {\n  .a .g {\n    d: g;\n  }\n}',
      ),
      'a named and an anonymous layer': (
        css.layer(name: 'app', [
          css('html').styles(raw: {'m': '0'}),
        ]),
        '@layer app {\n  html {\n    m: 0;\n  }\n}',
      ),
      // Straight in `thor` a rule would beat every thor sublayer (widget
      // props included); the old name keeps meaning "below thor's classes".
      'the old thor layer is the reset layer': (
        css.layer(name: 'thor', [
          css('html').styles(raw: {'m': '0'}),
        ]),
        '@layer thor.reset {\n  html {\n    m: 0;\n  }\n}',
      ),
      // Below every element's props: a widget's own values beat the
      // component's defaults.
      'component styles are in thor.components': (
        css.components([
          css('.chip').styles(raw: {'p': '4px'}),
        ]),
        '@layer thor.components {\n  .chip {\n    p: 4px;\n  }\n}',
      ),
      // Above the elements' props: the state of an ancestor beats the
      // child's own value.
      'state rules are in thor.overrides': (
        css.states([
          css('.row:has(a[aria-current]) .name').styles(raw: {'w': '600'}),
        ]),
        '@layer thor.overrides {\n  .row:has(a[aria-current]) .name {\n    w: 600;\n  }\n}',
      ),
      'keyframes': (
        css.keyframes('fade', {
          'from': const StyleProps(opacity: 0),
          '50%': const StyleProps(raw: {'opacity': '0.4'}),
          'to': const StyleProps(opacity: 1),
        }),
        '@keyframes fade {\n  from {\n    opacity: 0;\n  }\n  50% {\n    opacity: 0.4;\n  }\n  to {\n    opacity: 1;\n  }\n}',
      ),
      'typed values through props()': (
        css('.card').props(
          const StyleProps(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: Color(0xFFFFFFFF)),
          ),
        ),
        '.card {\n  padding: 12px;\n  background-color: #ffffff;\n}',
      ),
    };
    for (final MapEntry(key: name, value: (rule, css)) in cases.entries) {
      test(name, () => expect(rule.toCss(), css));
    }
  });

  group('breakpoint overrides of a nested rule', () {
    // `.mb .row` (0,2,0) beats a top-level `.row` (0,1,0) in a media query:
    // the override goes inside the same parent to have the same weight.
    test('a media query nested in the parent writes the same selector', () {
      final css1 = css('.mb', [
        css('.row').styles(raw: {'p': '8px'}),
        css.minWidth(480, [
          css('.row').styles(raw: {'p': '10px'}),
        ]),
        WindowSizeClass.large.media([
          css('.row').styles(raw: {'p': '12px'}),
        ]),
      ]).toCss();
      expect(css1, contains('.mb .row {'));
      final medias = css1.split('@media').skip(1).toList();
      expect(medias, hasLength(2));
      for (final m in medias) {
        expect(m, contains('.mb .row {'));
      }
      // Same selector, later in the sheet: the override wins at its width.
      expect(css1.lastIndexOf('p: 12px'), greaterThan(css1.indexOf('p: 8px')));
    });

    test('outside the parent the media rule is lighter', () {
      final out = css.minWidth(480, [
        css('.row').styles(raw: {'p': '10px'}),
      ]);
      expect(out.toCss(), contains('  .row {'));
      expect(out.toCss(), isNot(contains('.mb')));
    });
  });

  group('& resolution', () {
    test('a list parent: every item gets the child, none escapes', () {
      expect(resolveSelector('&:hover', '.a, .b'), '.a:hover, .b:hover');
      expect(resolveSelector('.c', '.a, .b'), '.a .c, .b .c');
    });

    test('a list child under a parent: each item is scoped', () {
      expect(resolveSelector('h2, h3', '.p'), '.p h2, .p h3');
      expect(resolveSelector('&:hover, &:focus', '.p'), '.p:hover, .p:focus');
    });

    test(':is() and attribute values are one item, not a list', () {
      expect(resolveSelector(':is(a, b)', '.p'), '.p :is(a, b)');
      expect(resolveSelector('[data-x="a, b"]', '.p'), '.p [data-x="a, b"]');
    });

    test('& inside an attribute value is not the parent', () {
      expect(resolveSelector('&[data-x="a&b"]', '.p'), '.p[data-x="a&b"]');
    });

    test('& in the middle stands for the parent', () {
      expect(resolveSelector('.dark &', '.p'), '.dark .p');
    });

    test('at the top, & means nothing', () {
      expect(resolveSelector('&:root', ''), ':root');
      expect(resolveSelector('.a, .b', ''), '.a, .b');
    });
  });

  group('fail-closed', () {
    test('a value cannot end the rule, inject one or close <style>', () {
      final sheet = renderStyleRules([
        css('.a').styles(
          raw: {
            'color': 'red; } body { display: none',
            'background': '</style><script>alert(1)</script>',
            'content': '"unterminated',
          },
        ),
        css('.next').styles(raw: {'margin': '0'}),
      ]);
      expect(sheet, isNot(contains('</style')));
      expect(sheet, isNot(contains('body {')));
      expect(RegExp('[{}]').allMatches(_outsideStrings(sheet)).length, 4);
      expect(sheet, contains('.next {'));
    });

    test('a selector or at-rule prelude cannot break out either', () {
      final sheet = renderStyleRules([
        css('.a { } body').styles(raw: {'x': '1'}),
        css('.b</style>').styles(raw: {'x': '1'}),
        css.media('screen { } body {', [
          css('.c').styles(raw: {'x': '1'}),
        ]),
        css.keyframes('k { }', {
          'from; } body {': const StyleProps(opacity: 0),
        }),
        css('.ok').styles(raw: {'y': '2'}),
      ]);
      expect(sheet, isNot(contains('</style')));
      // Only the rules' own braces are structural: .a, .b, the media and
      // its rule, the keyframes and its stop, .ok (7 pairs). The injected
      // ones are CSS escapes inside an invalid prelude, which the browser
      // drops without reading on.
      final bare = _outsideStrings(sheet);
      expect(RegExp('{').allMatches(bare), hasLength(7));
      expect(RegExp('}').allMatches(bare), hasLength(7));
      expect(sheet, contains('.ok {'));
    });

    test('a valid prelude is unchanged', () {
      for (final prelude in [
        '.a > .b ~ .c + .d',
        '[data-x="a;b{c}"]',
        'screen and (min-width: 768px)',
        '(width < 600px)',
        ':is(h1, h2)::before',
      ]) {
        final escaped = safeCssPrelude(prelude);
        if (prelude.contains('<')) {
          expect(escaped, isNot(contains('<')), reason: prelude);
        } else {
          expect(escaped, prelude, reason: prelude);
        }
      }
    });

    test('a backslash-escaped `<` in a quoted prelude is escaped', () {
      final out = safeCssPrelude('[data-x="\\</style><img>"]');
      expect(out, isNot(contains('<')));
    });

    test('an invalid property name is dropped, the rest stays', () {
      final sheet = css('.a')
          .styles(
            raw: {'color': 'red', 'bad name': 'x', 'x}y': 'z', 'margin': '0'},
          )
          .toCss();
      expect(sheet, contains('color: red'));
      expect(sheet, contains('margin: 0'));
      expect(sheet, isNot(contains('bad name')));
      expect(sheet, isNot(contains('x}y')));
    });

    test('.when() in a stylesheet fails, in release too (not an assert)', () {
      final adaptive = const StyleProps(
        opacity: 1,
      ).when(medium: const StyleProps(opacity: 0));
      expect(() => css('.a').props(adaptive), throwsArgumentError);
      expect(() => css.keyframes('k', {'from': adaptive}), throwsArgumentError);
    });

    test('keyframes nested in a rule fail with a clear message', () {
      final nested = css('.a', [
        css.keyframes('k', {'from': const StyleProps(opacity: 0)}),
      ]);
      expect(
        nested.toCss,
        throwsA(
          isA<ArgumentError>().having(
            (e) => '${e.message}',
            'message',
            contains('top of the stylesheet'),
          ),
        ),
      );
    });
  });

  group('registration', () {
    test('a rule listed twice is written once, first place kept', () {
      final a = css('.a').styles(raw: {'x': '1'});
      final b = css('.b').styles(raw: {'y': '2'});
      expect(uniqueStyleRules([a, b, a]), [a, b]);
      final sheet = renderStyleRules([a, b, a]);
      expect(RegExp(r'\.a \{').allMatches(sheet), hasLength(1));
      expect(sheet.indexOf('.a {'), lessThan(sheet.indexOf('.b {')));
    });

    test('equal rules built twice are both kept (identity, not content)', () {
      final sheet = renderStyleRules([
        css('.a').styles(raw: {'x': '1'}),
        css('.a').styles(raw: {'x': '1'}),
      ]);
      expect(RegExp(r'\.a \{').allMatches(sheet), hasLength(2));
    });
  });
}

/// [css] without its quoted strings.
String _outsideStrings(String css) =>
    css.replaceAll(RegExp(r'"(\\.|[^"\\])*"'), '""');
