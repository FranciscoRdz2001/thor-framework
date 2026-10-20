/// ARB files → the Dart of a typed `AppLocalizations` (Flutter's
/// `gen-l10n` output, for thor).
library;

import 'dart:convert';

import '../errors.dart';
import 'icu.dart';

/// What [generateLocalizations] produced: the code (unless there are
/// `errors`) and what the app should look at (`warnings`).
typedef L10nResult = ({
  String? code,
  List<String> errors,
  List<String> warnings,
});

/// Placeholder types an ARB file may declare.
const _types = {'String', 'int', 'double', 'num', 'DateTime', 'Object'};

/// `NumberFormat` constructors a numeric placeholder's `format` may name,
/// with the optional parameters each takes; `positional` ones take the
/// locale as their only positional argument.
const _numberFormats = <String, ({bool positional, Set<String> params})>{
  'compact': (positional: false, params: {}),
  'compactCurrency': (
    positional: false,
    params: {'name', 'symbol', 'decimalDigits'},
  ),
  'compactSimpleCurrency': (
    positional: false,
    params: {'name', 'decimalDigits'},
  ),
  'compactLong': (positional: false, params: {}),
  'currency': (
    positional: false,
    params: {'name', 'symbol', 'decimalDigits', 'customPattern'},
  ),
  'decimalPattern': (positional: true, params: {}),
  'decimalPatternDigits': (positional: false, params: {'decimalDigits'}),
  'decimalPercentPattern': (positional: false, params: {'decimalDigits'}),
  'percentPattern': (positional: true, params: {}),
  'scientificPattern': (positional: true, params: {}),
  'simpleCurrency': (positional: false, params: {'name', 'decimalDigits'}),
};

/// `DateFormat` skeletons a `DateTime` placeholder's `format` may name
/// (others need `"isCustomDateFormat": "true"`).
const _dateSkeletons = {
  'd', 'E', 'EEEE', 'LLL', 'LLLL', 'M', 'Md', 'MEd', 'MMM', 'MMMd', //
  'MMMEd', 'MMMM', 'MMMMd', 'MMMMEEEEd', 'QQQ', 'QQQQ', 'y', 'yM', 'yMd',
  'yMEd', 'yMMM', 'yMMMd', 'yMMMEd', 'yMMMM', 'yMMMMd', 'yMMMMEEEEd',
  'yQQQ', 'yQQQQ', 'H', 'Hm', 'Hms', 'j', 'jm', 'jms', 'jmv', 'jmz', 'jz',
  'm', 'ms', 's',
};

const _dartReserved = {
  'abstract', 'as', 'assert', 'async', 'await', 'base', 'break', 'case', //
  'catch', 'class', 'const', 'continue', 'covariant', 'default', 'deferred',
  'do', 'dynamic', 'else', 'enum', 'export', 'extends', 'extension',
  'external', 'factory', 'false', 'final', 'finally', 'for', 'Function',
  'get', 'hide', 'if', 'implements', 'import', 'in', 'interface', 'is',
  'late', 'library', 'mixin', 'new', 'null', 'of', 'on', 'operator', 'part',
  'required', 'rethrow', 'return', 'sealed', 'set', 'show', 'static',
  'super', 'switch', 'sync', 'this', 'throw', 'true', 'try', 'type',
  'typedef', 'var', 'void', 'when', 'while', 'with', 'yield',
};

/// Names the generated class already uses.
const _memberNames = {
  'localeName', 'delegate', 'localizationsDelegates', 'supportedLocales', //
  'hashCode', 'runtimeType', 'toString', 'noSuchMethod', 'intl', 'initDates',
};

final _messageKey = RegExp(r'^[a-z][A-Za-z0-9_]*$');
final _placeholderName = RegExp(r'^[A-Za-z][A-Za-z0-9_]*$');
final _localeName = RegExp(
  r'^[a-z]{2,8}(_[A-Z][a-z]{3})?(_([A-Z]{2}|\d{3}))?$',
);

class _Placeholder {
  _Placeholder(this.name, this.type);
  final String name;
  String type;
  String? format;
  bool customDate = false;
  Map<String, Object?> params = const {};
}

