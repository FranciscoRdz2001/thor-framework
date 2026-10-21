import 'package:test/test.dart';
import 'package:thor_ui/thor_ui.dart';
import 'package:thor_ui/web.dart' show TextTransform;

void main() {
  test('typography and box values StyleProps used to need raw: for', () {
    final out = StyleProps(
      textTransform: TextTransform.uppercase,
      textOverflow: TextOverflow.ellipsis,
      textUnderlineOffset: 2.px,
      inset: 0.px,
      scrollPadding: const EdgeInsets.symmetric(horizontal: 16),
      backgroundClip: BackgroundClip.text,
    ).toCss();
    expect(out['text-transform'], 'uppercase');
    expect(out['text-overflow'], 'ellipsis');
    expect(out['text-underline-offset'], '2px');
    expect(out['inset'], '0px');
    expect(out['scroll-padding'], '0px 16px');
    expect(out['-webkit-background-clip'], 'text');
    expect(out['background-clip'], 'text');
  });

  test('lineClamp writes the clamp with its box', () {
    final out = const StyleProps(lineClamp: 3).toCss();
    expect(out['-webkit-line-clamp'], '3');
    expect(out['line-clamp'], '3');
    expect(out['display'], '-webkit-box');
    expect(out['-webkit-box-orient'], 'vertical');
    expect(out['overflow'], 'hidden');
  });

  test('aspectRatio keeps a fraction as the fraction', () {
    expect(
      const StyleProps(aspectRatio: 4 / 3).toCss()['aspect-ratio'],
      '4 / 3',
    );
    expect(
      const StyleProps(aspectRatio: 16 / 9).toCss()['aspect-ratio'],
      '16 / 9',
    );
    expect(const StyleProps(aspectRatio: 1.5).toCss()['aspect-ratio'], '1.5');
    expect(const StyleProps(aspectRatio: 1).toCss()['aspect-ratio'], '1');
    expect(const StyleProps(aspectRatio: 0.75).toCss()['aspect-ratio'], '0.75');
    expect(
      const StyleProps(aspectRatio: 1.2345).toCss()['aspect-ratio'],
      '1.2345',
    );
  });

  test('safe area and inherit are lengths', () {
    expect(Length.safeAreaBottom.css, 'env(safe-area-inset-bottom, 0px)');
    expect(
      (Length.safeAreaBottom + 16.px).css,
      'calc(env(safe-area-inset-bottom, 0px) + 16px)',
    );
    expect(
      const StyleProps(minHeight: Length.safeAreaTop).toCss()['min-height'],
      'env(safe-area-inset-top, 0px)',
    );
    expect(Length.inherit.css, 'inherit');
  });

  test('a negative margin is not a value a widget owns', () {
    const negative = StyleProps(margin: EdgeInsets.symmetric(vertical: -12));
    expect(negative.widgetProps(), isEmpty);
    expect(negative.toCss()['margin'], '-12px 0px');
    expect(
      const StyleProps(margin: EdgeInsets.all(8)).widgetProps(),
      isNotEmpty,
    );
  });
}
