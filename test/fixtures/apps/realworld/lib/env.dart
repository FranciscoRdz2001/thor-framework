import 'package:thor_server/thor_server.dart';

/// Everything the app reads from the environment, checked at startup
/// (THOR-P011 lists every problem at once).
abstract final class RealworldEnv {
  /// The Conduit API.
  static const api = EnvUrl(
    'REALWORLD_API',
    fallback: 'https://api.realworld.show/api',
  );

  /// Signs the session cookie; unset, each start makes a random one
  /// (sessions then end on restart).
  static const sessionSecret = EnvOptional(
    EnvSecret('SESSION_SECRET', minLength: 32),
  );

  /// `Secure` on cookies: unset, whenever the request came over HTTPS.
  static const secureCookies = EnvOptional(EnvBool('SECURE_COOKIES'));

  /// Where the static files are (default: `build/public` if built, else
  /// `web`).
  static const publicDir = EnvOptional(EnvString('PUBLIC_DIR'));

  /// The port.
  static const port = EnvInt('PORT', fallback: 4300);

  /// Isolates serving (default: one per core).
  static const isolates = EnvOptional(EnvInt('ISOLATES'));

  /// Sign-in attempts allowed per account every 15 minutes (twice that per
  /// IP); default 10. Raise it for automated test suites, which sign in
  /// more often than any person would from one address.
  static const loginLimit = EnvOptional(EnvInt('REALWORLD_LOGIN_LIMIT'));

  /// The schema.
  static const schema = EnvSchema([
    api,
    sessionSecret,
    secureCookies,
    publicDir,
    port,
    isolates,
    loginLimit,
  ]);
}

/// The environment, loaded on first use (the server's `main` touches it
/// first, so a bad deploy fails before listening).
final env = RealworldEnv.schema.load();
