import 'dart:math';
import 'dart:typed_data';

import 'cache_bus.dart';
import 'http_types.dart';

/// A page answered to a form's upload (`x-thor-upload`), kept for a
/// moment so the browser can navigate to it: the request that sent the files
/// cannot show it (an `XMLHttpRequest`), and sending the files again would
/// repeat the upload and its effects.
///
/// - The key is an unguessable token (128 random bits). The answer to the
///   upload carries it in the address and in a cookie of the visitor
///   (`HttpOnly`, scoped to the result's path): the address alone, a leaked
///   URL, shows nothing.
/// - It is served **once**, within [ttl], with the status the page had.
/// - Memory is bounded: [capacity] results, none over [maxBytes].
/// - Isolates: a server runs one isolate per core and the next request can
///   land in any. A stored result is sent to the others by the [CacheBus]
///   (a bounded copy in each, the same limits). Another host of a cluster is
///   not reached: there a miss is a redirect to the page the form was on.
final class UploadResults {
  UploadResults._();

  /// How long a result waits for the navigation that fetches it.
  static Duration ttl = const Duration(seconds: 60);

  /// The most results kept at once (the oldest goes first).
  static int capacity = 64;

  /// The largest page kept (a bigger one goes as the upload's answer).
  static int maxBytes = 1 << 20;

  /// The path of a result: `/_thor/upload-result/<token>`.
  static const path = '/_thor/upload-result/';

  /// The cookie that holds the token of the visitor's result.
  static const cookie = 'thor-upload';

  static final _kept = <String, _Result>{};
  static final _random = Random.secure();

  /// Forgets everything and restores the limits (tests).
  static void reset() {
    _kept.clear();
    ttl = const Duration(seconds: 60);
    capacity = 64;
    maxBytes = 1 << 20;
  }

  /// How many results wait.
  static int get length => _kept.length;

  /// A new token.
  static String newToken() {
    final bytes = Uint8List.fromList([
      for (var i = 0; i < 16; i++) _random.nextInt(256),
    ]);
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Keeps a page under [token] and tells the other isolates; `false` when it
  /// is over [maxBytes].
  static bool store(
    String token,
    int status,
    Map<HttpHeader, String> headers,
    List<int> body,
  ) {
    if (body.length > maxBytes) return false;
    _put(token, _Result(status, headers, Uint8List.fromList(body)));
    CacheBus.share(takeMessage(token)!);
    return true;
  }

  /// The message that gives the result under [token] to another isolate.
  static Map<String, Object?>? takeMessage(String token) {
    final r = _kept[token];
    if (r == null) return null;
    return {
      'thor-upload': token,
      'status': r.status,
      'headers': r.headers,
      'body': r.body,
    };
  }

  /// Makes this isolate take the results the others store (a handler does it
  /// when it is made).
  static void wire() => CacheBus.onShare = _receive;

  /// A result another isolate stored (the [CacheBus] calls it).
  static void _receive(Map<Object?, Object?> m) {
    if (m['thor-upload'] case final String token) {
      final body = Uint8List.fromList(m['body']! as List<int>);
      _put(
        token,
        _Result(m['status']! as int, {
          for (final e in (m['headers']! as Map).entries)
            HttpHeader('${e.key}'): '${e.value}',
        }, body),
      );
    }
  }

  static void _put(String token, _Result r) {
    _sweep();
    _kept[token] = r;
    while (_kept.length > capacity) {
      _kept.remove(_kept.keys.first);
    }
  }

  static void _sweep() {
    final now = DateTime.now();
    _kept.removeWhere((_, r) => now.difference(r.at) >= ttl);
  }

  /// The page under [token], taken out (single use), if it is still there.
  static ({int status, Map<HttpHeader, String> headers, Uint8List body})? take(
    String token,
  ) {
    _sweep();
    final r = _kept.remove(token);
    return r == null
        ? null
        : (status: r.status, headers: r.headers, body: r.body);
  }

  /// Whether [token] is waiting (without using it up).
  static bool has(String token) {
    _sweep();
    return _kept.containsKey(token);
  }
}

final class _Result {
  _Result(this.status, this.headers, this.body) : at = DateTime.now();
  final int status;
  final Map<HttpHeader, String> headers;
  final Uint8List body;
  final DateTime at;
}
