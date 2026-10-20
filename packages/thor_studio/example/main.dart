// The Studio design system: one theme per brightness is the whole setup.
// `THOR_RENDER_TO=out.html dart run example/main.dart` renders the page to a
// file; without the variable, `dart run example/main.dart` serves it.
import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/server.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  initializeThor(styles: const []);
  runApp(
    Document(
      title: 'Studio',
      body: ThorApp(
        theme: StudioTheme.light(fontsPath: '/fonts'),
        darkTheme: StudioTheme.dark(fontsPath: '/fonts'),
        child: const StudioScaffold(
          appBar: StudioTopBar(brand: StudioBrand(name: 'thor')),
          body: StudioPageHeader(title: 'Hello Studio'),
        ),
      ),
    ),
  );
}
