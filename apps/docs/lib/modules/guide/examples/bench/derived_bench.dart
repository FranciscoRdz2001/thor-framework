/// `:::bench bench-state-derived`: a value computed once with `derived`. A
/// Level sets the minimum magnitude and a Switch the order; the list and the
/// counter read the same `derived`, which runs once per change.
library;

import 'package:thor_ui/thor_ui.dart';

import 'bench_example.dart';

/// One row of the list.
class Quake {
  /// A quake at [place] with magnitude [mag].
  const Quake(this.id, this.place, this.mag);

  /// Its key in the list.
  final String id;

  /// Where it was.
  final String place;

  /// How strong.
  final double mag;

  /// Reads a quake from its JSON (how the state travels).
  factory Quake.fromJson(Map<String, Object?> json) => Quake(
    json['id']! as String,
    json['place']! as String,
    (json['mag']! as num).toDouble(),
  );

  /// Its JSON.
  Map<String, Object?> toJson() => {'id': id, 'place': place, 'mag': mag};
}

/// How the list is sorted.
enum QuakeOrder {
  /// The strongest first.
  magnitude,

  /// A to Z.
  place,
}

/// What the controls change and the stage reads.
class QuakesViewModel extends ThorState {
  /// Every quake (the data, never filtered).
  final all = state(const [
    Quake('q1', 'Oaxaca', 5.8),
    Quake('q2', 'Chiapas', 4.1),
    Quake('q3', 'Guerrero', 6.2),
    Quake('q4', 'Jalisco', 3.4),
    Quake('q5', 'Michoacán', 4.9),
    Quake('q6', 'Colima', 2.7),
  ]);

  /// The least magnitude shown.
  final minMag = state(3.0);

  /// The order of the list.
  final order = state(QuakeOrder.magnitude);

  /// Filtered and sorted: runs once per change of `all`, `minMag` or
  /// `order`, however many widgets read it.
  late final visible = derived(() {
    final shown = all.value.where((q) => q.mag >= minMag.value).toList();
    if (order.value == QuakeOrder.magnitude) {
      shown.sort((a, b) => b.mag.compareTo(a.mag));
    } else {
      shown.sort((a, b) => a.place.compareTo(b.place));
    }
    return shown;
  });

  /// The rows the list draws.
  List<Quake> rows() => visible.value;

  /// The counter's text.
  String count() => '${visible.value.length}';

  /// The key of a row.
  String keyOf(Quake q) => q.id;

  /// The place of a row.
  String placeOf(Quake q) => q.place;

  /// The magnitude of a row, as text.
  String magOf(Quake q) => q.mag.toStringAsFixed(1);

  /// The number next to the Level's bar.
  String minText() => minMag.value.toStringAsFixed(1);

  /// The `where` line of the Code view.
  String filterCode() =>
      '.where((q) => q.mag >= ${minMag.value.toStringAsFixed(1)})';

  /// The `sort` line of the Code view.
  String sortCode() => order.value == QuakeOrder.magnitude
      ? '..sort((a, b) => b.mag.compareTo(a.mag)),'
      : '..sort((a, b) => a.place.compareTo(b.place)),';

  /// What the Level calls.
  void setMin(double value) => minMag.value = value;

  /// What the Switch calls.
  void setOrder(Set<QuakeOrder> value) => order.value = value.first;
}

/// One instance, at the top level: the browser boots with it.
final quakes = QuakesViewModel();

/// The example: a Level, a Switch, the stage and its code.
final derivedBench = BenchExample(
  title: (t) => t.exStateDerivedTitle,
  description: (t) => t.exStateDerivedDescription,
  stage: const DerivedStage(),
  code: BenchCode([
    const BenchCodeLine('late final visible = derived('),
    const BenchCodeLine('() => all.value', indent: 1),
    BenchCodeLine.live(quakes.filterCode, indent: 3),
    const BenchCodeLine('.toList()', indent: 3),
    BenchCodeLine.live(quakes.sortCode, indent: 3),
    const BenchCodeLine(');'),
  ], appCode: true),
  controls: [
    BenchSwitch<QuakeOrder>(
      label: (t) => t.exStateDerivedOrder,
      value: quakes.order.value,
      onChanged: quakes.setOrder,
      segments: [
        BenchSegment(
          QuakeOrder.magnitude,
          label: (t) => t.exStateDerivedOrderMag,
        ),
        BenchSegment(
          QuakeOrder.place,
          label: (t) => t.exStateDerivedOrderPlace,
        ),
      ],
    ),
    BenchLevel(
      label: (t) => t.exStateDerivedMin,
      value: quakes.minMag.value,
      max: 6,
      divisions: 12,
      onChanged: quakes.setMin,
      valueText: quakes.minText,
    ),
  ],
);

/// The stage: a counter and the list, both reading `visible`.
class DerivedStage extends StatelessWidget {
  /// The stage of the example.
  const DerivedStage({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 280,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Row(
          spacing: 6,
          children: [
            Watch(
              quakes.count,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const Text('earthquakes'),
          ],
        ),
        Watch.list(
          quakes.rows,
          itemKey: quakes.keyOf,
          container: (rows) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 4,
            children: rows,
          ),
          each: (row) => Row(
            children: [
              Expanded(child: row.text(quakes.placeOf)),
              row.text(
                quakes.magOf,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
