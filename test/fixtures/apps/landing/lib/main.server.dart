/// Pre-renders the landing page.
library;

import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/server.dart';
import 'package:thor_ui/thor_ui.dart' show ThorApp;

import 'app.dart';
import 'theme.dart';

const _title = 'Thor Starter';

const _description =
    "Thor Starter: build fast web apps with Flutter's widget API.";

void main() {
  initializeThor(styles: landingStyles);
  runApp(
    Document(
      title: _title,
      lang: const Locale('en'),
      meta: const {
        'description': _description,
        'twitter:card': 'summary_large_image',
      },
      head: [
        const html.link(rel: 'icon', href: 'favicon.png'),
        // Link previews (an Open Graph card): `property=`.
        for (final (property, content) in const [
          ('og:title', _title),
          ('og:description', _description),
          ('og:image', 'og.jpg'),
        ])
          html.meta(attributes: {'property': property, 'content': content}),
      ],
      body: ThorApp(
        theme: lightTheme,
        darkTheme: darkTheme,
        child: const LandingPage(),
      ),
    ),
  );
}
