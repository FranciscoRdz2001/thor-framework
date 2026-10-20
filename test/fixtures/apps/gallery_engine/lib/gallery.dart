import 'package:thor_ui/thor_ui.dart';

import 'gallery_state.dart';

class Gallery extends StatelessWidget implements ThorElementWidget {
  const Gallery({super.key});

  static const _h2 = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);

  Widget _section(String title, List<Widget> children) => Semantics(
    role: SemanticsRole.region,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Semantics(headingLevel: 2, child: Text(title, style: _h2)),
        ),
        ...children,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        role: SemanticsRole.main,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Semantics(
                headingLevel: 1,
                child: Text(
                  'Controles',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
              ),
              _section('Checkbox', [
                CheckboxListTile(
                  value: gallery.ticket.value,
                  onChanged: gallery.setTicket,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Imprimir ticket'),
                ),
                CheckboxListTile(
                  value: gallery.email.value,
                  onChanged: gallery.setEmail,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Enviar por correo'),
                ),
                const CheckboxListTile(
                  value: false,
                  onChanged: null,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text('Factura'),
                ),
                Watch(
                  gallery.allState,
                  builder: (all) => CheckboxListTile(
                    value: switch (all) {
                      AllState.mixed => null,
                      AllState.all => true,
                      AllState.none => false,
                    },
                    tristate: true,
                    onChanged: gallery.cycleAll,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Todos'),
                  ),
                ),
              ]),
              _section('Switch', [
                SwitchListTile(
                  value: gallery.dark.value,
                  onChanged: gallery.setDark,
                  title: const Text('Modo oscuro'),
                ),
                SwitchListTile(
                  value: gallery.sound.value,
                  onChanged: gallery.setSound,
                  title: const Text('Sonido'),
                ),
              ]),
              _section('Método de pago', [
                RadioGroup<String>(
                  groupValue: gallery.payment.value,
                  onChanged: gallery.setPayment,
                  name: 'payment',
                  child: Column(
                    children: [
                      for (final m in const [
                        'Efectivo',
                        'Tarjeta',
                        'Transferencia',
                      ])
                        RadioListTile<String>(
                          value: m,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(m),
                        ),
                    ],
                  ),
                ),
              ]),
              _section('Propina', [
                Slider(
                  value: gallery.tip.value.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 20,
                  onChanged: gallery.setTip,
                  semanticLabel: 'Propina',
                ),
                Watch(gallery.tipLabel),
              ]),
              _section('Sucursal', [
                DropdownButton<String>(
                  hint: 'Elige una sucursal',
                  value: gallery.branch.value,
                  onChanged: gallery.setBranch,
                  isExpanded: true,
                  semanticLabel: 'Sucursal',
                  items: [
                    for (final s in branches)
                      DropdownMenuItem(value: s, child: Text(s)),
                  ],
                ),
              ]),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Watch(gallery.summary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
