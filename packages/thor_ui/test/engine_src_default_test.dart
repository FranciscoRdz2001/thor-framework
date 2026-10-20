// Where each app loads the engine from when it doesn't say (engineSrc).
import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  test('a router app loads it from the site root', () {
    // Relative, a nested route (`/article/x`) would ask for
    // `/article/engine.dart.js`.
    final app = ThorApp.router(routerConfig: ThorRouter(const []));
    expect(app.engineSrc, '/engine.dart.js');
  });

  test('a single page loads it from next to the page', () {
    const app = ThorApp(child: Text('x'));
    expect(app.engineSrc, 'engine.dart.js');
  });
}
