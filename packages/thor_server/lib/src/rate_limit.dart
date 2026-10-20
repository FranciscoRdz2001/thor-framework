import 'dart:async';
import 'dart:convert';
import 'dart:io' show InternetAddress, InternetAddressType;

import 'package:crypto/crypto.dart';

import 'http_types.dart';
import 'request.dart';
import 'results.dart';
import 'routes.dart';

/// Attempts counted for a key in the current window.
class RateLimitCount {
  /// [count] attempts so far (this one included) in a window that ends at
  /// [resetsAt].
  const RateLimitCount(this.count, this.resetsAt);

  /// Attempts in the window, this one included.
  final int count;

  /// When the window ends and the count starts over.
  final DateTime resetsAt;
}

/// Where [RateLimit] keeps its counters.
///
/// The default ([MemoryRateLimitStore]) lives in one isolate: with several
/// isolates (`ThorServer` starts one per core) or several instances behind
/// a load balancer, each has its own count and the real limit is `max` times
/// as many. For a limit that must hold, implement this over a shared store
/// (Redis `INCR` + `EXPIRE`, a database row): [increment] must be atomic.
abstract interface class RateLimitStore {
  /// Counts one attempt for [key] and returns the window's total. A window
  /// starts at the first attempt after the last one ended and lasts
  /// [window]; [now] is the caller's clock.
  Future<RateLimitCount> increment(String key, Duration window, DateTime now);

  /// Forgets [key] (a successful login).
  Future<void> reset(String key);
}

/// Counters in this isolate's memory, bounded by [maxKeys]: a client that
/// invents a key per request (a new account name each time) cannot grow it.
/// When full, expired windows go first, then the keys with the fewest
/// attempts (oldest first): a flood of new keys pushes out other one-off
/// keys, never the counter of a client that is being blocked.
class MemoryRateLimitStore implements RateLimitStore {
  /// A store of at most [maxKeys] counters.
  MemoryRateLimitStore({this.maxKeys = 10000}) {
    if (maxKeys < 1) throw ArgumentError.value(maxKeys, 'maxKeys');
  }

  /// Most counters kept.
  final int maxKeys;

  // Insertion order = window start order (a key is re-inserted when its
  // window restarts), so among equal counts the first entry is the oldest.
  final _windows = <String, ({DateTime start, DateTime end, int count})>{};

  /// Counters alive now (expired ones not yet dropped included).
  int get length => _windows.length;

  @override
  Future<RateLimitCount> increment(
    String key,
    Duration window,
    DateTime now,
  ) async {
    final w = _windows[key];
    if (w != null && now.isBefore(w.end)) {
      _windows[key] = (start: w.start, end: w.end, count: w.count + 1);
      return RateLimitCount(w.count + 1, w.end);
    }
    _windows.remove(key);
    if (_windows.length >= maxKeys) _makeRoom(now);
    final end = now.add(window);
    _windows[key] = (start: now, end: end, count: 1);
    return RateLimitCount(1, end);
  }

  void _makeRoom(DateTime now) {
    _windows.removeWhere((_, w) => !now.isBefore(w.end));
    if (_windows.length < maxKeys) return;
    // Room for a tenth at once, so a flood pays the scan once per many keys.
    final drop = _windows.length - maxKeys + 1 + maxKeys ~/ 10;
    final byCount = _windows.entries.toList()
      ..sort((a, b) => a.value.count.compareTo(b.value.count)); // stable
    for (final e in byCount.take(drop)) {
      _windows.remove(e.key);
    }
  }

  @override
  Future<void> reset(String key) async => _windows.remove(key);
}

/// What one attempt got.
class RateLimitResult {
  /// An attempt that was [allowed] or not.
  const RateLimitResult({
    required this.allowed,
    required this.remaining,
    required this.retryAfter,
  });

  /// Whether it may go on.
  final bool allowed;

  /// Attempts left in this window.
  final int remaining;

  /// Until the window ends (at least one second when not [allowed]).
  final Duration retryAfter;
}

