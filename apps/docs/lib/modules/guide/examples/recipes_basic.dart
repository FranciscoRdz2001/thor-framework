// ignore_for_file: public_member_api_docs
// (each recipe is named by its region or its bench; a doc comment would sit
// outside the code the site shows)
// The cookbook's first four recipes: Counter, Temperature converter, Flight
// booker and Timer (docs/guia/es/ejemplos/). Counter, Temperature and Timer
// are benches (their controls change the solution and its code); the flight
// booker is a plain example whose region is the whole solution.
import 'dart:async';

import 'package:thor_ui/thor_ui.dart';

import 'bench/bench_example.dart';

// ----------------------------------------------------------------- Counter

class CounterRecipeViewModel extends ThorState {
  final count = state(0);

  /// How much each press adds (the bench's Level; the recipe adds 1).
  final step = state(1);

  String label() => '${count.value}';
  String stepText() => '${step.value}';

  /// What the button says it adds, so the Level shows before any press.
  String buttonText() => 'Count +${step.value}';
  String stepCode() => 'void increment() => count.value += ${step.value};';
  String buttonCode() => "child: Text('Count +${step.value}'),";

  void increment() => count.value += step.value;
  void setStep(double value) => step.value = value.round();
}

final counterRecipe = CounterRecipeViewModel();

final counterRecipeBench = BenchExample(
  title: (t) => t.exRecCounterTitle,
  description: (t) => t.exRecCounterDescription,
  stage: const CounterRecipe(),
  code: BenchCode(
    benchLines(
      r'''
class CounterViewModel extends ThorState {
  final count = state(0);

  String label() => '${count.value}';
  @increment
}

final counter = CounterViewModel();

class CounterView extends StatelessWidget {
  const CounterView({super.key});

  @override
  Widget build(BuildContext context) => Row(
    spacing: 12,
    children: [
      Semantics(
        label: 'Count',
        liveRegion: true,
        child: Watch(counter.label),
      ),
      FilledButton(
        onPressed: counter.increment,
        @child
      ),
    ],
  );
}
''',
      {
        '@increment': counterRecipe.stepCode,
        '@child': counterRecipe.buttonCode,
      },
    ),
  ),
  controls: [
    BenchLevel(
      label: (t) => t.exRecCounterStep,
      value: counterRecipe.step.value,
      min: 1,
      max: 10,
      divisions: 9,
      onChanged: counterRecipe.setStep,
      valueText: counterRecipe.stepText,
    ),
  ],
);

