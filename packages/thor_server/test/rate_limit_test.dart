// RateLimit: attempts per key in a window. Prior art: express-rate-limit
// (`trust proxy` pitfalls), Phoenix Hammer, Rails 7.2 `rate_limit to:,
// within:`, django-ratelimit.
import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) =>
      'error ${state.status} ${state.message}';
}

PageRequest _req(
  String method,
  String path, {
  String? ip = '10.0.0.1',
  Map<HttpHeader, String> headers = const {},
  String body = '',
}) => PageRequest(
  method: HttpMethod.tryParse(method)!,
  uri: Uri.parse('http://site.test$path'),
  remoteAddress: ip,
  headers: {
    HttpHeader.host: 'site.test',
    HttpHeader.origin: 'http://site.test',
    if (method == 'POST')
      HttpHeader.contentType: 'application/x-www-form-urlencoded',
    ...headers,
  },
  body: method == 'POST' ? Stream.value(utf8.encode(body)) : null,
);

void main() {
  late DateTime now;
  DateTime clock() => now;
  setUp(() => now = DateTime.utc(2026, 1, 1, 12));

  RateLimit limiter({
    int max = 3,
    Duration window = const Duration(minutes: 1),
    int trustedProxies = 0,
    RateLimitStore? store,
    int maxKeys = 10000,
  }) => RateLimit(
    max: max,
    window: window,
    trustedProxies: trustedProxies,
    store: store ?? MemoryRateLimitStore(maxKeys: maxKeys),
    clock: clock,
  );

  group('take', () {
    test('allows max attempts per key, then refuses', () async {
      final l = limiter();
      for (var i = 0; i < 3; i++) {
        expect(await l.take('a'), isTrue, reason: 'attempt $i');
      }
      expect(await l.take('a'), isFalse);
      expect(await l.take('b'), isTrue, reason: 'other keys are apart');
    });

    test(
      'window edges: still refused 1 s before, allowed at the end',
      () async {
        final l = limiter(max: 1);
        expect(await l.take('a'), isTrue);
        now = now.add(const Duration(seconds: 59));
        expect(await l.take('a'), isFalse);
        now = now.add(const Duration(seconds: 1));
        expect(await l.take('a'), isTrue, reason: 'a new window starts');
        expect(await l.take('a'), isFalse);
      },
    );

    test('a refused attempt does not extend the window', () async {
      final l = limiter(max: 1);
      await l.take('a');
      for (var i = 0; i < 10; i++) {
        now = now.add(const Duration(seconds: 5));
        await l.take('a');
      }
      now = now.add(const Duration(seconds: 10)); // 60 s since the first
      expect(await l.take('a'), isTrue);
    });

    test('attempt reports remaining and how long to wait', () async {
      final l = limiter(max: 2);
      var r = await l.attempt('a');
      expect((r.allowed, r.remaining), (true, 1));
      now = now.add(const Duration(seconds: 20));
      r = await l.attempt('a');
      expect((r.allowed, r.remaining), (true, 0));
      r = await l.attempt('a');
      expect(r.allowed, isFalse);
      expect(r.retryAfter, const Duration(seconds: 40));
    });

    test('retryAfter never rounds down to zero', () async {
      final l = limiter(max: 1);
      await l.take('a');
      now = now.add(const Duration(milliseconds: 59900));
      final r = await l.attempt('a');
      expect(r.allowed, isFalse);
      expect(r.retryAfter.inSeconds, 1);
    });

    test('concurrent takes never exceed max', () async {
      final l = limiter(max: 5);
      final results = await Future.wait([
        for (var i = 0; i < 100; i++) l.take('a'),
      ]);
      expect(results.where((ok) => ok), hasLength(5));
    });

    test('max 0 refuses everything', () async {
      expect(await limiter(max: 0).take('a'), isFalse);
    });

    test('a bad configuration is a mistake', () {
      expect(() => limiter(max: -1), throwsArgumentError);
      expect(() => limiter(window: Duration.zero), throwsArgumentError);
      expect(() => limiter(trustedProxies: -1), throwsArgumentError);
    });

    test('reset forgets a key (a successful login)', () async {
      final l = limiter(max: 1);
      await l.take('a');
      await l.reset('a');
      expect(await l.take('a'), isTrue);
    });
  });

  group('memory store', () {
    test('is bounded: many keys evict, never grow past maxKeys', () async {
      final store = MemoryRateLimitStore(maxKeys: 100);
      final l = limiter(store: store);
      for (var i = 0; i < 5000; i++) {
        await l.take('k$i');
      }
      expect(store.length, lessThanOrEqualTo(100));
    });

    test('expired windows go first when it is full', () async {
      final store = MemoryRateLimitStore(maxKeys: 3);
      final l = limiter(max: 1, store: store);
      await l.take('old1');
      await l.take('old2');
      now = now.add(const Duration(minutes: 2));
      await l.take('live');
      await l.take('new'); // full: the two expired ones are dropped
      expect(await l.take('live'), isFalse, reason: 'a live key survived');
      expect(store.length, lessThanOrEqualTo(3));
    });

    test('a client that hammers one key cannot evict others', () async {
      final store = MemoryRateLimitStore(maxKeys: 10);
      final l = limiter(max: 1, store: store);
      await l.take('victim');
      for (var i = 0; i < 1000; i++) {
        await l.take('attacker');
      }
      expect(await l.take('victim'), isFalse);
    });
  });

  group('client IP', () {
    test('is the socket address, ignoring X-Forwarded-For by default', () {
      final r = _req(
        'GET',
        '/',
        headers: {HttpHeader.xForwardedFor: '1.2.3.4'},
      );
      expect(RateLimit.clientIp(r), '10.0.0.1');
    });

    test('spoofed X-Forwarded-For does not dodge the limit', () async {
      final l = limiter(max: 1);
      Future<bool> hit(String spoof) => l.take(
        RateLimit.clientIp(
          _req('GET', '/', headers: {HttpHeader.xForwardedFor: spoof}),
        ),
      );
      expect(await hit('1.1.1.1'), isTrue);
      expect(await hit('2.2.2.2'), isFalse);
    });

    test('behind one trusted proxy: the address the proxy appended', () {
      // The client sent `6.6.6.6`; the proxy appended the real peer.
      final r = _req(
        'GET',
        '/',
        ip: '10.0.0.9',
        headers: {HttpHeader.xForwardedFor: '6.6.6.6, 203.0.113.7'},
      );
      expect(RateLimit.clientIp(r, trustedProxies: 1), '203.0.113.7');
    });

    test('behind two proxies: the second from the right', () {
      final r = _req(
        'GET',
        '/',
        headers: {HttpHeader.xForwardedFor: '6.6.6.6, 203.0.113.7, 10.0.0.5'},
      );
      expect(RateLimit.clientIp(r, trustedProxies: 2), '203.0.113.7');
    });

    test('a shorter list than proxies is not believed: the socket', () {
      final r = _req(
        'GET',
        '/',
        headers: {HttpHeader.xForwardedFor: '203.0.113.7'},
      );
      expect(RateLimit.clientIp(r, trustedProxies: 3), '10.0.0.1');
    });

    test('no header with trusted proxies: the socket address', () {
      expect(
        RateLimit.clientIp(_req('GET', '/'), trustedProxies: 1),
        '10.0.0.1',
      );
    });

    test('garbage in the header falls back to the socket address', () {
      for (final junk in ['', ' , ', 'not-an-ip', '<script>', 'a' * 500]) {
        final r = _req('GET', '/', headers: {HttpHeader.xForwardedFor: junk});
        expect(
          RateLimit.clientIp(r, trustedProxies: 1),
          '10.0.0.1',
          reason: junk,
        );
      }
    });

    test('IPv6 is kept, and ::ffff: mapped IPv4 matches the plain one', () {
      final v6 = _req('GET', '/', ip: '2001:db8::1');
      expect(RateLimit.clientIp(v6), '2001:db8:0:0::/56');
      final mapped = _req('GET', '/', ip: '::ffff:10.0.0.1');
      expect(RateLimit.clientIp(mapped), '10.0.0.1');
    });

    test('no address at all is one shared key (fails closed)', () {
      expect(RateLimit.clientIp(_req('GET', '/', ip: null)), 'unknown');
    });
  });

  group('middleware and actions', () {
    RouteHandler<String> handlerFor(RateLimit l) => RouteHandler<String>(
      renderer: _Renderer(),
      onError: (r, e, s) => fail('unexpected $e'),
      routes: [
        LayoutRoute<String, void>(
          build: (s, child) => child,
          error: (e) => 'error ${e.status} ${e.message}',
          middleware: l.middleware(),
          children: [PageRoute<String, void>(build: (s) => 'home')],
        ),
        PageRoute<String, void>(
          path: 'login',
          build: (s) => 'login form ${s.form ?? ''}',
          actions: {
            'default': (r) async {
              final form = await r.form();
              final limited = await l.limit(
                r,
                key: 'login:${form['email']}',
                data: {'error': 'Too many attempts'},
              );
              if (limited != null) return limited;
              return const ActionResult.fail(401, {'error': 'wrong password'});
            },
          },
        ),
      ],
    );

    test(
      'the middleware passes until the limit and answers 429 after',
      () async {
        final h = handlerFor(limiter(max: 2));
        expect((await h.handle(_req('GET', '/'))).status, 200);
        expect((await h.handle(_req('GET', '/'))).status, 200);
        final r = await h.handle(_req('GET', '/'));
        expect(r.status, 429);
        expect(r.headers['retry-after'], '60');
        expect(r.text, contains('error 429'));
      },
    );

    test(
      'the middleware limits by client IP: another IP has its own',
      () async {
        final h = handlerFor(limiter(max: 1));
        await h.handle(_req('GET', '/'));
        expect((await h.handle(_req('GET', '/'))).status, 429);
        expect((await h.handle(_req('GET', '/', ip: '10.0.0.2'))).status, 200);
      },
    );

    test('Retry-After counts down with the window', () async {
      final h = handlerFor(limiter(max: 1));
      await h.handle(_req('GET', '/'));
      now = now.add(const Duration(seconds: 45));
      final r = await h.handle(_req('GET', '/'));
      expect(r.headers['retry-after'], '15');
    });

    test(
      'an action re-renders the form with 429, the message and the header',
      () async {
        final h = handlerFor(limiter(max: 2));
        Future<ThorResponse> post() =>
            h.handle(_req('POST', '/login', body: 'email=a%40b.c'));
        expect((await post()).status, 401);
        expect((await post()).status, 401);
        final r = await post();
        expect(r.status, 429);
        expect(r.text, contains('login form'));
        expect(r.text, contains('Too many attempts'));
        expect(r.headers['retry-after'], '60');
      },
    );

    test('an action limit by account holds across IPs', () async {
      final h = handlerFor(limiter(max: 1));
      await h.handle(_req('POST', '/login', body: 'email=a%40b.c'));
      final r = await h.handle(
        _req('POST', '/login', ip: '10.9.9.9', body: 'email=a%40b.c'),
      );
      expect(r.status, 429);
      final other = await h.handle(
        _req('POST', '/login', ip: '10.9.9.9', body: 'email=x%40b.c'),
      );
      expect(other.status, 401);
    });

    test(
      'a query or command call gets JSON with the header, not a page',
      () async {
        final h = handlerFor(limiter(max: 1));
        PageRequest call() => PageRequest(
          method: HttpMethod.post,
          uri: Uri.parse('http://site.test/'),
          remoteAddress: '10.0.0.1',
          headers: {
            HttpHeader.host: 'site.test',
            HttpHeader.origin: 'http://site.test',
            HttpHeader.contentType: 'application/json',
            const HttpHeader('x-thor-query'): 'q1',
          },
          body: Stream.value(utf8.encode('{}')),
        );
        await h.handle(call());
        final r = await h.handle(call());
        expect(r.status, 429);
        expect(r.headers['content-type'], startsWith('application/json'));
        expect(r.headers['retry-after'], '60');
        final body = jsonDecode(r.text) as Map;
        expect(body['error'], isNotEmpty);
        expect(body['retryAfter'], 60);
        expect(r.text, isNot(contains('<')));
      },
    );

    test('a TooManyRequests thrown by hand carries its Retry-After', () async {
      final h = RouteHandler<String>(
        renderer: _Renderer(),
        routes: [
          PageRoute<String, void>(
            load: (r) => throw const TooManyRequests(Duration(seconds: 7)),
            build: (s) => 'x',
          ),
        ],
      );
      final r = await h.handle(_req('GET', '/'));
      expect((r.status, r.headers['retry-after']), (429, '7'));
    });

    test(
      'a custom key function: by header, null key skips the limit',
      () async {
        final l = RateLimit(
          max: 1,
          window: const Duration(minutes: 1),
          key: (r) => r.headers['x-api-key'],
          clock: clock,
        );
        final h = handlerFor(l);
        for (var i = 0; i < 5; i++) {
          expect((await h.handle(_req('GET', '/'))).status, 200);
        }
        final k = <HttpHeader, String>{const HttpHeader('x-api-key'): 'abc'};
        expect((await h.handle(_req('GET', '/', headers: k))).status, 200);
        expect((await h.handle(_req('GET', '/', headers: k))).status, 429);
      },
    );

    test(
      'a store that throws fails open and reports nothing to the client',
      () async {
        final l = RateLimit(
          max: 1,
          window: const Duration(minutes: 1),
          store: _Broken(),
          clock: clock,
        );
        final h = handlerFor(l);
        expect((await h.handle(_req('GET', '/'))).status, 200);
      },
    );

    test('a slow shared store is awaited (async stores work)', () async {
      final l = RateLimit(
        max: 1,
        window: const Duration(minutes: 1),
        store: _Slow(MemoryRateLimitStore()),
        clock: clock,
      );
      expect(await l.take('a'), isTrue);
      expect(await l.take('a'), isFalse);
    });
  });
}

class _Broken implements RateLimitStore {
  @override
  Future<RateLimitCount> increment(String key, Duration window, DateTime now) =>
      throw StateError('redis down');

  @override
  Future<void> reset(String key) async {}
}

class _Slow implements RateLimitStore {
  _Slow(this.inner);
  final RateLimitStore inner;

  @override
  Future<RateLimitCount> increment(
    String key,
    Duration window,
    DateTime now,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 1));
    return inner.increment(key, window, now);
  }

  @override
  Future<void> reset(String key) => inner.reset(key);
}
