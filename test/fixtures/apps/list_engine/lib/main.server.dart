/// Pre-renders the keyed list page.
library;

import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/server.dart';
import 'package:thor_ui/thor_ui.dart' show DefaultTextStyle, TextStyle, ThorApp;

import 'page.dart';

void main() {
  initializeThor(styles: []);
  runApp(
    const Document(
      title: 'Lista',
      lang: Locale('es'),
      meta: {'description': 'Lista con claves'},
      viewport: 'width=device-width, initial-scale=1',
      head: [html.link(rel: 'icon', href: 'data:,')],
      body: ThorApp(
        child: DefaultTextStyle(
          style: TextStyle(fontFamily: 'system-ui'),
          child: ListPage(),
        ),
      ),
    ),
  );
}
