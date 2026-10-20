import 'dart:io' show Platform;

import 'errors.dart';

/// An app's environment, declared once and checked at startup.
///
/// ```dart
/// // lib/env.dart
/// abstract final class AppEnv {
///   static const api = EnvUrl('API_URL', fallback: 'https://api.example.com');
///   static const port = EnvInt('PORT', fallback: 4300);
///   static const secure = EnvBool('SECURE_COOKIES', fallback: false);
///   static const session = EnvSecret('SESSION_SECRET', minLength: 32);
///   static const schema = EnvSchema([api, port, secure, session]);
/// }
///
/// // bin/server.dart
/// final env = AppEnv.schema.load(); // every problem at once, or it throws
/// env.of(AppEnv.api); // Uri
/// env.of(AppEnv.session).reveal(); // String, only where it is used
/// ```
///
/// The structure: the schema is `const` app code; [EnvSchema.load] reads
/// the process environment once (plus a `.env` file `thor dev` passes in
/// the environment it starts the server with) and fails with the list of
/// every missing or invalid variable (THOR-P011), so a deploy never starts
/// half configured. A variable is private unless marked `public:`; a
/// secret ([EnvSecret]) is a [Secret], never printed, never JSON, and
/// under `thor dev` and at export a page that contains its value is an
/// error (THOR-P012).
class EnvSchema {
  /// A schema with [vars] (names must be unique).
  const EnvSchema(this.vars);

  /// The variables, in order.
  final List<EnvVar<Object?>> vars;

  /// Reads every variable from [environment] (the process's by default).
  /// Throws an [EnvError] listing all the problems, not just the first.
  EnvValues load([Map<String, String>? environment]) {
    final source = environment ?? Platform.environment;
    final values = <String, Object?>{};
    final problems = <String>[];
    final seen = <String>{};
    for (final v in vars) {
      if (!seen.add(v.name)) {
        problems.add('${v.name}: declared twice in the schema');
        continue;
      }
      final raw = source[v.name];
      if (raw == null || raw.isEmpty) {
        if (v.hasFallback) {
          values[v.name] = v._fallback();
        } else {
          problems.add('${v.name}: missing (${v.describe})');
        }
        continue;
      }
      final error = v._check(raw);
      if (error != null) {
        problems.add('${v.name}: $error');
        continue;
      }
      values[v.name] = v._parse(raw);
    }
    if (problems.isNotEmpty) throw EnvError(problems);
    for (final value in values.values) {
      if (value is Secret) Secret._known.add(value._value);
    }
    return EnvValues._(vars, values);
  }
}

/// The loaded environment.
class EnvValues {
  EnvValues._(this._vars, this._values);

  final List<EnvVar<Object?>> _vars;
  final Map<String, Object?> _values;

  /// The value of [variable], typed.
  T of<T>(EnvVar<T> variable) {
    if (!_values.containsKey(variable.name)) {
      // The schema lists the variables it loads: one declared but left out
      // of `EnvSchema([...])` is neither required nor parsed.
      throw ArgumentError.value(
        variable.name,
        'variable',
        thorError(
          'THOR-P011',
          '${variable.name} is not in the EnvSchema that loaded this '
              'environment (it has ${_vars.map((v) => v.name).join(', ')}). '
              'Add it to the `EnvSchema([...])` list, next to the others',
        ),
      );
    }
    return _values[variable.name] as T;
  }

  /// The variables marked `public:` as text: what the app may put in a
  /// page (or hand to a `ThorState`). A secret can't be public.
  Map<String, String> get public => {
    for (final v in _vars)
      if (v.public) v.name: '${_values[v.name]}',
  };
}

/// The environment was missing variables or had invalid ones (THOR-P011).
class EnvError extends Error {
  /// An error with every [problems] line.
  EnvError(this.problems);

  /// One line per variable.
  final List<String> problems;

  @override
  String toString() => thorError(
    'THOR-P011',
    'the environment is not valid:\n'
        '${problems.map((p) => '  - $p').join('\n')}\n',
  );
}

/// One environment variable of an [EnvSchema].
sealed class EnvVar<T> {
  const EnvVar(this.name, {this.public = false});

  // An [EnvOptional] answers [name] and [public] from what it wraps.
  const EnvVar._optional() : name = '', public = false;

  /// Its name in the environment.
  final String name;

  /// Whether a page may show it ([EnvValues.public]).
  final bool public;

  /// Whether it has a value when the variable is not set.
  bool get hasFallback;
  T _fallback();
  String? _check(String raw);
  T _parse(String raw);

  /// What it expects, for the error message.
  String get describe;
}

/// A text variable.
final class EnvString extends EnvVar<String> {
  /// [name], with [fallback] when it is not set.
  const EnvString(super.name, {this.fallback, super.public});

  /// The value when the variable is not set (`null`: required).
  final String? fallback;

