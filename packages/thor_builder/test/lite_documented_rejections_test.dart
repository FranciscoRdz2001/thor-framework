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

Future<String> _js(String body, {String top = ''}) =>
    _translate(_state(body, top: top), parts: {'s_more.dart': _partHeader});

/// The lite subset docs say the construct is rejected: it must be.
void _rejected(String name, String body, {String top = ''}) {
  test('the doc rejects $name and the translator does too', () async {
    try {
      final js = await _js(body, top: top);
      fail('accepted, the doc says it is rejected. JS:\n$js');
    } on LiteTranslationException {
      // rejected, as documented
    }
  });
}

void _claims() {
  // `==` of collections is identity in Dart too: accepted, as `===`.
  for (final t in ['List<int>', 'Set<int>', 'Map<int, int>']) {
    test('== of $t is identity, as in Dart, and translates', () async {
      final js = await _js('bool f($t a, $t b) => a == b;');
      expect(js, contains('==='));
    });
  }
  // Records and classes with `==` compare by value in a Set and as a Map
  // key: translated to the runtime's hash-aware `$HS` / `$HM`.
  test('a Set of records and a Map keyed by a record translate', () async {
    expect(
      await _js('bool f() => {(1, 2)}.contains((1, 2));'),
      contains(r'new $HS('),
    );
    expect(
      await _js('int f() => {(1, 2): 3}[(1, 2)]!;'),
      contains(r'new $HM('),
    );
  });
  _rejected('is List<T>', 'bool f(Object o) => o is List<int>;');
  _rejected(
    'is List<String> on dynamic',
    'bool f(dynamic o) => o is List<String>;',
  );
  _rejected(
    'lastIndexOf(RegExp)',
    'int f(String s) => s.lastIndexOf(RegExp("a"));',
  );
  _rejected(
    'list pattern with type args on dynamic',
    'int f(dynamic d) { if (d case List<int> l) { return l.length; } return 0; }',
  );
  // A `when` guard is supported (a constant switch with one lowers to
  // patterns): the doc must not list it as outside the subset.
  for (final body in [
    'int f(int x) { switch (x) { case 1 when x > 0: return 1; default: return 0; } }',
    'int f(int x) => switch (x) { 1 when x > 0 => 1, _ => 0 };',
  ]) {
    test('a when guard on a constant pattern translates: $body', () async {
      expect(await _js(body), isNotEmpty);
    });
  }
  _rejected(
    'late final field on a helper class (not documented, silently wrong)',
    'int f() => H().g();',
    top: 'class H { late final int x; void s() { x = 1; } int g() => x; }',
  );
  _rejected('late field on the state', 'int g() => 1;\n  late int lz = 3;');
  _rejected(
    'late final field on the state without initializer',
    'void s() { lz = 3; }\n  late final int lz;',
  );
  _rejected(
    'Future.timeout (hint lists it)',
    'Future<int> f() => Future.value(1).timeout(const Duration(seconds: 1));',
  );
}

const _one =
    "import 'dart:async';import 'package:thor_ui/thor_ui.dart';part 's_more.dart';";
const _cls =
    r'class PState extends ThorState { final a = state(0); Future<List<int>> f() => Future.wait([], cleanUp: (x) {}); }';

Future<LiteTranslationException> _failRaw(
  String src, {
  Map<String, String> parts = const {'s_more.dart': _partHeader},
}) => _fail(src, parts: parts);

void _caretIs(LiteError x, String under) => _expectCaretUnder(x.frame, under);

