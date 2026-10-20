import 'package:analyzer/dart/analysis/results.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:thor_builder/src/app_entries.dart';
import 'package:thor_lints/lite.dart';

// A state with server commands whose functions use what the lite engine
// can't translate (dart:io, sync*): they must never be walked.
const _cart = r"""
import 'dart:io';

import 'package:thor_ui/thor_ui.dart';

class Line {
  const Line(this.sku, this.qty);
  factory Line.fromJson(Map<String, Object?> json) =>
      Line(json['sku']! as String, json['qty']! as int);
  final String sku;
  final int qty;
  Map<String, Object?> toJson() => {'sku': sku, 'qty': qty};
}

class Repo {
  const Repo();
  Iterable<int> _ids() sync* {
    yield 1;
  }
  Future<List<Line>> lines() async => [for (final i in _ids()) Line('$i', i)];
  Future<Line> add(String sku) async {
    await File('/tmp/cart').writeAsString(sku);
    return Line(sku, 1);
  }
  Future<void> clear() async => File('/tmp/cart').deleteSync();
  Future<int> setQty(int qty) async => qty;
}

const repo = Repo();

class CartState extends ThorState {
  final lines = query(repo.lines);
  final add = commandWith(repo.add, invalidates: (CartState s) => [s.lines]);
  final clear = command(repo.clear);
  final setQty = commandWith(repo.setQty);

  bool busy() => add.pending.value || clear.pending.value;
  String failure() => add.error.value ?? '';
  String last() => add.result.value?.sku ?? '';
  void buy(String sku) => add.run(sku);
  void empty() => clear.run();

  // `run` gives a Future: a state method can wait for it and go on.
  Future<void> buyTwice(String sku) async {
    final first = await add.run(sku);
    if (first != null) await add.run(sku);
    await clear.run();
  }

  bool rowBusy(String sku) => add.pendingFor(sku);

  // Branch on why a call failed.
  bool offline() => add.errorKind.value == ServerErrorKind.network;
  String why() => clear.errorKind.value?.name ?? '';
  bool signedOut() => lines.errorKind.value == ServerErrorKind.unauthorized;
}

final cart = CartState();
""";

// `setQty` takes a class of the app.
final _withClassArg = _cart
    .replaceFirst(
      'Future<int> setQty(int qty) async => qty;',
      'Future<int> setQty(Line line) async => line.qty;',
    )
    .replaceFirst(
      'void empty() => clear.run();',
      "void empty() => clear.run();\n  void set() => setQty.run(const Line('a', 2));",
    );

Future<T> _resolve<T>(
  String source,
  Future<T> Function(ResolvedLibraryResult lib) body,
) => resolveSources(
  {'app|lib/shop.dart': source},
  (resolver) async {
    final lib = await resolver.libraryFor(AssetId.parse('app|lib/shop.dart'));
    return body(
      await lib.session.getResolvedLibraryByElement(lib)
          as ResolvedLibraryResult,
    );
  },
  rootPackage: 'app',
  readAllSourcesFromFilesystem: true,
);

Future<(String, List<EntryProblem>)> _registry(String source) =>
    _resolve(source, (lib) async {
      final problems = <EntryProblem>[];
      final code = statesLibrary(
        [
          for (final c in lib.element.classes)
            if (isRegisteredState(c)) (c, 'lib/shop.dart'),
        ],
        warn: (_) {},
        problems: problems,
      );
      return (code, problems);
    });

Future<String> _lite(String source) => _resolve(
  source,
  (lib) async => translateLiteStates([
    for (final u in lib.units) LiteUnit('lib/shop.dart', u.unit),
  ]),
);

