import 'package:test/test.dart';
import 'package:thor_engine/css_text.dart';

void main() {
  group('splitCssStatements', () {
    test('rules, at-rules and statements that end in ;', () {
      final s = splitCssStatements(
        '@layer a, b;.x{color: red}@media (min-width: 1px){.x{color: blue}}',
      );
      expect(s.map(cssStatementText), [
        '@layer a, b;',
        '.x{color: red}',
        '@media (min-width: 1px){.x{color: blue}}',
      ]);
    });

    test('a brace in a string or url() does not end the block', () {
      const css =
          '.x{content: "}{"}.y{background-image: url("data:a{b}")}'
          ".z{content: '\\'}'}";
      expect(splitCssStatements(css).map(cssStatementText), [
        '.x{content: "}{"}',
        '.y{background-image: url("data:a{b}")}',
        ".z{content: '\\'}'}",
      ]);
    });

    test('flattenRules gives each rule inside a group its condition', () {
      final rules = flattenRules(
        splitCssStatements('.a{x: 1}@media m{.a{x: 2}.b{x: 3}}'),
      );
      expect(rules, [
        (wrap: null, rule: '.a{x: 1}'),
        (wrap: '@media m', rule: '.a{x: 2}'),
        (wrap: '@media m', rule: '.b{x: 3}'),
      ]);
    });
  });

  group('groupClassRules', () {
    test('one at-rule per condition for many classes', () {
      final css = groupClassRules([
        [(wrap: null, rule: '.a{x: 1}'), (wrap: '@media m', rule: '.a{x: 2}')],
        [(wrap: null, rule: '.b{x: 1}'), (wrap: '@media m', rule: '.b{x: 2}')],
      ]);
      expect(css, '.a{x: 1}.b{x: 1}@media m{.a{x: 2}.b{x: 2}}');
    });

    test("keeps each class's own order (a later state still wins)", () {
      // .a: base, hover (guarded), then :disabled, which must stay after
      // the hover rule. .b has no hover: its :disabled can share .a's.
      final css = groupClassRules([
        [
          (wrap: null, rule: '.a{x: 1}'),
          (wrap: '@media (hover: hover)', rule: '.a:hover{x: 2}'),
          (wrap: null, rule: '.a:disabled{x: 3}'),
        ],
        [
          (wrap: null, rule: '.b{x: 1}'),
          (wrap: null, rule: '.b:disabled{x: 3}'),
        ],
      ]);
      expect(
        css,
        '.a{x: 1}.b{x: 1}.b:disabled{x: 3}'
        '@media (hover: hover){.a:hover{x: 2}}.a:disabled{x: 3}',
      );
      final hover = css.indexOf('.a:hover'), disabled = css.indexOf('.a:dis');
      expect(hover < disabled, isTrue);
    });

    test('breakpoints stay in the order each class wrote them', () {
      // .a: md then lg; .b: lg then md (an app's own order): .b's md needs
      // a group after its lg.
      final css = groupClassRules([
        [
          (wrap: null, rule: '.a{x: 0}'),
          (wrap: '@media md', rule: '.a{x: 1}'),
          (wrap: '@media lg', rule: '.a{x: 2}'),
        ],
        [
          (wrap: null, rule: '.b{x: 0}'),
          (wrap: '@media lg', rule: '.b{x: 2}'),
          (wrap: '@media md', rule: '.b{x: 1}'),
        ],
      ]);
      expect(
        css,
        '.a{x: 0}.b{x: 0}@media md{.a{x: 1}}@media lg{.a{x: 2}.b{x: 2}}'
        '@media md{.b{x: 1}}',
      );
    });

    test('nothing in, nothing out', () {
      expect(groupClassRules(const []), '');
    });
  });
}
