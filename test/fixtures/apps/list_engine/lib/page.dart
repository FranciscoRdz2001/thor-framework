import 'package:thor_ui/thor_ui.dart';

import 'list_state.dart';

class ListPage extends StatelessWidget implements ThorElementWidget {
  const ListPage({super.key});

  static const _border = BoxDecoration(
    border: Border.fromBorderSide(BorderSide(color: Color(0xFFCCCCCC))),
    borderRadius: BorderRadius.all(Radius.circular(4)),
  );

  Widget _button(String label, void Function() onTap) => Gesture(
    onTap: onTap,
    child: Semantics(
      button: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: _border,
        child: Text(label),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      role: SemanticsRole.main,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Semantics(
              headingLevel: 1,
              child: Text(
                'Lista',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _button('Crear 1,000', list.create),
                  _button('Crear 10,000', list.createMany),
                  _button('Agregar 1,000', list.append),
                  _button('Actualizar cada 10ª', list.update),
                  _button('Intercambiar', list.swap),
                  _button('Quitar primera', list.removeFirst),
                  _button('Limpiar', list.clear),
                ],
              ),
            ),
            Watch.list(
              list.rows,
              itemKey: list.rowKey,
              container: (rows) => Semantics(
                role: SemanticsRole.list,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: rows,
                ),
              ),
              each: (row) => Semantics(
                role: SemanticsRole.listItem,
                child: row.watch(
                  list.isSelected,
                  builder: (selected) => Container(
                    constraints: const BoxConstraints(minHeight: 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFFFE9A8) : null,
                      border: const Border(
                        bottom: BorderSide(color: Color(0xFFEEEEEE)),
                      ),
                    ),
                    child: Row(
                      spacing: 8,
                      children: [
                        SizedBox(
                          width: 48,
                          child: row.text(
                            list.rowId,
                            style: const TextStyle(color: Color(0xFF666666)),
                          ),
                        ),
                        Expanded(
                          child: Gesture(
                            onTap: list.select.withArg(row.key),
                            semanticButton: false,
                            child: row.text(list.rowLabel),
                          ),
                        ),
                        Gesture(
                          onTap: list.remove.withArg(row.key),
                          semanticButton: false,
                          child: const Semantics(
                            label: 'Quitar',
                            button: true,
                            child: Container(child: Text('×')),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
