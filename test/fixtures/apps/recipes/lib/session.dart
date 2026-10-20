/// The recipes' session: who is signed in, in a signed cookie.
library;

import 'package:thor_ui/router.dart';

/// The signed-in user, published by `(private)/middleware.dart` to the
/// pages below it (`request.context.get(currentUser)`).
const currentUser = ContextKey<String>('user');

/// How long a session lasts, on the server and on the cookie.
const sessionLifetime = Duration(days: 7);

/// Signs the session cookie (a real app reads the key from the
/// environment, never from the code).
final cookies = SignedCookies(
  'recetas-solo-para-el-ejemplo-no-lo-uses',
  purpose: 'session',
  maxAge: sessionLifetime,
);

/// The session cookie's name.
const sessionCookie = 'sesion';
