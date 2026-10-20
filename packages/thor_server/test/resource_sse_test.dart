@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

void main() {
  late HttpServer http;
  var cleaned = Completer<void>();
  var heartbeat = const Duration(milliseconds: 100);
  // ignore: close_sinks
  late StreamController<ServerEvent> source;
  // Sinks of the test, closed with the server.

  setUp(() async {
    cleaned = Completer<void>();
    // ignore: close_sinks
    source = StreamController<ServerEvent>();
    final server = ThorServer(
      handler: RouteHandler<String>(
        renderer: _Renderer(),
        onError: (request, error, stack) {},
        routes: [
          ResourceRoute<String>(
            path: 'data.json',
            respond: (r) => ThorResponse.json({
              'a': 1,
              'html': '</script>',
            }, maxAge: const Duration(minutes: 5)),
          ),
          ResourceRoute<String>(
            path: 'logo.bin',
            respond: (r) => ThorResponse.bytes(
              [1, 2, 3],
              contentType: 'application/octet-stream',
              maxAge: const Duration(days: 365),
              immutable: true,
            ),
          ),
          ResourceRoute<String>(
            path: 'resume',
            respond: (r) => ThorResponse.events(
              Stream.value(
                ServerEvent(
                  'after ${r.lastEventId}',
                  id: '${int.parse(r.lastEventId ?? '0') + 1}',
                ),
              ),
              heartbeat: Duration.zero,
            ),
          ),
          ResourceRoute<String>(
            path: 'events',
            respond: (r) {
              // ignore: close_sinks
              final events = StreamController<ServerEvent>(
                onListen: () {},
                onCancel: () => cleaned.complete(),
              );
              events.addStream(source.stream);
              return ThorResponse.events(events.stream, heartbeat: heartbeat);
            },
          ),
        ],
      ),
    );
    http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    http.listen(server.handleHttp);
  });

  tearDown(() async {
    await http.close(force: true);
  });

  Future<HttpClientResponse> get(
    String path, {
    Map<String, String> headers = const {},
    HttpClient? client,
  }) async {
    final c = client ?? HttpClient();
    final request = await c.get('127.0.0.1', http.port, path);
    headers.forEach(request.headers.set);
    return request.close();
  }

  group('resource', () {
    test('JSON: type, cache, ETag, escaped, 304 on a match', () async {
      final r = await get('/data.json');
      expect(r.statusCode, 200);
      expect(r.headers.contentType?.mimeType, 'application/json');
      expect(r.headers.value('cache-control'), 'public, max-age=300');
      final body = await utf8.decodeStream(r);
      expect(body, isNot(contains('</script>')), reason: '< is escaped');
      expect(jsonDecode(body), {'a': 1, 'html': '</script>'});
      final etag = r.headers.value('etag')!;
      final again = await get('/data.json', headers: {'if-none-match': etag});
      expect(again.statusCode, 304);
      await again.drain<void>();
    });

    test('bytes: type, immutable cache, nosniff', () async {
      final r = await get('/logo.bin');
      expect(
        r.headers.value('cache-control'),
        'public, max-age=31536000, immutable',
      );
      expect(r.headers.value('x-content-type-options'), 'nosniff');
      expect(await r.fold<List<int>>([], (a, b) => [...a, ...b]), [1, 2, 3]);
    });
  });

  group('server-sent events', () {
    Future<(HttpClient, Stream<String>, HttpClientResponse)> open() async {
      final client = HttpClient();
      final r = await get(
        '/events',
        headers: {'accept-encoding': 'gzip'},
        client: client,
      );
      return (client, r.transform(utf8.decoder), r);
    }

    test('headers: event-stream, no cache, no gzip, no buffering', () async {
      final (client, _, r) = await open();
      addTearDown(() => client.close(force: true));
      expect(r.statusCode, 200);
      expect(r.headers.contentType?.mimeType, 'text/event-stream');
      expect(r.headers.value('cache-control'), 'no-store');
      expect(r.headers.value('content-encoding'), isNull);
      expect(r.headers.value('x-accel-buffering'), 'no');
    });

    test('an event arrives as it is added, in the wire format', () async {
      final (client, text, _) = await open();
      addTearDown(() => client.close(force: true));
      final chunks = StreamIterator(text);
      source.add(const ServerEvent('line1\nline2', event: 'tick', id: '7'));
      var got = '';
      while (!got.contains('line2')) {
        expect(await chunks.moveNext(), isTrue);
        got += chunks.current;
      }
      expect(got, contains('id: 7\n'));
      expect(got, contains('event: tick\n'));
      expect(got, contains('data: line1\ndata: line2\n\n'));
    });

    test('a newline in the event name cannot forge another field', () {
      expect(
        const ServerEvent('x', event: 'a\ndata: forged').encode(),
        isNot(contains('data: forged')),
      );
      expect(
        utf8.decode(const ServerEvent('a\r\nb\rc').encode()),
        'data: a\ndata: b\ndata: c\n\n',
      );
    });

    test('Last-Event-ID reaches the route to resume from', () async {
      final r = await get('/resume', headers: {'Last-Event-ID': '41'});
      final text = await utf8.decodeStream(r);
      expect(text, contains('id: 42\n'));
      expect(text, contains('data: after 41\n'));
    });

    test('an idle stream sends a heartbeat comment', () async {
      final (client, text, _) = await open();
      addTearDown(() => client.close(force: true));
      final first = await text.first.timeout(const Duration(seconds: 5));
      expect(first, startsWith(':'));
    });

    test('the source is cancelled at once when the client leaves', () async {
      // Far longer than the wait below: only noticing the closed socket,
      // not the next heartbeat, can free the source in time.
      heartbeat = const Duration(seconds: 30);
      final (client, text, _) = await open();
      final sub = text.listen((_) {});
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await sub.cancel();
      client.close(force: true);
      await cleaned.future.timeout(const Duration(seconds: 5));
    });
  });
}