class _Message {
  _Message(this.key, this.nodes, this.placeholders, this.description);
  final String key;
  final List<IcuNode> nodes;
  final List<_Placeholder> placeholders;
  final String? description;
}

class _Arb {
  _Arb(this.file, this.locale, this.messages);
  final String file;
  final String locale; // pt_BR
  final Map<String, List<IcuNode>> messages;

  String get language => locale.split('_').first;
}

/// Generates the localizations library from [arbFiles] (file name →
/// content, all of `lib/l10n/`). [templateArbFile] is the complete one
/// (its placeholders are the contract); [outputClass] the class name.
///
/// Errors (the build fails): a file that isn't ARB, an ICU syntax error, a
/// placeholder a translation invents or uses as another kind, bad keys,
/// types or formats, a regional file without its language's. Warnings: a
/// message a locale lacks (it falls back to its language's, then the
/// template's; an error with [missingAreErrors]) and keys the template
/// doesn't have (ignored).
L10nResult generateLocalizations(
  Map<String, String> arbFiles, {
  String templateArbFile = 'app_en.arb',
  String outputClass = 'AppLocalizations',
  bool missingAreErrors = false,
}) {
  final errors = <String>[];
  final warnings = <String>[];
  L10nResult fail() => (code: null, errors: errors, warnings: warnings);

  if (!RegExp(r'^[A-Z][A-Za-z0-9]*$').hasMatch(outputClass)) {
    errors.add('output_class "$outputClass" is not a Dart class name');
    return fail();
  }
  final template = arbFiles[templateArbFile];
  if (template == null) {
    errors.add(
      'lib/l10n/$templateArbFile (the template) does not exist; '
      'set template_arb_file to one of ${arbFiles.keys.join(', ')}',
    );
    return fail();
  }
  final prefix = templateArbFile.contains('_')
      ? templateArbFile.substring(0, templateArbFile.indexOf('_') + 1)
      : '';

  // Parse every file.
  final raw = <String, Map<String, Object?>>{};
  for (final MapEntry(key: file, value: content) in arbFiles.entries) {
    try {
      final json = jsonDecode(content);
      if (json is! Map<String, Object?>) {
        errors.add('$file: not a JSON object');
        continue;
      }
      raw[file] = json;
    } on FormatException catch (e) {
      errors.add('$file: not valid JSON (${e.message})');
    }
  }
  if (errors.isNotEmpty) return fail();

  String? localeOf(String file) {
    final declared = raw[file]!['@@locale'];
    final base = file.substring(0, file.length - '.arb'.length);
    final fromName = prefix.isNotEmpty && base.startsWith(prefix)
        ? base.substring(prefix.length)
        : null;
    if (declared != null) {
      if (declared is! String || !_localeName.hasMatch(declared)) {
        errors.add('$file: @@locale "$declared" is not a locale (es, pt_BR)');
        return null;
      }
      if (fromName != null && fromName != declared) {
        errors.add(
          '$file: @@locale "$declared" contradicts the file name ("$fromName")',
        );
        return null;
      }
      return declared;
    }
    if (fromName == null || !_localeName.hasMatch(fromName)) {
      errors.add(
        '$file: no locale (name it $prefix<locale>.arb or add "@@locale")',
      );
      return null;
    }
    return fromName;
  }

  // The template: messages and their placeholders.
  final templateJson = raw[templateArbFile]!;
  final templateLocale = localeOf(templateArbFile);
  if (templateLocale == null) return fail();
  final messages = <String, _Message>{};
  for (final MapEntry(:key, :value) in templateJson.entries) {
    if (key.startsWith('@')) continue;
    final where = '$templateArbFile: "$key"';
    if (!_messageKey.hasMatch(key) ||
        _dartReserved.contains(key) ||
        _memberNames.contains(key)) {
      errors.add(
        '$where is not usable as a Dart member (lowerCamelCase, not a '
        'reserved word or ${_memberNames.join('/')})',
      );
      continue;
    }
    if (value is! String) {
      errors.add('$where: a message must be a string');
      continue;
    }
    final List<IcuNode> nodes;
    try {
      nodes = parseIcu(value);
    } on IcuSyntaxError catch (e) {
      errors.add('$where: $e');
      continue;
    }
    final meta = templateJson['@$key'];
    if (meta != null && meta is! Map<String, Object?>) {
      errors.add('$templateArbFile: "@$key" must be an object');
      continue;
    }
    final message = _templateMessage(
      key,
      nodes,
      meta as Map<String, Object?>?,
      where,
      errors,
    );
    if (message != null) messages[key] = message;
  }
  if (errors.isNotEmpty) return fail();

  // Translations.
  final arbs = <_Arb>[
    _Arb(templateArbFile, templateLocale, {
      for (final m in messages.values) m.key: m.nodes,
    }),
  ];
  for (final file in raw.keys) {
    if (file == templateArbFile) continue;
    final locale = localeOf(file);
    if (locale == null) continue;
    final json = raw[file]!;
    final translated = <String, List<IcuNode>>{};
    final extra = <String>[];
    for (final MapEntry(:key, :value) in json.entries) {
      if (key.startsWith('@')) continue;
      final message = messages[key];
      if (message == null) {
        extra.add(key);
        continue;
      }
      final where = '$file: "$key"';
      if (value is! String) {
        errors.add('$where: a message must be a string');
        continue;
      }
      try {
        final nodes = parseIcu(value);
        final byName = {for (final p in message.placeholders) p.name: p};
        for (final MapEntry(key: name, value: kinds) in placeholderUses(
          nodes,
        ).entries) {
          final p = byName[name];
          if (p == null) {
            errors.add(
              '$where uses {$name}, which the template does not declare',
            );
          } else if (kinds.contains('plural') && !_numeric(p.type)) {
            errors.add('$where uses {$name} as a plural, but it is ${p.type}');
          }
        }
        translated[key] = nodes;
      } on IcuSyntaxError catch (e) {
        errors.add('$where: $e');
      }
    }
    if (extra.isNotEmpty) {
      warnings.add(
        '$file: ${extra.length} key(s) the template ($templateArbFile) does '
        'not have, ignored: ${extra.join(', ')}',
      );
    }
    arbs.add(_Arb(file, locale, translated));
  }
  final byLocale = <String, _Arb>{};
  for (final arb in arbs) {
    final other = byLocale[arb.locale];
    if (other != null) {
      errors.add('${arb.file} and ${other.file} are both "${arb.locale}"');
    }
    byLocale[arb.locale] = arb;
  }
  for (final arb in arbs) {
    if (arb.locale != arb.language && !byLocale.containsKey(arb.language)) {
      errors.add(
        '${arb.file} (${arb.locale}) needs $prefix${arb.language}.arb, the '
        'language it falls back to',
      );
    }
  }
  if (errors.isNotEmpty) return fail();

  // Missing translations (regional files inherit their language's).
  for (final arb in arbs) {
    if (arb.file == templateArbFile) continue;
    final parent = arb.locale == arb.language ? null : byLocale[arb.language];
    final missing = [
      for (final key in messages.keys)
        if (!arb.messages.containsKey(key) &&
            !(parent?.messages.containsKey(key) ?? false))
          key,
    ];
    if (missing.isEmpty) continue;
    final text = thorError(
      'THOR-B016',
      '${arb.file}: ${missing.length} message(s) missing, the template\'s '
          '($templateLocale) is used: ${missing.join(', ')}',
    );
    (missingAreErrors ? errors : warnings).add(text);
  }
  if (errors.isNotEmpty) return fail();

  return (
    code: _emit(
      outputClass,
      templateArbFile,
      templateLocale,
      messages,
      arbs,
      byLocale,
    ),
    errors: errors,
    warnings: warnings,
  );
}