class CounterRecipe extends StatelessWidget {
  const CounterRecipe({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        Semantics(
          label: 'Count',
          liveRegion: true,
          child: Watch(
            counterRecipe.label,
            style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w700),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 56),
            padding: const EdgeInsets.symmetric(horizontal: 24),
          ),
          onPressed: counterRecipe.increment,
          child: Watch(counterRecipe.buttonText),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- Temperature

class TemperatureRecipeViewModel extends ThorState {
  final celsius = TextEditingController(text: '21.5');
  final fahrenheit = TextEditingController(text: '70.7');

  /// How many decimals the other field shows (the bench's Switch).
  final decimals = state(1);

  String _show(double value) => value.toStringAsFixed(decimals.value);

  void fromCelsius(String text) {
    final c = double.tryParse(text);
    if (c != null) fahrenheit.text = _show(c * 9 / 5 + 32);
  }

  void fromFahrenheit(String text) {
    final f = double.tryParse(text);
    if (f != null) celsius.text = _show((f - 32) * 5 / 9);
  }

  String showCode() =>
      'String show(double value) => value.toStringAsFixed(${decimals.value});';

  void setDecimals(Set<int> value) {
    decimals.value = value.first;
    fromCelsius(celsius.text);
  }
}

final temperatureRecipe = TemperatureRecipeViewModel();

final temperatureRecipeBench = BenchExample(
  title: (t) => t.exRecTempTitle,
  description: (t) => t.exRecTempDescription,
  stage: const TemperatureRecipe(),
  code: BenchCode(
    benchLines(
      r'''
class TemperatureViewModel extends ThorState {
  final celsius = TextEditingController(text: '21.5');
  final fahrenheit = TextEditingController(text: '70.7');

  @show

  void fromCelsius(String text) {
    final c = double.tryParse(text);
    if (c != null) fahrenheit.text = show(c * 9 / 5 + 32);
  }

  void fromFahrenheit(String text) {
    final f = double.tryParse(text);
    if (f != null) celsius.text = show((f - 32) * 5 / 9);
  }
}

final temperature = TemperatureViewModel();

class TemperatureView extends StatelessWidget {
  const TemperatureView({super.key});

  @override
  Widget build(BuildContext context) => Row(
    spacing: 12,
    children: [
      SizedBox(
        width: 130,
        child: TextField(
          controller: temperature.celsius,
          onChanged: temperature.fromCelsius,
          keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
          decoration: const InputDecoration(labelText: 'Celsius'),
        ),
      ),
      const Text('='),
      SizedBox(
        width: 130,
        child: TextField(
          controller: temperature.fahrenheit,
          onChanged: temperature.fromFahrenheit,
          keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
          decoration: const InputDecoration(labelText: 'Fahrenheit'),
        ),
      ),
    ],
  );
}
''',
      {'@show': temperatureRecipe.showCode},
    ),
  ),
  controls: [
    BenchSwitch<int>(
      label: (t) => t.exRecTempDecimals,
      value: temperatureRecipe.decimals.value,
      onChanged: temperatureRecipe.setDecimals,
      segments: [
        BenchSegment(0, label: (t) => t.exRecTempDec0),
        BenchSegment(1, label: (t) => t.exRecTempDec1),
        BenchSegment(2, label: (t) => t.exRecTempDec2),
      ],
    ),
  ],
);

class TemperatureRecipe extends StatelessWidget {
  const TemperatureRecipe({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: 12,
      children: [
        SizedBox(
          width: 130,
          child: TextField(
            controller: temperatureRecipe.celsius,
            onChanged: temperatureRecipe.fromCelsius,
            keyboardType: const TextInputType.numberWithOptions(
              signed: true,
              decimal: true,
            ),
            decoration: const InputDecoration(labelText: 'Celsius'),
          ),
        ),
        const Text('='),
        SizedBox(
          width: 130,
          child: TextField(
            controller: temperatureRecipe.fahrenheit,
            onChanged: temperatureRecipe.fromFahrenheit,
            keyboardType: const TextInputType.numberWithOptions(
              signed: true,
              decimal: true,
            ),
            decoration: const InputDecoration(labelText: 'Fahrenheit'),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ Flights

// region: recipe-flights
enum FlightKind { oneWay, returnFlight }

class FlightsViewModel extends ThorState {
  final kind = state(FlightKind.oneWay);
  final start = TextEditingController(text: '10.10.2026');
  final back = TextEditingController(text: '10.10.2026');
  final startOk = state(true);
  final backOk = state(true);
  final canBook = state(true);
  final booked = state(false);

  DateTime? parseDate(String text) {
    final p = text.split('.');
    if (p.length != 3) return null;
    final d = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final y = int.tryParse(p[2]);
    if (d == null || m == null || y == null || p[2].length != 4) return null;
    final date = DateTime(y, m, d);
    return date.day == d && date.month == m && date.year == y ? date : null;
  }

  // One method per change: the validity of both dates and the Book button.
  void validate() {
    final a = parseDate(start.text);
    final b = parseDate(back.text);
    final round = kind.value == FlightKind.returnFlight;
    batch(() {
      startOk.value = a != null;
      backOk.value = !round || b != null;
      canBook.value = a != null && (!round || (b != null && !b.isBefore(a)));
      booked.value = false;
    });
  }

  void setKind(FlightKind? value) {
    kind.value = value ?? FlightKind.oneWay;
    validate();
  }

  void setStart(String text) => validate();
  void setBack(String text) => validate();

  bool isReturn() => kind.value == FlightKind.returnFlight;
  String? startError() => startOk.value ? null : 'Use dd.mm.yyyy';
  String? backError() => backOk.value ? null : 'Use dd.mm.yyyy';
  bool bookable() => canBook.value;
  String dates() => kind.value == FlightKind.oneWay
      ? start.text
      : '${start.text} - ${back.text}';

  void book() => booked.value = true;
}

final flights = FlightsViewModel();

// web: a field with an error (`errorTextWatch`, bound below) paints its
// `errorBorder`.
const _invalidBorder = UnderlineInputBorder(
  borderSide: BorderSide(color: ThemeColor.error, width: 3),
);

class FlightBooker extends StatelessWidget {
  const FlightBooker({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          DropdownButton<FlightKind>(
            value: FlightKind.oneWay,
            semanticLabel: 'Flight type',
            items: [
              const DropdownMenuItem(
                value: FlightKind.oneWay,
                child: Text('one-way flight'),
              ),
              const DropdownMenuItem(
                value: FlightKind.returnFlight,
                child: Text('return flight'),
              ),
            ],
            onChanged: flights.setKind,
          ),
          TextField(
            controller: flights.start,
            onChanged: flights.setStart,
            decoration: InputDecoration(
              labelText: 'Departure',
              errorBorder: _invalidBorder,
              errorTextWatch: flights.startError,
            ),
          ),
          // web: `disabled` is not a bound attribute: the field has one
          // variant per value of `isReturn`.
          Watch(
            flights.isReturn,
            builder: (round) => TextField(
              controller: flights.back,
              onChanged: flights.setBack,
              enabled: round,
              decoration: InputDecoration(
                labelText: 'Return',
                errorBorder: _invalidBorder,
                errorTextWatch: flights.backError,
              ),
            ),
          ),
          Watch(
            flights.bookable,
            builder: (ok) => FilledButton(
              onPressed: ok ? flights.book : null,
              child: const Text('Book'),
            ),
          ),
          Semantics(
            liveRegion: true,
            child: Watch.field(
              flights.booked,
              builder: (booked) => booked
                  ? Row(
                      spacing: 6,
                      children: [
                        const Text('Flight booked:'),
                        Watch(
                          flights.dates,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
// endregion

// -------------------------------------------------------------------- Timer

class TimerRecipeViewModel extends ThorState {
  final elapsedMs = state(0);
  final seconds = state(15.0);
  Timer? _ticker;

  @override
  void onHydrated() {
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => tick());
  }

  @override
  void dispose() => _ticker?.cancel();

  void tick() {
    if (elapsedMs.value < seconds.value * 1000) elapsedMs.value += 100;
  }

  void setSeconds(double value) => seconds.value = value;
  void reset() => elapsedMs.value = 0;

  double fraction() {
    final r = elapsedMs.value / (seconds.value * 1000);
    return r > 1 ? 1.0 : r;
  }

  String elapsedLabel() =>
      '${elapsedMs.value ~/ 1000}.${(elapsedMs.value % 1000) ~/ 100}s';
  String durationText() => '${seconds.value.round()} s';
}

final timerRecipe = TimerRecipeViewModel();

final timerRecipeBench = BenchExample(
  title: (t) => t.exRecTimerTitle,
  description: (t) => t.exRecTimerDescription,
  stage: const TimerRecipe(),
  code: BenchCode(
    benchLines(r'''
class TimerViewModel extends ThorState {
  final elapsedMs = state(0);
  final seconds = state(15.0);
  Timer? _ticker;

  @override
  void onHydrated() {
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => tick());
  }

  @override
  void dispose() => _ticker?.cancel();

  void tick() {
    if (elapsedMs.value < seconds.value * 1000) elapsedMs.value += 100;
  }

  void setSeconds(double value) => seconds.value = value;
  void reset() => elapsedMs.value = 0;

  double fraction() {
    final r = elapsedMs.value / (seconds.value * 1000);
    return r > 1 ? 1.0 : r;
  }

  String elapsedLabel() =>
      '${elapsedMs.value ~/ 1000}.${(elapsedMs.value % 1000) ~/ 100}s';
  String durationText() => '${seconds.value.round()} s';
}

final timer = TimerViewModel();

class TimerView extends StatelessWidget {
  const TimerView({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 12,
    children: [
      LinearProgressIndicator.watch(
        timer.fraction,
        minHeight: 12,
        semanticsLabel: 'Elapsed time',
      ),
      Watch(timer.elapsedLabel),
      Row(
        spacing: 12,
        children: [
          Expanded(
            child: Slider(
              value: 15,
              min: 1,
              max: 30,
              divisions: 29,
              semanticLabel: 'Duration',
              onChanged: timer.setSeconds,
            ),
          ),
          Watch(timer.durationText),
        ],
      ),
      OutlinedButton(onPressed: timer.reset, child: const Text('Reset')),
    ],
  );
}
'''),
  ),
);

class TimerRecipe extends StatelessWidget {
  const TimerRecipe({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          // web: the gauge is the native <progress>; its `value` follows the
          // state in the browser.
          LinearProgressIndicator.watch(
            timerRecipe.fraction,
            minHeight: 12,
            semanticsLabel: 'Elapsed time',
          ),
          Watch(timerRecipe.elapsedLabel),
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: Slider(
                  value: timerRecipe.seconds.value,
                  min: 1,
                  max: 30,
                  divisions: 29,
                  semanticLabel: 'Duration',
                  onChanged: timerRecipe.setSeconds,
                ),
              ),
              Watch(timerRecipe.durationText),
            ],
          ),
          OutlinedButton(
            onPressed: timerRecipe.reset,
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
