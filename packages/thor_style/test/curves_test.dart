import 'package:test/test.dart';
import 'package:thor_style/thor_style.dart';

void main() {
  test('cubic curves compile to exact cubic-bezier()', () {
    expect(Curves.easeInOut.css, 'cubic-bezier(0.42, 0, 0.58, 1)');
    expect(Curves.fastOutSlowIn.css, 'cubic-bezier(0.4, 0, 0.2, 1)');
    expect(Curves.linear.css, 'linear');
    expect(Curves.easeIn.flipped.css, 'cubic-bezier(0, 0, 0.58, 1)');
  });

  test('curves evaluate like Flutter', () {
    expect(Curves.linear.transform(0.3), 0.3);
    expect(Curves.easeInOut.transform(0.5), closeTo(0.5, 0.01));
    expect(Curves.easeIn.transform(0.5), closeTo(0.315, 0.01));
    expect(Curves.bounceOut.transform(1), 1);
    expect(Curves.elasticOut.transform(0.2), greaterThan(1)); // overshoots
    expect(const Interval(0.5, 1).transform(0.25), 0);
    expect(const Interval(0.5, 1).transform(0.75), 0.5);
  });

  test('non-cubic curves are sampled into linear()', () {
    final css = Curves.bounceOut.css;
    expect(css, startsWith('linear(0, '));
    expect(css, endsWith(', 1)'));
    expect(','.allMatches(css), hasLength(40));
  });

  test('transitions use longhands and combine when merged', () {
    final opacity = cssTransition(
      ['opacity'],
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeIn,
    );
    expect(opacity, {
      'transition-property': 'opacity',
      'transition-duration': '200ms',
      'transition-timing-function': 'cubic-bezier(0.42, 0, 1, 1)',
    });
    final box = cssTransition([
      'width',
      'opacity',
    ], duration: const Duration(milliseconds: 300));
    final merged = mergeCss(box, opacity);
    expect(merged['transition-property'], 'width, opacity');
    expect(merged['transition-duration'], '300ms, 200ms');
    expect(
      merged['transition-timing-function'],
      'linear, cubic-bezier(0.42, 0, 1, 1)',
    );
    // Without transitions on both sides it is a plain map merge.
    expect(mergeCss({'a': '1'}, {'a': '2', 'b': '3'}), {'a': '2', 'b': '3'});
  });

  test('mergeCss: scroll-driven animations keep one timeline and range '
      'each, after the shorthand', () {
    final merged = mergeCss(
      {'animation': 'a 1s linear, b 2s linear'},
      {
        'animation': 'c auto linear both',
        'animation-timeline': 'view()',
        'animation-range': 'entry 0% entry 100%',
      },
    );
    expect(merged, {
      'animation': 'a 1s linear, b 2s linear, c auto linear both',
      'animation-timeline': 'auto, auto, view()',
      'animation-range': 'normal, normal, entry 0% entry 100%',
    });
    // The shorthand resets the longhands: it must come first.
    expect(merged.keys.toList(), [
      'animation',
      'animation-timeline',
      'animation-range',
    ]);
    // Time animations alone stay as they were.
    expect(mergeCss({'animation': 'a 1s'}, {'animation': 'b 2s'}), {
      'animation': 'a 1s, b 2s',
    });
  });

  test('mergeCss: scroll-triggered animations keep one trigger entry each '
      'and declare each trigger once', () {
    const trigger = '--tv1 view() entry 30% exit 100%';
    final merged = mergeCss(
      {'animation': 'a 1s linear both'},
      mergeCss(
        {
          'animation': 'b 1s linear both',
          'timeline-trigger': trigger,
          'animation-trigger': '--tv1 play-once',
        },
        {
          'animation': 'c 1s linear both',
          'timeline-trigger': trigger,
          'animation-trigger': '--tv1 play-once',
        },
      ),
    );
    expect(merged, {
      'animation': 'a 1s linear both, b 1s linear both, c 1s linear both',
      'animation-trigger': 'none, --tv1 play-once, --tv1 play-once',
      'timeline-trigger': trigger,
    });
    expect(merged.keys.first, 'animation', reason: 'the shorthand first');
  });

  test('the missing Flutter curves have the same control points', () {
    // Control points from flutter/lib/src/animation/curves.dart.
    expect(Curves.easeInQuart.css, 'cubic-bezier(0.895, 0.03, 0.685, 0.22)');
    expect(Curves.easeOutQuart.css, 'cubic-bezier(0.165, 0.84, 0.44, 1)');
    expect(Curves.easeInOutQuart.css, 'cubic-bezier(0.77, 0, 0.175, 1)');
    expect(Curves.easeInQuint.css, 'cubic-bezier(0.755, 0.05, 0.855, 0.06)');
    expect(Curves.easeOutQuint.css, 'cubic-bezier(0.23, 1, 0.32, 1)');
    expect(Curves.easeInOutQuint.css, 'cubic-bezier(0.86, 0, 0.07, 1)');
    expect(Curves.easeInCirc.css, 'cubic-bezier(0.6, 0.04, 0.98, 0.335)');
    expect(Curves.easeOutCirc.css, 'cubic-bezier(0.075, 0.82, 0.165, 1)');
    expect(Curves.easeInOutCirc.css, 'cubic-bezier(0.785, 0.135, 0.15, 0.86)');
    expect(Curves.easeInOutExpo.css, 'cubic-bezier(1, 0, 0, 1)');
    expect(Curves.fastOutSlowIn.css, 'cubic-bezier(0.4, 0, 0.2, 1)');
  });

  test('three-point cubics evaluate like Flutter and sample to linear()', () {
    const c = Curves.easeInOutCubicEmphasized;
    expect(c.transform(0), 0);
    expect(c.transform(1), 1);
    expect(c.transform(0.166666), closeTo(0.4, 0.01)); // the midpoint
    expect(c.transform(0.1), lessThan(c.transform(0.2)));
    expect(c.css, startsWith('linear(0, '));
    expect(c.css, endsWith(', 1)'));
    expect(
      Curves.fastEaseInToSlowEaseOut.transform(0.198),
      closeTo(0.541, 0.01),
    );
  });

  test('an empty Interval is a step, not NaN', () {
    const step = Interval(0.5, 0.5);
    expect(step.transform(0.25), 0);
    expect(step.transform(0.5), 1);
    expect(step.transform(0.75), 1);
    expect(const Interval(0, 0).transform(0.2), 1);
    expect(const Interval(1, 1).transform(0.99), 0);
    expect(step.css, isNot(contains('NaN')));
  });

  test('mergeCss: `all` is the default timing, a named property overrides '
      'it wherever it came from', () {
    final opacity = cssTransition([
      'opacity',
    ], duration: const Duration(seconds: 2));
    final all = cssTransition([
      'all',
    ], duration: const Duration(milliseconds: 200));
    for (final merged in [mergeCss(opacity, all), mergeCss(all, opacity)]) {
      // CSS: the last entry of a property wins, so `all` goes first.
      expect(merged['transition-property'], 'all, opacity');
      expect(merged['transition-duration'], '200ms, 2000ms');
    }
  });
}
