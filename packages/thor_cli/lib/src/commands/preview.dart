import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../dotenv.dart';
import '../run.dart';
import '../stop_signals.dart';
import 'base.dart';

/// `thor preview`: the release as a host would serve it.
///
/// `build/site` (a static build or export) with the hosts' clean URLs
/// (`/guia/x` → `guia/x.html`) and `404.html`; or `build/server`.
class PreviewCommand extends Command<int> with ProjectCommand {
  /// The command.
  PreviewCommand() {
    argParser.addOption('port', abbr: 'p', defaultsTo: '4400');
  }

  @override
  String get name => 'preview';

  @override
  String get description => 'Serve the release (build/site or build/server).';

  @override
  String get invocation => 'thor preview [project]';

  @override
  Future<int> run() async {
    final wanted = parsePort(argResults!['port'] as String);
    final app = resolveProject();
    final port = await previewPort(
      wanted,
      explicit: argResults!.wasParsed('port'),
    );
    final site = Directory(app.path('build/site'));
    final server = File(app.path('build/server'));
    if (site.existsSync()) {
      final http = await serveStatic(site.path, port);
      Say.ok(
        'http://localhost:$port  (${p.relative(site.path)}, Ctrl-C to stop)',
      );
      await _untilStopped();
      await http.close(force: true);
      return 0;
    }
    if (server.existsSync()) {
      Say.ok(
        'http://localhost:$port  (${p.relative(server.path)}, Ctrl-C to stop)',
      );
      final process = await Process.start(
        server.path,
        const [],
        workingDirectory: app.dir,
        environment: appEnvironment(app.dir, {'PORT': '$port'}),
        mode: ProcessStartMode.inheritStdio,
      );
      return superviseChild(process);
    }
    throw ThorException('Nothing built yet: run thor build (or thor export).');
  }
}

Future<void> _untilStopped() {
  final done = Completer<void>();
  final subs = <StreamSubscription<ProcessSignal>>[];
  for (final signal in stopSignals()) {
    subs.add(
      signal.watch().listen((_) {
        if (!done.isCompleted) done.complete();
      }),
    );
  }
  return done.future.whenComplete(() {
    for (final s in subs) {
      unawaited(s.cancel());
    }
  });
}

/// Waits for [child] and returns its exit code, so this process lives exactly
/// as long as it: a signal for this one (Ctrl-C, `kill`) goes on to the
/// child, which is stopped for good ([grace] later) if it ignores it. The
/// signal handlers are dropped when the child is gone, or they would keep
/// this process alive after it.
Future<int> superviseChild(
  Process child, {
  Duration grace = const Duration(seconds: 5),
}) async {
  Timer? hard;
  final subs = [
    for (final signal in stopSignals())
      signal.watch().listen((_) {
        child.kill();
        hard ??= Timer(grace, () => child.kill(ProcessSignal.sigkill));
      }),
  ];
  final code = await child.exitCode;
  hard?.cancel();
  for (final s in subs) {
    await s.cancel();
  }
  // Killed by a signal: the shell's convention.
  return code < 0 ? 128 - code : code;
}

/// Serves [root] like a static host: `/a` → `a.html` or `a/index.html`,
/// a missing page → `404.html` with status 404.
Future<HttpServer> serveStatic(String root, int port) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  server.listen((request) async {
    final response = request.response;
    final String path;
    try {
      path = Uri.decodeComponent(request.uri.path);
    } on FormatException {
      // `/%C3`, `/%FF`: not UTF-8. A bad request, not a dead server.
      response.statusCode = HttpStatus.badRequest;
      await response.close();
      return;
    }
    final file = resolveStatic(root, path);
    if (file != null) {
      response.headers.contentType = _type(file.path);
      await response.addStream(file.openRead());
    } else {
      response.statusCode = HttpStatus.notFound;
      final notFound = File(p.join(root, '404.html'));
      if (notFound.existsSync()) {
        response.headers.contentType = ContentType.html;
        await response.addStream(notFound.openRead());
      }
    }
    await response.close();
  });
  return server;
}

/// The file a static host serves for [path], or null.
File? resolveStatic(String root, String path) {
  final clean = p.normalize(
    p.join(root, '.${path.startsWith('/') ? path : '/$path'}'),
  );
  if (!p.isWithin(root, clean) && clean != p.normalize(root)) return null;
  for (final candidate in [clean, '$clean.html', p.join(clean, 'index.html')]) {
    if (FileSystemEntity.isFileSync(candidate)) return File(candidate);
  }
  return null;
}

ContentType _type(String path) => switch (p.extension(path)) {
  '.html' => ContentType.html,
  '.css' => ContentType('text', 'css', charset: 'utf-8'),
  '.js' || '.mjs' => ContentType('text', 'javascript', charset: 'utf-8'),
  // Flutter's CanvasKit/Skwasm: streaming compilation needs the type.
  '.wasm' => ContentType('application', 'wasm'),
  '.otf' => ContentType('font', 'otf'),
  '.ttf' => ContentType('font', 'ttf'),
  '.json' => ContentType.json,
  '.svg' => ContentType('image', 'svg+xml'),
  '.png' => ContentType('image', 'png'),
  '.jpg' || '.jpeg' => ContentType('image', 'jpeg'),
  '.webp' => ContentType('image', 'webp'),
  '.woff2' => ContentType('font', 'woff2'),
  '.ico' => ContentType('image', 'x-icon'),
  '.xml' => ContentType('application', 'xml'),
  '.txt' => ContentType.text,
  _ => ContentType.binary,
};

/// The port `thor preview` serves on. Without `--port` it is the first free
/// one from the default up; with `--port N` it is N or an error, never a
/// quiet move to another port (which looked like the option being ignored).
Future<int> previewPort(
  int requested, {
  required bool explicit,
  Future<bool> Function(int port) isFree = portIsFree,
}) async {
  if (!explicit) return freePort(requested, isFree: isFree);
  if (await isFree(requested)) return requested;
  throw ThorException(
    'Port $requested is in use: stop what holds it, or pick another with '
    '--port.',
  );
}
