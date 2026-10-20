// ignore_for_file: public_member_api_docs
// (each recipe is named by its bench; a doc comment would sit outside the
// code the site shows)
// The cookbook's interaction patterns (docs/guia/es/ejemplos/): slide to
// confirm, a copy button that morphs into a check, tabs with a sliding
// indicator and a stack of toasts. Every one is a bench: the controls change
// the motion (the duration, the curve, how strong it is) and the code that is
// shown.
//
// How they move, by the cheapest tool that works:
//   * a state that flips (tabs, toasts): the widget that reads it is a
//     `Watch`, the server compiles every variant and the browser swaps a
//     class, so the CSS transition does the rest;
//   * a one-shot effect (the copy check): an `AnimationController` that is a
//     field of the state and that a method plays, so the frames are CSS
//     keyframes and no Dart runs per frame;
//   * a drag (slide to confirm): `Gesture` follows the pointer in the
//     browser and the state only hears where it ended.
// Every one respects `prefers-reduced-motion`: durations become 1 ms and the
// controllers show their end state.
import 'package:thor_ui/thor_ui.dart';

import 'bench/bench_example.dart';
import 'bench/motion_curve.dart';
import 'bench/motion_graph.dart';

/// The three curves every recipe's Switch offers (three fit one row).
List<BenchSegment<MotionCurve>> _curveSegments() => [
  BenchSegment(MotionCurve.easeOut, label: (t) => t.exMotionCurveOut),
  BenchSegment(MotionCurve.easeInOut, label: (t) => t.exMotionCurveInOut),
  BenchSegment(MotionCurve.back, label: (t) => t.exMotionCurveBack),
];

// ------------------------------------------------------- Slide to confirm

// The track is 260 wide and the handle 48 with 4 of margin: 208 px of travel.
const _slideTravel = 208.0;

class SlideRecipeViewModel extends ThorState {
  final confirmed = state(false);

  /// How far the handle must go, as a step of 15 % from 40 %.
  final threshold = state(2);
  final curve = state(MotionCurve.easeOut);
  final step = state(1);

  bool isConfirmed() => confirmed.value;
  String thresholdText() => '${40 + 15 * threshold.value} %';
  String durationText() => '${coarseDuration(step.value).inMilliseconds} ms';

  String releasedCode() =>
      'if (dx >= ${(_slideTravel * (40 + 15 * threshold.value) / 100).round()}) confirmed.value = true;';
  String durationCode() =>
      'duration: Duration(milliseconds: ${coarseDuration(step.value).inMilliseconds}),';
  String curveCode() => 'curve: ${curve.value.code},';

  /// What `onDragEnd` calls: the pixels the handle went when it was dropped.
  void released(double dx, double dy) {
    if (dx >= 208.0 * (40 + 15 * threshold.value) / 100) confirmed.value = true;
  }

  void confirm() => confirmed.value = true;
  void reset() => confirmed.value = false;

  void setThreshold(double percent) =>
      threshold.value = ((percent - 40) / 15).round();
  void setCurve(Set<MotionCurve> value) => curve.value = value.first;
  void setDuration(double ms) => step.value = coarseStepOf(ms);
}

final slideRecipe = SlideRecipeViewModel();

