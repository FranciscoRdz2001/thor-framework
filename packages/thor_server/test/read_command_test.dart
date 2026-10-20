// A command made with `writes: false` (a read the visitor asks for) keeps the
// page cache and sends no Clear-Site-Data; a default command clears both.
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String>, ServerCommands, ServerCallIds {
  @override
  ServerMessages get serverMessages => const ServerMessages();

  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';

  @override
  bool declaresCall(String id) => id == 'S.read' || id == 'S.write';

  @override
  Set<String> queriesFound(RenderContext context) => {'S.read', 'S.write'};

  @override
  List<(Object, StackTrace)> queryErrorsFound(RenderContext context) => [];

  @override
  Future<Object?> runQuery(PageRequest request, String id, Object? arg) async =>
      null;

  @override
  Future<CommandAnswer> runCommand(
    PageRequest request,
    String id,
    Object? arg, {
    required Set<String> refresh,
    required Map<String, Object?> queryArgs,
  }) async => CommandAnswer(result: null, writes: id != 'S.read');
}

PageRequest _get() => PageRequest(
  method: HttpMethod.get,
  uri: Uri.parse('http://site.test/'),
  headers: const {HttpHeader.host: 'site.test'},
);

PageRequest _command(String id) => PageRequest(
  method: HttpMethod.post,
  uri: Uri.parse('http://site.test/'),
  headers: {
    HttpHeader.host: 'site.test',
    HttpHeader.origin: 'http://site.test',
    HttpHeader.contentType: 'application/json',
    const HttpHeader('x-thor-command'): id,
  },
  body: Stream.value(utf8.encode('{}')),
);

void main() {
  var draws = 0;
  final handler = RouteHandler<String>(
    renderer: _Renderer(),
    onError: (request, error, stack) {},
    routes: [
      PageRoute<String, void>(
        cache: const Duration(minutes: 1),
        build: (s) => 'draw ${++draws}',
      ),
    ],
  );

  Future<String> body(PageRequest r) async =>
      utf8.decode((await handler.handle(r)).body);

  test(
    'writes: false keeps the page cache; a default command clears it',
    () async {
      expect(await body(_get()), 'draw 1');
      expect(await body(_get()), 'draw 1', reason: 'cached');

      final read = await handler.handle(_command('S.read'));
      expect(read.status, 200);
      expect(
        read.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('clear-site-data')),
      );
      expect(await body(_get()), 'draw 1', reason: 'still served from cache');

      final write = await handler.handle(_command('S.write'));
      expect(write.status, 200);
      expect(write.headers['clear-site-data'], contains('prefetchCache'));
      expect(await body(_get()), 'draw 2', reason: 'the write cleared it');
    },
  );
}
