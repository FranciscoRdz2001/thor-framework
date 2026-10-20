@TestOn('vm')
library;

// The lite engine pastes the runtime and its parts that are not wrapped in
// a function of their own into one scope. A function two of them declare is
// one function: the later declaration wins for both. When `lists` declared
// `drawn(c, el)` it replaced the runtime's `drawn(el)`, and a `Watch` whose
// variants hold other `Watch`es could no longer be drawn from its template.
import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';

/// The functions declared at the top of the shared scope in [source] (two
/// spaces of indentation, as the runtime and its parts are written). A
/// repeated `const` is a syntax error that stops the page; a repeated
/// function is silent.
Set<String> _declared(String source) => {
  for (final m in RegExp(
    r'^  function\*? (\w+)\(',
    multiLine: true,
  ).allMatches(source))
    m.group(1)!,
};

/// The parts that are not an IIFE of their own: their code is pasted at the
/// runtime's `// @thor-lite-parts` line.
bool _shared(String source) =>
    !RegExp(r'^\(\(', multiLine: true).hasMatch(source);

Map<String, List<String>> _redeclared() {
  final uri = Isolate.resolvePackageUriSync(
    Uri.parse('package:thor_engine/lite/runtime.js'),
  );
  final dir = File.fromUri(uri!).parent.path;
  final files = <String, String>{
    'runtime.js': File('$dir/runtime.js').readAsStringSync(),
    for (final f in Directory('$dir/parts').listSync().whereType<File>())
      if (f.path.endsWith('.js') && _shared(f.readAsStringSync()))
        f.uri.pathSegments.last: f.readAsStringSync(),
  };
  final owners = <String, List<String>>{};
  for (final MapEntry(:key, :value) in files.entries) {
    for (final name in _declared(value)) {
      (owners[name] ??= []).add(key);
    }
  }
  return {
    for (final MapEntry(:key, :value) in owners.entries)
      if (value.length > 1) key: value,
  };
}

void main() {
  final clashes = _redeclared();
  test(
    'the lite runtime and its shared parts declare each name once',
    () => expect(clashes, isEmpty),
  );
}
