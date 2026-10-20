import 'package:thor_ui/thor_ui.dart';

import 'content_state.dart';

const _bell = IconData.svg(
  'lucide-bell',
  '<path d="M10.268 21a2 2 0 0 0 3.464 0"/><path d="M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326"/>',
  strokeWidth: 2,
);

class Content extends StatelessWidget implements ThorElementWidget {
  const Content({super.key});

  static const _h2 = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);

  Widget _h(String t) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Semantics(headingLevel: 2, child: Text(t, style: _h2)),
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
                  'Contenido',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
              ),
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, n, s) in [
                      ('AN', 'Ana', 'Cajera · Turno matutino'),
                      ('LU', 'Luis', 'Mesero · Turno vespertino'),
                      ('MA', 'María', 'Gerente'),
                    ])
                      ListTile(
                        leading: CircleAvatar(child: Text(i)),
                        title: Text(n),
                        subtitle: Text(s),
                      ),
                  ],
                ),
              ),
              _h('Categorías'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < categories.length; i++)
                    Watch(
                      content.chipSelected.withArg(i),
                      builder: (selected) => FilterChip(
                        label: Text(categories[i]),
                        selected: selected,
                        onSelected: content.setChip.withArg(i),
                      ),
                    ),
                ],
              ),
              _h('Preguntas'),
              const ExpansionPanelList(
                name: 'faq',
                children: [
                  ExpansionTile(
                    title: Text('¿Horario?'),
                    children: [Text('9:00 a 18:00')],
                  ),
                  ExpansionTile(
                    title: Text('¿Envíos?'),
                    initiallyExpanded: true,
                    children: [Text('Sí, a toda la ciudad')],
                  ),
                  ExpansionTile(
                    title: Text('¿Pagos?'),
                    children: [Text('Efectivo y tarjeta')],
                  ),
                ],
              ),
              _h('Progreso'),
              const LinearProgressIndicator(
                value: 0.4,
                semanticsLabel: 'Cargando',
              ),
              const SizedBox(height: 12),
              const LinearProgressIndicator(semanticsLabel: 'Sincronizando'),
              const SizedBox(height: 12),
              const Row(
                children: [
                  CircularProgressIndicator(semanticsLabel: 'Procesando'),
                ],
              ),
              _h('Notificaciones'),
              const Row(
                children: [Badge(label: Text('3'), child: Icon(_bell))],
              ),
              _h('Acciones'),
              Row(
                spacing: 8,
                children: [
                  PopupMenuButton(
                    id: 'more',
                    tooltip: 'Más opciones',
                    onSelected: content.pick,
                    items: const [
                      PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(value: 'copy', child: Text('Duplicar')),
                      PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                    ],
                    child: const Text('⋮'),
                  ),
                  DialogTrigger(
                    id: 'sheet',
                    child: OutlinedButton(
                      onPressed: () {},
                      child: const Text('Opciones'),
                    ),
                  ),
                ],
              ),
              ModalBottomSheet(
                id: 'sheet',
                label: 'Opciones de la orden',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ListTile(title: Text('Dividir cuenta')),
                    const ListTile(title: Text('Agregar nota')),
                    DialogClose(
                      id: 'sheet',
                      child: TextButton(
                        onPressed: () {},
                        child: const Text('Cerrar'),
                      ),
                    ),
                  ],
                ),
              ),
              Watch(
                content.snackVisible,
                builder: (visible) => SnackBar(
                  visible: visible,
                  content: Watch(content.snackText),
                ),
              ),
              _h('Acceso'),
              Form(
                action: '/login',
                onSubmit: content.login,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: [
                    TextFormField(
                      name: 'email',
                      onChanged: content.setEmail,
                      autofillHints: [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Correo',
                        helperText: 'El de tu trabajo',
                        border: OutlineInputBorder(),
                      ),
                      validators: const [
                        Validator.required('Escribe tu correo'),
                        Validator.email('Ese correo no es válido'),
                      ],
                    ),
                    const TextFormField(
                      name: 'password',
                      obscureText: true,
                      autofillHints: [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        border: OutlineInputBorder(),
                      ),
                      validators: [
                        Validator.required('Escribe tu contraseña'),
                        Validator.minLength(8, 'Mínimo 8 caracteres'),
                      ],
                    ),
                    Row(
                      children: [
                        FilledButton(
                          buttonType: ButtonType.submit,
                          onPressed: () {},
                          child: const Text('Entrar'),
                        ),
                      ],
                    ),
                    Watch(content.welcomeText),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  DialogTrigger(
                    id: 'confirm',
                    // web: opened by `commandfor` (no Dart callback).
                    child: FilledButton(
                      onPressed: () {},
                      child: const Text('Cobrar'),
                    ),
                  ),
                ],
              ),
              AlertDialog(
                id: 'confirm',
                title: const Semantics(
                  headingLevel: 2,
                  child: Text('¿Cobrar \$187.00?'),
                ),
                content: const Semantics(
                  role: SemanticsRole.paragraph,
                  child: Text('Se registrará en el turno actual.'),
                ),
                actions: [
                  DialogClose(
                    id: 'confirm',
                    child: TextButton(
                      onPressed: () {},
                      child: const Text('Cancelar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
