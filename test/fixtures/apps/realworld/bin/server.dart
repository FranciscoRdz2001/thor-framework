import 'package:realworld/app.dart';
import 'package:realworld/env.dart';
import 'package:realworld/session.dart';
import 'package:realworld/widgets/nav.dart';
import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

/// Serves the app: `REALWORLD_API=… PORT=4300 build/server`.
Future<void> main() async {
  final secret = sessionSecret();
  final public = env.of(RealworldEnv.publicDir) ?? (ThorServer.appPublicDir());
  await ThorServer.serve(
    () {
      configureSessions(secret);
      return ThorServer(
        handler: RouteHandler(
          routes: realworldApp.routes,
          secureCookies: env.of(RealworldEnv.secureCookies),
          renderer: WidgetRenderer.router(
            realworldApp,
            // Every page links one cached sheet (reset, theme, the app
            // stylesheet and the navbar's classes) and keeps inline only
            // its own classes.
            shareStyles: true,
            // The navbar as the layout draws it (a guest's): the classes
            // every page shares.
            specimens: const [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [NavBar(user: null, path: '/')],
              ),
            ],
            head: const [
              html.link(rel: 'icon', href: '/favicon.ico'),
              // The reference's fonts (same request, same bytes).
              html.link(
                rel: 'stylesheet',
                href:
                    '//fonts.googleapis.com/css?family=Titillium+Web:700|Source+Serif+Pro:400,700|Merriweather+Sans:400,700|Source+Sans+Pro:400,300,600,700,300italic,400italic,600italic,700italic',
              ),
            ],
          ),
        ),
        publicDir: public,
      );
    },
    port: env.of(RealworldEnv.port),
    isolates: env.of(RealworldEnv.isolates),
  );
}
