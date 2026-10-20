import 'package:analyzer/dart/analysis/results.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:thor_lints/lite.dart';

/// Resolves `lib/s.dart` and translates it.
Future<String> _translate(
  String source, {
  bool shortNames = false,
  Map<String, String> parts = const {},
}) async {
  final units = await resolveSources(
    {
      'app|lib/s.dart': source,
      for (final p in parts.entries) 'app|lib/${p.key}': p.value,
    },
    (resolver) async {
      final lib = await resolver.libraryFor(AssetId.parse('app|lib/s.dart'));
      final result =
          await lib.session.getResolvedLibraryByElement(lib)
              as ResolvedLibraryResult;
      return [
        for (final u in result.units)
          LiteUnit('lib/${u.path.split('/').last}', u.unit),
      ];
    },
    rootPackage: 'app',
    readAllSourcesFromFilesystem: true,
  );
  return translateLiteStates(units, shortNames: shortNames);
}

Future<LiteTranslationException> _fail(
  String source, {
  Map<String, String> parts = const {},
}) async {
  try {
    await _translate(source, parts: parts);
  } on LiteTranslationException catch (e) {
    return e;
  }
  fail('expected lite errors');
}

const _header = """
import 'dart:async';

import 'package:thor_ui/thor_ui.dart';

part 's_more.dart';
""";

const _partHeader = "part of 's.dart';\n";

/// A state whose method [body] (and top-level [top] code) is translated.
String _state(String body, {String top = ''}) =>
    '''
$_header
$top
class PState extends ThorState {
  final a = state(0);
  $body
}
''';

/// The 1-based index of the caret in the frame of [text] and the index of
/// [under] in the code line above it (both in runes): they must be equal.
void _expectCaretUnder(String text, String under) {
  final lines = text.split('\n');
  final i = lines.indexWhere((l) => RegExp(r'^\s+\|\s*\t*\s*\^').hasMatch(l));
  expect(i, greaterThan(0), reason: 'no caret line in:\n$text');
  final code = lines[i - 1], caret = lines[i];
  final codeStart = code.indexOf('| ') + 2,
      caretStart = caret.indexOf('| ') + 2;
  final codeRunes = code.substring(codeStart).runes.toList();
  final caretRunes = caret.substring(caretStart).runes.toList();
  final col = caretRunes.indexOf(0x5e);
  final target = under.runes.toList();
  final at = String.fromCharCodes(codeRunes.sublist(col));
  expect(
    at.startsWith(under),
    isTrue,
    reason:
        'caret is under "${at.substring(0, at.length.clamp(0, 12))}", '
        'not "$under":\n$text',
  );
  expect(target, isNotEmpty);
}

