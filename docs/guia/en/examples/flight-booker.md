# Flight booker

A one-way or return flight, two dates that are validated as you type and a button that only books when they are valid.

:::flutter Flutter: `DropdownButton`, `TextField` and `setState` · Thor: the same ones, with the validity in a `ThorState`

:::example recipe-flights
:::

## Validate in a single method

Every field change calls `validate` (through `setKind`, `setStart` or `setBack`), which checks both dates and decides whether booking is possible. `batch` groups the changes so the page updates only once.

```dart
enum FlightKind { oneWay, returnFlight }

class FlightsViewModel extends ThorState {
  final kind = state(FlightKind.oneWay);
  final start = TextEditingController(text: '10.10.2026');
  final back = TextEditingController(text: '10.10.2026');
  final startOk = state(true);
  final backOk = state(true);
  final canBook = state(true);
  final booked = state(false);

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

  // dd.mm.yyyy, or null when the text is not a real date.
  DateTime? parseDate(String text) {
    final p = text.split('.');
    if (p.length != 3 || p[2].length != 4) return null;
    final [d, m, y] = [for (final part in p) int.tryParse(part)];
    if (d == null || m == null || y == null) return null;
    final date = DateTime(y, m, d);
    return date.day == d && date.month == m ? date : null;
  }

  void setKind(FlightKind? value) {
    kind.value = value ?? FlightKind.oneWay;
    validate();
  }

  void setStart(String _) => validate();
  void setBack(String _) => validate();

  bool isReturn() => kind.value == FlightKind.returnFlight;
  String? startError() => startOk.value ? null : 'Use dd.mm.yyyy';
  String? backError() => backOk.value ? null : 'Use dd.mm.yyyy';
  bool bookable() => canBook.value;
  void book() => booked.value = true;
}

final flights = FlightsViewModel();
```

## The view only reads

`InputDecoration(errorTextWatch:)` binds the error message to a ViewModel method and marks the field as invalid for screen readers. The button sits inside a `Watch` and receives `onPressed: null` while booking isn't possible.

```dart
Column(
  children: [
    TextField(
      controller: flights.start,
      onChanged: flights.setStart,
      decoration: InputDecoration(
        labelText: 'Departure',
        errorTextWatch: flights.startError,
      ),
    ),
    Watch(
      flights.bookable,
      builder: (ok) => FilledButton(
        onPressed: ok ? flights.book : null,
        child: const Text('Book'),
      ),
    ),
  ],
)
```

The return field is also a `Watch` over `isReturn`, which enables it only for a return flight.

Related: [Forms](../forms.md) · [State](../state.md)
