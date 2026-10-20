// Adversarial checks of the Host filter of `thor dev` (DNS rebinding), with
// raw sockets: what a hostile page can and can't make a browser send.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_cli/src/dev_proxy.dart';
import 'package:thor_server/thor_server.dart' show DevHosts;

void main() {
  late HttpServer app;
  late DevProxy proxy;
  final seen = <String>[];

  setUp(() async {
    seen.clear();
    app = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    app.listen((r) async {
      seen.add('${r.method} ${r.uri} host=${r.headers.value('host')}');
      r.response
        ..headers.contentType = ContentType.text
        ..write('secret');
      await r.response.close();
    });
    proxy = DevProxy(upstream: app.port);
    await proxy.start(0);
    proxy.ready();
  });

  tearDown(() async {
    await proxy.close();
    await app.close(force: true);
  });

  /// The bytes sent as they are; the whole answer (empty if it hangs up).
  Future<String> raw(List<int> request) async {
    final socket = await Socket.connect('127.0.0.1', proxy.port);
    socket.add(request);
    final answer = await latin1
        .decodeStream(socket)
        .timeout(const Duration(seconds: 5), onTimeout: () => 'TIMEOUT');
    socket.destroy();
    return answer;
  }

  int status(String answer) =>
      answer.startsWith('HTTP/') ? int.parse(answer.split(' ')[1]) : -1;

  Future<int> get(String headers, {String target = '/x'}) async => status(
    await raw(latin1.encode('GET $target HTTP/1.1\r\n$headers\r\n\r\n')),
  );

  group('a hostile Host never reaches the app', () {
    for (final host in [
      'localhost:80@evil.example',
      'evil.example#localhost',
      'evil.example?localhost',
      'evil.example/localhost',
      'evil.example\\localhost',
      'localhost.evil.example',
      'localhost..',
      '127.0.0.1.nip.io',
      '127.0.0.1.nip.io:4300',
      '0x7f.0.0.1.evil.example',
      'xn--lcalhost-evil',
      'localhost%2eevil.example',
      'localhost;evil.example',
      'localhost evil.example',
      'localhost,evil.example',
      '[::1]@evil.example',
      '[evil.example]',
      '[127.0.0.1]',
      'localhost:80:80',
      'localhost:99999999',
    ]) {
      test(host, () async {
        expect(await get('Host: $host\r\nConnection: close'), isNot(200));
        expect(seen, isEmpty);
      });
    }

    test('bytes above ASCII (a Cyrillic o in localhost)', () async {
      final request = [
        ...latin1.encode('GET /x HTTP/1.1\r\nHost: l'),
        ...utf8.encode('о'),
        ...latin1.encode('calhost\r\nConnection: close\r\n\r\n'),
      ];
      expect(status(await raw(request)), isNot(200));
      expect(seen, isEmpty);
    });

    test('a NUL byte after localhost', () async {
      final request = [
        ...latin1.encode('GET /x HTTP/1.1\r\nHost: localhost'),
        0,
        ...latin1.encode('.evil.example\r\nConnection: close\r\n\r\n'),
      ];
      expect(status(await raw(request)), isNot(200));
      expect(seen, isEmpty);
    });

    test('a huge Host', () async {
      final host = 'a' * 100000;
      expect(await get('Host: $host\r\nConnection: close'), isNot(200));
      expect(seen, isEmpty);
    });
  });

  group('two Host headers', () {
    // dart:io keeps the last one: what is checked is what the app gets, and a
    // browser never sends two.
    test('what is served is what was checked', () async {
      for (final headers in [
        'Host: evil.example\r\nHost: localhost',
        'Host: localhost\r\nHost: evil.example',
      ]) {
        seen.clear();
        final s = await get('$headers\r\nConnection: close');
        if (s == 200) expect(seen.single, endsWith('host=localhost'));
        expect(seen.where((r) => r.contains('evil')), isEmpty);
        // Still up.
        expect(await get('Host: localhost\r\nConnection: close'), 200);
      }
    });
  });

  group('the request target', () {
    test('absolute-form for a foreign host with Host: localhost', () async {
      // RFC 9112 3.2.2: the target's authority wins over Host.
      final s = await get(
        'Host: localhost\r\nConnection: close',
        target: 'http://evil.example/secret',
      );
      expect(s, isNot(200));
      expect(seen, isEmpty);
    });

    test(
      'a foreign X-Forwarded-Host or Origin does not matter, Host does',
      () async {
        expect(
          await get(
            'Host: evil.example\r\nX-Forwarded-Host: localhost\r\n'
            'Origin: http://localhost\r\nConnection: close',
          ),
          403,
        );
        expect(seen, isEmpty);
      },
    );
  });

  group('the channels', () {
    test('events, hot reload and upgrades with a foreign Host: 403', () async {
      for (final path in [DevProxy.eventsPath, '/', '/x', '/_thor/anything']) {
        expect(
          await get(
            'Host: attacker.example:${proxy.port}\r\n'
            'Accept: text/event-stream\r\nConnection: close',
            target: path,
          ),
          403,
          reason: path,
        );
      }
      expect(
        await get(
          'Host: attacker.example:${proxy.port}\r\nConnection: Upgrade\r\n'
          'Upgrade: websocket\r\nSec-WebSocket-Version: 13\r\n'
          'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n'
          'Origin: http://attacker.example:${proxy.port}',
          target: DevProxy.eventsPath,
        ),
        403,
      );
      expect(seen, isEmpty);
    });

    test(
      'the events stream sends no CORS header (a page can not read it)',
      () async {
        final socket = await Socket.connect('127.0.0.1', proxy.port);
        socket.write(
          'GET ${DevProxy.eventsPath} HTTP/1.1\r\nHost: localhost\r\n'
          'Origin: http://attacker.example\r\n\r\n',
        );
        final head = StringBuffer();
        await for (final chunk in socket.timeout(
          const Duration(seconds: 3),
          onTimeout: (s) => s.close(),
        )) {
          head.write(latin1.decode(chunk));
          if (head.toString().contains('\r\n\r\n')) break;
        }
        socket.destroy();
        expect(
          head.toString().toLowerCase(),
          isNot(contains('access-control')),
        );
      },
    );
  });

  group('allowed forms', () {
    for (final host in [
      'LOCALHOST.:1',
      '127.0.0.1:1',
      '[::1]:1',
      '[::ffff:127.0.0.1]:1',
      '192.168.1.5',
      'a.b.localhost',
      '[fe80::1%25en0]:1',
      '[fe80::1]',
      '10.1.2.3.',
    ]) {
      test(host, () async {
        expect(await get('Host: $host\r\nConnection: close'), 200);
      });
    }
  });

  group('--allowed-host', () {
    Future<int> with_(List<String> allowed, String host) async {
      final other = DevProxy(upstream: app.port, hosts: DevHosts(allowed));
      await other.start(0);
      other.ready();
      final socket = await Socket.connect('127.0.0.1', other.port);
      socket.write(
        'GET /x HTTP/1.1\r\nHost: $host\r\nConnection: close\r\n\r\n',
      );
      final answer = await latin1.decodeStream(socket);
      socket.destroy();
      await other.close();
      return status(answer);
    }

    test('.example allows example and its subdomains only', () async {
      expect(await with_(['.example.test'], 'a.example.test'), 200);
      expect(await with_(['.example.test'], 'example.test'), 200);
      expect(await with_(['.example.test'], 'evilexample.test'), 403);
      expect(await with_(['.example.test'], 'example.test.evil.example'), 403);
    });

    test('a name with no dot is exact', () async {
      expect(await with_(['dev.test'], 'a.dev.test'), 403);
      expect(await with_(['dev.test'], 'dev.test:4300'), 200);
    });

    test('a wildcard glob is not a rule (it allows nothing)', () async {
      expect(await with_(['*.example.test'], 'a.example.test'), 403);
    });

    test('empty and odd entries allow nothing', () async {
      expect(await with_(['', ' ', '.', '..', ','], 'evil.example'), 403);
    });

    test('the list is parsed from the environment format', () async {
      final hosts = DevHosts.parse(' a.test , ,.b.test,');
      expect(hosts.allows('a.test'), isTrue);
      expect(hosts.allows('x.b.test'), isTrue);
      expect(hosts.allows('evil.test'), isFalse);
      expect(DevHosts.parse(null).allows('evil.test'), isFalse);
      expect(DevHosts.parse('').allows('evil.test'), isFalse);
    });
  });
}
