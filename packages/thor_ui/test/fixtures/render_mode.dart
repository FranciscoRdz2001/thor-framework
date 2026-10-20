// Renders one small page and prints its HTML: run by release_mode_test.dart
// with different -D flags (the release mode is a compile-time constant).
import 'dart:io';

import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<void> main() async {
  initializeThorTests();
  final html = await renderDocument(
    const ThorApp(child: Column(children: [Text('a'), Text('b')])),
  );
  stdout.write(html);
}
