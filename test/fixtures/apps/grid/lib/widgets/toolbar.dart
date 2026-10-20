// The base's top bar and the view's toolbar (hide, filter, group, sort,
// row height, search) with their popovers.
import 'package:thor_ui/thor_ui.dart';

import '../data.dart';
import '../grid_state.dart';
import '../icons.dart';
import '../ui.dart';
import '../view.dart';

class TopBar extends StatelessWidget implements ThorElementWidget {
  const TopBar({super.key});

  Widget _tab(String text, {bool active = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: active ? surface : null,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        color: active ? ink : const Color(0xFFE8EEFF),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Semantics(
    role: SemanticsRole.header,
    child: Container(
      color: const Color(0xFF2D5BD8),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 16,
        runSpacing: 4,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                Icon(baseIcon, size: 20, color: surface),
                const Semantics(
                  headingLevel: 1,
                  child: Text(
                    'Launch HQ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: surface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            role: SemanticsRole.navigation,
            label: 'Tables',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _tab('Launches', active: true),
                _tab('Roadmap'),
                _tab('Feedback'),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// The row under the top bar: view switcher, view tools, search.
class ViewToolbar extends StatelessWidget implements ThorElementWidget {
  const ViewToolbar({super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: const BoxDecoration(
      color: surface,
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        _viewSwitcher(),
        _popover(
          'hide',
          Watch(
            grid.hasHidden,
            builder: (bool on) =>
                buttonFace(eyeOff, Watch(grid.hiddenLabel), active: on),
          ),
          const _HidePanel(),
        ),
        _popover(
          'filter',
          Watch(
            grid.isFiltered,
            builder: (bool on) =>
                buttonFace(filterIcon, Watch(grid.filterLabel), active: on),
          ),
          const _FilterPanel(),
          minWidth: 540,
        ),
        _popover(
          'group',
          Watch(
            grid.isGrouped,
            builder: (bool on) =>
                buttonFace(groupIcon, Watch(grid.groupLabel), active: on),
          ),
          const _GroupPanel(),
        ),
        _popover(
          'sort',
          Watch(
            grid.isSorted,
            builder: (bool on) =>
                buttonFace(sortIcon, Watch(grid.sortLabel), active: on),
          ),
          const _SortPanel(),
          minWidth: 300,
        ),
        _popover(
          'height',
          buttonFace(rowsIcon, const Text('Row height')),
          minWidth: 180,
          menuPanel(
            children: [
              for (final h in RowHeight.values)
                Watch(
                  grid.isRowHeight.withArg(h),
                  builder: (bool on) => menuItem(
                    Row(
                      spacing: 8,
                      children: [
                        Opacity(
                          opacity: on ? 1 : 0,
                          child: Icon(checkIcon, size: 14, color: blue),
                        ),
                        Text(h.label),
                      ],
                    ),
                    onTap: grid.setRowHeight.withArg(h.name),
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: grid.undo,
          tooltip: 'Undo (⌘Z)',
          icon: Icon(undoIcon, size: 16, color: muted),
        ),
        IconButton(
          onPressed: grid.redo,
          tooltip: 'Redo (⇧⌘Z)',
          icon: Icon(redoIcon, size: 16, color: muted),
        ),
        const _SearchBox(),
      ],
    ),
  );

  Widget _viewSwitcher() => _popover(
    'views',
    buttonFace(
      gridIcon,
      const Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Text('Grid view'),
          Text('▾', style: smallMuted),
        ],
      ),
      active: true,
    ),
    minWidth: 200,
    menuPanel(
      children: [
        menuItem(
          Row(
            spacing: 8,
            children: [
              Icon(gridIcon, size: 14, color: blue),
              const Expanded(child: Text('Grid view')),
              Icon(checkIcon, size: 14, color: blue),
            ],
          ),
          onTap: grid.escape,
        ),
        for (final v in const ['Kanban', 'Calendar', 'Gallery', 'Form'])
          Opacity(
            opacity: 0.5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text('$v · soon', style: small),
            ),
          ),
      ],
    ),
  );
}

/// A toolbar popover: [panel] in the app's menu look, at least [minWidth]
/// wide.
Widget _popover(
  String id,
  Widget trigger,
  Widget panel, {
  double minWidth = 260,
}) => Popover(
  id: 'pop-$id',
  trigger: trigger,
  decoration: menuDecoration,
  menuPadding: const EdgeInsets.all(12),
  constraints: BoxConstraints(minWidth: minWidth, maxWidth: 560),
  child: panel,
);

class _HidePanel extends StatelessWidget implements ThorElementWidget {
  const _HidePanel();

  @override
  Widget build(BuildContext context) => menuPanel(
    children: [
      const Text('Fields in this view', style: smallMuted),
      for (final f in GridField.values.skip(1))
        Watch(
          grid.isShown.withArg(f.index),
          builder: (bool on) => SwitchListTile(
            value: on,
            onChanged: grid.setShown.withArg(f.index),
            title: Text(f.label, style: small),
          ),
        ),
      TextButton(onPressed: grid.showAll, child: const Text('Show all')),
    ],
  );
}

class _FilterPanel extends StatelessWidget implements ThorElementWidget {
  const _FilterPanel();

  List<DropdownMenuItem<String>> get _fieldItems => [
    for (final f in GridField.values)
      DropdownMenuItem(value: f.name, child: Text(f.label)),
  ];

  Widget _slot(int slot) => Watch(
    grid.filterActive.withArg(slot),
    builder: (bool on) => Offstage(
      offstage: !on,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 64,
            child: slot == 0
                ? const Text('Where', style: small)
                : slot == 1
                ? Watch(
                    grid.anyMode,
                    builder: (bool any) => DropdownButton<String>(
                      value: any ? 'or' : 'and',
                      semanticLabel: 'And or or',
                      onChanged: grid.setMatchAny,
                      items: const [
                        DropdownMenuItem(value: 'and', child: Text('and')),
                        DropdownMenuItem(value: 'or', child: Text('or')),
                      ],
                    ),
                  )
                : Watch(
                    grid.anyMode,
                    builder: (bool any) =>
                        Text(any ? 'or' : 'and', style: small),
                  ),
          ),
          Watch(
            grid.filterField.withArg(slot),
            builder: (GridField f) => DropdownButton<String>(
              value: f.name,
              semanticLabel: 'Field',
              onChanged: grid.setFilterField.withArg(slot),
              items: _fieldItems,
            ),
          ),
          Watch(
            grid.filterFamily.withArg(slot),
            builder: (OpFamily family) {
              final ops = opsFor(switch (family) {
                OpFamily.text => FieldKind.text,
                OpFamily.choice => FieldKind.select,
                OpFamily.multi => FieldKind.multi,
                OpFamily.date => FieldKind.date,
                OpFamily.number => FieldKind.currency,
                OpFamily.check => FieldKind.checkbox,
              });
              return Watch(
                grid.filterOp.withArg(slot),
                count: 5,
                builder: (int i) => DropdownButton<String>(
                  value: ops[i.clamp(0, ops.length - 1)].name,
                  semanticLabel: 'Operator',
                  onChanged: grid.setFilterOp.withArg(slot),
                  items: [
                    for (final op in ops)
                      DropdownMenuItem(value: op.name, child: Text(op.label)),
                  ],
                ),
              );
            },
          ),
          Watch(
            grid.filterTakesValue.withArg(slot),
            builder: (bool takes) => Offstage(
              offstage: !takes,
              child: SizedBox(
                width: 150,
                child: TextField(
                  controller: switch (slot) {
                    0 => grid.filterValue0,
                    1 => grid.filterValue1,
                    2 => grid.filterValue2,
                    _ => grid.filterValue3,
                  },
                  onChanged: grid.setFilterValue.withArg(slot),
                  style: small,
                  decoration: const InputDecoration(
                    hintText: 'Enter a value',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: grid.removeFilter.withArg(slot),
            tooltip: 'Remove condition',
            icon: Icon(closeIcon, size: 14, color: muted),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => menuPanel(
    children: [
      const Text('In this view, show records', style: smallMuted),
      for (var i = 0; i < maxFilters; i++) _slot(i),
      Row(
        children: [
          TextButton(
            onPressed: grid.addFilter,
            child: const Text('+ Add condition'),
          ),
        ],
      ),
    ],
  );
}

class _SortPanel extends StatelessWidget implements ThorElementWidget {
  const _SortPanel();

  Widget _slot(int slot) => Watch(
    grid.sortActive.withArg(slot),
    builder: (bool on) => Offstage(
      offstage: !on,
      child: Row(
        spacing: 6,
        children: [
          Watch(
            grid.sortField.withArg(slot),
            builder: (GridField f) => DropdownButton<String>(
              value: f.name,
              semanticLabel: 'Sort field',
              onChanged: grid.setSortField.withArg(slot),
              items: [
                for (final g in GridField.values)
                  DropdownMenuItem(value: g.name, child: Text(g.label)),
              ],
            ),
          ),
          Watch(
            grid.sortDescending.withArg(slot),
            builder: (bool desc) => DropdownButton<String>(
              value: desc ? 'desc' : 'asc',
              semanticLabel: 'Direction',
              onChanged: grid.setSortDirection.withArg(slot),
              items: const [
                DropdownMenuItem(value: 'asc', child: Text('A → Z')),
                DropdownMenuItem(value: 'desc', child: Text('Z → A')),
              ],
            ),
          ),
          if (slot > 0)
            IconButton(
              onPressed: grid.moveSortUp.withArg(slot),
              tooltip: 'Move up',
              icon: Icon(chevronUp, size: 14, color: muted),
            ),
          IconButton(
            onPressed: grid.removeSort.withArg(slot),
            tooltip: 'Remove sort',
            icon: Icon(closeIcon, size: 14, color: muted),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => menuPanel(
    children: [
      const Text('Sort by', style: smallMuted),
      for (var i = 0; i < maxSorts; i++) _slot(i),
      Row(
        children: [
          TextButton(onPressed: grid.addSort, child: const Text('+ Add sort')),
        ],
      ),
    ],
  );
}

class _GroupPanel extends StatelessWidget implements ThorElementWidget {
  const _GroupPanel();

  @override
  Widget build(BuildContext context) => menuPanel(
    children: [
      const Text('Group by', style: smallMuted),
      Watch(
        grid.groupIndex,
        count: groupChoices.length,
        builder: (int i) => DropdownButton<String>(
          value: groupChoices[i]?.name ?? '',
          isExpanded: true,
          semanticLabel: 'Group field',
          onChanged: grid.setGroup,
          items: [
            for (final f in groupChoices)
              DropdownMenuItem(
                value: f?.name ?? '',
                child: Text(f?.label ?? 'None'),
              ),
          ],
        ),
      ),
      Row(
        spacing: 8,
        children: [
          TextButton(
            onPressed: grid.collapseAll,
            child: const Text('Collapse all'),
          ),
          TextButton(
            onPressed: grid.expandAll,
            child: const Text('Expand all'),
          ),
        ],
      ),
    ],
  );
}

class _SearchBox extends StatelessWidget implements ThorElementWidget {
  const _SearchBox();

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.enter): grid.nextMatch,
      const SingleActivator(LogicalKeyboardKey.enter, shift: true):
          grid.previousMatch,
      const SingleActivator(LogicalKeyboardKey.escape): grid.clearSearch,
    },
    // Without JavaScript the box is a GET form: the server renders the
    // view with the search from the URL.
    child: Form(
      action: '/',
      formMethod: FormMethod.get,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Icon(searchIcon, size: 14, color: muted),
          SizedBox(
            width: 180,
            child: TextField(
              name: 'q',
              controller: grid.searchBox,
              onChanged: grid.setSearch,
              keyboardType: TextInputType.webSearch,
              style: small,
              decoration: const InputDecoration(
                hintText: 'Find in view',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
              ),
            ),
          ),
          Watch(grid.searchCount, style: smallMuted),
          Watch(
            grid.isSearching,
            builder: (bool on) => Offstage(
              offstage: !on,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: grid.previousMatch,
                    tooltip: 'Previous match',
                    icon: Icon(chevronUp, size: 14, color: muted),
                  ),
                  IconButton(
                    onPressed: grid.nextMatch,
                    tooltip: 'Next match',
                    icon: Icon(chevronDown, size: 14, color: muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Shown while rows are checked: set their status, delete them.
class BulkBar extends StatelessWidget implements ThorElementWidget {
  const BulkBar({super.key});

  @override
  Widget build(BuildContext context) => Watch(
    grid.hasChecked,
    builder: (bool on) => Offstage(
      offstage: !on,
      child: Container(
        color: blueTint,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Watch(grid.checkedLabel, style: label),
            _popover(
              'bulk-status',
              buttonFace(fieldIcons['select']!, const Text('Set status')),
              minWidth: 160,
              menuPanel(
                children: [
                  for (var i = 1; i < Status.values.length; i++)
                    menuItem(
                      Row(children: [statusPill(Status.values[i])]),
                      onTap: grid.bulkStatus.withArg(i),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: grid.bulkDelete,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [Icon(trashIcon, size: 14), const Text('Delete')],
              ),
            ),
            TextButton(
              onPressed: grid.clearChecked,
              child: const Text('Clear selection'),
            ),
          ],
        ),
      ),
    ),
  );
}
