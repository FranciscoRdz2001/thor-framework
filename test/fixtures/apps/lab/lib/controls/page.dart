import 'package:thor_ui/thor_ui.dart';

import 'controls_state.dart';

const _h2 = TextStyle(fontSize: 18, fontWeight: FontWeight.w700);

/// One section per controller, and one for dates.
class ControlsPage extends StatelessWidget implements ThorElementWidget {
  const ControlsPage({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      role: SemanticsRole.main,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 24,
          children: [
            _section('Desplazamiento', [
              SizedBox(
                height: 120,
                child: SingleChildScrollView(
                  controller: controls.feed,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 1; i <= 30; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text('Fila $i'),
                        ),
                    ],
                  ),
                ),
              ),
              Watch(controls.scrollLabel),
              Row(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: controls.toTop,
                    child: const Text('Arriba'),
                  ),
                  OutlinedButton(
                    onPressed: controls.toEnd,
                    child: const Text('Al final'),
                  ),
                ],
              ),
            ]),
            _section('Texto y foco', [
              TextField(
                controller: controls.name,
                focusNode: controls.nameFocus,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              Watch(controls.greeting),
              Watch(controls.focusLabel),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: controls.clearName,
                    child: const Text('Limpiar'),
                  ),
                  OutlinedButton(
                    onPressed: controls.setBea,
                    child: const Text('Poner Bea'),
                  ),
                  OutlinedButton(
                    onPressed: controls.focusName,
                    child: const Text('Enfocar'),
                  ),
                  OutlinedButton(
                    onPressed: controls.blurName,
                    child: const Text('Quitar foco'),
                  ),
                ],
              ),
            ]),
            _section('Hoja', [
              Row(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: controls.openSheet,
                    child: const Text('Abrir desde el estado'),
                  ),
                  DialogTrigger(
                    id: 'hoja',
                    child: OutlinedButton(
                      onPressed: () {},
                      child: const Text('Abrir sin estado'),
                    ),
                  ),
                ],
              ),
              Watch(controls.sheetLabel),
              AlertDialog(
                id: 'hoja',
                controller: controls.sheet,
                title: const Text('Hoja'),
                content: Watch(controls.sheetLabel),
                actions: [
                  TextButton(
                    onPressed: controls.closeSheet,
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            ]),
            _section('Navegación', [
              Watch(
                controls.isCompact,
                builder: (compact) =>
                    Text(compact ? 'Vista compacta' : 'Vista amplia'),
              ),
              OutlinedButton(
                onPressed: controls.toggleCompact,
                child: const Text('Cambiar vista'),
              ),
              Watch(controls.navNote),
              Row(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: controls.goNext,
                    child: const Text('Ir a la vista 2'),
                  ),
                  OutlinedButton(
                    onPressed: controls.tryUnsafe,
                    child: const Text('Probar javascript:'),
                  ),
                  OutlinedButton(
                    onPressed: controls.askBack,
                    child: const Text('¿Puedo volver?'),
                  ),
                  OutlinedButton(
                    onPressed: controls.goBack,
                    child: const Text('Volver'),
                  ),
                  OutlinedButton(
                    onPressed: controls.reloadPage,
                    child: const Text('Recargar'),
                  ),
                ],
              ),
            ]),
            _section('Tiempo', [
              Watch(controls.elapsedLabel),
              Watch(controls.dateLabel),
              Watch(
                controls.afternoon,
                builder: (pm) => Text(pm ? 'Por la tarde' : 'Por la mañana'),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: controls.addLap,
                    child: const Text('+95 s'),
                  ),
                  OutlinedButton(
                    onPressed: controls.addHour,
                    child: const Text('+1 h'),
                  ),
                  OutlinedButton(
                    onPressed: controls.back,
                    child: const Text('−200 s'),
                  ),
                  OutlinedButton(
                    onPressed: controls.nextDay,
                    child: const Text('+1 día'),
                  ),
                  OutlinedButton(
                    onPressed: controls.nextMonth,
                    child: const Text('+31 días'),
                  ),
                  OutlinedButton(
                    onPressed: controls.prevWeek,
                    child: const Text('−7 días'),
                  ),
                ],
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
