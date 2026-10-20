/// `:::bench bench-page-transition`: a preview of `PageTransition`. A Switch
/// picks the transition, a Level its duration, and Replay plays it between two
/// miniature pages.
///
/// A real page transition happens between two documents, which a bench cannot
/// be; the stage draws the same motion with two `AnimationController`s that
/// run when the stage is drawn, and the Code view shows the real
/// `PageTransition`.
library;

import 'package:thor_ui/thor_ui.dart';

import 'bench_example.dart';
import 'motion_curve.dart';

/// The transitions of `PageTransition` the Switch offers.
enum PageMotion {
  /// `PageTransition.fade`.
  fade,

  /// `PageTransition.slide`.
  slide,

  /// `PageTransition.fadeUp`.
  fadeUp,
}

/// What the panel controls and the stage reads.
class PageTransitionViewModel extends ThorState {
  /// The transition.
  final motion = state(PageMotion.slide);

  /// The duration, as a step of 100 ms.
  final step = state(2);

  /// The number next to the duration Level's bar.
  String durationText() => '${motionDuration(step.value).inMilliseconds} ms';

  /// The `transition` line of the Code view.
  String transitionCode() => 'transition: PageTransition.${motion.value.name}(';

  /// The `duration` line of the Code view.
  String durationCode() =>
      'duration: Duration(milliseconds: ${motionDuration(step.value).inMilliseconds}),';

  /// What the transition Switch calls.
  void setMotion(Set<PageMotion> value) => motion.value = value.first;

  /// What the duration Level calls.
  void setDuration(double ms) => step.value = motionStepOf(ms);
}

/// One instance, at the top level: the browser boots with it.
final pageTransition = PageTransitionViewModel();

/// The example: a Switch, a Level, the stage and its code.
final pageTransitionBench = BenchExample(
  title: (t) => t.exMotionPageTitle,
  description: (t) => t.exMotionPageDescription,
  replay: true,
  stage: const PageTransitionStage(),
  code: BenchCode([
    const BenchCodeLine('ThorApp.router('),
    const BenchCodeLine('routerConfig: router,', indent: 1),
    const BenchCodeLine('navigation: PageNavigation(', indent: 1),
    BenchCodeLine.live(pageTransition.transitionCode, indent: 2),
    BenchCodeLine.live(pageTransition.durationCode, indent: 3),
    const BenchCodeLine('),', indent: 2),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchSwitch<PageMotion>(
      label: (t) => t.exMotionPageKind,
      value: pageTransition.motion.value,
      onChanged: pageTransition.setMotion,
      segments: [
        BenchSegment(PageMotion.fade, label: (t) => t.exMotionPageFade),
        BenchSegment(PageMotion.slide, label: (t) => t.exMotionPageSlide),
        BenchSegment(PageMotion.fadeUp, label: (t) => t.exMotionPageFadeUp),
      ],
    ),
    BenchLevel(
      label: (t) => t.exMotionDuration,
      value: motionMs(pageTransition.step.value),
      min: motionMinMs.toDouble(),
      max: (motionMinMs + (motionSteps - 1) * motionStepMs).toDouble(),
      divisions: motionSteps - 1,
      onChanged: pageTransition.setDuration,
      valueText: pageTransition.durationText,
    ),
  ],
);

/// The stage: the two pages in a frame, one copy per transition and duration.
class PageTransitionStage extends StatelessWidget {
  /// The stage of the example.
  const PageTransitionStage({super.key});

  @override
  Widget build(BuildContext context) => Watch.field(
    pageTransition.step,
    count: motionSteps,
    builder: (step) => Watch.field(
      pageTransition.motion,
      builder: (motion) {
        final run = CurvedAnimation(
          parent: AnimationController(duration: motionDuration(step))
            ..forward(),
          curve: Curves.fastOutSlowIn,
        );
        final (leaving, entering) = switch (motion) {
          PageMotion.fade => (
            FadeTransition(
              opacity: Tween(begin: 1.0, end: 0.0).animate(run),
              child: const _Page(label: 'List', filled: false),
            ),
            FadeTransition(
              opacity: run,
              child: const _Page(label: 'Article', filled: true),
            ),
          ),
          PageMotion.slide => (
            SlideTransition(
              position: Tween(
                begin: Offset.zero,
                end: const Offset(-0.3, 0),
              ).animate(run),
              child: FadeTransition(
                opacity: Tween(begin: 1.0, end: 0.0).animate(run),
                child: const _Page(label: 'List', filled: false),
              ),
            ),
            SlideTransition(
              position: Tween(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(run),
              child: const _Page(label: 'Article', filled: true),
            ),
          ),
          PageMotion.fadeUp => (
            const _Page(label: 'List', filled: false),
            FadeTransition(
              opacity: run,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.25),
                  end: Offset.zero,
                ).animate(run),
                child: const _Page(label: 'Article', filled: true),
              ),
            ),
          ),
        };
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 14,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 200,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [leaving, entering],
                  ),
                ),
              ),
              // What the motion is, for once it has settled.
              Text(
                switch (motion) {
                  PageMotion.fade =>
                    'The new page appears while the old one fades out',
                  PageMotion.slide =>
                    'The new page slides in from the right and the old one steps aside',
                  PageMotion.fadeUp =>
                    'The new page rises a little as it appears',
                },
                style: const TextStyle(
                  fontSize: 14,
                  color: ThemeColor.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _Page extends StatelessWidget {
  const _Page({required this.label, required this.filled});

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: filled ? ThemeColor.primary : ThemeColor.surfaceContainer,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: filled ? ThemeColor.onPrimary : ThemeColor.onSurface,
          ),
        ),
        for (final w in const [200.0, 150.0, 90.0])
          Container(
            width: w,
            height: 10,
            decoration: BoxDecoration(
              color: filled
                  ? ThemeColor.onPrimary.withValues(alpha: 0.5)
                  : ThemeColor.outlineVariant,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
      ],
    ),
  );
}