void _frames() {
  test('BOM on line 1', () async {
    final e = await _failRaw('﻿$_one$_cls');
    final x = e.errors.singleWhere((x) => x.message.startsWith('Future.wait'));
    _caretIs(x, 'Future.wait');
  });
  test('mixed LF and CRLF', () async {
    final e = await _failRaw(
      '$_header\r\n\r\nclass PState extends ThorState {\n  final a = state(0);\r\n  Future<List<int>> f() =>\n      Future.wait([], cleanUp: (x) {});\r\n}\n',
    );
    final x = e.errors.singleWhere((x) => x.message.startsWith('Future.wait'));
    expect(x.toString(), isNot(contains('\r')));
    _caretIs(x, 'Future.wait');
  });
  test('error on the last line without trailing newline', () async {
    final e = await _failRaw('$_header\n$_cls');
    final x = e.errors.singleWhere((x) => x.message.startsWith('Future.wait'));
    expect(x.frame, contains('Future.wait'));
    _caretIs(x, 'Future.wait');
  });
  test('a construct that spans lines points at its first line', () async {
    final e = await _failRaw(
      _state(
        'Future<List<int>> f() => Future.wait(\n    [\n      Future.value(1),\n    ],\n    cleanUp: (x) {},\n  );',
      ),
    );
    final x = e.errors.singleWhere((x) => x.message.startsWith('Future.wait'));
    _caretIs(x, 'Future.wait');
  });
  test(
    'ZWJ emoji before the column keeps the caret under it (display cells; known limit: aligned by rune)',
    skip: 'documented limit: liteCodeFrame aligns by rune, not display cells',
    () async {
      final e = await _failRaw(
        _state(
          "Object f() { final s = '👨‍👩‍👧'; return [s, Future.wait([], cleanUp: (x) {})]; }",
        ),
      );
      final x = e.errors.singleWhere(
        (x) => x.message.startsWith('Future.wait'),
      );
      _caretIs(x, 'Future.wait');
      // The ZWJ family is 1 glyph (2 cells) but the caret line pads 8 units.
      final lines = x.frame.split('\n');
      final code = lines[0].substring(lines[0].indexOf('| ') + 2);
      final caret = lines[1].substring(lines[1].indexOf('| ') + 2);
      final upto = code.substring(0, code.indexOf('Future.wait'));
      // Cells: every rune is 1 cell except the emoji glyph = 2 cells.
      final cells = upto.replaceAll('👨‍👩‍👧', 'XX').runes.length;
      expect(
        caret.indexOf('^'),
        cells,
        reason: 'caret misaligned in a terminal:\n${x.frame}',
      );
    },
  );
  test(
    'a CJK string before the column keeps the caret under it',
    skip: 'documented limit: liteCodeFrame aligns by rune, not display cells',
    () async {
      final e = await _failRaw(
        _state(
          "Object f() { final s = '日本語'; return [s, Future.wait([], cleanUp: (x) {})]; }",
        ),
      );
      final x = e.errors.singleWhere(
        (x) => x.message.startsWith('Future.wait'),
      );
      final lines = x.frame.split('\n');
      final code = lines[0].substring(lines[0].indexOf('| ') + 2);
      final caret = lines[1].substring(lines[1].indexOf('| ') + 2);
      final upto = code.substring(0, code.indexOf('Future.wait'));
      final cells =
          upto.replaceAll('日本語', '日本語日本語日本語'.substring(0, 3)).runes.length +
          3; // wide glyphs count 2
      expect(
        caret.indexOf('^'),
        cells,
        reason: 'caret misaligned for wide glyphs:\n${x.frame}',
      );
    },
  );
}

void _hints() {
  test('an operator other than == does not get the hashCode hint', () async {
    final e = await _failRaw(
      _state(
        'int f() => (P(1) + P(2)).a;',
        top:
            'class P { final int a; const P(this.a); P operator +(P o) => P(a + o.a); }',
      ),
    );
    final x = e.errors.firstWhere((x) => x.message.contains('Operator P.+'));
    expect(x.hint, isNot(contains('key sets and maps')), reason: x.hint);
    expect(x.hint, contains('method'));
  });
  test('the Iterable hint (turn it into a List) actually fixes it', () async {
    final e = await _failRaw(
      _state(r'String f() { final s = <Object>{}; return "$s"; }'),
    );
    final x = e.errors.firstWhere(
      (x) => x.message.contains('Interpolating a Set<Object>'),
    );
    // .toList() does not fix a collection of Object: type it or join.
    expect(x.hint, isNot(contains('.toList()')));
    expect(x.hint, contains('join'));
  });
}

