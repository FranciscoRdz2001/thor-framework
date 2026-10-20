/// Pre-renders the controls gallery to static HTML.
library;

import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/server.dart';
import 'package:thor_ui/thor_ui.dart' show ThorApp;

import 'gallery.dart';

void main() {
  initializeThor(styles: []);
  runApp(
    const Document(
      title: 'Controles',
      lang: Locale('es'),
      meta: {
        'description':
            'Galería de controles nativos de thor_ui sobre thor_engine.',
      },
      viewport: 'width=device-width, initial-scale=1',
      head: [html.link(rel: 'icon', href: 'data:,')],
      body: ThorApp(child: Gallery()),
    ),
  );
}
