/// Why a server call (`query`, `command`) failed, for a state to branch on:
/// `if (cart.add.errorKind.value == ServerErrorKind.unauthorized)`.
///
/// The browser sets it next to the `error` text the visitor reads (its
/// `name` is what travels in the page and in a command's answer).
library;

/// The reason a server call failed.
enum ServerErrorKind {
  /// The request never got an answer (offline, refused, dropped).
  network,

  /// The call's `timeout:` ran out; a command may still have happened on
  /// the server.
  timeout,

  /// Something outside the state cancelled the request (a `refresh` that
  /// replaced another one never shows: the newest call wins).
  aborted,

  /// `401`: no session, or it expired.
  unauthorized,

  /// `403`: the session isn't allowed.
  forbidden,

  /// `400` or `422`: the server rejected the argument.
  validation,

  /// Any other `4xx`: `404`, a `409` conflict, a `429`…
  client,

  /// `5xx`, or an answer that isn't the server's (a proxy's `502`).
  server;

  /// The kind of an HTTP [status] the server (or a proxy) answered.
  static ServerErrorKind ofStatus(int status) => switch (status) {
    401 => unauthorized,
    403 => forbidden,
    400 || 422 => validation,
    >= 500 => server,
    _ => client,
  };
}
