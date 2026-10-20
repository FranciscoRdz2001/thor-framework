/// `:::bench bench-scroll-reveal`: rows that appear as they scroll into view.
/// A Switch picks whether the scroll plays the animation (`inView`) or only
/// starts it, once (`onVisible`); another picks the effect.
///
/// Both are CSS scroll timelines and triggers: nothing runs in Dart or in
/// JavaScript while you scroll, and with "reduce motion" the rows are just
/// there. The Replay button draws the box again.
library;

import 'package:thor_ui/thor_ui.dart';

import 'bench_example.dart';

/// How the reveal is driven.
enum RevealDriver {
  /// `AnimationController.inView()`: the scroll is the clock.
  inView,

  /// `AnimationController.onVisible()`: it plays once when seen.
  onVisible,
}

/// What each row does as it enters.
enum RevealEffect {
  /// Rises while it fades in.
  rise,

  /// Grows from a smaller size while it fades in.
  scale,

  /// Comes in from the side.
  slide,
}

/// What the panel controls and the stage reads.
class ScrollRevealViewModel extends ThorState {
  /// What drives it.
  final driver = state(RevealDriver.inView);

  /// What each row does.
  final effect = state(RevealEffect.rise);

  /// The `controller` line of the Code view.
  String controllerCode() => driver.value == RevealDriver.inView
      ? 'final view = AnimationController.inView();'
      : 'final view = AnimationController.onVisible('
            'duration: Duration(milliseconds: 500));';

  /// The line of the Code view that moves the row.
  String effectCode() => switch (effect.value) {
    RevealEffect.rise =>
      'position: Tween(begin: Offset(0, 0.4), end: Offset.zero).animate(view),',
    RevealEffect.scale => 'scale: Tween(begin: 0.9, end: 1.0).animate(view),',
    RevealEffect.slide =>
      'position: Tween(begin: Offset(-0.3, 0), end: Offset.zero).animate(view),',
  };

  /// The widget that takes [effectCode].
  String effectWidget() => switch (effect.value) {
    RevealEffect.rise || RevealEffect.slide => 'SlideTransition(',
    RevealEffect.scale => 'ScaleTransition(',
  };

  /// What the driver Switch calls.
  void setDriver(Set<RevealDriver> value) => driver.value = value.first;

  /// What the effect Switch calls.
  void setEffect(Set<RevealEffect> value) => effect.value = value.first;
}

/// One instance, at the top level: the browser boots with it.
final scrollRevealState = ScrollRevealViewModel();

/// The example.
final scrollRevealBench = BenchExample(
  title: (t) => t.exMotion2ScrollTitle,
  description: (t) => t.exMotion2ScrollDescription,
  replay: true,
  stage: const ScrollRevealStage(),
  code: BenchCode([
    BenchCodeLine.live(scrollRevealState.controllerCode),
    const BenchCodeLine(' '),
    const BenchCodeLine('FadeTransition('),
    const BenchCodeLine('opacity: view,', indent: 1),
    BenchCodeLine.live(scrollRevealState.effectWidget, indent: 1),
    BenchCodeLine.live(scrollRevealState.effectCode, indent: 2),
    const BenchCodeLine('child: row,', indent: 2),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchSwitch<RevealDriver>(
      label: (t) => t.exMotion2Driver,
      value: scrollRevealState.driver.value,
      onChanged: scrollRevealState.setDriver,
      segments: [
        BenchSegment(RevealDriver.inView, label: (t) => 'inView'),
        BenchSegment(RevealDriver.onVisible, label: (t) => 'onVisible'),
      ],
    ),
    BenchSwitch<RevealEffect>(
      label: (t) => t.exMotion2Effect,
      value: scrollRevealState.effect.value,
      onChanged: scrollRevealState.setEffect,
      segments: [
        BenchSegment(RevealEffect.rise, label: (t) => t.exMotion2EffectRise),
        BenchSegment(RevealEffect.scale, label: (t) => t.exMotion2EffectScale),
        BenchSegment(RevealEffect.slide, label: (t) => t.exMotion2EffectSlide),
      ],
    ),
  ],
);

/// The stage: a box that scrolls, with rows that reveal.
class ScrollRevealStage extends StatelessWidget {
  /// The stage of the example.
  const ScrollRevealStage({super.key});

  @override
  Widget build(BuildContext context) => Watch.field(
    scrollRevealState.driver,
    builder: (driver) => Watch.field(
      scrollRevealState.effect,
      builder: (effect) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Text(
              '${driver == RevealDriver.inView ? 'inView' : 'onVisible'} · ${switch (effect) {
                RevealEffect.rise => 'Rise',
                RevealEffect.scale => 'Grow',
                RevealEffect.slide => 'Slide in',
              }}',
              style: const TextStyle(
                fontSize: 12,
                color: ThemeColor.onSurfaceVariant,
              ),
            ),
            Container(
              width: 300,
              height: 260,
              decoration: BoxDecoration(
                color: ThemeColor.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 72),
                        child: Text(
                          'Scroll down',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: ThemeColor.onSurfaceVariant),
                        ),
                      ),
                      for (var i = 0; i < 6; i++)
                        _Reveal(driver, effect, _Item(i, 'Item ${i + 1}')),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// A row that appears as the scroll (or the sight of it) moves its controller.
class _Reveal extends StatelessWidget {
  const _Reveal(this.driver, this.effect, this.child);

  final RevealDriver driver;
  final RevealEffect effect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final view = CurvedAnimation(
      parent: driver == RevealDriver.inView
          ? AnimationController.inView()
          : AnimationController.onVisible(
              duration: const Duration(milliseconds: 500),
            ),
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: view,
      child: switch (effect) {
        RevealEffect.rise => SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.4),
            end: Offset.zero,
          ).animate(view),
          child: child,
        ),
        RevealEffect.scale => ScaleTransition(
          scale: Tween(begin: 0.9, end: 1.0).animate(view),
          child: child,
        ),
        RevealEffect.slide => SlideTransition(
          position: Tween(
            begin: const Offset(-0.3, 0),
            end: Offset.zero,
          ).animate(view),
          child: child,
        ),
      },
    );
  }
}

class _Item extends StatelessWidget {
  const _Item(this.index, this.title);

  final int index;
  final String title;

  @override
  Widget build(BuildContext context) => Container(
    height: 56,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: ThemeColor.surface,
      border: Border.all(color: ThemeColor.outlineVariant),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      spacing: 12,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: index.isEven
                ? ThemeColor.primary
                : ThemeColor.onSurfaceVariant,
            borderRadius: BorderRadius.circular(9),
          ),
        ),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    ),
  );
}
