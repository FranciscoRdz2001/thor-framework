import 'package:test/test.dart';
import 'package:thor_style/thor_style.dart';

void main() {
  test('units from numbers', () {
    expect(16.px.css, '16px');
    expect(0.5.px.css, '0.5px');
    expect(double.infinity.px.css, '100%');
    expect(50.percent.css, '50%');
    expect(1.5.em.css, '1.5em');
    expect(1.rem.css, '1rem');
    expect(60.ch.css, '60ch');
    expect(100.vw.css, '100vw');
    expect(100.vh.css, '100vh');
    expect(100.dvh.css, '100dvh');
    expect(100.svh.css, '100svh');
    expect(100.lvh.css, '100lvh');
  });

  test('const constructors match the extensions', () {
    const a = Length.px(16);
    expect(a, 16.px);
    expect(const Length.dvh(100), 100.dvh);
  });

  test('arithmetic is one calc(), nested in parentheses', () {
    expect((100.dvh - 48.px).css, 'calc(100dvh - 48px)');
    expect((100.dvh - 48.px - 24.px).css, 'calc((100dvh - 48px) - 24px)');
    expect((50.percent * 2).css, 'calc(50% * 2)');
    expect((100.vw / 3).css, 'calc(100vw / 3)');
    expect((-8.px).css, 'calc(8px * -1)');
  });

  test('min, max, clamp', () {
    expect(Length.min([100.percent, 720.px]).css, 'min(100%, 720px)');
    expect(Length.max([1.rem, 2.vw]).css, 'max(1rem, 2vw)');
    expect(
      Length.clamp(1.rem, 2.vw + 1.rem, 3.rem).css,
      'clamp(1rem, (2vw + 1rem), 3rem)',
    );
  });

  test('variables, keywords', () {
    expect(const Length.variable(CssVariable('--gutter')).css, 'var(--gutter)');
    expect(
      Length.variable(const CssVariable('--gutter'), fallback: 16.px).css,
      'var(--gutter, 16px)',
    );
    expect(
      (const Length.variable(CssVariable('--top')) + 12.px).css,
      'calc(var(--top) + 12px)',
    );
    expect(Length.auto.css, 'auto');
    expect(Length.zero.css, '0');
  });

  test('a tiled gradient is a pattern', () {
    const dots = BoxDecoration(
      color: Color(0xFFECEEF3),
      gradient: RadialGradient(
        colors: [Color(0xFF4F46E5), Color(0x00000000)],
        stops: [0.09, 0.09],
        tile: Size.square(16),
      ),
    );
    expect(dots.toCss()['background-size'], '16px 16px');
    expect(
      dots.toCss()['background-image'],
      contains('#4f46e5 9%, transparent 9%'),
    );
    const plain = BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xFF000000), Color(0xFFFFFFFF)]),
    );
    expect(plain.toCss().containsKey('background-size'), isFalse);
  });

  test('Size.zero', () {
    expect(Size.zero.width, 0);
    expect(Size.zero.height, 0);
  });

  test('min, max and clamp are const, and nest', () {
    const gutter = Length.clamp(Length.px(14), Length.vw(3), Length.px(28));
    const width = Length.min([
      Length.percent(100),
      Length.max([Length.ch(40), gutter]),
    ]);
    expect(gutter.css, 'clamp(14px, 3vw, 28px)');
    expect(width.css, 'min(100%, max(40ch, clamp(14px, 3vw, 28px)))');
    // Same CSS, same value: a const one equals one built at run time.
    expect(gutter, Length.clamp(14.px, 3.vw, 28.px));
    expect((gutter + 1.rem).css, 'calc(clamp(14px, 3vw, 28px) + 1rem)');
  });

  test('Length.zero is 0px inside math functions', () {
    expect((Length.zero + 8.px).css, 'calc(0px + 8px)');
    expect(Length.max([Length.zero, 8.px]).css, 'max(0px, 8px)');
    expect(Length.zero.css, '0');
  });

  test('container units and ratios', () {
    expect(100.cqh.css, '100cqh');
    expect(50.cqw.css, '50cqw');
    expect(const Length.cqmin(10).css, '10cqmin');
    expect(25.cqi.css, '25cqi');
    expect(25.cqb.css, '25cqb');
    expect(10.cqmin.css, '10cqmin');
    expect(10.cqmax.css, '10cqmax');
    expect(const Length.cqw(1).css, '1cqw');
    expect(const Length.cqh(1).css, '1cqh');
    expect(const Length.cqi(1).css, '1cqi');
    expect(const Length.cqb(1).css, '1cqb');
    expect(const Length.cqmax(1).css, '1cqmax');
    expect(Ratio.of(100.cqh, 844.px).css, 'tan(atan2(100cqh, 844px))');
    expect(
      Ratio.of(100.cqh - 20.px, 844.px).css,
      'tan(atan2((100cqh - 20px), 844px))',
    );
    expect(
      const Ratio.min([
        Ratio.value(1),
        Ratio.of(Length.cqh(100), Length.px(844)),
      ]).css,
      'min(1, tan(atan2(100cqh, 844px)))',
    );
    expect(
      Ratio.max([const Ratio.value(0.25), Ratio.of(50.cqw, 100.cqh)]).css,
      'max(0.25, tan(atan2(50cqw, 100cqh)))',
    );
    expect(
      Ratio.min([
        Ratio.max([const Ratio.value(0.5), Ratio.of(100.cqw, 390.px)]),
        const Ratio.value(2),
      ]).css,
      'min(max(0.5, tan(atan2(100cqw, 390px))), 2)',
    );
    expect(Ratio.of(100.cqh, 844.px), Ratio.of(100.cqh, 844.px));
    expect(
      Ratio.of(100.cqh, 844.px).hashCode,
      Ratio.of(100.cqh, 844.px).hashCode,
    );
    expect(Ratio.of(100.cqh, 844.px), isNot(Ratio.of(844.px, 100.cqh)));
  });
}
