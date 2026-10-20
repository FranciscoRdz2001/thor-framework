import 'dart:convert';
import 'dart:io' show stderr;

import 'package:crypto/crypto.dart';

import 'dev.dart';
import 'errors.dart';

/// Parses a `Cookie` header into name → value (first wins).
Map<String, String> parseCookies(String? header) {
  final out = <String, String>{};
  if (header == null || header.isEmpty) return out;
  for (final part in header.split(';')) {
    final eq = part.indexOf('=');
    if (eq <= 0) continue;
    final name = part.substring(0, eq).trim();
    var value = part.substring(eq + 1).trim();
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      value = value.substring(1, value.length - 1);
    }
    try {
      out.putIfAbsent(name, () => Uri.decodeComponent(value));
    } on ArgumentError {
      out.putIfAbsent(name, () => value);
    } on FormatException {
      out.putIfAbsent(name, () => value); // invalid UTF-8: as written
    }
  }
  return out;
}

final _token = RegExp(r"^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$");

/// A cookie to set on the response.
class SetCookie {
  /// Cookie [name] = [value]. [secure] `null` = decided by the server
  /// (`Secure` when the request came over HTTPS: `secureCookies` of
  /// `RouteHandler`).
  SetCookie(
    this.name,
    this.value, {
    this.maxAge,
    this.path = '/',
    this.httpOnly = true,
    this.sameSite = 'Lax',
    this.secure,
  }) {
    if (!_token.hasMatch(name)) {
      throw ArgumentError.value(name, 'name', 'not a cookie name');
    }
  }

  /// Cookie name.
  final String name;

  /// Cookie value (percent-encoded on the wire).
  final String value;

  /// Lifetime; `null` = until the browser closes, zero = delete.
  final Duration? maxAge;

  /// Path it applies to.
  final String path;

  /// Hidden from page scripts.
  final bool httpOnly;

  /// `Lax`, `Strict` or `None`.
  final String sameSite;

  /// Sent only over HTTPS; `null` = the server's default (always for
  /// `SameSite=None`, which browsers refuse without it).
  final bool? secure;

  /// The `Set-Cookie` header value.
  String toHeader({bool secureByDefault = false}) {
    final b = StringBuffer(
      '$name=${Uri.encodeComponent(value)}; Path=$path; SameSite=$sameSite',
    );
    if (maxAge != null) b.write('; Max-Age=${maxAge!.inSeconds}');
    if (httpOnly) b.write('; HttpOnly');
    // `SameSite=None` without `Secure` is dropped by every browser: it
    // gets it unless the cookie says `secure: false` itself.
    if (secure ?? (secureByDefault || sameSite.toLowerCase() == 'none')) {
      b.write('; Secure');
    }
    return b.toString();
  }
}

/// Signs cookie values with HMAC-SHA256 so the client can read but not
/// forge them (a session holding a user id or an API token).
///
/// A signed value carries the second it was issued, under the signature, so
/// `maxAge` is checked by the server and not only by the browser (a stolen
/// cookie stops working when it is old enough, whatever `Max-Age` it had).
/// `previousSecrets` rotate the key: sign with the first, verify with any.
///
/// ```dart
/// final session = SignedCookies(
///   secret,
///   previousSecrets: [oldSecret], // drop it once its cookies expired
///   maxAge: const Duration(days: 30),
/// );
/// request.response.setCookie('session', session.sign(jsonEncode(user)));
/// final user = session.verify(request.cookies['session']);
/// ```
///
/// One secret for several cookies (a session and a flash, say): give each its
/// own `purpose:`, so a value signed for one cannot be replayed as another.
///
/// ```dart
/// final session = SignedCookies(secret, purpose: 'session', maxAge: days30);
/// final flash = SignedCookies(secret, purpose: 'flash', maxAge: minute);
/// flash.verify(session.sign('ana')); // null
/// ```
///
/// `// web:` Plug.Crypto's `MessageVerifier` with `max_age`, iron-session's
/// `ttl` and its map of passwords, Rails' `MessageVerifier` rotations and
/// itsdangerous' `TimestampSigner.unsign(max_age:)` do the same; Rails'
/// `generate(…, purpose:)` and itsdangerous' `salt` are the `purpose`.
class SignedCookies {
  /// Signs with [secret] (at least 32 bytes: generate it once and keep it
  /// out of the repo).
  ///
  /// [previousSecrets] only verify: the keys of before a rotation, so nobody
  /// is signed out by it (each at least 32 bytes). Rotating does not renew a
  /// cookie: it keeps the expiry of when it was issued.
  ///
  /// [maxAge] (`null` = signed values never expire) is how old a value may
  /// be; zero rejects every value. [clock] is for tests.
  ///
  /// [purpose] (`null` = none) names what the value is
  /// for (`'session'`, `'flash'`): it goes into the signed bytes, not into the
  /// cookie, so a value only verifies with the purpose it was signed with,
  /// and cookies of other purposes (or none) that share the [secret] are
  /// rejected. Use one whenever a secret signs more than one kind of cookie.
  /// A cookie signed before you add a purpose stops verifying (its holders
  /// sign in again once). Under `thor dev`, a `'session'` without [maxAge]
  /// warns (THOR-P033).
  SignedCookies(
    String secret, {
    List<String> previousSecrets = const [],
    this.maxAge,
    this.purpose,
    DateTime Function()? clock,
  }) : _hmacs = [
         for (final k in [secret, ...previousSecrets])
           Hmac(sha256, utf8.encode(_checked(k))),
       ],
       _clock = clock ?? DateTime.now {
    if (maxAge != null && maxAge!.isNegative) {
      throw ArgumentError.value(maxAge, 'maxAge', 'must not be negative');
    }
    final p = purpose;
    if (p != null && (p.isEmpty || p.contains('\n'))) {
      throw ArgumentError.value(
        p,
        'purpose',
        'must not be empty or have a newline',
      );
    }
    if (p == 'session' && maxAge == null && ThorDev.enabled && !_warned) {
      _warned = true;
      onWarning(
        thorError(
          'THOR-P033',
          'this session (SignedCookies with purpose: \'session\') has no '
              'maxAge, so its cookies never expire on the server. Fix: '
              'maxAge: const Duration(days: 30), and the same on the cookie',
        ),
      );
    }
  }

