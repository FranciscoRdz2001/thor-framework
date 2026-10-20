import 'package:thor_ui/thor_ui.dart';

import 'menu_state.dart';

const _fruits = [
  ('apple', 'Apple'),
  ('apricot', 'Apricot'),
  ('banana', 'Banana'),
  ('blueberry', 'Blueberry'),
  ('cherry', 'Cherry'),
  ('grape', 'Grape'),
];

// A neutral zinc palette and Lucide icons: a searchable select.
const _border = Color(0xFFE4E4E7);
const _muted = Color(0xFF71717A);
const _accent = Color(0xFFF4F4F5);
const _chevron = IconData.svg(
  'lucide-chevron-down',
  '<path d="m6 9 6 6 6-6"/>',
  strokeWidth: 2,
);
const _check = IconData.svg(
  'lucide-check',
  '<path d="M20 6 9 17l-5-5"/>',
  strokeWidth: 2,
);
const _search = IconData.svg(
  'lucide-search',
  '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>',
  strokeWidth: 2,
);
const _radius = BorderRadius.all(Radius.circular(6));
const _chevronIcon = Opacity(opacity: 0.5, child: Icon(_chevron, size: 16));

/// A Material `DropdownMenu` bound to a state, and one styled like
/// A searchable select, inside a GET form (the no-JS path).
class DropdownMenus extends StatelessWidget implements ThorElementWidget {
  const DropdownMenus({super.key});

  @override
  Widget build(BuildContext context) => Form(
    formMethod: FormMethod.get,
    child: Column(
      spacing: 16,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownMenu<String>(
          name: 'fruit',
          label: const Text('Fruit'),
          initialSelection: 'banana',
          onSelected: menu.setFruit,
          helperText: 'Type a letter to jump to it',
          dropdownMenuEntries: [
            for (final (value, label) in _fruits)
              DropdownMenuEntry(
                value: value,
                label: label,
                enabled: value != 'grape',
              ),
          ],
        ),
        Watch(menu.fruitLabel),
        DropdownMenu<String>(
          name: 'color',
          width: 200,
          hintText: 'Select a color',
          enableFilter: true,
          alignmentOffset: const Offset(0, 4),
          textStyle: const TextStyle(fontSize: 14),
          trailingIcon: _chevronIcon,
          selectedTrailingIcon: _chevronIcon,
          inputDecorationTheme: const InputDecorationTheme(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            constraints: BoxConstraints.tightFor(height: 40),
            hintStyle: TextStyle(color: _muted),
            border: OutlineInputBorder(
              borderRadius: _radius,
              borderSide: BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: _radius,
              borderSide: BorderSide(color: _border),
            ),
          ),
          menuStyle: const MenuStyle(
            backgroundColor: Colors.white,
            padding: EdgeInsets.all(4),
            side: BorderSide(color: _border),
            shape: RoundedRectangleBorder(borderRadius: _radius),
            shadows: [
              BoxShadow(
                color: Color(0x1A000000),
                offset: Offset(0, 4),
                blurRadius: 6,
                spreadRadius: -1,
              ),
              BoxShadow(
                color: Color(0x1A000000),
                offset: Offset(0, 2),
                blurRadius: 4,
                spreadRadius: -2,
              ),
            ],
          ),
          searchDecoration: const InputDecoration(
            hintText: 'Search…',
            prefixIcon: Icon(_search, size: 16, color: _muted),
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: _border),
            ),
          ),
          dropdownMenuEntries: [
            for (final c in ['Red', 'Green', 'Blue', 'Yellow', 'Purple'])
              DropdownMenuEntry(
                value: c.toLowerCase(),
                label: c,
                leadingIcon: const DropdownMenuSelectedIcon(
                  child: Icon(_check, size: 16),
                ),
                style: const ButtonStyle(
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  minimumSize: WidgetStatePropertyAll(Size(0, 0)),
                  overlayColor: WidgetStatePropertyAll(_accent),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                  textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 14)),
                ),
              ),
          ],
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
