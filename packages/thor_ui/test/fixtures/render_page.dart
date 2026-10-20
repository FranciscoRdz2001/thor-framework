// A static app's entry, run by static_render_test.dart: renders
// `THOR_RENDER_TO` once. `FIXTURE_THROW=1` makes the page throw.
import 'dart:io';

import 'package:thor_ui/server.dart';
import 'package:thor_ui/thor_ui.dart';

class _Boom extends StatelessWidget {
  const _Boom();

  @override
  Widget build(BuildContext context) =>
      throw StateError('the page failed on purpose');
}

void main() {
  initializeThor(styles: const []);
  runApp(
    Document(
      title: 'Fixture',
      body: ThorApp(
        child: Platform.environment['FIXTURE_THROW'] == '1'
            ? const _Boom()
            : const Text('hello'),
      ),
    ),
  );
}