  static bool _warned = false;

  /// Forgets the warnings already given (they go once per process); for tests.
  static void resetWarnings() => _warned = false;

  /// Where a warning goes (the standard error); tests replace it.
  static void Function(String message) onWarning = stderr.writeln;

  static String _checked(String secret) {
    if (utf8.encode(secret).length < 32) {
      throw ArgumentError.value(
        '…',
        'secret',
        thorError('THOR-P003', 'use at least 32 bytes'),
      );
    }
    return secret;
  }

  final List<Hmac> _hmacs;
  final DateTime Function() _clock;

  /// How old a signed value may be, or `null` for no limit.
  final Duration? maxAge;

  /// What the values are for (see the constructor), or `null`.
  final String? purpose;

  /// A cookie whose issue time is this far ahead of the clock is still
  /// good (two instances never agree to the second), further is forged.
  static const _skew = 60;

  // Values of cookies that verified, by their exact signed text: a session
  // sends the same cookie on every request, and the HMAC is most of reading
  // it. Only matches are kept (forged cookies never grow it); bounded,
  // least recently used out first. A hit returns what the HMAC would, and
  // its age is checked again on every hit.
  final _verified = <String, (String, int)>{};

  /// Most verified cookies remembered per instance.
  static int maxVerified = 4096;

  int get _now => _clock().millisecondsSinceEpoch ~/ 1000;

  /// [value] followed by the time it was issued and its signature.
  String sign(String value) {
    final payload = base64Url.encode(utf8.encode(value)).replaceAll('=', '');
    final signed = '$payload.$_now';
    return '$signed.${_signature(_hmacs.first, signed)}';
  }

  /// The value [signed] carries, or `null` when it is missing, malformed,
  /// expired ([maxAge]) or its signature doesn't match any key.
  String? verify(String? signed) {
    if (signed == null) return null;
    final known = _verified.remove(signed);
    if (known != null) {
      if (!_fresh(known.$2)) return null;
      return (_verified[signed] = known).$1;
    }
    final parts = signed.split('.');
    if (parts.length != 3) return null;
    final issued = int.tryParse(parts[1]);
    if (issued == null || issued < 0 || parts[1].startsWith('+')) {
      return null;
    }
    if (!_signedByAny('${parts[0]}.${parts[1]}', parts[2])) return null;
    if (!_fresh(issued)) return null;
    final String value;
    try {
      value = utf8.decode(base64Url.decode(base64Url.normalize(parts[0])));
    } on FormatException {
      return null;
    }
    while (_verified.length >= maxVerified && _verified.isNotEmpty) {
      _verified.remove(_verified.keys.first);
    }
    if (maxVerified > 0) _verified[signed] = (value, issued);
    return value;
  }

  /// Every key is tried (no early exit on the position of a match beyond
  /// the compare itself, which is constant-time per key).
  bool _signedByAny(String text, String signature) {
    var ok = false;
    for (final h in _hmacs) {
      if (_constantTimeEquals(_signature(h, text), signature)) ok = true;
    }
    return ok;
  }

  /// Whether a value issued at [issued] is still good.
  bool _fresh(int issued) {
    final limit = maxAge;
    if (limit == null) return true;
    final age = _now - issued;
    if (age < -_skew) return false;
    return age < limit.inSeconds;
  }

  /// The HMAC of [text], behind the purpose and a newline when there is one
  /// (base64url text and digits never have a newline, so a purposed input is
  /// never one without purpose, and purposes can't run into the text).
  String _signature(Hmac hmac, String text) => base64Url
      .encode(
        hmac
            .convert(utf8.encode(purpose == null ? text : '$purpose\n$text'))
            .bytes,
      )
      .replaceAll('=', '');
}

bool _constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}

/// Prefix of the cookies a page state persists in the browser
/// (`state(…, cookie: 'name')` writes `thor-s.name`). The engine's
/// protocol owns it (`thor_engine`'s `persistedStateCookiePrefix`); this
/// package can't import the engine, so a test keeps the two equal.
const persistedStateCookiePrefix = 'thor-s.';
