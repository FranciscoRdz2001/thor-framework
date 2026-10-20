// Hostile inputs for the fake backends: file names, secrets, host
// boundaries, zones.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';
import 'package:thor_test/thor_test.dart';

final api = ThorHttpClient(timeout: const Duration(seconds: 2));

Future<HttpServer> _serve(
  String body, {
  String type = 'application/json',
}) async {
  final server = await HttpServer.bind('127.0.0.1', 0);
  server.listen((r) async {
    await r.drain<void>();
    r.response
      ..headers.set('content-type', type)
      ..write(body);
    await r.response.close();
  });
  return server;
}

Directory _tmp() {
  final dir = Directory.systemTemp.createTempSync('thor_http_adv');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

void main() {
  group('recorded file names', () {
    test('hostile paths stay one safe file inside the directory', () async {
      final dir = _tmp();
      final server = await _serve('{"a":1}');
      addTearDown(() => server.close(force: true));
      final p = server.port;
      final paths = [
        '/../../etc/passwd',
        '/%2e%2e%2f%2e%2e%2fx',
        '/%00x',
        '/${'a' * 5000}',
        '/ñandú/日本語?q=ü',
        '/a?x=1&x=2#frag',
      ];
      for (final path in paths) {
        await withHttpMock(
          MockTransport.recorded(dir.path, record: true),
          () => api.get('http://127.0.0.1:$p$path'),
        );
      }
      final entries = dir.listSync(recursive: true);
      expect(entries.every((e) => e is File), isTrue);
      for (final e in entries) {
        final name = e.uri.pathSegments.last;
        expect(name, matches(RegExp(r'^[A-Za-z0-9_.]+$')));
        expect(name.length, lessThan(120));
        expect(e.parent.path, dir.path);
      }
    });

    test(
      'names differing only by case do not collide on a case-insensitive FS',
      () async {
        final dir = _tmp();
        final server = await _serve('{"a":1}');
        addTearDown(() => server.close(force: true));
        for (final path in ['/Abc', '/abc']) {
          await withHttpMock(
            MockTransport.recorded(dir.path, record: true),
            () => api.get('http://127.0.0.1:${server.port}$path'),
          );
        }
        final lower = dir.listSync().map(
          (e) => e.uri.pathSegments.last.toLowerCase(),
        );
        expect(lower.toSet(), hasLength(2));
      },
    );

    test(
      'POSTs with different bodies to one URL are different recordings',
      () async {
        final dir = _tmp();
        final server = await _serve('{"a":1}');
        addTearDown(() => server.close(force: true));
        final url = 'http://127.0.0.1:${server.port}/cart';
        for (final sku in ['a', 'b']) {
          await withHttpMock(
            MockTransport.recorded(dir.path, record: true),
            () => api.post(url, json: {'sku': sku}),
          );
        }
        expect(dir.listSync(), hasLength(2));
      },
    );

    test('secrets in the URL never reach a file name or its content', () async {
      final dir = _tmp();
      final server = await _serve('{"a":1}');
      addTearDown(() => server.close(force: true));
      final url =
          'http://user:hunter2@127.0.0.1:${server.port}/x?token=SEKRET&api_key=KEY2&q=shoes';
      await withHttpMock(
        MockTransport.recorded(dir.path, record: true),
        () => api.get(url),
      );
      final file = dir.listSync().single as File;
      final all = '${file.uri.pathSegments.last}\n${file.readAsStringSync()}';
      for (final secret in ['SEKRET', 'hunter2', 'KEY2', 'user:']) {
        expect(all, isNot(contains(secret)));
      }
      expect(all, contains('q=shoes'));
    });

    test('a rotated token still replays the same recording', () async {
      final dir = _tmp();
      final server = await _serve('{"a":1}');
      final base = 'http://127.0.0.1:${server.port}/x?token=';
      await withHttpMock(
        MockTransport.recorded(dir.path, record: true),
        () => api.get('${base}one'),
      );
      await server.close(force: true);
      final res = await withHttpMock(
        MockTransport.recorded(dir.path, record: false),
        () => api.get('${base}two'),
      );
      expect(res.json(), {'a': 1});
    });

    test('a body that is not canonical JSON replays byte for byte', () async {
      final dir = _tmp();
      const body = '{"n": 1e2,\n "big":12345678901234567890}';
      final server = await _serve(body, type: 'text/plain');
      final url = 'http://127.0.0.1:${server.port}/raw';
      await withHttpMock(
        MockTransport.recorded(dir.path, record: true),
        () => api.get(url),
      );
      await server.close(force: true);
      final res = await withHttpMock(
        MockTransport.recorded(dir.path, record: false),
        () => api.get(url),
      );
      expect(res.text, body);
    });
  });

  group('prefix keys', () {
    ThorHttpRequest req(String url, [HttpMethod method = HttpMethod.get]) =>
        ThorHttpRequest(
          method,
          Uri.parse(url),
          {},
          Uint8List(0),
          () => throw 0,
        );

    test('a host prefix does not match another host', () async {
      final m = MockTransport.fixtures({'https://a.com*': 1});
      await m.call(req('https://a.com/x'));
      await m.call(req('https://a.com'));
      await m.call(req('https://a.com:8443/x'));
      for (final evil in [
        'https://a.com.evil.io/',
        'https://a.com@evil.io/',
        'https://a.comx/',
      ]) {
        await expectLater(
          m.call(req(evil)),
          throwsA(isA<UnmockedHttpRequest>()),
        );
      }
    });

    test('a path prefix still matches by prefix', () async {
      final m = MockTransport.fixtures({'https://a.com/x*': 1});
      await m.call(req('https://a.com/xy'));
      await expectLater(
        m.call(req('https://a.com.evil/x')),
        throwsA(isA<UnmockedHttpRequest>()),
      );
    });

    test('HEAD and OPTIONS match their own method keys', () async {
      final m = MockTransport.fixtures({
        'HEAD https://a.com/x': 1,
        'OPTIONS https://a.com/x': 2,
      });
      expect((await m.call(req('https://a.com/x', HttpMethod.head))).json(), 1);
      expect(
        (await m.call(req('https://a.com/x', HttpMethod.options))).json(),
        2,
      );
      await expectLater(
        m.call(req('https://a.com/x')),
        throwsA(isA<UnmockedHttpRequest>()),
      );
    });
  });

  group('zones', () {
    test('concurrent zones each see their own fake', () async {
      Future<Object?> one(String v) =>
          withHttpFixtures({'GET http://x.test/a': v}, () async {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return (await api.get('http://x.test/a')).json();
          });
      expect(await Future.wait([one('A'), one('B')]), ['A', 'B']);
    });

    test('the inner fake wins and the outer is back after it', () async {
      await withHttpFixtures({'GET http://x.test/a': 'outer'}, () async {
        await withHttpFixtures({'GET http://x.test/a': 'inner'}, () async {
          expect((await api.get('http://x.test/a')).json(), 'inner');
        });
        expect((await api.get('http://x.test/a')).json(), 'outer');
      });
    });

    test('no fake leaks out of the zone', () async {
      await withHttpFixtures({'GET http://127.0.0.1:1/a': 1}, () async {});
      await expectLater(
        api.get('http://127.0.0.1:1/a'),
        throwsA(isA<UpstreamError>()),
      );
    });

    test('a call after the zone ended still fails, not silently', () async {
      late Future<void> late_;
      final mock = MockTransport.fixtures({});
      await expectLater(
        withHttpMock(mock, () async {
          late_ = Future<void>.delayed(
            const Duration(milliseconds: 20),
            () => api.get('http://x.test/late'),
          ).then((_) {}, onError: (_) {});
        }),
        completes,
      );
      await late_;
      // The late call reached the fake of its zone: it is on record.
      expect(mock.unmatched, hasLength(1));
    });

    test('both catch styles leave the failure in verify()', () async {
      for (final style in ['object', 'any']) {
        final mock = MockTransport.fixtures({});
        await expectLater(
          withHttpMock(mock, () async {
            try {
              await api.get('http://x.test/a');
            } on Object catch (_) {
              // swallowed
            }
          }),
          throwsA(isA<UnmockedHttpRequest>()),
          reason: style,
        );
      }
      final mock = MockTransport.fixtures({});
      await expectLater(
        withHttpMock(mock, () async {
          try {
            await api.get('http://x.test/a');
            // ignore: avoid_catches_without_on_clauses
          } catch (_) {}
        }),
        throwsA(isA<UnmockedHttpRequest>()),
      );
    });

    test('a fake that never answers hits the client timeout', () async {
      final slow = ThorHttpClient(timeout: const Duration(milliseconds: 100));
      final never = Completer<ThorHttpResponse>();
      await expectLater(
        runWithThorHttpTransport(
          (r) => never.future,
          () => slow.get('http://x.test/'),
        ),
        throwsA(isA<UpstreamError>()),
      );
    });

    test('bodyBytes can be read twice', () async {
      final seen = <String>[];
      await withHttpFixtures({
        'POST http://x.test/p': (ThorHttpRequest r) {
          seen
            ..add(r.text)
            ..add(r.text);
          return 1;
        },
      }, () => api.post('http://x.test/p', body: utf8.encode('x' * 100000)));
      expect(seen.first, seen.last);
      expect(seen.first.length, 100000);
    });
  });
}
