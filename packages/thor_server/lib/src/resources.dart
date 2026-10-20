import 'dart:io';
import 'dart:isolate';

/// Where `thor build` leaves the resources packages declare
/// (`thor: resources:` in their pubspec), next to `build/server`.
const resourcesFolder = 'resources';

/// The folder of the bundled Dart SDK inside [resourcesFolder] (an app that
/// declares `thor: sdk: true`).
const bundledSdkFolder = 'dart-sdk';

/// The file behind [packageUri] (`package:my_pkg/assets/bridge.js`): the
/// same URI in `thor dev` / `dart run` and in the compiled `build/server`.
///
/// A native executable (`dart compile exe`) resolves no `package:` URIs, so
/// `thor build` copies what each package lists under `thor: resources:`
/// (paths relative to its `lib/`) to `build/resources/<package>/…`. Found,
/// in order: the package itself (JIT), `$THOR_RESOURCES/<package>/…`,
/// `resources/` next to the executable, then `build/resources/` under the
/// working directory. Throws a [FileSystemException] naming the places it
/// looked when there is none.
Future<File> thorResource(String packageUri) async {
  final uri = Uri.parse(packageUri);
  if (uri.scheme != 'package' || uri.pathSegments.length < 2) {
    throw ArgumentError.value(
      packageUri,
      'packageUri',
      'must be a package: URI, e.g. package:my_pkg/assets/file.js',
    );
  }
  final tried = <String>[];
  Uri? resolved;
  try {
    resolved = await Isolate.resolvePackageUri(uri);
  } on Object {
    // Not in the isolate's package config (a compiled executable).
  }
  if (resolved != null && resolved.scheme == 'file') {
    final file = File.fromUri(resolved);
    if (file.existsSync()) return file;
    tried.add(file.path);
  }
  final rest = _join(uri.pathSegments);
  for (final root in _resourceRoots()) {
    final file = File(_join([root, rest]));
    if (file.existsSync()) return file;
    tried.add(file.path);
  }
  throw FileSystemException(
    '$packageUri is not a resource of this build (declare it under '
    '`thor: resources:` in its pubspec and run `thor build`); looked in: '
    '${tried.join(', ')}',
    packageUri,
  );
}

/// [thorResource] read as text.
Future<String> readThorResource(String packageUri) async =>
    (await thorResource(packageUri)).readAsString();

/// A Dart SDK folder (one with `lib/_internal`, an absolute path), for tools that read the
/// SDK's libraries next to the executable, such as the analyzer: the one
/// `thor build` bundled (`thor: sdk: true`), else the SDK of the running
/// `dart`, else the first `dart` of `PATH`; null when there is none.
String? thorDartSdkPath() {
  for (final root in _resourceRoots()) {
    final bundled = _join([root, bundledSdkFolder]);
    if (_isSdk(bundled)) return bundled;
  }
  final running = _up(_up(Platform.resolvedExecutable));
  if (_isSdk(running)) return running;
  final path = Platform.environment['PATH'] ?? '';
  for (final dir in path.split(Platform.isWindows ? ';' : ':')) {
    final dart = File(_join([dir, Platform.isWindows ? 'dart.exe' : 'dart']));
    if (!dart.existsSync()) continue;
    final sdk = _up(_up(dart.resolveSymbolicLinksSync()));
    if (_isSdk(sdk)) return sdk;
  }
  return null;
}

bool _isSdk(String dir) =>
    Directory(_join([dir, 'lib', '_internal'])).existsSync();

Iterable<String> _resourceRoots() sync* {
  final named = Platform.environment['THOR_RESOURCES'];
  if (named != null && named.isNotEmpty) yield named;
  yield _join([_up(Platform.resolvedExecutable), resourcesFolder]);
  yield _join([Directory.current.path, 'build', resourcesFolder]);
}

String _join(List<String> parts) => parts.join(Platform.pathSeparator);

String _up(String path) => File(path).parent.path;
