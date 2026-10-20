import 'package:test/test.dart';
import 'package:thor_style/thor_style.dart';

/// Arithmetic, `copyWith` and `merge` on a value built with `.when()` map the
/// operation over the base and every variant instead of dropping them.
void main() {
  Map<String, CssDeclarations> variantsOf(CssDeclarations css) =>
      splitAdaptive(css).byBreakpoint;

  final insets = const EdgeInsets.all(
    8,
  ).when(medium: const EdgeInsets.all(16), hover: const EdgeInsets.all(12));

  test('EdgeInsets arithmetic keeps the variants', () {
    final doubled = insets * 2;
    final split = splitAdaptive({'padding': doubled.css});
    expect(split.base, {'padding': '16px'});
    expect(split.byBreakpoint['medium'], {'padding': '32px'});
    expect(split.byBreakpoint['hover'], {'padding': '24px'});

    final plus = splitAdaptive({
      'padding': (insets + const EdgeInsets.all(1)).css,
    });
    expect(plus.base, {'padding': '9px'});
    expect(plus.byBreakpoint['medium'], {'padding': '17px'});

    final negated = splitAdaptive({'padding': (-insets).css});
    expect(negated.byBreakpoint['medium'], {'padding': '-16px'});

    final plain = const EdgeInsets.all(1) + insets;
    expect(splitAdaptive({'padding': plain.css}).byBreakpoint['medium'], {
      'padding': '17px',
    });
  });

  test('two adaptive insets combine variant by variant', () {
    final other = const EdgeInsets.all(1).when(medium: const EdgeInsets.all(2));
    final sum = splitAdaptive({'padding': (insets + other).css});
    expect(sum.base, {'padding': '9px'});
    expect(sum.byBreakpoint['medium'], {'padding': '18px'});
    // `hover` only in one side: the other side's base is used.
    expect(sum.byBreakpoint['hover'], {'padding': '13px'});
  });

  test('EdgeInsetsGeometry.add keeps the variants of either side', () {
    final geometry = (const EdgeInsets.all(1) as EdgeInsetsGeometry).when(
      medium: const EdgeInsets.all(2),
    );
    for (final sum in [insets.add(geometry), geometry.add(insets)]) {
      final split = splitAdaptive(sum.toCss('padding'));
      expect(split.base, {'padding': '9px'});
      expect(split.byBreakpoint['medium'], {'padding': '18px'});
      expect(split.byBreakpoint['hover'], {'padding': '13px'});
    }

    final start =
        (const EdgeInsetsDirectional.only(start: 1) as EdgeInsetsGeometry).when(
          medium: const EdgeInsetsDirectional.only(start: 2),
        );
    final top = (const EdgeInsetsDirectional.only(top: 1) as EdgeInsetsGeometry)
        .when(medium: const EdgeInsetsDirectional.only(top: 3));
    final split = splitAdaptive(start.add(top).toCss('padding'));
    expect(split.base, containsPair('padding-top', '1px'));
    expect(split.base, containsPair('padding-inline-start', '1px'));
    expect(split.byBreakpoint['medium'], {
      'padding-top': '3px',
      'padding-inline-start': '2px',
    });

    final plain = const EdgeInsetsDirectional.only(top: 4).add(start);
    expect(splitAdaptive(plain.toCss('padding')).byBreakpoint['medium'], {
      'padding-inline-start': '2px',
    });
  });

  test('EdgeInsets.copyWith replaces the side in every variant', () {
    final copy = insets.copyWith(top: 0);
    final split = splitAdaptive({'padding': copy.css});
    expect(split.base, {'padding': '0px 8px 8px'});
    expect(split.byBreakpoint['medium'], {'padding': '0px 16px 16px'});
  });

  test('BorderRadius.copyWith keeps the variants', () {
    final r = BorderRadius.circular(
      4,
    ).when(medium: BorderRadius.circular(8)).copyWith(topLeft: Radius.zero);
    final split = splitAdaptive({'border-radius': r.css});
    expect(split.base, {'border-radius': '0px 4px 4px 4px'});
    expect(split.byBreakpoint['medium'], {'border-radius': '0px 8px 8px 8px'});
  });

  test('TextStyle copyWith, merge and withRole keep the variants', () {
    final style = const TextStyle(
      fontSize: 14,
    ).when(medium: const TextStyle(fontSize: 18));

    final bold = style.copyWith(fontWeight: FontWeight.bold);
    final by = variantsOf(bold.toCss());
    expect(bold.toCss()['font-size'], isNotNull);
    expect(by['medium'], {'font-size': '18px'});
    expect(splitAdaptive(bold.toCss()).base['font-weight'], '700');

    final merged = const TextStyle(
      color: Color(0xFF000000),
    ).merge(style.copyWith(height: 1.5));
    expect(
      variantsOf(merged.toCss())['medium'],
      containsPair('font-size', '18px'),
    );
    expect(splitAdaptive(merged.toCss()).base['color'], '#000000');

    final merged2 = style.merge(const TextStyle(color: Color(0xFF000000)));
    expect(
      variantsOf(merged2.toCss())['medium'],
      containsPair('font-size', '18px'),
    );

    final roled = style.withRole(TextThemeRole.bodyLarge);
    expect(roled.role, TextThemeRole.bodyLarge);
    expect(variantsOf(roled.toCss()), contains('medium'));
  });

  test('BoxDecoration.copyWith keeps the variants', () {
    final d = const BoxDecoration(
      color: Color(0xFF000000),
    ).when(hover: const BoxDecoration(color: Color(0xFFFFFFFF)));
    final copy = d.copyWith(shape: BoxShape.circle);
    final split = splitAdaptive(copy.toCss());
    expect(split.base['border-radius'], '50%');
    expect(split.byBreakpoint['hover']?['background-color'], '#ffffff');
  });
}
