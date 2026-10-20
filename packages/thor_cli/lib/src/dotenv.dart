import 'dart:convert' show LineSplitter;
import 'dart:io';

import 'package:path/path.dart' as p;

/// The variables of the app's `.env` file (`KEY=value` lines; `#`
/// comments, `export `, and single or double quotes allowed), minus the
/// ones the process environment already sets: the real environment wins,
/// as in a deploy. What `thor dev` and `thor preview` start the server
/// with, so `EnvSchema.load` sees the same names in dev and in production
/// ([appEnvironment]).
/// No file: nothing.
Map<String, String> dotEnv(String appDir, [Map<String, String>? process]) {
  final file = File(p.join(appDir, '.env'));
  if (!file.existsSync()) return const {};
  final env = process ?? Platform.environment;
  return {
    for (final MapEntry(:key, :value) in parseDotEnv(
      file.readAsStringSync(),
    ).entries)
      if (!env.containsKey(key)) key: value,
  };
}

/// The environment a command starts the app's process with: the app's
/// `.env` ([dotEnv]: the real environment wins), then [fixed], what the
/// command itself sets (`PORT`, `THOR_DEV`), which wins over the file.
/// `thor dev`, `thor preview`, `thor render` and `thor test` use it, so an
/// `EnvSecret` in `.env` is there in all four.
Map<String, String> appEnvironment(
  String appDir,
  Map<String, String> fixed, [
  Map<String, String>? process,
]) => {...dotEnv(appDir, process), ...fixed};

/// The `KEY=value` pairs of a `.env` text.
Map<String, String> parseDotEnv(String text) {
  final out = <String, String>{};
  for (var line in const LineSplitter().convert(text)) {
    line = line.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    if (line.startsWith('export ')) line = line.substring(7).trimLeft();
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    final key = line.substring(0, eq).trim();
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(key)) continue;
    var value = line.substring(eq + 1).trim();
    if (value.length >= 2 &&
        (value[0] == '"' || value[0] == "'") &&
        value.endsWith(value[0])) {
      final quote = value[0];
      value = value.substring(1, value.length - 1);
      if (quote == '"') value = value.replaceAll(r'\n', '\n');
    } else {
      final hash = value.indexOf(' #');
      if (hash >= 0) value = value.substring(0, hash).trimRight();
    }
    out[key] = value;
  }
  return out;
}