bool _numeric(String type) => const {'int', 'double', 'num'}.contains(type);

_Message? _templateMessage(
  String key,
  List<IcuNode> nodes,
  Map<String, Object?>? meta,
  String where,
  List<String> errors,
) {
  final uses = placeholderUses(nodes);
  final declared = meta?['placeholders'];
  if (declared != null && declared is! Map<String, Object?>) {
    errors.add('$where: "placeholders" must be an object');
    return null;
  }
  final placeholders = <String, _Placeholder>{};
  final spec = (declared as Map<String, Object?>?) ?? const {};
  for (final MapEntry(key: name, value: raw) in spec.entries) {
    if (raw is! Map<String, Object?>) {
      errors.add('$where: placeholder "$name" must be an object');
      continue;
    }
    final type = raw['type'] ?? _inferredType(uses[name]);
    if (type is! String || !_types.contains(type)) {
      errors.add(
        '$where: placeholder "$name" has type "$type" '
        '(${_types.join(', ')})',
      );
      continue;
    }
    final p = _Placeholder(name, type);
    final format = raw['format'];
    if (format != null) {
      if (format is! String) {
        errors.add('$where: "$name".format must be a string');
        continue;
      }
      p.format = format;
    }
    p.customDate = '${raw['isCustomDateFormat']}' == 'true';
    final params = raw['optionalParameters'];
    if (params != null) {
      if (params is! Map<String, Object?>) {
        errors.add('$where: "$name".optionalParameters must be an object');
        continue;
      }
      p.params = params;
    }
    placeholders[name] = p;
  }
  // Placeholders the message uses but doesn't declare: inferred.
  for (final MapEntry(key: name, value: kinds) in uses.entries) {
    placeholders.putIfAbsent(
      name,
      () => _Placeholder(name, _inferredType(kinds)),
    );
  }
  for (final p in placeholders.values) {
    final kinds = uses[p.name] ?? const {};
    if (!_placeholderName.hasMatch(p.name) ||
        _dartReserved.contains(p.name) ||
        _memberNames.contains(p.name) ||
        p.name == key ||
        placeholders.containsKey('${p.name}String')) {
      errors.add(
        '$where: placeholder "${p.name}" is not usable as a Dart name',
      );
    }
    if (kinds.contains('plural') && !_numeric(p.type)) {
      errors.add('$where: {${p.name}} is a plural but its type is ${p.type}');
    }
    if (p.type == 'DateTime' && p.format == null) {
      errors.add(
        '$where: DateTime placeholder "${p.name}" needs a "format" '
        '(a DateFormat skeleton: yMd, yMMMd, jm…)',
      );
    }
    final format = p.format;
    if (format != null) {
      if (_numeric(p.type)) {
        final known = _numberFormats[format];
        if (known == null) {
          errors.add(
            '$where: "${p.name}" format "$format" is not a NumberFormat '
            '(${_numberFormats.keys.join(', ')})',
          );
        } else {
          for (final param in p.params.keys) {
            if (!known.params.contains(param)) {
              errors.add(
                '$where: "${p.name}" format "$format" takes no "$param"',
              );
            }
          }
        }
      } else if (p.type == 'DateTime') {
        if (!p.customDate && !_dateSkeletons.contains(format)) {
          errors.add(
            '$where: "${p.name}" format "$format" is not a DateFormat '
            'skeleton; add "isCustomDateFormat": "true" for a pattern',
          );
        }
      } else {
        errors.add('$where: a ${p.type} placeholder takes no "format"');
      }
    }
  }
  final description = meta?['description'];
  return _Message(
    key,
    nodes,
    placeholders.values.toList(),
    description is String ? description : null,
  );
}

