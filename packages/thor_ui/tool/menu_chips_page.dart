// The page of the `menu-chips` browser check: a MenuAnchor with button,
// link, disabled and submenu items, and the chips that navigate or delete,
// rendered by the real widgets.
//
//   dart run packages/thor_ui/tool/menu_chips_page.dart <out.html>
import 'dart:io';

import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main(List<String> args) async {
  initializeThorTests();
  void noop() {}
  final body = Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      spacing: 24,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MenuAnchor(
          id: 'account-menu',
          builder: (context, controller, child) => TextButton(
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
            child: const Text('Account'),
          ),
          menuChildren: [
            const MenuItemButton(
              href: '/target.html',
              leadingIcon: Icon(Icons.list),
              child: Text('Orders'),
            ),
            MenuItemButton(onPressed: noop, child: const Text('Share')),
            const MenuItemButton(child: Text('Disabled')),
            SubmenuButton(
              id: 'more-menu',
              menuChildren: [
                MenuItemButton(onPressed: noop, child: const Text('Export')),
                const MenuItemButton(href: '#help', child: Text('Help')),
              ],
              child: const Text('More'),
            ),
            MenuItemButton(
              closeOnActivate: false,
              onPressed: noop,
              child: const Text('Stay open'),
            ),
          ],
        ),
        const Semantics(
          identifier: 'chips',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InputChip(label: Text('Red'), onDeleted: null, deleteHref: '/'),
              InputChip(
                label: Text('Blue'),
                href: '/target.html#blue',
                deleteHref: '/target.html#unblue',
                deleteButtonTooltipMessage: 'Remove',
              ),
              InputChip(
                label: Text('Picked'),
                selected: true,
                onSelected: null,
                href: '/target.html#picked',
                showCheckmark: true,
              ),
              InputChip(
                label: Text('Both'),
                selected: true,
                href: '/target.html#both',
                deleteHref: '/target.html#unboth',
              ),
              InputChip(label: Text('Off'), isEnabled: false, deleteHref: '/'),
              FilterChip(
                label: Text('Link filter'),
                selected: true,
                onSelected: null,
                href: '/target.html#filter',
              ),
              ActionChip(
                label: Text('Link action'),
                onPressed: null,
                href: '/target.html#action',
              ),
              Chip(label: Text('Plain')),
            ],
          ),
        ),
      ],
    ),
  );
  final html = await renderDocument(
    ThorApp(
      theme: ThemeData(colorScheme: const ColorScheme.light()),
      child: body,
    ),
  );
  File(args.single).writeAsStringSync(html);
}
