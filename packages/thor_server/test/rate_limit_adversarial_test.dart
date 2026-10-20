// RateLimit, attacker's view. Prior art: express-rate-limit `ipKeyGenerator`
// (IPv6 subnet), OWASP credential stuffing / authentication cheat sheets.
import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

PageRequest _req({
  String? ip = '10.0.0.1',
  Map<HttpHeader, String> headers = const {},
}) => PageRequest(
  method: HttpMethod.get,
  uri: Uri.parse('http://site.test/'),
  remoteAddress: ip,
  headers: {HttpHeader.host: 'site.test', ...headers},
);

void main() {
  late DateTime now;
  setUp(() => now = DateTime.utc(2026, 1, 1, 12));
  RateLimit limiter({int max = 3, RateLimitStore? store}) => RateLimit(
    max: max,
    window: const Duration(minutes: 1),
    store: store,
    clock: () => now,
  );

  group('key normalization', () {
    test('case and padding of an account key share one counter', () async {
      final l = limiter(max: 1);
      expect(await l.take('login:ana@x.com'), isTrue);
      expect(await l.take('login:ANA@x.com'), isFalse);
      expect(await l.take('  login:Ana@X.com '), isFalse);
    });

    test('a huge key does not sit in memory as is', () async {
      final seen = <String>[];
      final l = limiter(store: _Spy(seen));
      await l.take('x' * 100000);
      expect(seen.single.length, lessThan(200));
      // Two different huge keys still differ.
      await l.take('${'x' * 100000}y');
      expect(seen.first, isNot(seen.last));
    });
  });

  group('IP keys', () {
    test('rotating inside one IPv6 /56 is one client', () {
      // A subscriber's /56 holds 256 /64s: all of them are one client.
      final a = RateLimit.clientIp(_req(ip: '2001:db8:1:200::1'));
      final b = RateLimit.clientIp(_req(ip: '2001:db8:1:2ff:ffff::9'));
      final other = RateLimit.clientIp(_req(ip: '2001:db8:1:300::1'));
      expect(a, b);
      expect(a, '2001:db8:1:200::/56');
      expect(a, isNot(other));
    });

    test('IPv4 mapped in hex form is the plain IPv4', () {
      expect(RateLimit.clientIp(_req(ip: '::ffff:a00:1')), '10.0.0.1');
    });

    test('a list shorter than the trusted proxies is not believed', () {
      final r = _req(headers: {HttpHeader.xForwardedFor: '6.6.6.6'});
      expect(RateLimit.clientIp(r, trustedProxies: 2), '10.0.0.1');
    });

    test('ports in the appended entry are ignored', () {
      final r = _req(
        ip: '10.0.0.9',
        headers: {HttpHeader.xForwardedFor: '6.6.6.6, 203.0.113.7:51234'},
      );
      expect(RateLimit.clientIp(r, trustedProxies: 1), '203.0.113.7');
      final v6 = _req(
        ip: '10.0.0.9',
        headers: {HttpHeader.xForwardedFor: '[2001:db8:1:2::5]:443'},
      );
      expect(
        RateLimit.clientIp(v6, trustedProxies: 1),
        RateLimit.clientIp(_req(ip: '2001:db8:1:2::9')),
      );
    });

    test('client-written entries to the left never pick the key', () {
      for (final lead in ['1.1.1.1', 'a, b', '9.9.9.9, 8.8.8.8, 7.7.7.7']) {
        final r = _req(
          ip: '10.0.0.9',
          headers: {HttpHeader.xForwardedFor: '$lead, 203.0.113.7'},
        );
        expect(RateLimit.clientIp(r, trustedProxies: 1), '203.0.113.7');
      }
    });
  });

  group('memory store eviction', () {
    test('flooding new keys does not reset a counter that is spent', () async {
      final store = MemoryRateLimitStore(maxKeys: 50);
      final l = limiter(max: 2, store: store);
      expect(await l.take('victim'), isTrue);
      expect(await l.take('victim'), isTrue);
      expect(await l.take('victim'), isFalse); // blocked
      for (var i = 0; i < 500; i++) {
        await l.take('flood$i');
      }
      expect(await l.take('victim'), isFalse, reason: 'still blocked');
      expect(store.length, lessThanOrEqualTo(50));
    });
  });

  test('a throwing store fails open and never throws', () async {
    final l = limiter(store: _Throws());
    expect(await l.take('a'), isTrue);
    await l.reset('a');
  });
}

class _Spy implements RateLimitStore {
  _Spy(this.keys);
  final List<String> keys;
  @override
  Future<RateLimitCount> increment(String k, Duration w, DateTime n) async {
    keys.add(k);
    return RateLimitCount(1, n.add(w));
  }

  @override
  Future<void> reset(String key) async {}
}

class _Throws implements RateLimitStore {
  @override
  Future<RateLimitCount> increment(String k, Duration w, DateTime n) =>
      throw StateError('down');

  @override
  Future<void> reset(String key) => throw StateError('down');
}
