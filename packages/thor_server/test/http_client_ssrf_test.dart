import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_server/src/http_guard.dart';
import 'package:thor_server/thor_server.dart';

/// The opt-in guard against SSRF (docs/guia/en/server-and-actions.md, «HTTP client»):
/// `ThorHttpClient(allowPrivateNetworks: false)` refuses to connect to a
/// loopback, private, link-local or metadata address, whatever name led
/// there (a DNS name, a decimal IP, an IPv4-mapped IPv6) and after every
/// redirect, and it connects to the address it checked (no rebinding).
void main() {
  group('isPrivateAddress', () {
    for (final a in [
      '0.0.0.0',
      '0.1.2.3',
      '10.0.0.1',
      '10.255.255.255',
      '100.64.0.1',
      '100.100.100.200', // Alibaba's metadata
      '127.0.0.1',
      '127.255.255.254',
      '169.254.169.254', // AWS, GCP, Azure metadata
      '169.254.0.1',
      '172.16.0.1',
      '172.31.255.255',
      '192.0.0.1',
      '192.168.0.1',
      '192.168.255.255',
      '198.18.0.1',
      '198.19.255.255',
      '224.0.0.1',
      '240.0.0.1',
      '255.255.255.255',
      '::',
      '::1',
      'fe80::1',
      'febf::1',
      'fc00::1',
      'fd00::1',
      'fd00:ec2::254', // AWS IMDS over IPv6
      'ff02::1',
      '::ffff:127.0.0.1',
      '::ffff:10.0.0.1',
      '::ffff:169.254.169.254',
      '::127.0.0.1',
      '64:ff9b::7f00:1', // NAT64 of 127.0.0.1
      '64:ff9b::a9fe:a9fe', // NAT64 of 169.254.169.254
      '2002:7f00:1::', // 6to4 of 127.0.0.1
      '2002:a9fe:a9fe::1', // 6to4 of 169.254.169.254
      '2001::1', // Teredo
    ]) {
      test('$a is private', () {
        expect(ThorHttpClient.isPrivateAddress(InternetAddress(a)), isTrue);
      });
    }

    for (final a in [
      '1.1.1.1',
      '8.8.8.8',
      '93.184.216.34',
      '9.255.255.255',
      '11.0.0.1',
      '100.63.255.255',
      '100.128.0.1',
      '126.255.255.255',
      '128.0.0.1',
      '169.253.255.255',
      '169.255.0.1',
      '172.15.255.255',
      '172.32.0.1',
      '192.167.255.255',
      '192.169.0.1',
      '198.17.255.255',
      '198.20.0.1',
      '223.255.255.255',
      '2606:4700:4700::1111',
      '2a00:1450:4001::200e',
      '::ffff:8.8.8.8',
      '64:ff9b::808:808', // NAT64 of 8.8.8.8
      '2002:808:808::1', // 6to4 of 8.8.8.8
      '2001:4860:4860::8888',
    ]) {
      test('$a is public', () {
        expect(ThorHttpClient.isPrivateAddress(InternetAddress(a)), isFalse);
      });
    }
  });

  group('a client that refuses private networks', () {
    late ThorHttpClient client;
    late HttpServer server;
    late List<String> hits;

    setUp(() async {
      hits = [];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((r) {
        hits.add(r.uri.path);
        r.response
          ..write('secret')
          ..close();
      });
      client = ThorHttpClient(
        allowPrivateNetworks: false,
        timeout: const Duration(seconds: 3),
      );
    });
    tearDown(() async {
      client.close(force: true);
      await server.close(force: true);
    });

    int port() => server.port;

    for (final name in [
      '127.0.0.1',
      'localhost',
      '2130706433', // 127.0.0.1 as one decimal
      '0x7f.1', // hex and short forms
      '127.1',
      '0', // 0.0.0.0 is this host on Linux and macOS
      '[::1]',
      '[::ffff:127.0.0.1]',
    ]) {
      test('http://$name is not reached', () async {
        final url = 'http://$name:${port()}/x';
        await expectLater(
          client.get(url),
          throwsA(
            isA<UpstreamError>().having(
              (e) => e.reason,
              'reason',
              anyOf(contains('private'), contains('lookup')),
            ),
          ),
        );
        expect(hits, isEmpty, reason: 'the server saw a request for $url');
      });
    }

    for (final host in [
      '169.254.169.254',
      '10.0.0.1',
      '172.16.0.1',
      '192.168.1.1',
      '100.100.100.200',
      '[fd00:ec2::254]',
      '[fe80::1]',
    ]) {
      test('http://$host fails at once, with no connection attempt', () async {
        final clock = Stopwatch()..start();
        await expectLater(
          client.get('http://$host/latest/meta-data/'),
          throwsA(
            isA<UpstreamError>().having(
              (e) => e.reason,
              'reason',
              contains('private'),
            ),
          ),
        );
        // A connect to a black hole would take the whole timeout.
        expect(clock.elapsed, lessThan(const Duration(seconds: 2)));
      });
    }

    test('every verb is guarded, a body goes nowhere', () async {
      for (final send in [
        () => client.post('http://127.0.0.1:${port()}/', json: {'a': 1}),
        () => client.put('http://127.0.0.1:${port()}/', body: [1, 2, 3]),
        () => client.delete('http://127.0.0.1:${port()}/'),
        () => client.getJson('http://127.0.0.1:${port()}/'),
      ]) {
        await expectLater(send(), throwsA(isA<UpstreamError>()));
      }
      expect(hits, isEmpty);
    });

    test('the warm-up connection is guarded too', () async {
      await client.preconnect('http://127.0.0.1:${port()}/');
      expect(hits, isEmpty);
    });

    test('the error says nothing the visitor could use', () async {
      try {
        await client.get('http://127.0.0.1:${port()}/x?token=abc');
        fail('reached');
      } on UpstreamError catch (e) {
        expect(e.status, 502);
        expect(e.toString(), isNot(contains('token')));
      }
    });
  });

  test('the default client still reaches the private network', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen(
      (r) => r.response
        ..write('ok')
        ..close(),
    );
    final client = ThorHttpClient();
    addTearDown(client.close);
    expect((await client.get('http://127.0.0.1:${server.port}/')).text, 'ok');
  });

  group('the connection factory', () {
    late HttpServer v4;
    HttpServer? v6;
    late HttpClient raw;

    setUp(() async {
      v4 = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      try {
        v6 = await HttpServer.bind(InternetAddress.loopbackIPv6, 0);
      } on SocketException {
        v6 = null;
      }
    });
    tearDown(() async {
      raw.close(force: true);
      await v4.close(force: true);
      await v6?.close(force: true);
    });

    // The first hop is allowed, the redirect points to a blocked address.
    // Only IPv6 is blocked here, so both servers are on this machine.
    test('a redirect to a blocked address is refused', () async {
      if (v6 == null) markTestSkipped('no IPv6 loopback');
      final seen = <String>[];
      v4.listen((r) {
        seen.add('v4 ${r.uri.path}');
        r.response
          ..statusCode = 302
          ..headers.set('location', 'http://[::1]:${v6!.port}/inside')
          ..close();
      });
      v6!.listen((r) {
        seen.add('v6 ${r.uri.path}');
        r.response
          ..write('inside')
          ..close();
      });
      raw = HttpClient()
        ..findProxy = ((_) => 'DIRECT')
        ..connectionFactory = guardedConnection(
          isBlocked: (a) => a.type == InternetAddressType.IPv6,
        );
      final request = await raw.getUrl(
        Uri.parse('http://127.0.0.1:${v4.port}/start'),
      );
      await expectLater(request.close(), throwsA(isA<Exception>()));
      expect(seen, ['v4 /start']);
    });

    test('it connects to the address it checked, not to the name', () async {
      // `rebind.test` first answers a public address, then a private one:
      // the factory resolves once, and the socket goes where it was checked.
      var asked = 0;
      v4.listen(
        (r) => r.response
          ..write('v4')
          ..close(),
      );
      raw = HttpClient()
        ..findProxy = ((_) => 'DIRECT')
        ..connectionFactory = guardedConnection(
          isBlocked: (a) => false,
          resolve: (host) async {
            asked++;
            return [InternetAddress.loopbackIPv4];
          },
        );
      final request = await raw.getUrl(
        Uri.parse('http://rebind.test:${v4.port}/'),
      );
      final response = await request.close();
      expect(response.statusCode, 200);
      await response.drain<void>();
      expect(asked, 1);
    });

    test('one blocked answer among many refuses the host', () async {
      raw = HttpClient()
        ..findProxy = ((_) => 'DIRECT')
        ..connectionFactory = guardedConnection(
          resolve: (host) async => [
            InternetAddress('93.184.216.34'),
            InternetAddress('169.254.169.254'),
          ],
        );
      await expectLater(
        raw.getUrl(Uri.parse('http://mixed.test/')).then((r) => r.close()),
        throwsA(isA<Exception>()),
      );
    });

    test('a name that does not resolve is an error, not a hang', () async {
      raw = HttpClient()
        ..findProxy = ((_) => 'DIRECT')
        ..connectionFactory = guardedConnection(
          resolve: (host) async => const [],
        );
      await expectLater(
        raw.getUrl(Uri.parse('http://nowhere.test/')).then((r) => r.close()),
        throwsA(isA<Exception>()),
      );
    });
  });

  // The factory makes the TLS handshake itself, against the URL's name: a
  // certificate for another name must fail, the right one must pass.
  group('https through the factory', () {
    late Directory dir;
    late SecurityContext serverContext;
    late SecurityContext clientContext;
    late HttpServer server;
    var available = true;

    setUpAll(() async {
      dir = Directory.systemTemp.createTempSync('thor-ssrf-tls');
      Future<bool> cert(String name) async {
        try {
          final r = await Process.run('openssl', [
            'req',
            '-x509',
            '-newkey',
            'rsa:2048',
            '-nodes',
            '-days',
            '1',
            '-subj',
            '/CN=$name',
            '-addext',
            'subjectAltName=DNS:$name',
            // A leaf, not a CA: the client refuses a self-signed leaf that
            // says it is a CA.
            '-addext',
            'basicConstraints=critical,CA:FALSE',
            '-addext',
            'extendedKeyUsage=serverAuth',
            '-keyout',
            '${dir.path}/$name.key',
            '-out',
            '${dir.path}/$name.pem',
          ]);
          return r.exitCode == 0;
        } on ProcessException {
          return false;
        }
      }

      available = await cert('good.test');
      if (!available) return;
      serverContext = SecurityContext()
        ..useCertificateChain('${dir.path}/good.test.pem')
        ..usePrivateKey('${dir.path}/good.test.key');
      clientContext = SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificates('${dir.path}/good.test.pem');
      server = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        0,
        serverContext,
      );
      server.listen(
        (r) => r.response
          ..write('tls')
          ..close(),
      );
    });
    tearDownAll(() async {
      dir.deleteSync(recursive: true);
      if (available) await server.close(force: true);
    });

    HttpClient client() => HttpClient()
      ..findProxy = ((_) => 'DIRECT')
      ..connectionFactory = guardedConnection(
        isBlocked: (_) => false,
        resolve: (_) async => [InternetAddress.loopbackIPv4],
        context: clientContext,
      );

    test(
      'the name of the URL is the one the certificate answers for',
      () async {
        if (!available) markTestSkipped('no openssl');
        final c = client();
        addTearDown(() => c.close(force: true));
        final r = await (await c.getUrl(
          Uri.parse('https://good.test:${server.port}/'),
        )).close();
        expect(r.statusCode, 200);
        await r.drain<void>();
      },
    );

    test('another name is a certificate error', () async {
      if (!available) markTestSkipped('no openssl');
      final c = client();
      addTearDown(() => c.close(force: true));
      await expectLater(
        c
            .getUrl(Uri.parse('https://evil.test:${server.port}/'))
            .then((r) => r.close()),
        throwsA(isA<HandshakeException>()),
      );
    });
  });

  test('the redirects followed are bounded', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var hops = 0;
    server.listen((r) {
      hops++;
      r.response
        ..statusCode = 302
        ..headers.set('location', '/loop/$hops')
        ..close();
    });
    final client = ThorHttpClient(
      maxRedirects: 2,
      timeout: const Duration(seconds: 3),
    );
    addTearDown(client.close);
    await expectLater(
      client.get('http://127.0.0.1:${server.port}/'),
      throwsA(isA<UpstreamError>()),
    );
    expect(hops, 3); // the first answer and two followed
  });
}
