import 'package:thor_ui/thor_ui.dart';

import 'dates_state.dart';

const _h2 = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);

/// Fixed "today" and range: the page is the same whenever it is built.
final _today = DateTime(2026, 9, 20);
final _first = DateTime(2026);
final _last = DateTime(2027, 12, 31);

bool _weekday(DateTime d) => d.weekday < DateTime.saturday;

/// One section per picker.
class DatesPage extends StatelessWidget implements ThorElementWidget {
  const DatesPage({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      role: SemanticsRole.main,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 24,
          children: [
            const Semantics(
              headingLevel: 1,
              child: Text(
                'Fechas y horas',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
            ),
            _section('Calendario', [
              CalendarDatePicker(
                initialDate: DateTime(2026, 9, 25),
                firstDate: _first,
                lastDate: _last,
                currentDate: _today,
                onDateChanged: dates.setDay,
                onDisplayedMonthChanged: dates.setShown,
              ),
              Watch(dates.dayLabel),
              Watch(dates.shownLabel),
            ]),
            _section('Diálogo (solo días hábiles)', [
              Row(
                spacing: 8,
                children: [
                  DialogTrigger(
                    id: 'due',
                    child: FilledButton(
                      onPressed: () {},
                      child: const Text('Elegir entrega'),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: dates.openDue,
                    child: const Text('Desde el estado'),
                  ),
                ],
              ),
              Watch(dates.dueLabel),
              DatePickerDialog(
                id: 'due',
                firstDate: _first,
                lastDate: _last,
                currentDate: _today,
                selectableDayPredicate: _weekday,
                onDatePicked: dates.setDue,
                controller: dates.dueDialog,
              ),
            ]),
            _section('Formulario (GET, funciona sin JS)', [
              Form(
                formMethod: FormMethod.get,
                action: '',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    Localizations(
                      locale: const Locale('es'),
                      delegates: const [],
                      child: DatePickerFormField(
                        id: 'from',
                        name: 'from',
                        initialDate: DateTime(2026, 10, 5),
                        firstDate: _first,
                        lastDate: _last,
                        currentDate: _today,
                        fieldLabelText: 'Desde',
                      ),
                    ),
                    InputDatePickerFormField(
                      name: 'to',
                      firstDate: _first,
                      lastDate: _last,
                      fieldLabelText: 'Hasta',
                      acceptEmptyDate: true,
                    ),
                    FilledButton(
                      buttonType: ButtonType.submit,
                      onPressed: () {},
                      child: const Text('Buscar'),
                    ),
                  ],
                ),
              ),
            ]),
            _section('Hora', [
              DialogTrigger(
                id: 'time',
                child: OutlinedButton(
                  onPressed: () {},
                  child: const Text('Elegir hora'),
                ),
              ),
              Watch(dates.atLabel),
              TimePickerDialog(
                id: 'time',
                initialTime: const TimeOfDay(hour: 9, minute: 30),
                onTimePicked: dates.setAt,
              ),
            ]),
          ],
        ),
      ),
    ),
  );

  Widget _section(String title, List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 12,
    children: [
      Semantics(headingLevel: 2, child: Text(title, style: _h2)),
      ...children,
    ],
  );
}
