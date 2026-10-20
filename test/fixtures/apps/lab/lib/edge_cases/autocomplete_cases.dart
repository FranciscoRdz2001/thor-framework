import 'package:thor_ui/thor_ui.dart';

import 'autocomplete_state.dart';

const _fruits = ['apple', 'apricot', 'banana', 'blueberry', 'cherry'];

/// `Autocomplete` with static options, and a `RawAutocomplete` whose panel
/// shows a state's list, both inside a clipping box with a later sibling
/// that would cover a plain dropdown (autocomplete check).
class AutocompleteCases extends StatelessWidget {
  const AutocompleteCases({super.key});

  @override
  Widget build(BuildContext context) => Form(
    formMethod: FormMethod.get,
    child: Column(
      spacing: 16,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Autocomplete<String>(
          semanticLabel: 'Fruit',
          optionsBuilder: (value) =>
              _fruits.where((f) => f.contains(value.text.toLowerCase())),
          onSelected: autocomplete.pick,
        ),
        Watch(autocomplete.pickedLabel),
        // A box that clips, and what comes after it: the panel must still
        // show whole and above both.
        Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            SizedBox(
              height: 40,
              child: RawAutocomplete<String>(
                optionsBuilder: (value) => const <String>[],
                fieldViewBuilder: (context, controller, focus, submit) =>
                    TextField(
                      controller: controller,
                      focusNode: focus,
                      name: 'q',
                      decoration: const InputDecoration(hintText: 'Search'),
                      onChanged: autocomplete.search,
                    ),
                optionsViewBuilder: (context, onSelected, options) => Container(
                  color: Colors.white,
                  child: Watch.list(
                    autocomplete.suggestions,
                    itemKey: autocomplete.nameOf,
                    each: (row) => Semantics(
                      role: SemanticsRole.option,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        child: row.text(autocomplete.nameOf),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const Styled(
          classes: ['ac-later'],
          style: StyleProps(position: BoxPosition.relative(), zIndex: 50),
          child: Container(
            height: 60,
            color: Colors.teal,
            child: Text('later sibling'),
          ),
        ),
        FilledButton(
          onPressed: () {},
          buttonType: ButtonType.submit,
          child: const Text('Send'),
        ),
      ],
    ),
  );
}

/// An `Autocomplete` in each row of a live list: one panel id per row, also
/// for the rows the browser adds (autocomplete check).
class AutocompleteRows extends StatelessWidget {
  const AutocompleteRows({super.key});

  @override
  Widget build(BuildContext context) => Column(
    spacing: 8,
    children: [
      Watch.list(
        autocomplete.rows,
        itemKey: autocomplete.nameOf,
        each: (row) => Autocomplete<String>(
          key: ValueKey(row.key),
          semanticLabel: 'Row fruit',
          optionsBuilder: (value) => _fruits,
        ),
      ),
      OutlinedButton(
        onPressed: autocomplete.addRow,
        child: const Text('Add row'),
      ),
    ],
  );
}
