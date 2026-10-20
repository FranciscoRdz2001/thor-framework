/// Pre-renders the design system's test page.
library;

import 'dart:io' show Platform;

import 'package:thor_studio/thor_studio.dart'
    show StudioLocalizations, StudioTheme;
import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/server.dart';
import 'package:thor_ui/thor_ui.dart' show Locale, ThorApp;

import 'page.dart';
import 'sections/scaffold_page.dart';

/// The design system's theme (fonts served from `web/fonts`).
final theme = StudioTheme.light(fontsPath: 'fonts');

/// Its dark palette: the system's, until the switch picks one.
final darkTheme = StudioTheme.dark(fontsPath: 'fonts');

void main() {
  initializeThor(styles: []);
  runApp(
    Document(
      title: 'Estado reactivo · thor docs',
      lang: const Locale('es'),
      meta: const {
        'description':
            'El sistema de diseño thor_studio en una página real de los docs.',
      },
      head: const [
        html.link(rel: 'icon', href: 'favicon.png'),
        html.script(src: 'scripts/studio-code.js', defer: true),
      ],
      body: ThorApp(
        theme: theme,
        darkTheme: darkTheme,
        // The studio's own strings ("Saltar al contenido", "Siguiente"…) in
        // the page's language: a widget's parameter still wins.
        locale: const Locale('es'),
        supportedLocales: StudioLocalizations.supportedLocales,
        localizationsDelegates: [StudioLocalizations.delegate],
        // `GALLERY_PAGE=scaffold` serves the whole-page StudioScaffold demo.
        child: Platform.environment['GALLERY_PAGE'] == 'scaffold'
            ? const ScaffoldPage()
            : const GuidePage(),
      ),
    ),
  );
}