String _inferredType(Set<String>? kinds) => kinds == null
    ? 'Object'
    : kinds.contains('plural')
    ? 'num'
    : kinds.contains('select')
    ? 'String'
    : 'Object';

/// [text] as the body of a single-quoted Dart string: nothing in it can
/// end the string or interpolate.
String dartStringBody(String text) {
  final out = StringBuffer();
  for (final rune in text.runes) {
    switch (rune) {
      case 0x5c: // \
        out.write(r'\\');
      case 0x27: // '
        out.write(r"\'");
      case 0x24: // $
        out.write(r'\$');
      case 0x0a:
        out.write(r'\n');
      case 0x0d:
        out.write(r'\r');
      case 0x09:
        out.write(r'\t');
      default:
        if (rune < 0x20 || rune == 0x7f || rune == 0x2028 || rune == 0x2029) {
          out.write('\\u{${rune.toRadixString(16)}}');
        } else {
          out.writeCharCode(rune);
        }
    }
  }
  return out.toString();
}

String _className(String outputClass, String locale) =>
    outputClass +
    locale
        .split('_')
        .map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase())
        .join();

String _emit(
  String outputClass,
  String templateFile,
  String templateLocale,
  Map<String, _Message> messages,
  List<_Arb> arbs,
  Map<String, _Arb> byLocale,
) {
  var usesIntl = false;
  var usesDates = false;
  for (final m in messages.values) {
    for (final p in m.placeholders) {
      if (p.format != null) usesIntl = true;
      if (p.type == 'DateTime') usesDates = true;
    }
  }
  bool needsPluralRules(List<IcuNode> nodes) => nodes.any(
    (n) =>
        n is IcuChoice &&
        ((n.plural &&
                n.cases.keys.any((k) => !k.startsWith('=') && k != 'other')) ||
            n.cases.values.any(needsPluralRules)),
  );
  for (final arb in arbs) {
    if (arb.messages.values.any(needsPluralRules)) usesIntl = true;
  }

  final out = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND (thor_builder).')
    ..writeln('// The messages of lib/l10n/*.arb (template: $templateFile).')
    ..writeln('// ignore_for_file: type=lint')
    ..writeln();
  if (usesDates) {
    out.writeln(
      "import 'package:intl/date_symbol_data_local.dart' as intl_dates;",
    );
  }
  if (usesIntl) out.writeln("import 'package:intl/intl.dart' as intl;");
  out
    ..writeln("import 'package:thor_ui/thor_ui.dart';")
    ..writeln();

  // Supported locales: the template first (the fallback), then by name.
  final locales = [
    templateLocale,
    ...(byLocale.keys.where((l) => l != templateLocale).toList()..sort()),
  ];
  String localeLiteral(String locale) {
    final parts = locale.split('_');
    final script = parts.length > 1 && parts[1].length == 4 ? parts[1] : null;
    final country = parts.skip(1).where((p) => p.length != 4).firstOrNull;
    if (script != null) {
      return "Locale.fromSubtags(languageCode: '${parts[0]}', "
          "scriptCode: '$script'${country == null ? '' : ", countryCode: '$country'"})";
    }
    return country == null
        ? "Locale('${parts[0]}')"
        : "Locale('${parts[0]}', '$country')";
  }

  final c = outputClass;
  out
    ..writeln(
      '/// The app\'s messages, one subclass per locale of `lib/l10n/`.',
    )
    ..writeln('///')
    ..writeln('/// ```dart')
    ..writeln('/// ThorApp(')
    ..writeln('///   localizationsDelegates: $c.localizationsDelegates,')
    ..writeln('///   supportedLocales: $c.supportedLocales,')
    ..writeln('///   child: …,')
    ..writeln('/// )')
    ..writeln('/// $c.of(context).someMessage')
    ..writeln('/// ```')
    ..writeln('abstract class $c {')
    ..writeln('  /// Messages in [locale] (`es`, `pt_BR`).')
    ..writeln(
      usesIntl
          ? '  $c(String locale) : localeName = intl.Intl.canonicalizedLocale(locale);'
          : '  $c(String locale) : localeName = locale;',
    )
    ..writeln()
    ..writeln('  /// The locale these messages are in.')
    ..writeln('  final String localeName;')
    ..writeln();
  if (usesDates) {
    out
      ..writeln('  static bool _datesReady = false;')
      ..writeln()
      ..writeln(
        '  /// Loads intl\'s date symbols, on the first date formatted: only',
      )
      ..writeln(
        '  /// the messages with a date carry them (and the browser, only',
      )
      ..writeln('  /// if it calls one).')
      ..writeln('  static void initDates() {')
      ..writeln('    if (_datesReady) return;')
      ..writeln('    // Synchronous: the data is in the program.')
      ..writeln('    intl_dates.initializeDateFormatting();')
      ..writeln('    _datesReady = true;')
      ..writeln('  }')
      ..writeln();
  }
  out
    ..writeln('  /// The messages of the nearest `Localizations` (`ThorApp`).')
    ..writeln('  static $c of(BuildContext context) =>')
    ..writeln('      Localizations.of<$c>(context, $c)!;')
    ..writeln()
    ..writeln('  /// Loads these messages for `Localizations`.')
    ..writeln('  static const LocalizationsDelegate<$c> delegate =')
    ..writeln('      _${c}Delegate();')
    ..writeln()
    ..writeln('  /// For `ThorApp(localizationsDelegates:)`.')
    ..writeln(
      '  static const List<LocalizationsDelegate<Object?>> localizationsDelegates = [delegate];',
    )
    ..writeln()
    ..writeln('  /// The locales of `lib/l10n/`, the template\'s first.')
    ..writeln('  static const List<Locale> supportedLocales = [')
    ..writeln([for (final l in locales) '    ${localeLiteral(l)},'].join('\n'))
    ..writeln('  ];')
    ..writeln();
  for (final m in messages.values) {
    _docs(out, m, arbs.first.messages[m.key]!);
    out.writeln('  ${_signature(m)};');
    out.writeln();
  }
  out.writeln('}');

  // One class per locale.
  for (final locale in locales) {
    final arb = byLocale[locale]!;
    final regional = locale != arb.language;
    final parentClass = regional ? _className(c, arb.language) : c;
    final name = _className(c, locale);
    out
      ..writeln()
      ..writeln('/// The messages in `$locale` (${arb.file}).')
      ..writeln('class $name extends $parentClass {')
      ..writeln('  /// Messages in [locale].')
      ..writeln("  $name([String locale = '$locale']) : super(locale);");
    for (final m in messages.values) {
      final nodes =
          arb.messages[m.key] ??
          // A language falls back to the template; a region inherits its
          // language's.
          (regional ? null : byLocale[templateLocale]!.messages[m.key]);
      if (nodes == null) continue;
      out
        ..writeln()
        ..writeln('  @override')
        ..writeln('  ${_signature(m)} ${_body(c, m, nodes)}');
    }
    out.writeln('}');
  }

  // Lookup and delegate.
  final byLanguage = <String, List<String>>{};
  for (final l in locales) {
    (byLanguage[l.split('_').first] ??= []).add(l);
  }
  out
    ..writeln()
    ..writeln(
      '/// The messages for [locale]: its region\'s, else its language\'s.',
    )
    ..writeln(
      '/// Throws for a language the app lacks (see `$c.supportedLocales`).',
    )
    ..writeln('$c lookup$c(Locale locale) {')
    ..writeln(
      '  final region = [locale.languageCode, ?locale.scriptCode, ?locale.countryCode].join(\'_\');',
    )
    ..writeln('  switch (region) {');
  for (final l in locales.where((l) => l.contains('_'))) {
    out.writeln("    case '$l':\n      return ${_className(c, l)}();");
  }
  out
    ..writeln('  }')
    ..writeln('  switch (locale.languageCode) {');
  for (final lang in byLanguage.keys) {
    out.writeln("    case '$lang':\n      return ${_className(c, lang)}();");
  }
  out
    ..writeln('  }')
    ..writeln('  throw UnsupportedError(')
    ..writeln(
      "    '$c has no messages for \$locale: add lib/l10n/ ARB files or '",
    )
    ..writeln("    'resolve against $c.supportedLocales',")
    ..writeln('  );')
    ..writeln('}')
    ..writeln()
    ..writeln('class _${c}Delegate extends LocalizationsDelegate<$c> {')
    ..writeln('  const _${c}Delegate();')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  Future<$c> load(Locale locale) =>')
    ..writeln('      SynchronousFuture<$c>(lookup$c(locale));')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  bool isSupported(Locale locale) =>')
    ..writeln(
      '      const {${byLanguage.keys.map((l) => "'$l'").join(', ')}}.contains(locale.languageCode);',
    )
    ..writeln()
    ..writeln('  @override')
    ..writeln('  bool shouldReload(_${c}Delegate old) => false;')
    ..writeln('}');
  return out.toString();
}