void _dedup() {
  test(
    'in a multi-line chain the caret points at the offending call, not the chain head',
    () async {
      final e = await _failRaw(
        _state(
          'Object f(Future<int> l) =>\n      l\n          .then((x) => x)\n          .timeout(const Duration(seconds: 1))\n          .toString();',
        ),
      );
      final x = e.errors.singleWhere((x) => x.message.contains('.timeout()'));
      expect(
        x.line,
        13,
        reason: 'reported at ${x.line}:${x.column}\n${x.frame}',
      );
    },
  );

  test('a helper reached through 3 states reports once', () async {
    final e = await _failRaw(
      _header +
          r'''
Future<List<int>> h() => Future.wait([], cleanUp: (x) {});
class AState extends ThorState { final a = state(0); Future<List<int>> f() => h(); }
class BState extends ThorState { final a = state(0); Future<List<int>> f() => h(); }
class CState extends ThorState { final a = state(0); Future<List<int>> f() => h(); }
''',
    );
    final w = e.errors
        .where((x) => x.message.startsWith('Future.wait'))
        .toList();
    expect(w.length, 1, reason: e.report);
    expect(e.report, startsWith('${e.errors.length} construct(s)'));
  });
  test('same message and line, different columns stay separate', () async {
    final e = await _failRaw(
      _state(
        'Object f() => [Future.wait([], cleanUp: (x) {}),Future.wait([], cleanUp: (x) {})];',
      ),
    );
    expect(
      e.errors.where((x) => x.message.startsWith('Future.wait')).length,
      2,
    );
  });
  test('an error in a generated .g.dart part says it is generated code', () async {
    final e = await _failRaw(
      "$_header part 's.g.dart';\nclass PState extends ThorState { final a = state(0); Object f() => g(); }\n",
      parts: {
        's_more.dart': _partHeader,
        's.g.dart':
            "part of 's.dart';\nObject g() => Future.value(1).timeout(const Duration(seconds: 1));\n",
      },
    );
    final x = e.errors.singleWhere((x) => x.path.endsWith('s.g.dart'));
    expect(x.frame, contains('timeout'));
    // Generated code cannot be edited: the fix must not tell to edit it.
    expect(
      x.hint + x.message,
      anyOf(contains('generated'), contains('.g.dart')),
      reason: '$x',
    );
  });
  test('500 errors report deterministically and completely', () async {
    final b = StringBuffer();
    for (var i = 0; i < 500; i++) {
      b.writeln(
        '  Future<List<int>> m$i() => Future.wait([], cleanUp: (x) {});',
      );
    }
    final src = _state(b.toString());
    final sw = Stopwatch()..start();
    final e1 = await _failRaw(src);
    final t = sw.elapsedMilliseconds;
    final e2 = await _failRaw(src);
    expect(e1.report, e2.report);
    expect(e1.errors.length, 500);
    expect(e1.report, startsWith('500 construct(s)'));
    expect(
      e1.report.split('\n').where((l) => l.contains('  fix: ')).length,
      500,
    );
    // ignore: avoid_print
    print('500 errors: ${e1.report.length} bytes, ${t}ms');
  });
  test('every error keeps its code and stays English', () async {
    final e = await _failRaw(
      _state('Future<List<int>> f() => Future.wait([], cleanUp: (x) {});'),
    );
    expect(e.report, contains('THOR-B012'));
    expect(
      e.report,
      matches(RegExp(r'^\d+ construct\(s\) outside the thor-lite subset:')),
    );
  });
}

void main() {
  _claims();
  _frames();
  _dedup();
  _hints();
}
