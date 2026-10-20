/// Source lookups on the Dart VM in JIT (`thor dev`, `thor render`, tests).
library;

import 'dart:io';
import 'dart:isolate';
// The inspector runs only in development, on the JIT VM (conditional
// import in inspect.dart); release builds compile the stub.
import 'dart:mirrors';

/// Whether the inspector is on without a test setting it.
bool enabledByDefault() => Platform.environment['THOR_DEV'] == '1';

final _types = <Type, String?>{};

/// `file:line:column` of what builds [owner] (see `ThorInspect.sourceOf`).
String? sourceOf(Object owner) => switch (owner) {
  final Type type => _types.putIfAbsent(type, () => _ofType(type)),
  final Function function => _ofFunction(function),
  _ => null,
};

/// Forgets the classes' sources: a reload can move a class's `build`, and
/// its old line would point the inspector at nothing.
void clearSources() => _types.clear();

String? _ofType(Type type) {
  final ClassMirror mirror;
  try {
    mirror = reflectClass(type);
  } on Object {
    return null;
  }
  final library = mirror.owner;
  if (library is! LibraryMirror || !_isApp(library.uri)) return null;
  final build = mirror.declarations[#build];
  return _format(build?.location ?? mirror.location);
}

String? _ofFunction(Function function) {
  final mirror = reflect(function);
  if (mirror is! ClosureMirror) return null;
  final location = mirror.function.location;
  if (location == null || !_isApp(location.sourceUri)) return null;
  return _format(location);
}

/// App code: not the SDK, not thor's packages, not generated routes.
bool _isApp(Uri uri) {
  if (uri.isScheme('dart')) return false;
  if (uri.path.endsWith('.thor.dart')) return false;
  if (uri.isScheme('package')) {
    final name = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
    if (name.startsWith('thor_')) return false;
  }
  return true;
}

String? _format(SourceLocation? location) {
  if (location == null) return null;
  var uri = location.sourceUri;
  if (uri.isScheme('package')) {
    uri = Isolate.resolvePackageUriSync(uri) ?? uri;
  }
  final path = uri.isScheme('file') ? uri.toFilePath() : uri.toString();
  return '$path:${location.line}:${location.column}';
}
