/// The texts of a server call's errors, in the visitor's language.
library;

import 'src/locale.dart' show Locale;

/// What the visitor reads when a `query` or a `command` fails: the ones the
/// server writes (a sign-in, a bad request, a generic failure) and the ones
/// the browser shows for what it finds itself (no network, a timeout), and
/// the buttons of the page that stands in for the confirm dialog. Set once in
/// `ThorApp(serverMessages:)`; the server puts the browser's in the page, so
/// the client never carries a string of its own.
///
/// What the app doesn't set is written in the language of each request
/// ([forLocale]): English and Spanish ship, another language answers in
/// English.
///
/// ```dart
/// ThorApp.router(
///   routerConfig: router,
///   serverMessages: const ServerMessages(
///     network: 'Sin conexión',
///     timeout: 'El servidor tardó demasiado',
///     generic: 'Algo salió mal',
///     signIn: 'Inicia sesión otra vez',
///   ),
/// );
/// ```
///
/// An `HttpError` keeps its own message: these are for the errors that have
/// none.
final class ServerMessages {
  /// Pass only what the app wants to say itself; the rest is the visitor's
  /// language ([forLocale]), English by default.
  const ServerMessages({
    String? network,
    String? timeout,
    String? aborted,
    String? generic,
    String? signIn,
    String? badRequest,
    String? notFound,
    String? httpError,
    String? ok,
    String? cancel,
    String? confirmNeedsScript,
  }) : _network = network,
       _timeout = timeout,
       _aborted = aborted,
       _generic = generic,
       _signIn = signIn,
       _badRequest = badRequest,
       _notFound = notFound,
       _httpError = httpError,
       _ok = ok,
       _cancel = cancel,
       _confirmNeedsScript = confirmNeedsScript,
       _words = _english;

  const ServerMessages._(
    this._network,
    this._timeout,
    this._aborted,
    this._generic,
    this._signIn,
    this._badRequest,
    this._notFound,
    this._httpError,
    this._ok,
    this._cancel,
    this._confirmNeedsScript,
    this._words,
  );

  final String? _network,
      _timeout,
      _aborted,
      _generic,
      _signIn,
      _badRequest,
      _notFound,
      _httpError,
      _ok,
      _cancel,
      _confirmNeedsScript;
  final _Words _words;

  /// These messages with the defaults in the language of [locale] (`es`,
  /// `pt_BR`; `null` or one thor has no texts for: English). What the app
  /// set stays.
  ServerMessages forLocale(Locale? locale) {
    final words = switch (locale?.languageCode) {
      'es' => _spanish,
      _ => _english,
    };
    return identical(words, _words)
        ? this
        : ServerMessages._(
            _network,
            _timeout,
            _aborted,
            _generic,
            _signIn,
            _badRequest,
            _notFound,
            _httpError,
            _ok,
            _cancel,
            _confirmNeedsScript,
            words,
          );
  }

  /// The browser got no answer (offline, refused, dropped).
  String get network => _network ?? _words.network;

  /// The call's `timeout:` ran out.
  String get timeout => _timeout ?? _words.timeout;

  /// The request was cancelled by something other than a newer call.
  String get aborted => _aborted ?? _words.aborted;

  /// Anything the server can't say better: an unexpected failure, or an
  /// answer that isn't the server's (a proxy's `502`).
  String get generic => _generic ?? _words.generic;

  /// The session is gone (`401` with the page to sign in at).
  String get signIn => _signIn ?? _words.signIn;

  /// A body or an argument the server can't read (`400`).
  String get badRequest => _badRequest ?? _words.badRequest;

  /// A query or command the page doesn't have (`404`).
  String get notFound => _notFound ?? _words.notFound;

  /// An `HttpError` with no message: `{status}` is its status code.
  String get httpError => _httpError ?? _words.httpError;

  /// The button that says yes in the page's confirm dialog (`confirm(…)`
  /// and a button's `confirm:`), unless the call gives its own label.
  String get ok => _ok ?? _words.ok;

  /// The button that says no in the confirm dialog.
  String get cancel => _cancel ?? _words.cancel;

  /// What the page that stands in for the dialog says (JavaScript off) about
  /// a form that sends a file: it can't be asked about without the script,
  /// because the file can't go through a second post.
  String get confirmNeedsScript =>
      _confirmNeedsScript ?? _words.confirmNeedsScript;

  /// [httpError] for [status].
  String forStatus(int status) => httpError.replaceAll('{status}', '$status');

  /// What the browser needs in the page (`network`, `timeout`, `aborted`,
  /// `generic`): the rest is written by the server's own answers.
  Map<String, String> toPage() => {
    'network': network,
    'timeout': timeout,
    'aborted': aborted,
    'generic': generic,
  };
}

/// The defaults of one language.
final class _Words {
  const _Words({
    required this.network,
    required this.timeout,
    required this.aborted,
    required this.generic,
    required this.signIn,
    required this.badRequest,
    required this.notFound,
    required this.httpError,
    required this.ok,
    required this.cancel,
    required this.confirmNeedsScript,
  });

  final String network,
      timeout,
      aborted,
      generic,
      signIn,
      badRequest,
      notFound,
      httpError,
      ok,
      cancel,
      confirmNeedsScript;
}

const _english = _Words(
  network: 'Network error',
  timeout: 'The server took too long to answer',
  aborted: 'The request was cancelled',
  generic: 'Something went wrong',
  signIn: 'Sign in again',
  badRequest: 'Bad request',
  notFound: 'Not found',
  httpError: 'Error {status}',
  ok: 'OK',
  cancel: 'Cancel',
  confirmNeedsScript:
      'This form sends a file, so asking before it goes needs JavaScript. '
      'Turn it on, or send the form without the file.',
);

const _spanish = _Words(
  network: 'Error de red',
  timeout: 'El servidor tardó demasiado en responder',
  aborted: 'Se canceló la solicitud',
  generic: 'Algo salió mal',
  signIn: 'Inicia sesión otra vez',
  badRequest: 'Solicitud incorrecta',
  notFound: 'No encontrado',
  httpError: 'Error {status}',
  ok: 'Aceptar',
  cancel: 'Cancelar',
  confirmNeedsScript:
      'Este formulario envía un archivo, así que preguntar antes de enviarlo '
      'necesita JavaScript. Actívalo, o envía el formulario sin el archivo.',
);
