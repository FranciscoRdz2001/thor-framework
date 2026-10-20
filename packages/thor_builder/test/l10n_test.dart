import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:thor_builder/src/l10n/generate.dart';
import 'package:thor_builder/src/l10n/icu.dart';
import 'package:thor_builder/src/l10n_builder.dart';

import 'support.dart';

String _text(List<IcuNode> nodes) => nodes
    .map(
      (n) => switch (n) {
        IcuText(:final text) => text,
        IcuArgument(:final name) => '<$name>',
        IcuPound(:final name) => '#$name',
        IcuChoice(:final name, :final cases) =>
          '[$name ${cases.entries.map((e) => '${e.key}:${_text(e.value)}').join('|')}]',
      },
    )
    .join();

/// Runs [expressions] (Dart, over the generated library imported as `l`)
/// in a fresh isolate and returns their values: the generated code runs,
/// not just compiles.
Future<List<String>> _run(String code, List<String> expressions) async {
  final dir = await Directory.systemTemp.createTemp('thor_l10n');
  addTearDown(() => dir.delete(recursive: true));
  File('${dir.path}/gen.dart').writeAsStringSync(code);
  File('${dir.path}/main.dart').writeAsStringSync('''
import 'dart:isolate';
import 'package:thor_ui/thor_ui.dart';
import 'gen.dart' as l;

void main(List<String> args, SendPort port) {
  final out = <String>[];
  for (final f in <String Function()>[
    ${expressions.map((e) => '() => $e,').join('\n    ')}
  ]) {
    try {
      out.add(f());
    } catch (e) {
      out.add('throws \${e.runtimeType}');
    }
  }
  port.send(out);
}
''');
  final port = ReceivePort();
  final errors = ReceivePort();
  await Isolate.spawnUri(
    Uri.file('${dir.path}/main.dart'),
    const [],
    port.sendPort,
    packageConfig: await Isolate.packageConfig,
    onError: errors.sendPort,
  );
  final result = await Future.any([
    port.first,
    errors.first.then((e) => throw StateError('$e')),
  ]);
  port.close();
  errors.close();
  return (result as List).cast<String>();
}

const _en = {
  '@@locale': 'en',
  'title': 'Store',
  '@title': {'description': 'The page title'},
  'items':
      '{count, plural, =0{Your cart is empty} =1{Just one item} '
      'one{# item} other{# items}}',
  'arabicZero': '{n, plural, zero{Z} one{O} two{T} few{F} many{M} other{X}}',
  'arabicExact': '{n, plural, =0{none} zero{Z} other{X}}',
  'welcome': 'Hi {name}',
  'escapes': r"Price: $5, $'{'notCode'}' \n 'quoted' \ back",
  'apostrophes': "It's '{literal}' and '''",
  'pronoun':
      '{gender, select, female{She has {count, plural, one{# cat} '
      'other{# cats}}} other{They have {count, plural, one{# cat} '
      'other{# cats}}}}',
  '@pronoun': {
    'placeholders': {
      'gender': {'type': 'String'},
      'count': {'type': 'int'},
    },
  },
  'price': 'Total: {amount}',
  '@price': {
    'placeholders': {
      'amount': {
        'type': 'double',
        'format': 'simpleCurrency',
        'optionalParameters': {'name': 'EUR'},
      },
    },
  },
  'placed': 'Placed on {date}',
  '@placed': {
    'placeholders': {
      'date': {'type': 'DateTime', 'format': 'yMMMd'},
    },
  },
  'onlyEnglish': 'Only in English',
};

const _es = {
  'title': 'Tienda',
  'items':
      '{count, plural, =0{Tu carrito está vacío} one{# artículo} '
      'other{# artículos}}',
  'welcome': 'Hola {name}',
  'arabicZero': '{n, plural, zero{Z} one{O} other{X}}',
  'arabicExact': '{n, plural, =0{nada} other{X}}',
  'escapes': r"Precio: $5, $'{'noCode'}' \n 'citado' \ barra",
  'apostrophes': "Es '{literal}' y ''",
  'pronoun':
      '{gender, select, female{Ella tiene {count, plural, one{# gato} '
      'other{# gatos}}} other{Tienen {count}}}',
  'price': 'Total: {amount}',
  'placed': 'Pedido el {date}',
};

