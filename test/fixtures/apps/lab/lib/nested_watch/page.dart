import 'package:thor_ui/thor_ui.dart';

import 'adv_page.dart';
import 'nested_watch_state.dart';

Widget _rowsWatch(Widget Function(List<Widget> rows) container) => Watch.list(
  nestedWatch.items,
  itemKey: nestedWatch.itemKey,
  container: container,
  each: (row) => Row(children: [row.text(nestedWatch.itemName)]),
);

Widget _section(String id, String title, Widget child) => Semantics(
  identifier: id,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [Text(title), child],
  ),
);

/// An app component that builds the real container.
class _Panel extends StatelessWidget {
  const _Panel(this.rows);
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    child: Column(children: rows),
  );
}

/// One section per gap.
class NestedWatchPage extends StatelessWidget implements ThorElementWidget {
  const NestedWatchPage({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // A Watch inside the variant of another Watch.
      _section(
        'nested-watch',
        'Nested Watch',
        Column(
          children: [
            Row(
              children: [
                TextButton(
                  onPressed: nestedWatch.toggleOuter,
                  child: const Text('toggle outer'),
                ),
                TextButton(
                  onPressed: nestedWatch.toggleInner,
                  child: const Text('toggle inner'),
                ),
                TextButton(
                  onPressed: nestedWatch.toggleSecond,
                  child: const Text('toggle second'),
                ),
              ],
            ),
            Watch(
              nestedWatch.isOuter,
              builder: (outer) => outer
                  ? Column(
                      children: [
                        const Text('outer on'),
                        Watch(
                          nestedWatch.isInner,
                          builder: (inner) =>
                              Text(inner ? 'inner on' : 'inner off'),
                        ),
                        Watch(
                          nestedWatch.isSecond,
                          builder: (s) => Text(s ? 'second on' : 'second off'),
                        ),
                      ],
                    )
                  : const Text('outer off'),
            ),
          ],
        ),
      ),
      // Containers that wrap the real container.
      TextButton(onPressed: nestedWatch.addItem, child: const Text('add item')),
      TextButton(
        onPressed: nestedWatch.clearItems,
        child: const Text('clear items'),
      ),
      _section(
        'list-column',
        'column',
        _rowsWatch((rows) => Column(children: rows)),
      ),
      _section('list-wrap', 'wrap', _rowsWatch((rows) => Wrap(children: rows))),
      _section(
        'list-padded',
        'padded',
        _rowsWatch(
          (rows) => Padding(
            padding: const EdgeInsets.all(4),
            child: Column(children: rows),
          ),
        ),
      ),
      _section(
        'list-container',
        'container',
        _rowsWatch(
          (rows) => Container(
            padding: const EdgeInsets.all(4),
            child: Column(children: rows),
          ),
        ),
      ),
      _section(
        'list-semantics',
        'semantics',
        _rowsWatch(
          (rows) => Semantics(
            role: SemanticsRole.list,
            child: Column(children: rows),
          ),
        ),
      ),
      _section(
        'list-sized',
        'sized',
        _rowsWatch(
          (rows) => SizedBox(width: 200, child: Column(children: rows)),
        ),
      ),
      _section(
        'list-card',
        'card',
        _rowsWatch((rows) => Card(child: Column(children: rows))),
      ),
      _section(
        'list-center',
        'center',
        _rowsWatch((rows) => Center(child: Column(children: rows))),
      ),
      _section(
        'list-scroll',
        'scroll',
        _rowsWatch(
          (rows) => SingleChildScrollView(child: Column(children: rows)),
        ),
      ),
      _section('list-component', 'component', _rowsWatch(_Panel.new)),
      _section(
        'list-decorated',
        'decorated',
        _rowsWatch(
          (rows) => DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xFFEEEEEE)),
            child: Column(children: rows),
          ),
        ),
      ),
      _section(
        'list-listview',
        'listview',
        _rowsWatch((rows) => ListView(children: rows)),
      ),
      // A date dialog inside a form.
      _section(
        'date-in-form',
        'Date in a form',
        Form(
          formMethod: FormMethod.post,
          action: '/sent',
          child: Column(
            children: [
              DialogTrigger(
                id: 'due',
                child: OutlinedButton(
                  onPressed: () {},
                  child: const Text('Elegir fecha'),
                ),
              ),
              Watch(nestedWatch.pickedLabel),
              DatePickerDialog(
                id: 'due',
                firstDate: DateTime(2026),
                lastDate: DateTime(2027, 12, 31),
                currentDate: DateTime(2026, 9, 20),
                onDatePicked: nestedWatch.setPicked,
              ),
              FilledButton(
                buttonType: ButtonType.submit,
                onPressed: () {},
                child: const Text('Enviar'),
              ),
            ],
          ),
        ),
      ),
      // A variant that changes the position.
      _section(
        'position-variant',
        'Position variant',
        Styled(
          style:
              StyleProps(
                position: BoxPosition.fixed(left: 40.px, top: 300.px),
              ).when(
                medium: StyleProps(position: BoxPosition.sticky(top: 0.px)),
              ),
          child: const Text('position box'),
        ),
      ),
      // A field with an icon vs one without.
      _section(
        'field-icons',
        'Field icons',
        const Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'plain',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            TextField(
              decoration: InputDecoration(
                hintText: 'with icon',
                isDense: true,
                border: OutlineInputBorder(),
                prefixIcon: Icon(IconData.svg('x', '<path d="M0 0"/>')),
              ),
            ),
            TextField(
              decoration: InputDecoration(
                hintText: 'icon by its size',
                isDense: true,
                border: OutlineInputBorder(),
                prefixIcon: Icon(IconData.svg('x', '<path d="M0 0"/>')),
                prefixIconConstraints: BoxConstraints(),
                suffixIcon: Icon(IconData.svg('x', '<path d="M0 0"/>')),
                suffixIconConstraints: BoxConstraints(),
              ),
            ),
          ],
        ),
      ),
      const AdvSections(),
    ],
  );
}