  @override
  bool get hasFallback => fallback != null;
  @override
  String _fallback() => fallback!;
  @override
  String? _check(String raw) => null;
  @override
  String _parse(String raw) => raw;
  @override
  String get describe => 'text';
}

/// A whole number.
final class EnvInt extends EnvVar<int> {
  /// [name], with [fallback] when it is not set.
  const EnvInt(super.name, {this.fallback, super.public});

  /// The value when the variable is not set (`null`: required).
  final int? fallback;

  @override
  bool get hasFallback => fallback != null;
  @override
  int _fallback() => fallback!;
  @override
  String? _check(String raw) =>
      int.tryParse(raw.trim()) == null ? 'not a whole number' : null;
  @override
  int _parse(String raw) => int.parse(raw.trim());
  @override
  String get describe => 'a whole number';
}

/// `true`/`false` (also `1`/`0`, `yes`/`no`, any case).
final class EnvBool extends EnvVar<bool> {
  /// [name], with [fallback] when it is not set.
  const EnvBool(super.name, {this.fallback, super.public});

  /// The value when the variable is not set (`null`: required).
  final bool? fallback;

  static const _true = {'true', '1', 'yes'};
  static const _false = {'false', '0', 'no'};

  @override
  bool get hasFallback => fallback != null;
  @override
  bool _fallback() => fallback!;
  @override
  String? _check(String raw) {
    final v = raw.trim().toLowerCase();
    return _true.contains(v) || _false.contains(v) ? null : 'not true or false';
  }

  @override
  bool _parse(String raw) => _true.contains(raw.trim().toLowerCase());
  @override
  String get describe => 'true or false';
}

/// An absolute `http`/`https` URL.
final class EnvUrl extends EnvVar<Uri> {
  /// [name], with [fallback] (a URL) when it is not set.
  const EnvUrl(super.name, {this.fallback, super.public});

  /// The URL when the variable is not set (`null`: required).
  final String? fallback;

  @override
  bool get hasFallback => fallback != null;
  @override
  Uri _fallback() => Uri.parse(fallback!);
  @override
  String? _check(String raw) {
    final uri = Uri.tryParse(raw.trim());
    return uri != null &&
            (uri.scheme == 'http' || uri.scheme == 'https') &&
            uri.host.isNotEmpty
        ? null
        : 'not an http(s) URL';
  }

  @override
  Uri _parse(String raw) => Uri.parse(raw.trim());
  @override
  String get describe => 'an http(s) URL';
}

/// A secret: required (no fallback), never public, at least [minLength]
/// characters.
final class EnvSecret extends EnvVar<Secret> {
  /// [name], at least [minLength] characters.
  const EnvSecret(super.name, {this.minLength = 16});

  /// The shortest value accepted.
  final int minLength;

  @override
  bool get hasFallback => false;
  @override
  Secret _fallback() => throw StateError('a secret has no fallback');
  @override
  String? _check(String raw) =>
      raw.length < minLength ? 'shorter than $minLength characters' : null;
  @override
  Secret _parse(String raw) => Secret._(raw);
  @override
  String get describe => 'a secret of $minLength+ characters';
}

/// [variable] made optional: `null` when it is not set, checked like
/// [variable] when it is (`EnvOptional(EnvSecret('SESSION_SECRET'))`,
/// `EnvOptional(EnvInt('ISOLATES'))`).
final class EnvOptional<T> extends EnvVar<T?> {
  /// [variable], or `null` when unset.
  const EnvOptional(this.variable) : super._optional();

  /// The variable it wraps.
  final EnvVar<T> variable;

  @override
  String get name => variable.name;

  @override
  bool get public => variable.public;

  @override
  bool get hasFallback => true;
  @override
  T? _fallback() => variable.hasFallback ? variable._fallback() : null;
  @override
  String? _check(String raw) => variable._check(raw);
  @override
  T? _parse(String raw) => variable._parse(raw);
  @override
  String get describe => variable.describe;
}

/// A secret value: `toString` hides it and it can't become JSON; read it
/// with [reveal] where it is used (signing a cookie, a backend header).
final class Secret {
  Secret._(this._value);

  final String _value;

  /// Every secret loaded in this process (what the leak check looks for).
  static final _known = <String>{};

  /// The value itself.
  String reveal() => _value;

  @override
  String toString() => '***';

  /// A secret never goes into JSON.
  Never toJson() => throw UnsupportedError(
    thorError('THOR-P012', 'a Secret can not be encoded as JSON'),
  );

  /// The first known secret inside [text], or `null`. What `thor dev` and
  /// the export check every page against.
  static String? leakIn(String text) {
    for (final s in _known) {
      if (text.contains(s)) return s;
    }
    return null;
  }

  /// Forgets every loaded secret (tests).
  static void forgetAll() => _known.clear();
}