/// At most [max] attempts per key in [window]: for login, password reset,
/// anything that guesses or costs. Counts in a fixed window (a client can
/// spend `max` at the end of one and `max` at the start of the next).
///
/// As a middleware of a route group (a page that answers 429, or JSON for a
/// query/command call, both with `Retry-After`):
///
/// ```dart
/// final loginLimit = RateLimit(max: 10, window: const Duration(minutes: 15));
/// Group(middleware: loginLimit.middleware(), children: [...])
/// ```
///
/// Or inside an action, to draw the form again with a message, by account
/// as well as by IP:
///
/// ```dart
/// final limited = await loginLimit.limit(
///   request,
///   key: 'login:${form['email']}',
///   data: {'error': 'Too many attempts. Try again later.'},
/// );
/// if (limited != null) return limited; // 429 + Retry-After
/// ```
///
/// The default key is [clientIp]. Behind a reverse proxy every request
/// comes from the proxy's address unless [trustedProxies] says how many
/// proxies to believe in `X-Forwarded-For`; believing it without a proxy
/// that rewrites it lets anyone dodge the limit by sending their own.
///
/// `// web:` Express' `express-rate-limit` (its `trust proxy` warnings),
/// Phoenix's Hammer, Rails 7.2's `rate_limit to:, within:` and
/// django-ratelimit; `store:` is where a multi-instance app plugs Redis.
class RateLimit {
  /// [max] attempts per key in [window].
  ///
  /// [key] picks the counter of a request (the middleware's; `null` = not
  /// limited); default [clientIp] with [trustedProxies]. [store] defaults to
  /// a [MemoryRateLimitStore] of this isolate. [clock] is for tests.
  ///
  /// A [store] that throws does not block anyone: the attempt is allowed
  /// (a Redis outage must not lock every user out).
  RateLimit({
    required this.max,
    required this.window,
    this.trustedProxies = 0,
    String? Function(PageRequest request)? key,
    RateLimitStore? store,
    DateTime Function()? clock,
  }) : store = store ?? MemoryRateLimitStore(),
       _clock = clock ?? DateTime.now,
       _key = key {
    if (max < 0) throw ArgumentError.value(max, 'max', 'must not be negative');
    if (window <= Duration.zero) {
      throw ArgumentError.value(window, 'window', 'must be positive');
    }
    if (trustedProxies < 0) {
      throw ArgumentError.value(trustedProxies, 'trustedProxies');
    }
  }

  /// Attempts allowed per key in a window.
  final int max;

  /// How long a count lasts.
  final Duration window;

  /// How many reverse proxies in front of the server append to
  /// `X-Forwarded-For` and are trusted (0 = none: the socket's address).
  final int trustedProxies;

  /// Where the counters live.
  final RateLimitStore store;

  final DateTime Function() _clock;
  final String? Function(PageRequest request)? _key;

  /// Counts an attempt for [key].
  Future<RateLimitResult> attempt(String key) async {
    key = _canonical(key);
    final now = _clock();
    final RateLimitCount c;
    try {
      c = await store.increment(key, window, now);
    } on Object {
      return RateLimitResult(
        allowed: true,
        remaining: max,
        retryAfter: Duration.zero,
      );
    }
    final left = c.resetsAt.difference(now);
    final wait = left.inMilliseconds <= 0
        ? const Duration(seconds: 1)
        : Duration(seconds: (left.inMilliseconds / 1000).ceil());
    return RateLimitResult(
      allowed: c.count <= max,
      remaining: c.count >= max ? 0 : max - c.count,
      retryAfter: wait,
    );
  }

  /// Keys are compared trimmed and lower-cased (`Ana@x.com ` and `ana@x.com`
  /// are one account), and a long one (a form field an attacker chose) is
  /// stored as its hash, so no key costs more than a few dozen bytes.
  static String _canonical(String key) {
    final k = key.trim().toLowerCase();
    return k.length <= 128
        ? k
        : 'sha256:${sha256.convert(utf8.encode(k)).toString()}';
  }

  /// Counts an attempt for [key]: whether it may go on.
  Future<bool> take(String key) async => (await attempt(key)).allowed;

