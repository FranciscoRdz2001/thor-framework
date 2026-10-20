/// Pre-renders the hybrid page (thor HTML + embedded Flutter views).
library;

import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/server.dart';
import 'package:thor_ui/thor_ui.dart' show ThorApp;

import 'app.dart';

void main() {
  initializeThor(styles: []);
  runApp(
    const Document(
      title: 'Modo híbrido',
      lang: Locale('es'),
      viewport: 'width=device-width, initial-scale=1',
      head: [html.link(rel: 'icon', href: 'data:,')],
      body: ThorApp(child: HybridPage()),
    ),
  );
}
