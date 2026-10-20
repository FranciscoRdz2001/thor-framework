import 'dart:io';

/// The `Host` values `thor dev` answers to (its proxy and the app behind
/// it), against DNS rebinding: a page of another site whose name resolves
/// to `127.0.0.1` reaches the dev server from the visitor's browser, and
/// with a `Host` of its own it could read every response (the overlay
/// carries source frames). Same check as Vite's `server.allowedHosts`.
///
/// Allowed: `localhost` and `*.localhost`, any IP address (a name can't be
/// rebound, but an address is what you type for a phone), and the names
/// given to `thor dev --allowed-host`. The port is ignored, the case too. A
/// request without `Host` (HTTP/1.0) passes: a browser always sends one, so
/// it is no rebinding.
final class DevHosts {
  /// Also allows [allowed]: a name (`dev.example`), a name with a leading
  /// dot for it and its subdomains (`.example`), or `*` for every host.
  const DevHosts([this.allowed = const []]);

  /// The list `thor dev` passes to the app in [envName]: names separated
  /// by commas.
  factory DevHosts.parse(String? list) => DevHosts([
    for (final name in (list ?? '').split(','))
      if (name.trim().isNotEmpty) name.trim(),
  ]);

  /// The environment variable that carries `--allowed-host` to the app.
  static const envName = 'THOR_ALLOWED_HOSTS';

  /// The extra names allowed.
  final List<String> allowed;

  /// Whether a request whose `Host` header is [header] is served.
  bool allows(String? header) {
    if (header == null || header.trim().isEmpty) return true;
    final name = hostname(header);
    if (name == null) return false;
    if (name == 'localhost' || name.endsWith('.localhost')) return true;
    if (InternetAddress.tryParse(name) != null) return true;
    for (final entry in allowed) {
      final text = entry.trim();
      if (text == '*') return true;
      final subdomains = text.startsWith('.');
      final rule = hostname(subdomains ? text.substring(1) : text);
      if (rule == null) continue;
      if (rule == name || (subdomains && name.endsWith('.$rule'))) return true;
    }
    return false;
  }

  /// Why [entry] is not a rule `--allowed-host` understands (a name, `.name`
  /// or `*`), or null when it is. A URL, a glob (`*.example`), a list in one
  /// value: silently allowing nothing would leave the 403 a mystery.
  static String? problem(String entry) {
    final text = entry.trim();
    if (text == '*') return null;
    final name = hostname(text.startsWith('.') ? text.substring(1) : text);
    if (name != null) return null;
    return '"$entry" is not a host name: use dev.example, .example (it and '
        'its subdomains) or * (any host); no scheme, path or wildcard.';
  }

  /// The 403 message for [request], or null when it is served. Its `Host`
  /// counts, and so does the authority of an absolute-form target
  /// (`GET http://evil.example/ HTTP/1.1`), which RFC 9112 puts before
  /// `Host`: no browser sends it to a server, but what the app would see as
  /// its host is what is checked.
  String? check(HttpRequest request) {
    final host = request.headers.value(HttpHeaders.hostHeader);
    if (!allows(host)) return refusal(host);
    final target = request.uri;
    if (target.hasAuthority && !allows(target.authority)) {
      return refusal(target.authority);
    }
    return null;
  }

  /// The name in a `Host` header (lower case, no port, no brackets, no
  /// trailing dot), or null when the header is not a valid host.
  static String? hostname(String header) {
    var text = header.trim().toLowerCase();
    String name;
    if (text.startsWith('[')) {
      final end = text.indexOf(']');
      if (end < 0) return null;
      name = text.substring(1, end);
      if (!_port.hasMatch(text.substring(end + 1))) return null;
      // An address in brackets is valid only as IPv6.
      return name.contains(':') && InternetAddress.tryParse(name) != null
          ? name
          : null;
    }
    final colon = text.indexOf(':');
    if (colon >= 0) {
      if (text.indexOf(':', colon + 1) >= 0 ||
          !_port.hasMatch(text.substring(colon))) {
        return null;
      }
      text = text.substring(0, colon);
    }
    name = text.endsWith('.') ? text.substring(0, text.length - 1) : text;
    return _name.hasMatch(name) ? name : null;
  }

  static final _port = RegExp(r'^(:\d{1,5})?$');
  static final _name = RegExp(r'^[a-z0-9_]([a-z0-9._-]*[a-z0-9_])?$');

  /// What the 403 says about [header].
  String refusal(String? header) =>
      'Blocked request: the Host "${header ?? ''}" is not allowed in '
      'development. If you trust it, run thor dev --allowed-host '
      '${header == null ? '<name>' : hostname(header) ?? '<name>'} '
      '(or thor dev --host to open it to your network). '
      'This protects the dev server against DNS rebinding.';
}
