// The page of the `material-buttons` browser check: every Material button
// kind, icons and an icon link, rendered by the real widgets.
//
//   dart run packages/thor_ui/tool/material_buttons_page.dart <out.html>
import 'dart:io';

import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main(List<String> args) async {
  initializeThorTests();
  void noop() {}
  const add = Icon(Icons.add);
  final body = Column(
    spacing: 8,
    children: [
      const Semantics(
        identifier: 'rtl-icons',
        child: Row(
          spacing: 8,
          children: [
            Icon(Icons.arrow_back),
            Icon(Icons.add),
            Icon(Icons.send),
            Icon(Icons.arrow_back_ios),
          ],
        ),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton(onPressed: noop, child: const Text('Elevated')),
          ElevatedButton.icon(
            onPressed: noop,
            icon: add,
            label: const Text('Elevated icon'),
          ),
          FilledButton(onPressed: noop, child: const Text('Filled')),
          FilledButton.icon(
            onPressed: noop,
            icon: add,
            label: const Text('Filled icon'),
          ),
          FilledButton.tonal(onPressed: noop, child: const Text('Tonal')),
          FilledButton.tonalIcon(
            onPressed: noop,
            icon: add,
            label: const Text('Tonal icon'),
          ),
          OutlinedButton(onPressed: noop, child: const Text('Outlined')),
          OutlinedButton.icon(
            onPressed: noop,
            icon: add,
            label: const Text('Outlined icon'),
          ),
          TextButton(onPressed: noop, child: const Text('Text')),
          TextButton.icon(
            onPressed: noop,
            icon: add,
            label: const Text('Text icon'),
          ),
          FloatingActionButton(onPressed: noop, tooltip: 'FAB', child: add),
          FloatingActionButton.small(
            onPressed: noop,
            tooltip: 'FAB small',
            child: add,
          ),
          FloatingActionButton.large(
            onPressed: noop,
            tooltip: 'FAB large',
            child: add,
          ),
          FloatingActionButton.extended(
            onPressed: noop,
            icon: add,
            label: const Text(
              'FAB extended with a rather long label that must wrap',
            ),
          ),
          IconButton(onPressed: noop, tooltip: 'Icon plain', icon: add),
          IconButton.filled(onPressed: noop, tooltip: 'Icon filled', icon: add),
          IconButton.filledTonal(
            onPressed: noop,
            tooltip: 'Icon tonal',
            icon: add,
          ),
          IconButton.outlined(
            onPressed: noop,
            tooltip: 'Icon outlined',
            icon: add,
          ),
          const IconButton(href: '/target', tooltip: 'Icon link', icon: add),
        ],
      ),
      const Text('Disabled'),
      const Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton(onPressed: null, child: Text('D elevated')),
          FilledButton(onPressed: null, child: Text('D filled')),
          FilledButton.tonal(onPressed: null, child: Text('D tonal')),
          OutlinedButton(onPressed: null, child: Text('D outlined')),
          TextButton(onPressed: null, child: Text('D text')),
          FloatingActionButton(onPressed: null, tooltip: 'D FAB', child: add),
          IconButton(onPressed: null, tooltip: 'D icon', icon: add),
          IconButton.filled(onPressed: null, tooltip: 'D filled', icon: add),
          IconButton.outlined(
            onPressed: null,
            tooltip: 'D outlined',
            icon: add,
          ),
        ],
      ),
    ],
  );
  final html = await renderDocument(
    ThorApp(
      theme: ThemeData(colorScheme: const ColorScheme.light()),
      darkTheme: ThemeData(colorScheme: const ColorScheme.dark()),
      child: body,
    ),
  );
  File(args.single).writeAsStringSync(html);
}
