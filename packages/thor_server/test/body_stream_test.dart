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

PageRequest _request(
  Stream<List<int>> body, {
  int max = 1 << 20,
  Map<HttpHeader, String> headers = const {},
  Duration timeout = const Duration(seconds: 30),
}) => PageRequest(
  method: HttpMethod.put,
  uri: Uri.parse('http://site.test/up'),
  headers: headers,
  body: body,
  maxBodyBytes: max,
  bodyReadTimeout: timeout,
);

/// A sink that records the chunks it got.
class _Sink implements StreamSink<List<int>> {
  final chunks = <List<int>>[];
  var closed = false;

  @override
  void add(List<int> data) => chunks.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.forEach(add);

  @override
  Future<void> close() async => closed = true;

  @override
  Future<void> get done async {}
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('thor_body'));
  tearDown(() => dir.deleteSync(recursive: true));

  Stream<List<int>> pieces(int n, int size) =>
      Stream.fromIterable([for (var i = 0; i < n; i++) List.filled(size, i)]);

  test(
    'pipeBody hands the chunks to the sink as they come, not as one',
    () async {
      final sink = _Sink();
      final total = await _request(pieces(50, 1000)).pipeBody(sink);
      expect(total, 50000);
      expect(sink.chunks, hasLength(50));
      expect(sink.closed, isFalse, reason: 'the caller closes its sink');
    },
  );

  test('saveBody writes the file, over what bytes() would hold', () async {
    final file = File('${dir.path}/up.bin');
    final request = _request(pieces(30, 100000), max: 4 << 20);
    final total = await request.saveBody(file);
    expect(total, 3000000);
    expect(file.lengthSync(), 3000000);
    expect(file.readAsBytesSync().sublist(100000, 100002), [1, 1]);
  });

  test('over the limit: 413, and no partial file is left', () async {
    final file = File('${dir.path}/big.bin');
    final request = _request(pieces(20, 1000), max: 5000);
    await expectLater(
      request.saveBody(file),
      throwsA(isA<HttpError>().having((e) => e.status, 'status', 413)),
    );
    expect(file.existsSync(), isFalse);
  });

  test('a declared length over the limit reads nothing', () async {
    var listened = false;
    final body =
        Stream.fromIterable([
          [1],
        ]).map((c) {
          listened = true;
          return c;
        });
    final request = _request(
      body,
      max: 10,
      headers: {HttpHeader.contentLength: '${100 << 20}'},
    );
    await expectLater(
      request.pipeBody(_Sink()),
      throwsA(isA<HttpError>().having((e) => e.status, 'status', 413)),
    );
    expect(listened, isFalse);
    expect(request.bodyRefused, isTrue);
  });

  test('a body that trickles is a 408 and the file is removed', () async {
    final file = File('${dir.path}/slow.bin');
    final controller = StreamController<List<int>>();
    final request = _request(
      controller.stream,
      timeout: const Duration(milliseconds: 200),
    );
    final timer = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => controller.add([1]),
    );
    addTearDown(() {
      timer.cancel();
      controller.close();
    });
    await expectLater(
      request.saveBody(file),
      throwsA(isA<HttpError>().having((e) => e.status, 'status', 408)),
    );
    expect(file.existsSync(), isFalse);
    expect(request.bodyRefused, isTrue);
  });

  test(
    'the body is read once: a second read of any kind is a StateError',
    () async {
      final request = _request(pieces(2, 10));
      await request.pipeBody(_Sink());
      expect(request.bytes, throwsStateError);
      expect(() => request.pipeBody(_Sink()), throwsStateError);
      final other = _request(pieces(2, 10));
      await other.bytes();
      expect(() => other.pipeBody(_Sink()), throwsStateError);
    },
  );

  test('a failing sink fails the read and still leaves no file', () async {
    final request = _request(pieces(5, 10));
    await expectLater(
      request.pipeBody(_Failing()),
      throwsA(isA<FileSystemException>()),
    );
  });

  group('saveBody is atomic', () {
    test('a failed upload keeps the file that was there', () async {
      final file = File('${dir.path}/keep.bin')..writeAsStringSync('old');
      await expectLater(
        _request(pieces(20, 1000), max: 5000).saveBody(file),
        throwsA(isA<HttpError>()),
      );
      expect(file.readAsStringSync(), 'old');
      expect(dir.listSync(), hasLength(1), reason: 'no temp file left');
    });

    test('the target only appears whole, and replaces the old one', () async {
      final file = File('${dir.path}/swap.bin')..writeAsStringSync('old');
      final controller = StreamController<List<int>>();
      final saving = _request(controller.stream).saveBody(file);
      controller.add(List.filled(1000, 7));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(file.readAsStringSync(), 'old', reason: 'not half written');
      await controller.close();
      expect(await saving, 1000);
      expect(file.lengthSync(), 1000);
      expect(dir.listSync(), hasLength(1));
    });

    test('concurrent uploads to one target each end whole', () async {
      final file = File('${dir.path}/same.bin');
      final writes = [
        for (var i = 0; i < 8; i++)
          _request(
            Stream.fromIterable([List.filled(5000, i), List.filled(5000, i)]),
          ).saveBody(file),
      ];
      await Future.wait(writes);
      final bytes = file.readAsBytesSync();
      expect(bytes, hasLength(10000));
      expect(bytes.toSet(), hasLength(1), reason: 'one upload, not a mix');
      expect(dir.listSync(), hasLength(1));
    });

    test('the temp name is not predictable', () async {
      final names = <String>{};
      for (var i = 0; i < 5; i++) {
        final controller = StreamController<List<int>>();
        final saving = _request(
          controller.stream,
        ).saveBody(File('${dir.path}/n.bin'));
        controller.add([1]);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        final temps = dir
            .listSync()
            .map((e) => e.path)
            .where((p) => !p.endsWith('n.bin'));
        names.addAll(temps);
        await controller.close();
        await saving;
      }
      expect(names, hasLength(5));
      for (final n in names) {
        expect(n, matches(RegExp(r'[0-9a-f]{16,}')));
      }
    });

    test('a folder that is not there fails and leaves nothing', () async {
      await expectLater(
        _request(pieces(2, 10)).saveBody(File('${dir.path}/nope/x.bin')),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('over HTTP', () {
    late HttpServer http;
    late File saved;

    setUp(() async {
      saved = File('${dir.path}/saved.bin');
      final server = ThorServer(
        bodyReadTimeout: const Duration(seconds: 5),
        handler: RouteHandler<String>(
          renderer: _Renderer(),
          onError: (request, error, stack) {},
          routes: [
            PageRoute<String, void>(
              path: 'up',
              build: (s) => 'up',
              maxBodyBytes: 8 << 20,
              actions: {
                'default': (r) async {
                  await r.saveBody(saved);
                  return null;
                },
              },
            ),
          ],
        ),
      );
      http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      http.listen(server.handleHttp);
    });

    tearDown(() => http.close(force: true));

    Future<int> upload(int bytes) async {
      final client = HttpClient();
      final request = await client.post('127.0.0.1', http.port, '/up');
      request.headers
        ..set('origin', 'http://127.0.0.1:${http.port}')
        ..contentType = ContentType.binary;
      request
        ..followRedirects = false
        ..contentLength = bytes;
      for (var sent = 0; sent < bytes; sent += 65536) {
        request.add(List.filled((bytes - sent).clamp(0, 65536), 7));
      }
      final response = await request.close();
      await response.drain<void>();
      client.close(force: true);
      return response.statusCode;
    }

    test(
      'a 6 MB upload on a route with its own limit lands in the file',
      () async {
        expect(await upload(6 << 20), 303);
        expect(saved.lengthSync(), 6 << 20);
      },
    );

    test('over the route limit: 413 and no file', () async {
      expect(await upload(9 << 20), 413);
      expect(saved.existsSync(), isFalse);
    });
  });
}

class _Failing extends _Sink {
  @override
  Future<void> addStream(Stream<List<int>> stream) =>
      Future.error(const FileSystemException('disk full'));

  @override
  void add(List<int> data) => throw const FileSystemException('disk full');
}
