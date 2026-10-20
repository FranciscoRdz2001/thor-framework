import 'package:thor_ui/thor_ui.dart';

/// Everything the animations page plays in the browser.
class MotionState extends ThorState {
  /// The panel that appears and hides.
  final reveal = AnimationController(
    duration: const Duration(milliseconds: 350),
    reverseDuration: const Duration(milliseconds: 220),
  );

  /// The loader that spins while "working".
  final spin = AnimationController(duration: const Duration(milliseconds: 900));

  /// A heartbeat, played from the start on every tap.
  final beat = AnimationController(duration: const Duration(milliseconds: 700));

  String revealLabel() => switch (reveal.status) {
    AnimationStatus.dismissed => 'Oculto',
    AnimationStatus.forward => 'Apareciendo…',
    AnimationStatus.reverse => 'Ocultándose…',
    AnimationStatus.completed => 'Visible',
  };

  bool isSpinning() => spin.isAnimating;

  void show() => reveal.forward();
  void hide() => reveal.reverse();
  void toggle() => reveal.toggle();

  /// Stops half way (the curve is the browser's: linear).
  void half() => reveal.animateTo(
    0.5,
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOut,
  );
  void quarter() => reveal.animateBack(0.25);
  void flingUp() => reveal.fling();

  void startSpin() => spin.repeat();
  void stopSpin() => spin.stop();

  /// A quarter turn back and forth: a loop over a stretch of the range.
  void rock() => spin.repeat(min: 0.25, max: 0.5, reverse: true);

  void pulse() => beat.forward(from: 0);
}

final motion = MotionState();