void _docs(StringBuffer out, _Message m, List<IcuNode> nodes) {
  final lines = <String>[
    if (m.description case final d?) ...d.split(RegExp(r'\r\n|\r|\n')),
    if (m.description != null) '',
    'In the template: `${_plain(nodes).replaceAll('`', "'")}`',
  ];
  for (final line in lines) {
    out.writeln(line.isEmpty ? '  ///' : '  /// $line');
  }
}

/// The message as ICU-ish text for a doc comment (one line).
String _plain(List<IcuNode> nodes) => nodes
    .map(
      (n) => switch (n) {
        IcuText(:final text) => text,
        IcuArgument(:final name) => '{$name}',
        IcuPound() => '#',
        IcuChoice(:final name, :final plural, :final cases) =>
          '{$name, ${plural ? 'plural' : 'select'}, '
              '${cases.entries.map((e) => '${e.key}{${_plain(e.value)}}').join(' ')}}',
      },
    )
    .join()
    .replaceAll(RegExp(r'[\r\n  ]+'), ' ');

String _signature(_Message m) => m.placeholders.isEmpty
    ? 'String get ${m.key}'
    : 'String ${m.key}(${m.placeholders.map((p) => '${p.type} ${p.name}').join(', ')})';

String _formatter(_Placeholder p) {
  final format = p.format!;
  if (p.type == 'DateTime') {
    return p.customDate
        ? "intl.DateFormat('${dartStringBody(format)}', localeName)"
        : 'intl.DateFormat.$format(localeName)';
  }
  final spec = _numberFormats[format]!;
  if (spec.positional) return 'intl.NumberFormat.$format(localeName)';
  final args = <String>['locale: localeName'];
  for (final MapEntry(:key, :value) in p.params.entries) {
    args.add(switch (value) {
      num() || bool() => '$key: $value',
      _ => "$key: '${dartStringBody('$value')}'",
    });
  }
  return 'intl.NumberFormat.$format(${args.join(', ')})';
}

