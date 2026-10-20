/// Pre-renders the counter page.
library;

import 'package:thor_ui/server.dart';
import 'package:thor_ui/thor_ui.dart' show Center, ThorApp;

import 'app.dart';

void main() {
  initializeThor(styles: []);
  runApp(
    const Document(
      title: 'Contador',
      lang: Locale('es'),
      body: ThorApp(child: Center(child: Counter())),
    ),
  );
}