void main() {
  group('no duplicates', () {
    test('a helper reached twice reports each place once', () async {
      final e = await _fail(
        _state(
          'String one() => kind(1);\n  String two() => kind(2);',
          top: 'String kind(Object o) => o.runtimeType.toString();',
        ),
        parts: {'s_more.dart': _partHeader},
      );
      final keys = [
        for (final x in e.errors)
          '${x.path}:${x.line}:${x.column}:${x.message}',
      ];
      expect(keys.toSet().length, keys.length, reason: keys.join('\n'));
      expect(
        e.errors.where((x) => x.message.contains('runtimeType')).length,
        1,
      );
      expect(e.report, startsWith('${e.errors.length} construct(s)'));
    });

    test('the same construct three times on a line is three errors', () async {
      final e = await _fail(
        _state(
          'List<Future<List<int>>> f() => [Future.wait([], cleanUp: (x) {}), Future.wait([], cleanUp: (x) {}), Future.wait([], cleanUp: (x) {})];',
        ),
        parts: {'s_more.dart': _partHeader},
      );
      final waits = e.errors.where((x) => x.message.startsWith('Future.wait'));
      expect(waits.map((x) => x.column).toSet().length, 3);
      for (final w in waits) {
        _expectCaretUnder('$w', 'Future.wait');
      }
    });

    test('the same construct in two files is one error per file', () async {
      final e = await _fail(
        _state('Future<List<int>> f() => Future.wait([], cleanUp: (x) {});'),
        parts: {
          's_more.dart':
              '$_partHeader\nFuture<List<int>> g() => Future.wait([], cleanUp: (x) {});\n'
              'class QState extends ThorState {\n  final b = state(0);\n'
              '  Future<List<int>> h() => g();\n}\n',
        },
      );
      final waits = e.errors.where((x) => x.message.startsWith('Future.wait'));
      expect(waits.map((x) => x.path).toSet(), {
        'lib/s.dart',
        'lib/s_more.dart',
      });
      expect(waits.length, 2);
    });
  });

  group('every common construct says how to fix it', () {
    // snippet (a state method or a top-level declaration), the construct in
    // the message, a fragment of the fix.
    final cases = <(String, String, String, String)>[
      (
        'Future<List<int>> f() => Future.wait([], cleanUp: (x) {});',
        '',
        'Future.wait(cleanUp:)',
        'try/finally',
      ),
      (
        'Object f() => Completer<int>.sync();',
        '',
        'Completer.sync',
        '`Completer()`',
      ),
      (
        'void f() { Stream.value(1).listen((e) {}); }',
        '',
        'Stream',
        'no streams',
      ),
      (
        'Iterable<int> f() sync* { yield 1; }',
        '',
        'Generators',
        'return a List',
      ),
      (
        'int f() => W().g();',
        'mixin class M2 { int g() => 1; }\nclass W with M2 {}',
        'mixes in',
        'composition',
      ),
      (
        'bool f() => P(1) < P(2);',
        'class P { final int a; const P(this.a); bool operator <(P o) => a < o.a; }',
        'Operator P.<',
        'only `==` is translated',
      ),
      (
        'bool f(Object o) => o is Map<String, Object>;',
        '',
        'is Map<String, Object>',
        'without them',
      ),
      (
        'List<Map<String, dynamic>> f(List<Object?> l) => l.whereType<Map<String, dynamic>>().toList();',
        '',
        '.whereType()',
        'where((x) => x is List)',
      ),
      (
        'int f(String s) => s.lastIndexOf(RegExp(r"\\s+"));',
        '',
        'with a RegExp',
        'RegExp.allMatches',
      ),
      (
        'int f() => Id(1).v;',
        'extension type Id(int v) {}',
        'Id(...)',
        'small class',
      ),
      ('void f() { late int x; x = 1; }', '', '`late`', 'nullable'),
      (
        'String label() => super.toString();',
        '',
        '`super`',
        'only `super.dispose()`',
      ),
      (
        r'String f() { final m = <String, int>{}; return "${m}"; }',
        '',
        'Interpolating a Map',
        'm.entries.map',
      ),
      (
        r'String f() { final r = (1, 2); return "${r}"; }',
        '',
        'Interpolating a (int, int)',
        r'${r.$1}',
      ),
      (
        r'String f() { final l = <Object>[]; return "${l}"; }',
        '',
        'Interpolating a List<Object>',
        '.join(", ")',
      ),
      (
        'int f(List<int> l) => l.getRange(0, 1).length;',
        '',
        '.getRange()',
        'sublist',
      ),
      (r'String f(Object o) => "${o.runtimeType}";', '', '.runtimeType', 'is'),
      ('Object f() => Object();', '', 'Object(...)', 'lite subset supports'),
    ];
    for (final (body, top, message, fix) in cases) {
      test('$message: $fix', () async {
        final isMethod =
            !top.contains('extension') &&
            !top.contains('mixin') &&
            !top.contains('class P');
        final e = await _fail(
          _state(
            isMethod ? body : 'int k() => f();',
            top: isMethod ? top : '$top\n$body',
          ),
          parts: {'s_more.dart': _partHeader},
        );
        final hit = e.errors.where((x) => x.message.contains(message)).toList();
        expect(hit, isNotEmpty, reason: e.errors.join('\n'));
        expect(hit.first.toString(), contains('fix: '));
        expect(hit.first.toString(), contains(fix));
        // Every error of the report has a code frame.
        for (final x in e.errors) {
          expect(x.toString(), contains(' | '), reason: '$x');
        }
      });
    }

    test(
      'Map interpolation no longer suggests join (a Map has none)',
      () async {
        final e = await _fail(
          _state(r'String f() { final m = <String, int>{}; return "${m}"; }'),
          parts: {'s_more.dart': _partHeader},
        );
        expect(e.report, isNot(contains('(e.g. `.join')));
        expect(e.report, contains('m.entries.map'));
      },
    );

    test('super.toString() is not "outside a class"', () async {
      final e = await _fail(
        _state('String label() => super.toString();'),
        parts: {'s_more.dart': _partHeader},
      );
      expect(e.report, isNot(contains('outside a class')));
    });

    test('an error the table does not know still gets a way out', () async {
      final e = await _fail(
        _state('Object f() => Object();'),
        parts: {'s_more.dart': _partHeader},
      );
      expect(e.errors.single.hint, contains('query()/command()'));
    });
  });

  group('the hint table and the doc are the same list', () {
    // construct → (body of a state method, top-level code): the translator
    // must REJECT each, and the error must carry that entry's suggestion.
    final snippets = <String, (String, String)>{
      'Future.wait(cleanUp:)': (
        'Future<List<int>> f() => Future.wait([], cleanUp: (x) {});',
        '',
      ),
      '.wait': (
        'Future<(int, int)> f() => (Future.value(1), Future.value(2)).wait;',
        '',
      ),
      '.timeout': (
        'Future<void> f() async { await Future.delayed(Duration.zero).timeout(Duration(seconds: 1)); }',
        '',
      ),
      'Timer.run': ('void f() { Timer.run(() {}); }', ''),
      'Completer.sync': ('Object f() => Completer<int>.sync();', ''),
      'StreamController': (
        'void f() { final c = StreamController<int>(); c.add(1); }',
        '',
      ),
      '.listen': ('void f() { Stream.value(1).listen((e) {}); }', ''),
      'await for': (
        'Future<void> f() async { await for (final x in Stream.value(1)) {} }',
        '',
      ),
      'Stream': ('Object f() => Stream.value(1);', ''),
      'sync*': ('Iterable<int> f() sync* { yield 1; }', ''),
      'mixin': (
        'int f() => W().g();',
        'mixin class M2 { int g() => 1; }\nclass W with M2 {}',
      ),
      'operator +': (
        'int f() => (P(1) + P(2)).a;',
        'class P { final int a; const P(this.a); P operator +(P o) => P(a + o.a); }',
      ),
      'is Map<String, dynamic>': (
        'bool f(Object o) => o is Map<String, Object>;',
        '',
      ),
      '.whereType': (
        'List<Map<String, dynamic>> f(List<Object?> l) => l.whereType<Map<String, dynamic>>().toList();',
        '',
      ),
      'lastIndexOf(RegExp)': (
        r'int f(String s) => s.lastIndexOf(RegExp(r"\s+"));',
        '',
      ),
      'extension type': ('int f() => Id(1).v;', 'extension type Id(int v) {}'),
      'late': ('void f() { late int x; x = 1; }', ''),
      'ValueNotifier': ('final n = ValueNotifier<int>(0);', ''),
      'super': ('String label() => super.toString();', ''),
      'interpolate a Map': (
        r'String f() { final m = <String, int>{}; return "${m}"; }',
        '',
      ),
      'interpolate a record': (
        r'String f() { final r = (1, 2); return "${r}"; }',
        '',
      ),
      'interpolate a List<Object>': (
        r'String f() { final l = <Object>[]; return "${l}"; }',
        '',
      ),
      'interpolate a list of objects': (
        r'String f() { final l = <K>[]; return "${l}"; }',
        'class K {}',
      ),
      'interpolate a class': (r'String f() => "${K()}";', 'class K {}'),
      'getRange': ('int f(List<int> l) => l.getRange(0, 1).length;', ''),
      'removeRange': ('void f(List<int> l) { l.removeRange(0, 1); }', ''),
      'runtimeType': (r'String f(Object o) => "${o.runtimeType}";', ''),
      'index on dynamic': ('Object? f(dynamic d) => d["x"];', ''),
      'compare by value': ('bool f() => {DateTime.utc(2024)}.isEmpty;', ''),
      'extends': ('int f() { K(); return 1; }', 'class K extends Error {}'),
      'integer above 2^53': ('int f() => 9007199254740993;', ''),
    };

    Future<LiteTranslationException> reject((String, String) c) {
      final (body, top) = c;
      final isMethod =
          !top.contains('extension') &&
          !top.contains('mixin') &&
          !top.contains('class ');
      return _fail(
        _state(
          isMethod ? body : 'int k() => f();',
          top: isMethod ? top : '$top\n$body',
        ),
        parts: {'s_more.dart': _partHeader},
      );
    }

    test('every construct of the table has a snippet (and only those)', () {
      expect({for (final h in liteHints) h.construct}, snippets.keys.toSet());
    });

    for (final h in liteHints) {
      test('${h.construct}: rejected, with its own suggestion', () async {
        final c = snippets[h.construct];
        if (c == null) fail('no snippet for ${h.construct}');
        final e = await reject(c);
        expect(
          e.errors.any((x) => x.hint == h.suggestion),
          isTrue,
          reason: e.errors.map((x) => '$x').join('\n'),
        );
      });
    }

    test('an error in generated code says the file is generated', () async {
      final e = await _fail(
        "$_header\npart 's.g.dart';\n"
        'class PState extends ThorState { final a = state(0); Object f() => g(); }\n',
        parts: {
          's_more.dart': _partHeader,
          's.g.dart':
              "part of 's.dart';\nObject g() => Future.value(1).timeout(const Duration(seconds: 1));\n",
        },
      );
      final x = e.errors.singleWhere((x) => x.path.endsWith('s.g.dart'));
      expect(x.hint, contains('generated'));
      expect(x.hint, contains('query()/command()'));
      expect(liteGeneratedConstruct, '*.g.dart');
    });

    // The only errors allowed to fall back to the generic suggestion. A new
    // common construct must join the table instead of this list.
    final genericOk = <String, (String, String)>{
      'Object(...)': ('Object f() => Object();', ''),
      'a Type as a value': ('Type f() => int;', ''),
    };
    for (final g in genericOk.entries) {
      test('generic on purpose: ${g.key}', () async {
        final e = await reject(g.value);
        expect(e.errors.map((x) => x.hint), everyElement(liteGenericHint));
      });
    }

    test(
      'every error of every snippet has a way out or says how itself',
      () async {
        for (final c in [...snippets.values, ...genericOk.values]) {
          final e = await reject(c);
          for (final x in e.errors) {
            expect(
              x.hint.isNotEmpty ||
                  RegExp(
                    r'\b(use|write|move|cast|create|iterate|catch|assign|interpolate|compare|only)\b',
                    caseSensitive: false,
                  ).hasMatch(x.message),
              isTrue,
              reason: '$x',
            );
          }
        }
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    for (final t in ['List<int>', 'Set<int>']) {
      test('is $t on Object is rejected; is List on Object is not', () async {
        final e = await reject(('bool f(Object o) => o is $t;', ''));
        expect(e.errors.single.message, contains('is $t'));
        expect(e.errors.single.hint, contains('is Map'));
        expect(
          await _translate(
            _state('bool f(Object o) => o is List;'),
            parts: {'s_more.dart': _partHeader},
          ),
          isNotEmpty,
        );
      });
    }

    test('case List<int> l on a dynamic value is rejected', () async {
      final e = await reject((
        'int f(dynamic d) { if (d case List<int> l) { return l.length; } return 0; }',
        '',
      ));
      expect(e.errors.single.message, contains('List<int>'));
    });

    test('a late field of the state or a helper class is rejected', () async {
      for (final c in [
        ('int g() => 1;\n  late int lz = 3;', ''),
        ('void s() { lz = 3; }\n  late final int lz;', ''),
        (
          'int f() => H().g();',
          'class H { late final int x; void s() { x = 1; } int g() => x; }',
        ),
      ]) {
        final e = await reject(c);
        final x = e.errors.firstWhere((x) => x.message.contains('`late`'));
        expect(x.hint, contains('nullable'));
      }
    });

    test('a chain over several lines points at the failing call', () async {
      final e = await reject((
        'Object f(Future<int> l) =>\n      l\n          .then((x) => x)\n          .timeout(const Duration(seconds: 1))\n          .toString();',
        '',
      ));
      final x = e.errors.singleWhere((x) => x.message.contains('.timeout()'));
      expect(x.frame, contains('.timeout('));
      expect(x.frame, isNot(contains('.then')));
    });
  });

  group('code frame', () {
    test('the line and a caret under the construct', () async {
      final e = await _fail(
        _state('Future<List<int>> f() => Future.wait([], cleanUp: (x) {});'),
        parts: {'s_more.dart': _partHeader},
      );
      final x = e.errors.singleWhere(
        (x) => x.message.startsWith('Future.wait'),
      );
      expect(
        x.frame,
        contains('Future<List<int>> f() => Future.wait([], cleanUp: (x) {});'),
      );
      _expectCaretUnder(x.frame, 'Future.wait');
    });

    test('an error inside a nested closure', () async {
      final e = await _fail(
        _state(
          'List<Object> f(List<int> l) {\n'
          '    return l.map((x) {\n'
          '      return [1].map((y) {\n'
          '        return Future.wait([Future.value(y)], cleanUp: (x) {});\n'
          '      }).toList();\n'
          '    }).toList();\n'
          '  }',
        ),
        parts: {'s_more.dart': _partHeader},
      );
      final x = e.errors.singleWhere(
        (x) => x.message.startsWith('Future.wait'),
      );
      expect(
        x.frame,
        contains('return Future.wait([Future.value(y)], cleanUp: (x) {});'),
      );
      _expectCaretUnder(x.frame, 'Future.wait');
    });

    test('CRLF line endings and tabs', () async {
      final source = _state(
        'Future<List<int>> f() {\n'
        '\t\tfinal x =\tFuture.wait([], cleanUp: (x) {});\n'
        '\t\treturn x;\n'
        '\t}',
      ).replaceAll('\n', '\r\n');
      final e = await _fail(source, parts: {'s_more.dart': _partHeader});
      final x = e.errors.singleWhere(
        (x) => x.message.startsWith('Future.wait'),
      );
      expect(x.frame, isNot(contains('\r')));
      expect(x.toString(), isNot(contains('\r')));
      // The tab between `=` and `Future` is a tab in the caret line too.
      expect(x.frame, contains('final x =\tFuture.wait([], cleanUp: (x) {});'));
      final caret = x.frame.split('\n').last;
      expect(caret, matches(RegExp(r'\|\s+ {6}\t\^$')));
    });

    test('unicode before the column', () async {
      final e = await _fail(
        _state(
          "Object f() { final s = 'ñ😀é'; return [s, Future.wait([], cleanUp: (x) {})]; }",
        ),
        parts: {'s_more.dart': _partHeader},
      );
      final x = e.errors.singleWhere(
        (x) => x.message.startsWith('Future.wait'),
      );
      _expectCaretUnder(x.frame, 'Future.wait');
    });

    test('a very long line is cut around the construct', () async {
      final pad = 'a' * 300;
      final e = await _fail(
        _state(
          "Object f() { final s = '$pad'; return [s, Future.wait([], cleanUp: (x) {}), '$pad']; }",
        ),
        parts: {'s_more.dart': _partHeader},
      );
      final x = e.errors.singleWhere(
        (x) => x.message.startsWith('Future.wait'),
      );
      for (final l in x.frame.split('\n')) {
        expect(l.length, lessThan(130), reason: l);
      }
      expect(x.frame, contains('…'));
      _expectCaretUnder(x.frame, 'Future.wait');
    });

    test('liteCodeFrame edges', () {
      expect(liteCodeFrame('a\nb', 5, 1), '');
      expect(liteCodeFrame('', 1, 1), contains('^'));
      expect(liteCodeFrame('ab', 1, 99), contains('^'));
      expect(liteCodeFrame('ab\r\ncd\r\n', 2, 2), isNot(contains('\r')));
      expect(liteCodeFrame('ab\r\ncd\r\n', 2, 2), contains('cd'));
    });
  });
}