const _esMx = {'title': 'Tiendita'};

const _ar = {
  'title': 'متجر',
  'arabicZero': '{n, plural, zero{Z} one{O} two{T} few{F} many{M} other{X}}',
  'arabicExact': '{n, plural, =0{none} zero{Z} other{X}}',
};

Map<String, String> _files([Map<String, Object?> extraEs = const {}]) => {
  'app_en.arb': jsonEncode(_en),
  'app_es.arb': jsonEncode({..._es, ...extraEs}),
  'app_es_MX.arb': jsonEncode(_esMx),
  'app_ar.arb': jsonEncode(_ar),
};

void main() {
  group('parseIcu', () {
    test('text, placeholders, plural with #, select, nested', () {
      expect(_text(parseIcu('Hi {name}!')), 'Hi <name>!');
      expect(
        _text(parseIcu('{n, plural, =0{none} one{# x} other{#}}')),
        '[n =0:none|one:#n x|other:#n]',
      );
      // `#` inside a select inside a plural is the plural's number.
      expect(
        _text(parseIcu('{n, plural, other{{g, select, a{# a} other{#}}}}')),
        '[n other:[g a:#n a|other:#n]]',
      );
      // Outside a plural, # is text.
      expect(_text(parseIcu('# {g, select, other{#}}')), '# [g other:#]');
    });

    test("apostrophes: ICU's default, friendly to prose", () {
      expect(_text(parseIcu("don't")), "don't");
      expect(_text(parseIcu("'{name}' is literal")), '{name} is literal');
      expect(_text(parseIcu("it''s")), "it's");
      expect(_text(parseIcu("'it''s {x}'")), "'it's <x>'");
      expect(
        _text(parseIcu("{n, plural, other{'#' is #}}")),
        '[n other:# is #n]',
      );
    });

    test('syntax errors say what and where', () {
      for (final (message, error) in [
        ('a } b', 'unbalanced'),
        ('{name', 'unclosed'),
        ('{n, plural, one{x}}', 'needs an "other"'),
        ('{n, plural, few2{x} other{y}}', 'not a plural category'),
        ('{n, plural, one{a} one{b} other{c}}', 'appears twice'),
        ('{n, plural, offset:1 other{x}}', 'offsets'),
        ('{n, number}', 'not supported'),
        ('{n, plural, =x{a} other{b}}', 'number after "="'),
        ("'{ never closed", 'unterminated quote'),
        ('{ }', 'placeholder name'),
        ('{n, plural, other{x}', 'unclosed'),
      ]) {
        expect(
          () => parseIcu(message),
          throwsA(
            isA<IcuSyntaxError>().having(
              (e) => e.message,
              'message',
              contains(error),
            ),
          ),
          reason: message,
        );
      }
    });
  });

  group('generateLocalizations: errors and warnings', () {
    List<String> errorsOf(Map<String, String> files, {bool strict = false}) =>
        generateLocalizations(files, missingAreErrors: strict).errors;

    test('a missing translation warns and falls back; strict fails', () {
      final result = generateLocalizations(_files());
      expect(result.errors, isEmpty);
      expect(
        result.warnings.join('\n'),
        allOf(
          allOf(
            contains('app_es.arb: 1 message(s) missing'),
            contains('THOR-B016'),
          ),
          contains('onlyEnglish'),
        ),
      );
      // es-MX inherits from es: only what es lacks counts.
      expect(result.warnings.join('\n'), contains('app_es_MX.arb: 1 message'));
      expect(errorsOf(_files(), strict: true), isNotEmpty);
    });

    test('keys the template lacks are ignored with a warning', () {
      final result = generateLocalizations(_files({'stray': 'x'}));
      expect(result.errors, isEmpty);
      expect(result.warnings.join(), contains('stray'));
      expect(result.code, isNot(contains('stray')));
    });

    test('a translation cannot invent a placeholder or change its kind', () {
      expect(
        errorsOf(_files({'welcome': 'Hola {nombre}'})).single,
        contains('{nombre}'),
      );
      expect(
        errorsOf(_files({'welcome': '{name, plural, other{x}}'})).single,
        contains('as a plural'),
      );
    });

    test('keys and placeholders must be Dart names', () {
      for (final key in ['class', 'hello-world', 'Title', 'localeName', '1a']) {
        expect(
          errorsOf({
            'app_en.arb': jsonEncode({key: 'x'}),
          }),
          isNotEmpty,
          reason: key,
        );
      }
      expect(
        errorsOf({
          'app_en.arb': jsonEncode({'a': '{class}'}),
        }),
        isNotEmpty,
      );
    });

    test('malformed files, templates and locales', () {
      expect(errorsOf({'app_en.arb': '{not json'}).single, contains('JSON'));
      expect(errorsOf({'app_en.arb': '[]'}).single, contains('object'));
      expect(errorsOf({'app_es.arb': '{}'}).single, contains('template'));
      expect(
        errorsOf({
          'app_en.arb': '{"a": "x"}',
          'app_es.arb': '{"@@locale": "fr", "a": "y"}',
        }).single,
        contains('contradicts'),
      );
      expect(
        errorsOf({
          'app_en.arb': '{"a": "x"}',
          'app_pt_BR.arb': '{"a": "y"}',
        }).single,
        contains('app_pt.arb'),
      );
      expect(
        errorsOf({'app_en.arb': '{"a": "{n, plural, other{x}"}'}).single,
        contains('unclosed'),
      );
      expect(errorsOf({'app_en.arb': '{"a": 3}'}).single, contains('string'));
    });

    test('types and formats are checked', () {
      Map<String, String> one(Map<String, Object?> placeholder) => {
        'app_en.arb': jsonEncode({
          'a': '{v}',
          '@a': {
            'placeholders': {'v': placeholder},
          },
        }),
      };
      expect(errorsOf(one({'type': 'Money'})).single, contains('type'));
      expect(
        errorsOf(one({'type': 'DateTime'})).single,
        contains('needs a "format"'),
      );
      expect(
        errorsOf(one({'type': 'int', 'format': 'money'})).single,
        contains('not a NumberFormat'),
      );
      expect(
        errorsOf(
          one({
            'type': 'int',
            'format': 'compact',
            'optionalParameters': {'symbol': 'x'},
          }),
        ).single,
        contains('takes no "symbol"'),
      );
      expect(
        errorsOf(one({'type': 'DateTime', 'format': 'dd/MM'})).single,
        contains('isCustomDateFormat'),
      );
      expect(
        errorsOf({
          'app_en.arb': jsonEncode({
            'a': '{v, plural, other{x}}',
            '@a': {
              'placeholders': {
                'v': {'type': 'String'},
              },
            },
          }),
        }).single,
        contains('plural'),
      );
    });

    test('a description cannot break out of its doc comment', () {
      final code = generateLocalizations({
        'app_en.arb': jsonEncode({
          'a': 'x',
          '@a': {'description': 'one\nvoid evil() {}\r\n*/ two'},
        }),
      }).code!;
      expect(code, contains('  /// void evil() {}'));
      expect(code, isNot(contains('\nvoid evil')));
    });

    test('messages without plural rules or formats need no intl', () {
      final code = generateLocalizations({
        'app_en.arb': jsonEncode({'a': 'x {n, plural, =0{none} other{#}}'}),
      }).code!;
      expect(code, isNot(contains('package:intl')));
    });
  });

  group('generated code', () {
    late String code;
    setUpAll(() => code = generateLocalizations(_files()).code!);

    test('compiles', () async {
      expect(
        await compileErrors({'app|lib/gen.dart': code}, 'app|lib/gen.dart'),
        isEmpty,
      );
    });

    test('runs: plurals, fallbacks, escapes, formats', () async {
      final values = await _run(code, [
        'l.AppLocalizationsEn().items(0)',
        'l.AppLocalizationsEn().items(1)',
        'l.AppLocalizationsEn().items(2)',
        'l.AppLocalizationsEs().items(0)',
        'l.AppLocalizationsEs().items(1)',
        'l.AppLocalizationsEs().items(1.5)',
        // `zero` is a CLDR category: English never has it, Arabic does.
        'l.AppLocalizationsEn().arabicZero(0)',
        'l.AppLocalizationsAr().arabicZero(0)',
        'l.AppLocalizationsAr().arabicZero(3)',
        'l.AppLocalizationsAr().arabicZero(11)',
        'l.AppLocalizationsAr().arabicZero(100)',
        // `=0` is exact and wins over the category.
        'l.AppLocalizationsAr().arabicExact(0)',
        // Missing in es: the template's text.
        'l.AppLocalizationsEs().onlyEnglish',
        // es-MX: its own, else es, else the template.
        "l.lookupAppLocalizations(const Locale('es', 'MX')).title",
        "l.lookupAppLocalizations(const Locale('es', 'MX')).welcome('Ana')",
        "l.lookupAppLocalizations(const Locale('es', 'AR')).title",
        "l.lookupAppLocalizations(const Locale('fr')).title",
        'l.AppLocalizationsEn().escapes',
        'l.AppLocalizationsEn().apostrophes',
        r"l.AppLocalizationsEn().welcome('<script>\${1}</script>')",
        "l.AppLocalizationsEn().pronoun('female', 1)",
        "l.AppLocalizationsEn().pronoun('x', 3)",
        "l.AppLocalizationsEs().pronoun('female', 2)",
        "l.AppLocalizationsEs().pronoun('x', 2)",
        'l.AppLocalizationsEs().price(1234.5)',
        'l.AppLocalizationsEs().placed(DateTime(2026, 9, 25))',
        "l.AppLocalizations.supportedLocales.join(' ')",
      ]);
      expect(values, [
        'Your cart is empty',
        'Just one item',
        '2 items',
        'Tu carrito está vacío',
        '1 artículo',
        '1.5 artículos',
        'X',
        'Z',
        'F',
        'M',
        'X',
        'none',
        'Only in English',
        'Tiendita',
        'Hola Ana',
        'Tienda',
        'throws UnsupportedError',
        r"Price: $5, ${notCode} \n 'quoted' \ back",
        "It's {literal} and ''",
        r'Hi <script>${1}</script>',
        'She has 1 cat',
        'They have 3 cats',
        'Ella tiene 2 gatos',
        'Tienen 2',
        'Total: 1.234,50\u00a0€',
        'Pedido el 25 sept 2026',
        'en ar es es_MX',
      ]);
    });
  });

  test('the builder writes lib/l10n/app_localizations.thor.dart', () async {
    await testBuilder(
      ThorL10nBuilder(),
      {
        'app|lib/l10n/app_en.arb': '{"hello": "Hello"}',
        'app|lib/l10n/app_es.arb': '{"hello": "Hola"}',
      },
      rootPackage: 'app',
      outputs: {
        'app|lib/l10n/app_localizations.thor.dart': decodedMatches(
          allOf(
            contains('String get hello;'),
            contains('class AppLocalizationsEs extends AppLocalizations'),
            isNot(contains('package:intl')),
          ),
        ),
      },
    );
  });

  test(
    'the builder fails when plurals need intl and the app lacks it',
    () async {
      final logs = <String>[];
      final out = await generate(ThorL10nBuilder(), {
        'app|pubspec.yaml': 'name: app\ndependencies:\n  thor_ui: any\n',
        'app|lib/l10n/app_en.arb': '{"n": "{c, plural, one{one} other{many}}"}',
      }, logs: logs);
      expect(out, isEmpty);
      expect(logs.join(), contains('add `intl'));
    },
  );
}