final slideRecipeBench = BenchExample(
  title: (t) => t.exMotion2SlideTitle,
  description: (t) => t.exMotion2SlideDescription,
  stage: const SlideRecipe(),
  code: BenchCode([
    const BenchCodeLine('class SlideViewModel extends ThorState {'),
    const BenchCodeLine('final confirmed = state(false);', indent: 1),
    const BenchCodeLine(' '),
    const BenchCodeLine('void released(double dx, double dy) {', indent: 1),
    BenchCodeLine.live(slideRecipe.releasedCode, indent: 2),
    const BenchCodeLine('}', indent: 1),
    const BenchCodeLine('}'),
    const BenchCodeLine(' '),
    const BenchCodeLine('final slide = SlideViewModel();'),
    const BenchCodeLine(' '),
    const BenchCodeLine('AnimatedPositioned('),
    BenchCodeLine.live(slideRecipe.durationCode, indent: 1),
    BenchCodeLine.live(slideRecipe.curveCode, indent: 1),
    const BenchCodeLine('left: confirmed ? 208 : 4,', indent: 1),
    const BenchCodeLine('child: Gesture(', indent: 1),
    const BenchCodeLine('onDragEnd: slide.released,', indent: 2),
    const BenchCodeLine('drag: Drag(axis: Axis.horizontal),', indent: 2),
    const BenchCodeLine('child: handle,', indent: 2),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchSwitch<MotionCurve>(
      label: (t) => t.exMotionCurve,
      value: slideRecipe.curve.value,
      onChanged: slideRecipe.setCurve,
      segments: _curveSegments(),
    ),
    BenchLevel(
      label: (t) => t.exMotion2Threshold,
      value: (40 + 15 * slideRecipe.threshold.value).toDouble(),
      min: 40,
      max: 85,
      divisions: 3,
      onChanged: slideRecipe.setThreshold,
      valueText: slideRecipe.thresholdText,
    ),
    BenchLevel(
      label: (t) => t.exMotionDuration,
      value: coarseMs(slideRecipe.step.value),
      min: coarseMinMs.toDouble(),
      max: coarseMaxMs.toDouble(),
      divisions: coarseSteps - 1,
      onChanged: slideRecipe.setDuration,
      valueText: slideRecipe.durationText,
    ),
  ],
);

class _SlideStage extends StatelessWidget {
  const _SlideStage();

  @override
  Widget build(BuildContext context) => Watch.field(
    slideRecipe.step,
    count: coarseSteps,
    builder: (step) => Watch.field(
      slideRecipe.curve,
      builder: (curve) => Watch(
        slideRecipe.isConfirmed,
        builder: (done) {
          final duration = coarseDuration(step);
          final easing = curveOf(curve);
          return Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: AnimatedContainer(
                  width: 260,
                  height: 56,
                  duration: duration,
                  curve: easing,
                  decoration: BoxDecoration(
                    color: done
                        ? ThemeColor.primary
                        : ThemeColor.surfaceContainer,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedOpacity(
                        opacity: done ? 0 : 1,
                        duration: duration,
                        curve: easing,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 40),
                          child: Text(
                            'Slide to confirm',
                            style: TextStyle(
                              color: ThemeColor.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      AnimatedOpacity(
                        opacity: done ? 1 : 0,
                        duration: duration,
                        curve: easing,
                        child: const Padding(
                          padding: EdgeInsets.only(right: 40),
                          child: Text(
                            'Confirmed',
                            style: TextStyle(
                              color: ThemeColor.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      AnimatedPositioned(
                        left: done ? _slideTravel + 4 : 4,
                        top: 4,
                        duration: duration,
                        curve: easing,
                        child: Semantics(
                          label: 'Confirmation handle',
                          child: Gesture(
                            onDragEnd: done ? null : slideRecipe.released,
                            drag: const Drag(axis: Axis.horizontal),
                            feedback: const Press(scale: 0.95),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: done
                                    ? ThemeColor.onPrimary
                                    : ThemeColor.primary,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  AnimatedOpacity(
                                    opacity: done ? 0 : 1,
                                    duration: duration,
                                    child: const Icon(
                                      Icons.arrow_forward,
                                      size: 22,
                                      color: ThemeColor.onPrimary,
                                    ),
                                  ),
                                  AnimatedOpacity(
                                    opacity: done ? 1 : 0,
                                    duration: duration,
                                    child: const Icon(
                                      Icons.check,
                                      size: 22,
                                      color: ThemeColor.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Not everyone can drag: the same action as a plain button.
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: done ? slideRecipe.reset : slideRecipe.confirm,
                    child: Text(done ? 'Start over' : 'Confirm with a button'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}

// ------------------------------------------------------------------- Copy

/// How the copy icon turns into the check.
enum CopyMorph { fade, scale, turn }

/// How long the check stays, in ms, per step of the Level.
const _copyHolds = [1200, 1800, 2400];

class CopyRecipeViewModel extends ThorState {
  final morph = state(CopyMorph.scale);
  final hold = state(1);

  /// The icon, the label and the check all follow this controller: the swap
  /// is its first and last 8 %, and the check stays in between.
  final done = AnimationController(
    duration: const Duration(milliseconds: 1800),
  );

  String holdText() => '${_copyHolds[hold.value.clamp(0, 2)]} ms';
  String morphCode() => switch (morph.value) {
    CopyMorph.fade => 'final scale = ConstantTween(1.0);',
    CopyMorph.scale => 'final scale = swap(from: 0.6, to: 1.0);',
    CopyMorph.turn =>
      'final scale = swap(from: 0.6, to: 1.0), turns = swap(from: -0.15, to: 0.0);',
  };
  String playCode() =>
      'done.animateTo(1.0, duration: Duration(milliseconds: ${_copyHolds[hold.value.clamp(0, 2)]}));';

  void copy() {
    Clipboard.setData(const ClipboardData(text: 'thor create my_app'));
    done.reset();
    done.animateTo(
      1.0,
      duration: Duration(milliseconds: 1200 + 600 * hold.value),
    );
  }

  void setMorph(Set<CopyMorph> value) => morph.value = value.first;
  void setHold(double ms) =>
      hold.value = ((ms - 1200) / 600).round().clamp(0, 2);
}

final copyRecipe = CopyRecipeViewModel();

final copyRecipeBench = BenchExample(
  title: (t) => t.exMotion2CopyTitle,
  description: (t) => t.exMotion2CopyDescription,
  stage: const CopyRecipe(),
  code: BenchCode([
    const BenchCodeLine('class CopyViewModel extends ThorState {'),
    const BenchCodeLine('final done = AnimationController(', indent: 1),
    const BenchCodeLine('duration: Duration(milliseconds: 1800),', indent: 2),
    const BenchCodeLine(');', indent: 1),
    const BenchCodeLine(' '),
    const BenchCodeLine('void copy() {', indent: 1),
    const BenchCodeLine(
      "Clipboard.setData(ClipboardData(text: 'thor create my_app'));",
      indent: 2,
    ),
    const BenchCodeLine('done.reset();', indent: 2),
    BenchCodeLine.live(copyRecipe.playCode, indent: 2),
    const BenchCodeLine('}', indent: 1),
    const BenchCodeLine('}'),
    const BenchCodeLine(' '),
    const BenchCodeLine('// 8 % in, 84 % shown, 8 % out.'),
    BenchCodeLine.live(copyRecipe.morphCode),
    const BenchCodeLine(
      'FadeTransition(opacity: copyIconOpacity, child: copyIcon),',
    ),
    const BenchCodeLine(
      'FadeTransition(opacity: checkOpacity, child: checkIcon),',
    ),
  ], appCode: true),
  controls: [
    BenchSwitch<CopyMorph>(
      label: (t) => t.exMotion2Morph,
      value: copyRecipe.morph.value,
      onChanged: copyRecipe.setMorph,
      segments: [
        BenchSegment(CopyMorph.fade, label: (t) => t.exMotion2MorphFade),
        BenchSegment(CopyMorph.scale, label: (t) => t.exMotion2MorphScale),
        BenchSegment(CopyMorph.turn, label: (t) => t.exMotion2MorphTurn),
      ],
    ),
    BenchLevel(
      label: (t) => t.exMotion2Hold,
      value: _copyHolds[copyRecipe.hold.value].toDouble(),
      min: 1200,
      max: 2400,
      divisions: 2,
      onChanged: copyRecipe.setHold,
      valueText: copyRecipe.holdText,
    ),
  ],
);

class _CopyStage extends StatelessWidget {
  const _CopyStage();

  @override
  Widget build(BuildContext context) => Watch.field(
    copyRecipe.morph,
    builder: (morph) {
      // The copy icon leaves as the check comes in: opposite sequences.
      final copyOut = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 8),
        TweenSequenceItem(tween: ConstantTween(0.0), weight: 84),
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 8),
      ]).animate(copyRecipe.done);
      final checkIn = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 8),
        TweenSequenceItem(tween: ConstantTween(1.0), weight: 84),
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 8),
      ]).animate(copyRecipe.done);
      final copyScale = morph == CopyMorph.fade
          ? null
          : TweenSequence<double>([
              TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.6), weight: 8),
              TweenSequenceItem(tween: ConstantTween(0.6), weight: 84),
              TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.0), weight: 8),
            ]).animate(copyRecipe.done);
      final checkScale = morph == CopyMorph.fade
          ? null
          : TweenSequence<double>([
              TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.0), weight: 8),
              TweenSequenceItem(tween: ConstantTween(1.0), weight: 84),
              TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.6), weight: 8),
            ]).animate(copyRecipe.done);
      final checkTurns = morph != CopyMorph.turn
          ? null
          : TweenSequence<double>([
              TweenSequenceItem(
                tween: Tween(begin: -0.15, end: 0.0),
                weight: 8,
              ),
              TweenSequenceItem(tween: ConstantTween(0.0), weight: 84),
              TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.15), weight: 8),
            ]).animate(copyRecipe.done);

      return Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(
          color: ThemeColor.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            const Text(
              'thor create my_app',
              style: TextStyle(
                fontFamily: 'IBM Plex Mono',
                fontFamilyFallback: ['ui-monospace', 'monospace'],
                fontSize: 14,
              ),
            ),
            Semantics(
              label: 'Copy the command',
              child: Gesture(
                onTap: copyRecipe.copy,
                feedback: const Press(scale: 0.95),
                child: Container(
                  width: 112,
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: ThemeColor.surface,
                    border: Border.all(color: ThemeColor.outlineVariant),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: 8,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                _Layer(
                                  opacity: copyOut,
                                  scale: copyScale,
                                  turns: null,
                                  child: const Icon(
                                    Icons.content_copy,
                                    size: 18,
                                  ),
                                ),
                                _Layer(
                                  opacity: checkIn,
                                  scale: checkScale,
                                  turns: checkTurns,
                                  child: const Icon(Icons.check, size: 18),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 60,
                            height: 20,
                            child: Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                FadeTransition(
                                  opacity: copyOut,
                                  child: const Text('Copy'),
                                ),
                                FadeTransition(
                                  opacity: checkIn,
                                  child: const Text('Copied'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

// ------------------------------------------------------------------- Tabs

/// What the sliding indicator looks like.
enum TabIndicator { pill, line }

const _tabWidth = 96.0;

class TabsRecipeViewModel extends ThorState {
  final current = state(0);
  final indicator = state(TabIndicator.pill);
  final curve = state(MotionCurve.easeInOut);
  final step = state(1);

  int currentTab() => current.value;
  String durationText() => '${coarseDuration(step.value).inMilliseconds} ms';
  String durationCode() =>
      'duration: Duration(milliseconds: ${coarseDuration(step.value).inMilliseconds}),';
  String curveCode() => 'curve: ${curve.value.code},';
  String indicatorCode() => indicator.value == TabIndicator.pill
      ? 'final indicator = filledBox; // a rounded box under the label'
      : 'final indicator = underline; // 3 px line under the label';

  void go(int index) => current.value = index;
  void setIndicator(Set<TabIndicator> value) => indicator.value = value.first;
  void setCurve(Set<MotionCurve> value) => curve.value = value.first;
  void setDuration(double ms) => step.value = coarseStepOf(ms);
}

final tabsRecipe = TabsRecipeViewModel();

final tabsRecipeBench = BenchExample(
  title: (t) => t.exMotion2TabsTitle,
  description: (t) => t.exMotion2TabsDescription,
  stage: const TabsRecipe(),
  code: BenchCode([
    ...benchLines('''
class TabsViewModel extends ThorState {
  final current = state(0);

  int currentTab() => current.value;
  void go(int index) => current.value = index;
}

final tabs = TabsViewModel();
'''),
    const BenchCodeLine(' '),
    BenchCodeLine.live(tabsRecipe.indicatorCode),
    const BenchCodeLine('Watch('),
    const BenchCodeLine('tabs.currentTab,', indent: 1),
    const BenchCodeLine('count: 3,', indent: 1),
    const BenchCodeLine('builder: (i) => Stack(children: [', indent: 1),
    const BenchCodeLine(
      '// One element that slides under the labels.',
      indent: 2,
    ),
    const BenchCodeLine('AnimatedSlide(', indent: 2),
    const BenchCodeLine('offset: Offset(i.toDouble(), 0),', indent: 3),
    BenchCodeLine.live(tabsRecipe.durationCode, indent: 3),
    BenchCodeLine.live(tabsRecipe.curveCode, indent: 3),
    const BenchCodeLine('child: indicator,', indent: 3),
    const BenchCodeLine('),', indent: 2),
    const BenchCodeLine('Row(children: [', indent: 2),
    const BenchCodeLine('for (var t = 0; t < 3; t++)', indent: 3),
    const BenchCodeLine('Gesture(', indent: 4),
    const BenchCodeLine('onTap: tabs.go.withArg(t),', indent: 5),
    const BenchCodeLine('child: AnimatedDefaultTextStyle(', indent: 5),
    const BenchCodeLine('style: t == i ? selected : idle,', indent: 6),
    const BenchCodeLine('duration: Duration(milliseconds: 150),', indent: 6),
    const BenchCodeLine('child: Text(labels[t]),', indent: 6),
    const BenchCodeLine('),', indent: 5),
    const BenchCodeLine('),', indent: 4),
    const BenchCodeLine(']),', indent: 2),
    const BenchCodeLine(']),', indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchSwitch<TabIndicator>(
      label: (t) => t.exMotion2Indicator,
      value: tabsRecipe.indicator.value,
      onChanged: tabsRecipe.setIndicator,
      segments: [
        BenchSegment(TabIndicator.pill, label: (t) => t.exMotion2IndicatorPill),
        BenchSegment(TabIndicator.line, label: (t) => t.exMotion2IndicatorLine),
      ],
    ),
    BenchSwitch<MotionCurve>(
      label: (t) => t.exMotionCurve,
      value: tabsRecipe.curve.value,
      onChanged: tabsRecipe.setCurve,
      segments: _curveSegments(),
    ),
    BenchLevel(
      label: (t) => t.exMotionDuration,
      value: coarseMs(tabsRecipe.step.value),
      min: coarseMinMs.toDouble(),
      max: coarseMaxMs.toDouble(),
      divisions: coarseSteps - 1,
      onChanged: tabsRecipe.setDuration,
      valueText: tabsRecipe.durationText,
    ),
  ],
);

class _TabsStage extends StatelessWidget {
  const _TabsStage();

  @override
  Widget build(BuildContext context) => Watch.field(
    tabsRecipe.step,
    count: coarseSteps,
    builder: (step) => Watch.field(
      tabsRecipe.curve,
      builder: (curve) => Watch.field(
        tabsRecipe.indicator,
        builder: (indicator) {
          final duration = coarseDuration(step);
          final easing = curveOf(curve);
          final labels = ['Summary', 'Activity', 'Settings'];
          final panels = [
            'Three orders to deliver and one on the way.',
            'A payment was confirmed yesterday and a package shipped.',
            'Choose how you want to receive notifications.',
          ];
          final pill = indicator == TabIndicator.pill;
          return SizedBox(
            width: _tabWidth * 3 + 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: pill ? ThemeColor.surfaceContainer : null,
                    border: pill
                        ? null
                        : const Border(
                            bottom: BorderSide(
                              color: ThemeColor.outlineVariant,
                            ),
                          ),
                    borderRadius: pill ? BorderRadius.circular(14) : null,
                  ),
                  child: Watch(
                    tabsRecipe.currentTab,
                    count: 3,
                    builder: (current) => Stack(
                      children: [
                        // One element that slides under the labels.
                        AnimatedSlide(
                          offset: Offset(current.toDouble(), 0),
                          duration: duration,
                          curve: easing,
                          child: Container(
                            width: _tabWidth,
                            height: 36,
                            alignment: pill
                                ? Alignment.center
                                : Alignment.bottomCenter,
                            decoration: BoxDecoration(
                              color: pill
                                  ? ThemeColor.surfaceContainerHighest
                                  : null,
                              borderRadius: pill
                                  ? BorderRadius.circular(10)
                                  : null,
                              boxShadow: pill
                                  ? [
                                      BoxShadow(
                                        color: ThemeColor.onSurface.withValues(
                                          alpha: 0.18,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: pill
                                ? null
                                : Container(
                                    width: _tabWidth - 24,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      color: ThemeColor.primary,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                          ),
                        ),
                        // Positioned: the labels paint over the sliding indicator.
                        Positioned(
                          left: 0,
                          top: 0,
                          child: Row(
                            children: [
                              for (var i = 0; i < 3; i++)
                                Semantics(
                                  selected: i == current,
                                  button: true,
                                  child: Gesture(
                                    onTap: tabsRecipe.go.withArg(i),
                                    child: Container(
                                      width: _tabWidth,
                                      height: 36,
                                      alignment: Alignment.center,
                                      child: AnimatedDefaultTextStyle(
                                        duration: const Duration(
                                          milliseconds: 150,
                                        ),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: i == current
                                              ? ThemeColor.onSurface
                                              : ThemeColor.onSurfaceVariant,
                                        ),
                                        child: Text(labels[i]),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: AnimatedSwitcher(
                    duration: duration,
                    switchInCurve: easing,
                    child: Watch(
                      tabsRecipe.currentTab,
                      count: 3,
                      builder: (current) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          panels[current],
                          style: const TextStyle(
                            color: ThemeColor.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

// ----------------------------------------------------------------- Toasts

/// Where the toasts stack.
enum ToastEdge { bottom, top }

class ToastRecipeViewModel extends ThorState {
  /// How many toasts are on screen (0 to 3).
  final shown = state(1);
  final edge = state(ToastEdge.bottom);
  final curve = state(MotionCurve.easeOut);
  final step = state(1);

  int shownCount() => shown.value;
  bool canShow() => shown.value < 3;
  bool canDismiss() => shown.value > 0;
  String durationText() => '${coarseDuration(step.value).inMilliseconds} ms';
  String durationCode() =>
      'duration: Duration(milliseconds: ${coarseDuration(step.value).inMilliseconds}),';
  String curveCode() => 'curve: ${curve.value.code},';
  String edgeCode() => edge.value == ToastEdge.bottom
      ? 'final dy = hidden ? 1.0 : -0.28 * depth;'
      : 'final dy = hidden ? -1.0 : 0.28 * depth;';

  void show() => shown.value += 1;
  void dismiss() => shown.value -= 1;
  void setEdge(Set<ToastEdge> value) => edge.value = value.first;
  void setCurve(Set<MotionCurve> value) => curve.value = value.first;
  void setDuration(double ms) => step.value = coarseStepOf(ms);
}

final toastRecipe = ToastRecipeViewModel();

final toastRecipeBench = BenchExample(
  title: (t) => t.exMotion2ToastsTitle,
  description: (t) => t.exMotion2ToastsDescription,
  stage: const ToastRecipe(),
  code: BenchCode([
    ...benchLines('''
class ToastViewModel extends ThorState {
  final shown = state(1);

  int shownCount() => shown.value;
  bool canShow() => shown.value < 3;

  void show() => shown.value += 1;
  void dismiss() => shown.value -= 1;
}

final toasts = ToastViewModel();
'''),
    const BenchCodeLine(' '),
    const BenchCodeLine(
      '// For each toast k, in Watch(toasts.shownCount, count: 4, builder: (shown) => …):',
    ),
    const BenchCodeLine('// depth: 0 is the newest, in front.'),
    const BenchCodeLine('final depth = shown - 1 - k;'),
    const BenchCodeLine('final hidden = k >= shown;'),
    BenchCodeLine.live(toastRecipe.edgeCode),
    const BenchCodeLine(' '),
    const BenchCodeLine('AnimatedOpacity('),
    const BenchCodeLine('opacity: hidden ? 0 : 1 - 0.25 * depth,', indent: 1),
    BenchCodeLine.live(toastRecipe.durationCode, indent: 1),
    BenchCodeLine.live(toastRecipe.curveCode, indent: 1),
    const BenchCodeLine('child: AnimatedScale(', indent: 1),
    const BenchCodeLine('scale: 1 - 0.05 * depth,', indent: 2),
    BenchCodeLine.live(toastRecipe.durationCode, indent: 2),
    BenchCodeLine.live(toastRecipe.curveCode, indent: 2),
    const BenchCodeLine('child: AnimatedSlide(', indent: 2),
    const BenchCodeLine('offset: Offset(0, dy),', indent: 3),
    BenchCodeLine.live(toastRecipe.durationCode, indent: 3),
    BenchCodeLine.live(toastRecipe.curveCode, indent: 3),
    const BenchCodeLine('child: toast(k),', indent: 3),
    const BenchCodeLine('),', indent: 2),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchSwitch<ToastEdge>(
      label: (t) => t.exMotion2Edge,
      value: toastRecipe.edge.value,
      onChanged: toastRecipe.setEdge,
      segments: [
        BenchSegment(ToastEdge.bottom, label: (t) => t.exMotion2EdgeBottom),
        BenchSegment(ToastEdge.top, label: (t) => t.exMotion2EdgeTop),
      ],
    ),
    BenchSwitch<MotionCurve>(
      label: (t) => t.exMotionCurve,
      value: toastRecipe.curve.value,
      onChanged: toastRecipe.setCurve,
      segments: _curveSegments(),
    ),
    BenchLevel(
      label: (t) => t.exMotionDuration,
      value: coarseMs(toastRecipe.step.value),
      min: coarseMinMs.toDouble(),
      max: coarseMaxMs.toDouble(),
      divisions: coarseSteps - 1,
      onChanged: toastRecipe.setDuration,
      valueText: toastRecipe.durationText,
    ),
  ],
);

class _ToastStage extends StatelessWidget {
  const _ToastStage();

  @override
  Widget build(BuildContext context) => Watch.field(
    toastRecipe.step,
    count: coarseSteps,
    builder: (step) => Watch.field(
      toastRecipe.curve,
      builder: (curve) => Watch.field(
        toastRecipe.edge,
        builder: (edge) {
          final duration = coarseDuration(step);
          final easing = curveOf(curve);
          final bottom = edge == ToastEdge.bottom;
          final messages = [
            (Icons.check, 'Changes saved'),
            (Icons.content_copy, 'Link copied'),
            (Icons.add, 'File uploaded'),
          ];
          return Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              Container(
                width: 300,
                height: 190,
                decoration: BoxDecoration(
                  color: ThemeColor.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Watch(
                    toastRecipe.shownCount,
                    count: 4,
                    builder: (shown) => Stack(
                      children: [
                        for (var k = 0; k < 3; k++)
                          Positioned(
                            left: 12,
                            right: 12,
                            top: bottom ? null : 12,
                            bottom: bottom ? 12 : null,
                            child: _ToastCard(
                              k: k,
                              shown: shown,
                              bottom: bottom,
                              duration: duration,
                              easing: easing,
                              icon: messages[k].$1,
                              text: messages[k].$2,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  Watch(
                    toastRecipe.canShow,
                    builder: (can) => FilledButton(
                      onPressed: can ? toastRecipe.show : null,
                      child: const Text('Show toast'),
                    ),
                  ),
                  Watch(
                    toastRecipe.canDismiss,
                    builder: (can) => OutlinedButton(
                      onPressed: can ? toastRecipe.dismiss : null,
                      child: const Text('Dismiss'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}

/// One toast of the stack: the newest is in front and the ones behind it
/// shrink, rise and fade; a toast that is not shown waits off to the side it
/// enters from, so it leaves the way it came.
class _ToastCard extends StatelessWidget {
  const _ToastCard({
    required this.k,
    required this.shown,
    required this.bottom,
    required this.duration,
    required this.easing,
    required this.icon,
    required this.text,
  });

  final int k;
  final int shown;
  final bool bottom;
  final Duration duration;
  final Curve easing;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final hidden = k >= shown;
    final depth = shown - 1 - k;
    final dy = hidden ? (bottom ? 1.0 : -1.0) : (bottom ? -0.28 : 0.28) * depth;
    return Semantics(
      hidden: hidden,
      child: AnimatedOpacity(
        opacity: hidden ? 0 : 1 - 0.25 * depth,
        duration: duration,
        curve: easing,
        child: AnimatedScale(
          scale: hidden ? 0.95 : 1 - 0.05 * depth,
          duration: duration,
          curve: easing,
          child: AnimatedSlide(
            offset: Offset(0, dy),
            duration: duration,
            curve: easing,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: ThemeColor.inverseSurface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: ThemeColor.onSurface.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                spacing: 12,
                children: [
                  Icon(icon, size: 18, color: ThemeColor.onInverseSurface),
                  Text(
                    text,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: ThemeColor.onInverseSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An icon whose opacity, and optionally its scale and turn, follow
/// animations.
class _Layer extends StatelessWidget {
  const _Layer({
    required this.opacity,
    required this.child,
    this.scale,
    this.turns,
  });

  final Animation<double> opacity;
  final Animation<double>? scale;
  final Animation<double>? turns;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget out = FadeTransition(opacity: opacity, child: child);
    if (scale != null) out = ScaleTransition(scale: scale!, child: out);
    if (turns != null) out = RotationTransition(turns: turns!, child: out);
    return out;
  }
}

class SlideRecipe extends StatelessWidget {
  const SlideRecipe({super.key});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    spacing: 16,
    children: [
      const _SlideStage(),
      Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          const Text(
            'Threshold',
            style: TextStyle(fontSize: 12, color: ThemeColor.onSurfaceVariant),
          ),
          Watch(
            slideRecipe.thresholdText,
            style: const TextStyle(
              fontSize: 12,
              color: ThemeColor.onSurfaceVariant,
            ),
          ),
        ],
      ),
      MotionMeta(step: slideRecipe.step, curve: slideRecipe.curve),
    ],
  );
}

class TabsRecipe extends StatelessWidget {
  const TabsRecipe({super.key});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    spacing: 16,
    children: [
      const _TabsStage(),
      MotionMeta(step: tabsRecipe.step, curve: tabsRecipe.curve),
    ],
  );
}

class ToastRecipe extends StatelessWidget {
  const ToastRecipe({super.key});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    spacing: 16,
    children: [
      const _ToastStage(),
      MotionMeta(step: toastRecipe.step, curve: toastRecipe.curve),
    ],
  );
}

class CopyRecipe extends StatelessWidget {
  const CopyRecipe({super.key});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    spacing: 16,
    children: [
      const _CopyStage(),
      Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Watch.field(
            copyRecipe.morph,
            builder: (m) => Text(
              switch (m) {
                CopyMorph.fade => 'Fade',
                CopyMorph.scale => 'Scale',
                CopyMorph.turn => 'Turn',
              },
              style: const TextStyle(
                fontSize: 12,
                color: ThemeColor.onSurfaceVariant,
              ),
            ),
          ),
          Watch(
            copyRecipe.holdText,
            style: const TextStyle(
              fontSize: 12,
              color: ThemeColor.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ],
  );
}
