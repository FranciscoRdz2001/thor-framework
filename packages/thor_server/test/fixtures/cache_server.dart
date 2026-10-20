// A server for cache_bus_test: a cached page that shows a number kept in a
// file (shared by every isolate) and the isolate that drew it, a form action
// and a command that change the number, and one action that fails.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:thor_server/thor_server.dart';

// Each isolate has its own statics: the folder travels in the environment.
// The number is how many files it holds (one per write, with a name of its
// own, so writes from several isolates at once don't lose one).
Directory get _data => Directory(Platform.environment['CACHE_DATA']!);

int _read() => _data.listSync().length;

var _n = 0;

void _bump() => File(
  '${_data.path}/${Isolate.current.debugName}-${_n++}',
).writeAsStringSync('');

class _Renderer implements PageRenderer<String>, ServerCommands, ServerCallIds {
  @override
  ServerMessages get serverMessages => const ServerMessages();

  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';

  @override
  bool declaresCall(String id) => id == 'Data.bump';

  @override
  Set<String> queriesFound(RenderContext context) => {'Data.bump'};

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
  }) async {
    if (arg == 'fail') throw const HttpError(409, 'nope');
    _bump();
    return const CommandAnswer(result: null);
  }
}

Future<void> main(List<String> args) {
  return ThorServer.serve(
    () => ThorServer(
      handler: RouteHandler<String>(
        renderer: _Renderer(),
        routes: [
          PageRoute<String, int>(
            path: 'pinned',
            tags: const ['p'],
            invalidateOnWrite: false,
            load: (_) => _read(),
            build: (s) => 'v=${s.data} iso=${Isolate.current.debugName}',
            cache: const Duration(minutes: 5),
            actions: {
              'touch': (r) {
                _bump();
                revalidateTag('p');
                return null;
              },
            },
          ),
          PageRoute<String, int>(
            path: 'tagged',
            tags: const ['t'],
            load: (_) => _read(),
            build: (s) => 'v=${s.data} iso=${Isolate.current.debugName}',
            cache: const Duration(minutes: 5),
            actions: {
              'touch': (r) {
                _bump();
                revalidateTag('t');
                return null;
              },
            },
          ),
          PageRoute<String, int>(
            load: (_) => _read(),
            build: (s) => 'v=${s.data} iso=${Isolate.current.debugName}',
            cache: const Duration(minutes: 5),
            actions: {
              'bump': (r) {
                _bump();
                return null;
              },
              'fail': (r) => const ActionResult.fail(422, {'error': 'no'}),
            },
          ),
        ],
      ),
    ),
    address: InternetAddress.loopbackIPv4,
    port: int.parse(args[0]),
    isolates: int.parse(args[1]),
    shutdownTimeout: const Duration(seconds: 2),
  );
}
