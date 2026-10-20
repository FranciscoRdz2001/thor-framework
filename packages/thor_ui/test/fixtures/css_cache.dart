// Renders the pages named on the command line, in order, in one process,
// and prints each page's HTML as one base64 line: run by
// css_cache_test.dart in release, where a page's stylesheet text is kept
// per process (ThorStyleRegistry.cssText).
import 'dart:convert';
import 'dart:io';

import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

final _blue = ThemeData(
  colorScheme: const ColorScheme.light(primary: Color(0xFF1D4ED8)),
);
final _dark = ThemeData(
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF1D4ED8),
    secondary: Color(0xFF22C55E),
  ),
);

final pages = <String, Widget>{
  'plain': const ThorApp(child: Column(children: [Text('a'), Text('b')])),
  'row': const ThorApp(
    child: Row(spacing: 8, children: [Text('a'), Text('b')]),
  ),
  // The same classes as `row`, another theme: other variables.
  'row-blue': ThorApp(
    theme: _blue,
    child: const Row(spacing: 8, children: [Text('a'), Text('b')]),
  ),
  'row-dark': ThorApp(
    theme: _blue,
    darkTheme: _dark,
    child: const Row(spacing: 8, children: [Text('a'), Text('b')]),
  ),
  'padded': const ThorApp(
    child: Padding(
      padding: EdgeInsets.all(12),
      child: Text('c', style: TextStyle(color: Color(0xFFDC2626))),
    ),
  ),
};

Future<void> main(List<String> names) async {
  initializeThorTests();
  for (final name in names) {
    final html = await renderDocument(pages[name]!);
    stdout.writeln('$name ${base64.encode(utf8.encode(html))}');
  }
}
