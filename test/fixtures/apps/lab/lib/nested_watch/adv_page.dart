import 'package:thor_ui/thor_ui.dart';

import 'adv_state.dart';

Widget _box(String id, Widget child) => Semantics(
  identifier: id,
  child: Column(children: [child]),
);

Widget _rows(Widget Function(List<Widget> rows) container) => Watch.list(
  adv.xs,
  itemKey: adv.xsKey,
  container: container,
  each: (row) => Row(children: [row.text(adv.xsName)]),
);

Widget _btn(String label, void Function() f) =>
    TextButton(onPressed: f, child: Text(label));

/// The harder cases of the Watch nestedWatch: deeper nesting, more container shapes.
class AdvSections extends StatelessWidget {
  const AdvSections({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        children: [
          _btn('l1', adv.toggleL1),
          _btn('l2', adv.toggleL2),
          _btn('l3', adv.toggleL3),
          _btn('o2', adv.toggleO2),
          _btn('five', adv.nextFive),
          _btn('o3', adv.toggleO3),
          _btn('same', adv.toggleSame),
          _btn('other', adv.toggleOther),
          _btn('o4', adv.toggleO4),
          _btn('addX', adv.addX),
          _btn('reverseX', adv.reverseX),
          _btn('dropFirstX', adv.dropFirstX),
          _btn('clearX', adv.clearX),
          _btn('resetX', adv.resetX),
          _btn('markX', adv.markLast),
          _btn('o5', adv.toggleO5),
          _btn('flag', adv.toggleFlag),
          _btn('k-label', other.nextLabel),
          _btn('k-mode', other.toggleMode),
          _btn('k-add', other.addItem),
        ],
      ),
      // Three levels.
      _box(
        'x-levels',
        Watch(
          adv.isL1,
          builder: (a) => a
              ? Column(
                  children: [
                    const Text('A1'),
                    Watch(
                      adv.isL2,
                      builder: (b) => b
                          ? Column(
                              children: [
                                const Text('B1'),
                                Watch(
                                  adv.isL3,
                                  builder: (c) => Text(c ? 'C1' : 'C0'),
                                ),
                              ],
                            )
                          : const Text('B0'),
                    ),
                  ],
                )
              : const Text('A0'),
        ),
      ),
      // An enum inside a variant; a and b draw the same.
      _box(
        'x-five',
        Watch(
          adv.isO2,
          builder: (on) => on
              ? Column(
                  children: [
                    const Text('O2'),
                    Watch(
                      adv.fiveOf,
                      builder: (f) => Text(switch (f) {
                        Five.a => 'same',
                        Five.b => 'same',
                        Five.c => 'three',
                        Five.d => 'four',
                        Five.e => 'five',
                      }),
                    ),
                  ],
                )
              : const Text('O2 off'),
        ),
      ),
      // Two watches that draw the same in both states.
      _box(
        'x-same',
        Watch(
          adv.isO3,
          builder: (on) => on
              ? Column(
                  children: [
                    const Text('O3'),
                    Watch(adv.isSame, builder: (s) => const Text('same')),
                    Watch(adv.isOther, builder: (s) => Text(s ? 'yes' : 'no')),
                  ],
                )
              : const Text('O3 off'),
        ),
      ),
      // A keyed list, with row states, inside a variant.
      _box(
        'x-list',
        Watch(
          adv.isO4,
          builder: (on) => on
              ? Column(
                  children: [
                    const Text('O4'),
                    Watch.list(
                      adv.xs,
                      itemKey: adv.xsKey,
                      each: (row) => Row(
                        children: [
                          row.text(adv.xsName),
                          row.watch(
                            adv.xsMarked,
                            builder: (m) => Text(m ? '*' : '.'),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : const Text('O4 off'),
        ),
      ),
      _box(
        'x-marked',
        Watch.list(
          adv.xs,
          itemKey: adv.xsKey,
          each: (row) => Row(
            children: [
              row.text(adv.xsName),
              row.watch(adv.xsMarked, builder: (m) => Text(m ? '*' : '.')),
            ],
          ),
        ),
      ),
      // A thousand watches inside a variant.
      _box(
        'x-many',
        Watch(
          adv.isO5,
          builder: (on) => on
              ? Column(
                  children: [
                    const Text('O5'),
                    for (var i = 0; i < 1000; i++)
                      Watch(adv.isFlag, builder: (f) => Text(f ? '1' : '0')),
                  ],
                )
              : const Text('O5 off'),
        ),
      ),
      // The rows of a list watch another state (a text and a variant).
      _box(
        'other-rows',
        Watch.list(
          adv.xs,
          itemKey: adv.xsKey,
          each: (row) => Row(
            children: [
              row.text(adv.xsName),
              Watch(other.labelOf),
              Watch(other.isMode, builder: (m) => Text(m ? 'on' : 'off')),
            ],
          ),
        ),
      ),
      // A row, a variant of another state, a keyed list, a text of it.
      _box(
        'row-lists',
        Watch.list(
          adv.xs,
          itemKey: adv.xsKey,
          each: (row) => Row(
            children: [
              row.text(adv.xsName),
              Watch(
                other.isMode,
                builder: (m) => m
                    ? Watch.list(
                        other.items,
                        itemKey: other.itemKey,
                        each: (r) => Row(
                          children: [
                            r.text(other.itemName),
                            Watch(other.labelOf),
                          ],
                        ),
                      )
                    : const Text('-'),
              ),
            ],
          ),
        ),
      ),
      // More shapes of container.
      _box(
        'x-nest',
        _rows(
          (rows) => Center(
            child: DecoratedBox(
              decoration: const BoxDecoration(color: Color(0xFFEEEEEE)),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(children: rows),
              ),
            ),
          ),
        ),
      ),
      _box(
        'x-headfoot',
        _rows(
          (rows) => Column(
            children: [const Text('head'), ...rows, const Text('foot')],
          ),
        ),
      ),
      _box(
        'x-head',
        _rows((rows) => Column(children: [const Text('head'), ...rows])),
      ),
      _box(
        'x-after',
        _rows(
          (rows) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(2),
                child: Column(children: rows),
              ),
              const Text('after'),
            ],
          ),
        ),
      ),
      _box('x-listview', _rows((rows) => ListView(children: rows))),
      _box('x-center2', _rows((rows) => Center(child: Column(children: rows)))),
    ],
  );
}
