# Reserva de vuelos

Un vuelo de ida o de ida y vuelta, dos fechas que se validan mientras se escriben y un botón que solo reserva cuando son válidas.

:::flutter Flutter: `DropdownButton`, `TextField` y `setState` · Thor: los mismos, con la validez en un `ThorState`

:::example recipe-flights
:::

## Validar en un solo método

Cada cambio de un campo llama a `validate` (por `setKind`, `setStart` o `setBack`), que revisa las dos fechas y decide si se puede reservar. `batch` agrupa los cambios para que la página se actualice una sola vez.

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

## La vista solo lee

`InputDecoration(errorTextWatch:)` liga el mensaje de error a un método del ViewModel y marca el campo como no válido para los lectores de pantalla. El botón está dentro de un `Watch` y recibe `onPressed: null` mientras no se puede reservar.

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

El campo de regreso también es un `Watch` sobre `isReturn`, que lo habilita solo para un vuelo de ida y vuelta.

Relacionado: [Formularios](../formularios.md) · [Estado](../estado.md)