String _body(String outputClassRef, _Message m, List<IcuNode> nodes) {
  final used = placeholderUses(nodes);
  final formatted = [
    for (final p in m.placeholders)
      if (p.format != null && used.containsKey(p.name)) p,
  ];
  final byName = {for (final p in m.placeholders) p.name: p};
  String value(String name) =>
      byName[name]?.format != null ? '${name}String' : name;
  final expression = _expression(nodes, value, byName);
  if (formatted.isEmpty) return '=> $expression;';
  final body = StringBuffer('{\n');
  if (formatted.any((p) => p.type == 'DateTime')) {
    body.writeln('    $outputClassRef.initDates();');
  }
  for (final p in formatted) {
    body.writeln(
      '    final ${p.name}String = ${_formatter(p)}.format(${p.name});',
    );
  }
  body
    ..writeln('    return $expression;')
    ..write('  }');
  return body.toString();
}

/// [nodes] as one Dart string expression.
String _expression(
  List<IcuNode> nodes,
  String Function(String name) value,
  Map<String, _Placeholder> byName,
) {
  if (nodes case [IcuChoice(:final name, :final plural, :final cases)]) {
    return _choice(name, plural, cases, value, byName);
  }
  final out = StringBuffer("'");
  for (final n in nodes) {
    switch (n) {
      case IcuText(:final text):
        out.write(dartStringBody(text));
      case IcuArgument(:final name) || IcuPound(:final name):
        out.write('\${${value(name)}}');
      case IcuChoice(:final name, :final plural, :final cases):
        out.write('\${${_choice(name, plural, cases, value, byName)}}');
    }
  }
  out.write("'");
  return out.toString();
}

