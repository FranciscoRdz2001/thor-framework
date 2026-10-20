/// `:::bench bench-live-feed`: what a page with `events()` shows. This site
/// has no server, so a `Timer` plays the stream's part (`// web:`) and a
/// Switch plays the connection: the rows and the status are the ones a real
/// `events` field would draw.
library;

import 'dart:async';

import 'package:thor_ui/thor_ui.dart';

import 'bench_example.dart';

/// One row of the feed.
class Quote {
  /// A quote of [symbol] at [price].
  const Quote(this.symbol, this.price);

  /// Its key in the list.
  final String symbol;

  /// The last price.
  final double price;

  /// Reads a quote from its JSON (how the state travels).
  factory Quote.fromJson(Map<String, Object?> json) =>
      Quote(json['symbol']! as String, (json['price']! as num).toDouble());

  /// Its JSON.
  Map<String, Object?> toJson() => {'symbol': symbol, 'price': price};

  /// The same quote, a little higher.
  Quote bumped() => Quote(symbol, price + 0.35);
}

/// Where the stream is (what `ConnectionState` says in a real field).
enum FeedLink {
  /// Open: events arrive.
  active,

  /// Connecting, or reconnecting after a drop.
  waiting,

  /// Closed.
  done,
}

/// What the Switch changes and the stage reads.
class FeedViewModel extends ThorState {
  /// The rows (`feed.data` in a real field).
  final rows = state(const [
    Quote('ACME', 189.40),
    Quote('GLBX', 72.15),
    Quote('NRTH', 311.80),
    Quote('PLNT', 24.05),
  ]);

  /// The connection (`feed.connection` in a real field).
  final link = state(FeedLink.active);

  /// Which row the next event changes.
  final next = state(0);

  /// Plays the server's events.
  Timer? timer;

  /// The key of a row.
  String keyOf(Quote q) => q.symbol;

  /// The symbol of a row.
  String symbolOf(Quote q) => q.symbol;

  /// The price of a row, as text.
  String priceOf(Quote q) => q.price.toStringAsFixed(2);

  /// The `connection` line of the Code view.
  String linkCode() => switch (link.value) {
    FeedLink.active => 'feed.connection.value // active',
    FeedLink.waiting => 'feed.connection.value // waiting',
    FeedLink.done => 'feed.connection.value // done',
  };

  /// One event: the next row changes, the others stay the same objects.
  void tick() {
    if (link.value != FeedLink.active) return;
    final symbol = rows.value[next.value % rows.value.length].symbol;
    rows.value = [
      for (final q in rows.value)
        if (q.symbol == symbol) q.bumped() else q,
    ];
    next.value++;
  }

  /// What the Switch calls.
  void setLink(Set<FeedLink> value) => link.value = value.first;

  @override
  void onHydrated() {
    timer = Timer.periodic(const Duration(milliseconds: 1400), (_) => tick());
  }

  @override
  void dispose() => timer?.cancel();
}

/// One instance, at the top level: the browser boots with it.
final feedState = FeedViewModel();

/// The example: a Switch, the stage and its code.
final liveFeedBench = BenchExample(
  title: (t) => t.exDataFeedTitle,
  description: (t) => t.exDataFeedDescription,
  stage: const LiveFeedStage(),
  code: BenchCode([
    const BenchCodeLine('final feed = events<List<Quote>>('),
    const BenchCodeLine("'/markets/stream',", indent: 1),
    const BenchCodeLine("event: 'tick',", indent: 1),
    const BenchCodeLine('initial: market.snapshot,', indent: 1),
    const BenchCodeLine("key: 'symbol',", indent: 1),
    const BenchCodeLine(');'),
    const BenchCodeLine(' '),
    BenchCodeLine.live(feedState.linkCode),
  ], appCode: true),
  controls: [
    BenchSwitch<FeedLink>(
      label: (t) => t.exDataFeedLink,
      value: feedState.link.value,
      onChanged: feedState.setLink,
      segments: [
        BenchSegment(FeedLink.active, label: (t) => t.exDataFeedLive),
        BenchSegment(FeedLink.waiting, label: (t) => t.exDataFeedWaiting),
        BenchSegment(FeedLink.done, label: (t) => t.exDataFeedClosed),
      ],
    ),
  ],
);

/// The stage: the status and the rows.
class LiveFeedStage extends StatelessWidget {
  /// The stage of the example.
  const LiveFeedStage({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Watch.field(
            feedState.link,
            builder: (link) => Text(switch (link) {
              FeedLink.active => 'Live',
              FeedLink.waiting => 'Reconnecting…',
              FeedLink.done => 'Closed',
            }, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Watch.list(
            feedState.rows,
            itemKey: feedState.keyOf,
            container: (rows) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 4,
              children: rows,
            ),
            each: (row) => Row(
              children: [
                Expanded(child: row.text(feedState.symbolOf)),
                row.text(
                  feedState.priceOf,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
