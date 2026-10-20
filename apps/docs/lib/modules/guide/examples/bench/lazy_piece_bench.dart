/// `:::bench bench-lazy-piece`: a `LazyPiece` before and after the browser
/// asks for it. This site has no server to answer, so the Switch plays the
/// two moments (`// web:`): the fallback the page carries, and the piece the
/// server draws when the trigger happens.
library;

import 'package:thor_ui/thor_ui.dart';

import 'bench_example.dart';

/// What makes the piece load (the same cases as `LazyTrigger`).
enum PieceTrigger {
  /// When the accordion around it opens.
  open,

  /// When it comes near the screen.
  visible,

  /// When the page is ready.
  idle,
}

/// Which of the two moments the stage shows.
enum PieceMoment {
  /// What the page carries (and what shows without JavaScript).
  fallback,

  /// What the server drew when the trigger happened.
  loaded,
}

/// What the Switches change and the stage reads.
class LazyPieceViewModel extends ThorState {
  /// What makes it load.
  final trigger = state(PieceTrigger.open);

  /// What the stage shows.
  final moment = state(PieceMoment.fallback);

  /// The `trigger` line of the Code view.
  String triggerCode() => switch (trigger.value) {
    PieceTrigger.open => 'trigger: LazyTrigger.open,',
    PieceTrigger.visible => 'trigger: LazyTrigger.visible,',
    PieceTrigger.idle => 'trigger: LazyTrigger.idle,',
  };

  /// The line of the Code view that says which moment the stage shows.
  String momentCode() => moment.value == PieceMoment.fallback
      ? '// now: the fallback the page carries'
      : '// now: the piece the server drew';

  /// What the trigger Switch calls.
  void setTrigger(Set<PieceTrigger> value) => trigger.value = value.first;

  /// What the moment Switch calls.
  void setMoment(Set<PieceMoment> value) => moment.value = value.first;
}

/// One instance, at the top level: the browser boots with it.
final lazyPiece = LazyPieceViewModel();

/// The example: two Switches, the stage and its code.
final lazyPieceBench = BenchExample(
  title: (t) => t.exDataPieceTitle,
  description: (t) => t.exDataPieceDescription,
  stage: const LazyPieceStage(),
  code: BenchCode([
    const BenchCodeLine('LazyPiece<List<Review>>('),
    const BenchCodeLine("id: 'reviews',", indent: 1),
    const BenchCodeLine('load: (request) => shop.reviews(sku),', indent: 1),
    const BenchCodeLine(
      'builder: (context, reviews) => ReviewList(reviews),',
      indent: 1,
    ),
    const BenchCodeLine(
      "fallback: Link(href: reviewsUrl, child: Text('See reviews')),",
      indent: 1,
    ),
    BenchCodeLine.live(lazyPiece.triggerCode, indent: 1),
    const BenchCodeLine(')'),
    BenchCodeLine.live(lazyPiece.momentCode),
  ], appCode: true),
  controls: [
    BenchSwitch<PieceTrigger>(
      label: (t) => t.exDataPieceTrigger,
      value: lazyPiece.trigger.value,
      onChanged: lazyPiece.setTrigger,
      segments: [
        BenchSegment(PieceTrigger.open, label: (t) => t.exDataPieceOpen),
        BenchSegment(PieceTrigger.visible, label: (t) => t.exDataPieceVisible),
        BenchSegment(PieceTrigger.idle, label: (t) => t.exDataPieceIdle),
      ],
    ),
    BenchSwitch<PieceMoment>(
      label: (t) => t.exDataPieceMoment,
      value: lazyPiece.moment.value,
      onChanged: lazyPiece.setMoment,
      segments: [
        BenchSegment(PieceMoment.fallback, label: (t) => t.exDataPieceBefore),
        BenchSegment(PieceMoment.loaded, label: (t) => t.exDataPieceAfter),
      ],
    ),
  ],
);

/// The stage: a product's reviews, as the page carries them and as the
/// server draws them.
class LazyPieceStage extends StatelessWidget {
  /// The stage of the example.
  const LazyPieceStage({super.key});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: ThemeColor.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            const Text(
              'Reviews',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Watch.field(
              lazyPiece.trigger,
              builder: (trigger) => Text(
                switch (trigger) {
                  PieceTrigger.open =>
                    'Requested when the accordion that contains it opens',
                  PieceTrigger.visible =>
                    'Requested when it gets near the screen',
                  PieceTrigger.idle => 'Requested when the page is ready',
                },
                style: const TextStyle(
                  fontSize: 13,
                  color: ThemeColor.onSurfaceVariant,
                ),
              ),
            ),
            Watch.field(
              lazyPiece.moment,
              builder: (moment) => moment == PieceMoment.fallback
                  ? const Link(child: Text('See all reviews'))
                  : const Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 4,
                      children: [
                        Text('Arrived fast and well packed.'),
                        Text('The color matches the photo.'),
                        Text('I would buy it again.'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