String _choice(
  String name,
  bool plural,
  Map<String, List<IcuNode>> cases,
  String Function(String name) value,
  Map<String, _Placeholder> byName,
) {
  String sub(List<IcuNode> nodes) => _expression(nodes, value, byName);
  if (!plural) {
    final arms = [
      for (final MapEntry(:key, value: nodes) in cases.entries)
        if (key != 'other') "'${dartStringBody(key)}' => ${sub(nodes)}",
      '_ => ${sub(cases['other']!)}',
    ];
    return 'switch ($name) { ${arms.join(', ')} }';
  }
  // Exact values first (ICU: `=1` wins over `one`), then CLDR categories
  // by the locale's rules; `=0` is never confused with `zero`.
  final categories = [
    for (final MapEntry(:key, value: nodes) in cases.entries)
      if (!key.startsWith('=') && key != 'other') '$key: ${sub(nodes)}',
  ];
  var result = categories.isEmpty
      ? sub(cases['other']!)
      : 'intl.Intl.pluralLogic($name, locale: localeName, '
            '${categories.join(', ')}, other: ${sub(cases['other']!)}, '
            'useExplicitNumberCases: false)';
  for (final MapEntry(:key, value: nodes) in cases.entries.toList().reversed) {
    if (!key.startsWith('=')) continue;
    result = '$name == ${key.substring(1)} ? ${sub(nodes)} : $result';
  }
  return '($result)';
}
