import 'package:thor_ui/thor_ui.dart';

import 'list_box_state.dart';

const _languages = [
  ListBoxItem(value: 'es', child: Text('Español')),
  ListBoxItem(value: 'en', child: Text('English')),
  ListBoxItem(value: 'fr', child: Text('Français')),
  ListBoxItem(value: 'de', enabled: false, child: Text('Deutsch')),
];

const _toppings = [
  ListBoxItem(value: 'cheese', child: Text('Cheese')),
  ListBoxItem(value: 'ham', child: Text('Ham')),
  ListBoxItem(value: 'olives', child: Text('Olives')),
  ListBoxItem(value: 'pepper', child: Text('Pepper')),
];

/// `ListBox` (`<select size>`): 7GUIs' CRUD over `ListBox.list`, the
/// static lists of one value and several, a disabled one, and a form that
/// sends them with no JS (a GET, as the export is a static site).
class ListBoxPage extends StatelessWidget implements ThorElementWidget {
  /// The page.
  const ListBoxPage({super.key});

  @override
  Widget build(BuildContext context) => const Semantics(
    role: SemanticsRole.main,
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 24,
        children: [
          Semantics(headingLevel: 1, child: Text('ListBox')),
          _Crud(),
          _Picks(),
          _PlainForm(),
        ],
      ),
    ),
  );
}

/// A titled part of the page, its id for the checks.
class _Part extends StatelessWidget {
  const _Part({required this.id, required this.title, required this.child});

  final String id;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    identifier: id,
    role: SemanticsRole.region,
    label: title,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Semantics(headingLevel: 2, child: Text(title)),
        child,
      ],
    ),
  );
}

/// 7GUIs' CRUD: no hand-made rows, the list is the browser's.
class _Crud extends StatelessWidget {
  const _Crud();

  @override
  Widget build(BuildContext context) => _Part(
    id: 'crud',
    title: 'CRUD',
    child: SizedBox(
      width: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          TextField(
            onChanged: crud.setPrefix,
            decoration: const InputDecoration(labelText: 'Filter prefix'),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Expanded(
                child: ListBox.list(
                  crud.visible.call,
                  itemKey: crud.idOf,
                  itemLabel: crud.label,
                  selected: crud.selected,
                  onChanged: crud.select,
                  visibleItemCount: 6,
                  semanticLabel: 'People',
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: [
                    TextField(
                      controller: crud.name,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    TextField(
                      controller: crud.surname,
                      decoration: const InputDecoration(labelText: 'Surname'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: crud.create,
                child: const Text('Create'),
              ),
              Watch(
                crud.hasSelection,
                builder: (on) => OutlinedButton(
                  onPressed: on ? crud.update : null,
                  child: const Text('Update'),
                ),
              ),
              Watch(
                crud.hasSelection,
                builder: (on) => OutlinedButton(
                  onPressed: on ? crud.remove : null,
                  child: const Text('Delete'),
                ),
              ),
            ],
          ),
          Row(spacing: 16, children: [Watch(crud.count), Watch(crud.chosen)]),
        ],
      ),
    ),
  );
}

/// The static lists, reported to a state, and a disabled one.
class _Picks extends StatelessWidget {
  const _Picks();

  @override
  Widget build(BuildContext context) => _Part(
    id: 'picks',
    title: 'Static lists',
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            ListBox<String>(
              items: _languages,
              value: picks.language.value,
              onChanged: picks.setLanguage,
              semanticLabel: 'Language',
            ),
            Watch(picks.languageLabel),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            ListBox<String>(
              items: _toppings,
              multiSelectionEnabled: true,
              selected: picks.toppings.value,
              onSelectionChanged: picks.setToppings,
              semanticLabel: 'Toppings',
            ),
            Watch(picks.toppingsLabel),
          ],
        ),
        const ListBox<String>(
          items: _languages,
          value: 'es',
          onChanged: null,
          semanticLabel: 'Locked language',
        ),
      ],
    ),
  );
}

/// A form with the two kinds: the browser sends them with no JS.
class _PlainForm extends StatelessWidget {
  const _PlainForm();

  @override
  Widget build(BuildContext context) => const _Part(
    id: 'form',
    title: 'Form',
    child: Form(
      formMethod: FormMethod.get,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 16,
        children: [
          ListBox<String>(
            items: _languages,
            name: 'lang',
            value: 'es',
            semanticLabel: 'Form language',
          ),
          ListBox<String>(
            items: _toppings,
            name: 'top',
            multiSelectionEnabled: true,
            semanticLabel: 'Form toppings',
          ),
          FilledButton(
            buttonType: ButtonType.submit,
            onPressed: null,
            child: Text('Send'),
          ),
        ],
      ),
    ),
  );
}
