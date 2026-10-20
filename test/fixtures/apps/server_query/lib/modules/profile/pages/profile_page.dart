import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../state/profile_state.dart';

/// `/profile`: no `load` — the state's queries bring the data.
class ProfilePage extends ThorPage<void> {
  const ProfilePage();

  @override
  PageMeta meta(PageState<void> state) => const PageMeta(title: 'Perfil');

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 16,
    children: [
      Watch(profile.name, style: const TextStyle(fontSize: 24)),
      Watch(profile.email),
      Row(
        spacing: 12,
        children: [
          Watch(profile.visits),
          Watch(
            profile.busy,
            builder: (busy) => Semantics(
              label: 'estado del perfil',
              child: Text(busy ? 'Cargando…' : 'Al día'),
            ),
          ),
          FilledButton(
            onPressed: profile.info.refresh,
            child: const Text('Recargar perfil'),
          ),
        ],
      ),
      const Text('Pedidos'),
      Watch.list(
        profile.rows,
        itemKey: profile.orderKey,
        each: (row) => row.text(profile.orderText),
      ),
      Row(
        spacing: 12,
        children: [
          Watch(
            profile.firstPage,
            builder: (first) => OutlinedButton(
              onPressed: first ? null : profile.previousPage,
              child: const Text('Anterior'),
            ),
          ),
          Watch(profile.pageLabel),
          OutlinedButton(
            onPressed: profile.nextPage,
            child: const Text('Siguiente'),
          ),
          Watch(
            profile.ordersBusy,
            builder: (busy) => Text(busy ? 'Cargando pedidos…' : ''),
          ),
        ],
      ),
      Row(
        spacing: 12,
        children: [
          const Text('Libro contable:'),
          Watch(
            profile.ledgerFailed,
            builder: (failed) => Semantics(
              label: 'libro contable',
              child: failed
                  ? Watch(
                      profile.ledgerText,
                      style: const TextStyle(color: Color(0xFFB3261E)),
                    )
                  : Watch(profile.ledgerText),
            ),
          ),
          TextButton(
            onPressed: profile.ledger.refresh,
            child: const Text('Reintentar'),
          ),
        ],
      ),
      Row(
        spacing: 12,
        children: [
          TextButton(
            onPressed: profile.toggleEditing,
            child: const Text('Editar'),
          ),
          Watch(
            profile.isEditing,
            builder: (on) =>
                Text(on ? 'Editando (estado del navegador)' : 'Sin editar'),
          ),
        ],
      ),
    ],
  );
}
