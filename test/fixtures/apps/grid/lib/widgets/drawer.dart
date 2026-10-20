// The expanded record: every field of one launch, editable.
import 'package:thor_ui/thor_ui.dart';

import '../data.dart';
import '../grid_state.dart';
import '../icons.dart';
import '../ui.dart';

class RecordDrawer extends StatelessWidget implements ThorElementWidget {
  const RecordDrawer({super.key});

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Text(text, style: smallMuted),
  );

  Widget _text(
    TextEditingController controller,
    void Function(String) onChanged, {
    int lines = 1,
    TextInputType type = TextInputType.text,
    HtmlAttributes? attributes,
  }) => TextField(
    controller: controller,
    onChanged: onChanged,
    maxLines: lines,
    keyboardType: type,
    style: small,
    inputAttributes: attributes,
    decoration: const InputDecoration(
      border: OutlineInputBorder(),
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
  );

  Widget _choice(bool on, Widget child, void Function() onTap) => Gesture(
    onTap: onTap,
    semanticButton: false,
    child: Semantics(
      button: true,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          border: Border.all(
            color: on ? blue : const Color(0x00000000),
            width: 2,
          ),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: child,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Drawer(
    id: 'record',
    controller: grid.details,
    side: DrawerSide.end,
    width: 480,
    backgroundColor: surface,
    label: 'Expanded record',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Watch(
                  grid.drawerTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
              ),
              IconButton(
                onPressed: grid.closeDrawer,
                tooltip: 'Close',
                icon: Icon(closeIcon, size: 18, color: muted),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _label('Launch'),
                _text(grid.drawerName, grid.drawerSetName),
                _label('Status'),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (var i = 1; i < Status.values.length; i++)
                      Watch(
                        grid.drawerStatusIs.withArg(i),
                        builder: (bool on) => _choice(
                          on,
                          statusPill(Status.values[i]),
                          grid.drawerSetStatus.withArg(i),
                        ),
                      ),
                  ],
                ),
                _label('Platforms'),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final t in Tag.values)
                      Watch(
                        grid.drawerHasTag.withArg(t.index),
                        builder: (bool on) => _choice(
                          on,
                          tagPill(TagSlot.values[t.index + 1]),
                          grid.drawerToggleTag.withArg(t.index),
                        ),
                      ),
                  ],
                ),
                _label('Owner'),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (var i = 1; i < Person.values.length; i++)
                      Watch(
                        grid.drawerOwnerIs.withArg(i),
                        builder: (bool on) => _choice(
                          on,
                          personChip(Person.values[i]),
                          grid.drawerSetOwner.withArg(i),
                        ),
                      ),
                  ],
                ),
                _label('Launch date'),
                _text(
                  grid.drawerLaunch,
                  grid.drawerSetLaunch,
                  attributes: HtmlAttributes.custom({'type': 'date'}),
                ),
                _label('Budget (USD)'),
                _text(
                  grid.drawerBudget,
                  grid.drawerSetBudget,
                  type: TextInputType.number,
                ),
                _label('Progress (%)'),
                _text(
                  grid.drawerProgress,
                  grid.drawerSetProgress,
                  type: TextInputType.number,
                ),
                _label('Shipped'),
                Row(
                  children: [
                    Watch(
                      grid.drawerShipped,
                      builder: (bool on) => Checkbox(
                        value: on,
                        onChanged: grid.drawerSetShipped,
                        activeColor: blue,
                        semanticLabel: 'Shipped',
                      ),
                    ),
                  ],
                ),
                _label('Confidence'),
                Watch(
                  grid.drawerRating,
                  count: 6,
                  builder: (int n) => Row(
                    spacing: 2,
                    children: stars(n, grid.drawerRate.withArg),
                  ),
                ),
                _label('Page'),
                _text(
                  grid.drawerUrl,
                  grid.drawerSetUrl,
                  type: TextInputType.url,
                ),
                _label('Notes'),
                _text(grid.drawerNotes, grid.drawerSetNotes, lines: 4),
                _label('Files'),
                _text(
                  grid.drawerFiles,
                  grid.drawerSetFiles,
                  type: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