void main() {
  group('the registry', () {
    test('a command field gives its members, marked for thor build', () async {
      final (code, problems) = await _registry(_cart);
      expect(problems, isEmpty);
      expect(code, contains("...s.add.members('add') /* command */"));
      expect(code, contains("...s.clear.members('clear') /* command */"));
      expect(code, contains("...s.lines.members('lines'),"));
      // The repository never becomes a member.
      expect(code, isNot(contains('repo')));
    });

    test('lists the endpoints thor build prints', () async {
      final (queries, commands) = await _resolve(
        _cart,
        (lib) async => (
          queryEndpoints(lib.element.classes),
          commandEndpoints(lib.element.classes),
        ),
      );
      expect(queries, ['CartState.lines']);
      expect(commands, [
        'CartState.add',
        'CartState.clear',
        'CartState.setQty',
      ]);
    });

    test('a result that is not JSON is THOR-B021; void is fine', () async {
      final (_, problems) = await _registry(
        _cart.replaceFirst(
          "  Map<String, Object?> toJson() => {'sku': sku, 'qty': qty};\n",
          '',
        ),
      );
      // The query and the command both return Line: the first one found
      // stops the class.
      expect(problems.single.toString(), contains('THOR-B021'));
      expect(problems.single.toString(), contains('toJson()'));
    });

    test('an argument that is not a simple value is THOR-B021', () async {
      final (_, problems) = await _registry(
        _cart.replaceFirst(
          'Future<int> setQty(int qty) async => qty;',
          'Future<int> setQty(List<int> qty) async => qty.length;',
        ),
      );
      expect(problems.single.toString(), contains('THOR-B021'));
      expect(problems.single.toString(), contains('CartState.setQty'));
      expect(problems.single.toString(), contains('takes an argument'));
    });

    test('an argument may be a class with toJson and fromJson', () async {
      final (code, problems) = await _registry(_withClassArg);
      expect(problems, isEmpty);
      // The registry says how the argument becomes JSON and back.
      expect(
        code,
        contains(
          "...s.setQty.members('setQty', argToJson: (a) => a.toJson(), "
          'argFromJson: ',
        ),
      );
      expect(code, contains('Line.fromJson'));
      // A command with a simple argument says nothing.
      expect(code, contains("...s.add.members('add') /* command */"));
    });

    test('an argument may be a record of simple values', () async {
      final (code, problems) = await _registry(
        _cart.replaceFirst(
          'Future<int> setQty(int qty) async => qty;',
          'Future<int> setQty(({String sku, int qty}) e) async => e.qty;',
        ),
      );
      expect(problems, isEmpty);
      expect(code, contains("argToJson: (a) => {'qty': a.qty, 'sku': a.sku}"));
    });

    test('a class argument without fromJson is THOR-B021', () async {
      final (_, problems) = await _registry(
        _cart
            .replaceFirst(
              'Future<int> setQty(int qty) async => qty;',
              'Future<int> setQty(Raw raw) async => 1;',
            )
            .replaceFirst(
              'class Repo {',
              'class Raw {\n  const Raw();\n}\n\nclass Repo {',
            ),
      );
      expect(problems.single.toString(), contains('THOR-B021'));
      expect(problems.single.toString(), contains('CartState.setQty'));
      expect(problems.single.toString(), contains('takes an argument'));
    });
  });

  group('the lite translation', () {
    late String js;
    setUpAll(() async => js = await _lite(_cart));

    test('makes each command with the part `server_command`', () {
      expect(js, contains('server_command'));
      expect(
        js,
        contains(r"$SC($, 'CartState', 'add', (j) => Line.fromJson(j), 1);"),
      );
      expect(js, contains(r"$SC($, 'CartState', 'clear', null);"));
      expect(js, contains(r"'add$pending': () => add.pending.value"));
      expect(js, contains(r"'add$result': () => add.result.value"));
      // `run` from the page: the text argument parsed like a method's.
      expect(js, contains(r"'add$run': (a) => add.run(a)"));
      expect(js, contains(r"'setQty$run': (a) => setQty.run($int(a))"));
      expect(js, contains(r"'clear$run': () => clear.run()"));
    });

    test('a class argument is written with its toJson', () async {
      final out = await _lite(_withClassArg);
      expect(
        out,
        contains(
          r"$SC($, 'CartState', 'setQty', null, 1, null, (a) => a.toJson());",
        ),
      );
      // A simple argument adds nothing.
      expect(
        out,
        contains(r"$SC($, 'CartState', 'add', (j) => Line.fromJson(j), 1);"),
      );
    });

    test('`errorKind` is an enum of thor the state can compare', () {
      expect(
        js,
        contains('add.errorKind.value === \$ServerErrorKind\$values[0]'),
      );
      expect(js, contains('clear.errorKind.value?.name'));
      expect(
        js,
        contains('lines.errorKind.value === \$ServerErrorKind\$values[3]'),
      );
      // The part finds the values by name, from the one array.
      expect(
        js,
        contains(r"const $ServerErrorKind$values = $enum('ServerErrorKind', ["),
      );
      expect(js, contains(r'thor.K = $ServerErrorKind$values;'));
      for (final n in [
        'network',
        'timeout',
        'aborted',
        'unauthorized',
        'forbidden',
        'validation',
        'client',
        'server',
      ]) {
        expect(js, contains("'$n'"));
      }
    });

    test('a state that never reads `errorKind` ships no enum', () async {
      final out = await _lite(
        _cart
            .replaceFirst(
              '  bool offline() => add.errorKind.value == ServerErrorKind.network;\n',
              '',
            )
            .replaceFirst(
              "  String why() => clear.errorKind.value?.name ?? '';\n",
              '',
            )
            .replaceFirst(
              '  bool signedOut() => lines.errorKind.value == ServerErrorKind.unauthorized;\n',
              '',
            ),
      );
      expect(out, isNot(contains('ServerErrorKind')));
      expect(out, isNot(contains('thor.K')));
    });

    test('`invalidates:` stays on the server: not a byte of it in the JS', () {
      expect(js, isNot(contains('invalidates')));
      expect(js, isNot(contains('s.lines')));
      expect(
        js,
        contains(r"$SC($, 'CartState', 'add', (j) => Line.fromJson(j), 1);"),
      );
    });

    test('`timeout:` reaches the browser as milliseconds', () async {
      final out = await _lite(
        _cart
            .replaceFirst(
              'final setQty = commandWith(repo.setQty);',
              'final setQty = commandWith(repo.setQty, timeout: Duration(seconds: 3));',
            )
            .replaceFirst(
              'final clear = command(repo.clear);',
              'final clear = command(repo.clear, timeout: const Duration(minutes: 1, milliseconds: 500));',
            )
            .replaceFirst(
              'final lines = query(repo.lines);',
              'final lines = query(repo.lines, timeout: Duration(milliseconds: 1500));',
            ),
      );
      expect(out, contains(r"$SC($, 'CartState', 'setQty', null, 1, 3000);"));
      expect(out, contains(r"$SC($, 'CartState', 'clear', null, 0, 60500);"));
      expect(out, contains(', 0, 1500);'));
    });

    test(
      'a `timeout:` past what setTimeout holds is clamped, not overflown',
      () async {
        // A browser reads a delay over 2^31-1 ms as 0: the call would time out
        // at once. The cap is about 24.8 days; a literal that overflows an int
        // must not wrap around either.
        final out = await _lite(
          _cart
              .replaceFirst(
                'final setQty = commandWith(repo.setQty);',
                'final setQty = commandWith(repo.setQty, timeout: Duration(days: 40));',
              )
              .replaceFirst(
                'final clear = command(repo.clear);',
                'final clear = command(repo.clear, timeout: Duration(milliseconds: 9223372036854775807));',
              )
              .replaceFirst(
                'final lines = query(repo.lines);',
                'final lines = query(repo.lines, timeout: Duration(days: 9223372036854775807, hours: 9223372036854775807));',
              ),
        );
        expect(
          out,
          contains(r"$SC($, 'CartState', 'setQty', null, 1, 2147483647);"),
        );
        expect(
          out,
          contains(r"$SC($, 'CartState', 'clear', null, 0, 2147483647);"),
        );
        expect(out, contains(', 0, 2147483647);'));
      },
    );

    test('`Duration.zero` reaches the browser as 0: no timeout at all', () async {
      final out = await _lite(
        _cart
            .replaceFirst(
              'final setQty = commandWith(repo.setQty);',
              'final setQty = commandWith(repo.setQty, timeout: Duration.zero);',
            )
            .replaceFirst(
              'final clear = command(repo.clear);',
              'final clear = command(repo.clear, timeout: const Duration(seconds: 0));',
            )
            .replaceFirst(
              'final lines = query(repo.lines);',
              'final lines = query(repo.lines, timeout: Duration());',
            ),
      );
      expect(out, contains(r"$SC($, 'CartState', 'setQty', null, 1, 0);"));
      expect(out, contains(r"$SC($, 'CartState', 'clear', null, 0, 0);"));
      expect(out, contains(', 0, 0);'));
    });

    test(
      'a call without `timeout:` sends nothing: the browser has the default',
      () async {
        final out = await _lite(_cart);
        expect(out, isNot(contains('30000')));
        expect(out, contains(r"$SC($, 'CartState', 'clear', null);"));
      },
    );

    test('a `timeout:` that is not a Duration of literals is a lite error', () {
      for (final bad in [
        'timeout: wait',
        'timeout: Duration(seconds: n)',
        'timeout: Duration(microseconds: 5)',
        'timeout: Duration(seconds: -1)',
      ]) {
        expect(
          _lite(
            '${_cart.replaceFirst('final clear = command(repo.clear);', 'final clear = command(repo.clear, $bad);')}'
            '\nconst wait = Duration(seconds: 2);\nconst n = 2;',
          ),
          throwsA(
            predicate((e) => '$e'.contains('`timeout:` takes a Duration')),
          ),
          reason: bad,
        );
      }
    });

    test('never translates the server function', () {
      expect(js, isNot(contains('Repo')));
      expect(js, isNot(contains('/tmp/cart')));
      expect(js, isNot(contains('_ids')));
    });

    test('state methods read and run the command', () {
      expect(js, contains('add.pending.value || clear.pending.value'));
      expect(js, contains('add.result.value?.sku'));
      expect(js, contains('add.run(sku)'));
      expect(js, contains('clear.run()'));
    });

    test('a state awaits `run` and asks `pendingFor`', () {
      expect(js, contains('async '));
      expect(js, contains('await add.run(sku)'));
      expect(js, contains('await clear.run()'));
      expect(js, contains('add.pendingFor(sku)'));
    });

    test('a command outside a final field initializer is a lite error', () {
      expect(
        _lite(
          _cart.replaceFirst(
            'final clear = command(repo.clear);',
            'late ServerCommand<void> clear = command(repo.clear);',
          ),
        ),
        throwsA(
          predicate((e) => '$e'.contains('a command is made in a `final`')),
        ),
      );
    });
  });
}