  /// Forgets [key] (after a successful login, so a user who typed their
  /// password wrong twice is not punished later).
  Future<void> reset(String key) async {
    try {
      await store.reset(_canonical(key));
    } on Object {
      // Nothing to forget in a store that is down.
    }
  }

  /// For an action: counts an attempt for [key] (default: this request's
  /// key) and returns `null` when it may go on, else the [ActionResult] to
  /// return: a `429` that draws the page again with [data] as `state.form`,
  /// and `Retry-After` set on the response.
  Future<ActionResult?> limit(
    PageRequest request, {
    String? key,
    Object? data,
  }) async {
    final k = key ?? _requestKey(request);
    if (k == null) return null;
    final result = await attempt(k);
    if (result.allowed) return null;
    request.response.headers[HttpHeader.retryAfter] =
        '${result.retryAfter.inSeconds}';
    return ActionResult.fail(429, data);
  }

  String? _requestKey(PageRequest request) => _key != null
      ? _key(request)
      : clientIp(request, trustedProxies: trustedProxies);

  /// A [Middleware] for a route group: past the limit the request ends with
  /// a [TooManyRequests] (`429`, `Retry-After`).
  Middleware middleware() => (request, next) async {
    final k = _requestKey(request);
    if (k != null) {
      final result = await attempt(k);
      if (!result.allowed) throw TooManyRequests(result.retryAfter);
    }
    return next();
  };

  /// The address [request] came from. With [trustedProxies] 0 the socket's
  /// (`X-Forwarded-For` is only a header the client wrote); with `n`, the
  /// entry `n` from the right of `X-Forwarded-For`, which the `n`th proxy
  /// appended (the ones to its left are the client's to write; a list with
  /// fewer than `n` entries did not pass the proxies and is ignored).
  /// Anything that is not an IP address falls back to the socket's. An IPv4
  /// address mapped in IPv6 (`::ffff:1.2.3.4`) is the plain IPv4, and an
  /// IPv6 address is its `/56` (`2001:db8:0:0::/56`). No address at all
  /// is `unknown`: one shared key, so it fails closed.
  static String clientIp(PageRequest request, {int trustedProxies = 0}) {
    final socket = _normalize(request.remoteAddress) ?? 'unknown';
    if (trustedProxies <= 0) return socket;
    final header = request.headers['x-forwarded-for'];
    if (header == null) return socket;
    final hops = header.split(',').map((h) => h.trim()).toList();
    // Fewer entries than proxies: the request did not go through them all
    // (it reached the server some other way), so the list is the client's.
    if (hops.length < trustedProxies) return socket;
    return _normalize(hops[hops.length - trustedProxies]) ?? socket;
  }

  /// The key of an address: IPv4 as is (mapped ones too, whatever their
  /// spelling); IPv6 by its /56, since one subscriber is usually handed a
  /// /56 (or a /64 inside it) and could otherwise change address on every
  /// attempt (express-rate-limit's `ipKeyGenerator` defaults to 56 too).
  static String? _normalize(String? address) {
    if (address == null || address.length > 64) return null;
    var text = address.trim();
    if (text.startsWith('[')) {
      final end = text.indexOf(']');
      if (end < 0) return null;
      text = text.substring(1, end); // `[v6]:port`
    } else if (RegExp(r'^[\d.]+:\d{1,5}$').hasMatch(text)) {
      text = text.substring(0, text.indexOf(':')); // `v4:port`
    }
    final ip = InternetAddress.tryParse(text);
    if (ip == null) return null;
    final raw = ip.rawAddress;
    if (ip.type == InternetAddressType.IPv4) return raw.join('.');
    if (raw.length != 16) return null;
    var mapped = raw[10] == 0xff && raw[11] == 0xff;
    for (var i = 0; i < 10 && mapped; i++) {
      mapped = raw[i] == 0;
    }
    if (mapped) return raw.sublist(12).join('.');
    String group(int i) => ((raw[i] << 8) | raw[i + 1]).toRadixString(16);
    // The first 56 bits: three groups and the high byte of the fourth.
    final fourth = (raw[6] << 8).toRadixString(16);
    return '${[for (var i = 0; i < 6; i += 2) group(i)].join(':')}:$fourth::/56';
  }
}
