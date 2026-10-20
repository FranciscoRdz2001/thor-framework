// Renders a Flutter-style widget tree to a static HTML document.
// `THOR_RENDER_TO=out.html dart run example/main.dart` renders the page to a
// file; without the variable, `dart run example/main.dart` serves it.
import 'package:thor_ui/server.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  initializeThor(styles: const []);
  runApp(
    const Document(
      title: 'Hello',
      body: ThorApp(child: Center(child: Text('Hello from thor'))),
    ),
  );
}
