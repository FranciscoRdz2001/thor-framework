import 'package:test/test.dart';
import 'package:thor_style/thor_style.dart';

void main() {
  test('content sizes are Length keywords', () {
    expect(Length.maxContent.css, 'max-content');
    expect(Length.minContent.css, 'min-content');
    expect(Length.fitContent.css, 'fit-content');
    expect(Length.maxContent.css, isNot(startsWith('calc')));
  });

  test('a transition writes property, duration, curve and delay', () {
    expect(
      Transition.toCss([
        const Transition(CssProperty.opacity, Duration(milliseconds: 150)),
        Transition(
          CssProperty.custom('--t-ink'),
          const Duration(milliseconds: 200),
          curve: Curves.linear,
          delay: const Duration(milliseconds: 50),
        ),
      ]),
      {'transition': 'opacity 150ms ease, --t-ink 200ms linear 50ms'},
    );
    expect(Transition.toCss(const []), {'transition': 'none'});
  });

  test('an animation writes its whole shorthand; repeat 0 is infinite', () {
    expect(
      CssAnimation.toCss([
        const CssAnimation(
          'marquee',
          Duration(seconds: 25),
          curve: Curves.linear,
          repeat: 0,
        ),
      ]),
      {'animation': 'marquee 25000ms linear 0ms infinite normal none'},
    );
    expect(CssAnimation.toCss(const []), {'animation': 'none'});
  });

  test('image filters chain, the inner one first', () {
    expect(ImageFilter.blur(sigmaX: 8).css, 'blur(8px)');
    expect(ImageFilter.saturate(0).css, 'saturate(0)');
    expect(ImageFilter.sepia(.5).css, 'sepia(0.5)');
    expect(ImageFilter.hueRotate(90).css, 'hue-rotate(90deg)');
    expect(ImageFilter.opacity(.8).css, 'opacity(0.8)');
    expect(
      ImageFilter.compose(
        outer: ImageFilter.blur(sigmaX: 4),
        inner: ImageFilter.brightness(1.1),
      ).css,
      'brightness(1.1) blur(4px)',
    );
  });

  test('keyword values write their CSS keyword', () {
    expect(BlendMode.colorDodge.css, 'color-dodge');
    expect(Appearance.none.css, 'none');
    expect(TextWrap.balance.css, 'balance');
    expect(OverflowWrap.breakWord.css, 'break-word');
    expect(const ScrollSnapType(Axis.horizontal).css, 'x mandatory');
    expect(
      const ScrollSnapType(
        Axis.vertical,
        strictness: ScrollSnapStrictness.proximity,
      ).css,
      'y proximity',
    );
  });
}
