// `row.text((o) => o.customer)`: the build finds the lambdas that read
// one String property, writes the probe the server learns the property from
// (`registerRowProbes`) and the reader the lite bundle uses (`$Rows`); any
// other lambda is THOR-B030 with the fix.
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:thor_builder/src/app_entries.dart';
import 'package:thor_lints/lite.dart';

import 'support.dart';

String _app(String lambdas, {String extra = ''}) =>
    '''
import 'package:thor_ui/thor_ui.dart';

enum Tier { free, pro }

class Person {
  const Person(this.id, this.name, this.city);
  final int id;
  final String name;
  final String city;
  bool get vip => id > 1;
  Tier get tier => Tier.free;
  bool? get maybe => null;
  String get label => '\$name (\$city)';
  String? get note => null;
}

$extra

class RosterState extends ThorState {
  final people = state<List<Person>>(const []);
  int idOf(Person p) => p.id;
}

final roster = RosterState();

Widget page() => Watch.list(
  roster.people.call,
  itemKey: roster.idOf,
  each: (row) => Row(children: [$lambdas]),
);
''';

/// The lambdas of `lib/s.dart` and the library's classes.
Future<(List<RowLambda>, LibraryElement, CompilationUnit)> _scan(
  String source,
) => resolveSources(
  {'app|lib/s.dart': source},
  (resolver) async {
    final lib = await resolver.libraryFor(AssetId.parse('app|lib/s.dart'));
    final result =
        await lib.session.getResolvedLibraryByElement(lib)
            as ResolvedLibraryResult;
    final unit = result.units.first.unit;
    return (rowLambdasIn(unit, 'lib/s.dart'), lib, unit);
  },
  rootPackage: 'app',
  readAllSourcesFromFilesystem: true,
);

void main() {
  group('finding the lambdas', () {
    test('a property path is found, with its row class', () async {
      final (found, _, _) = await _scan(
        _app('row.text((o) => o.name), row.text((p) => (p.city))'),
      );
      expect(found.map((l) => l.property), ['name', 'city']);
      expect(found.map((l) => l.problem), [null, null]);
      expect(found.first.item!.name, 'Person');
    });

    test('an int or bool property as text is a property path', () async {
      final (found, _, _) = await _scan(
        _app(
          "row.text((o) => '\${o.id}'), row.text((o) => o.id.toString()), "
          "row.text((o) => (o.vip).toString()), row.text((o) => '\${o.name}')",
        ),
      );
      expect(found.map((l) => l.property), ['id', 'id', 'vip', 'name']);
      expect(found.map((l) => l.problem), [null, null, null, null]);
    });

    test('row.bind lambdas are found too, and named in the error', () async {
      final (found, _, _) = await _scan(
        _app(
          'Checkbox(value: false, semanticLabel: row.bind((o) => o.name)), '
          'Checkbox(value: false, semanticLabel: row.bind((o) => o.name.trim()))',
        ),
      );
      expect(found.map((l) => l.method), ['bind', 'bind']);
      expect(found.first.property, 'name');
      expect(found.last.message, contains('row.bind((o) => …)'));
      expect(found.last.message, contains('row.bind(state.customerOf)'));
    });

    test(
      'row.attribute and row.field lambdas are found: the name comes first',
      () async {
        final (found, _, _) = await _scan(
          _app(
            "row.attribute('title', (o) => o.name, child: const Text('x')), "
            "row.attribute('title', (o) => o.name.trim(), child: const Text('x')), "
            "row.field('who', (o) => o.city), "
            "row.field('who', (o) => '\${o.city}!')",
          ),
        );
        expect(found.map((l) => l.method), [
          'attribute',
          'attribute',
          'field',
          'field',
        ]);
        expect(found.map((l) => l.property), ['name', null, 'city', null]);
        expect(
          found[1].message,
          contains('row.attribute(AttributeName.title, (o) => …)'),
        );
        expect(
          found[1].message,
          contains('row.attribute(AttributeName.title, state.customerOf)'),
        );
        expect(
          found[3].message,
          contains("row.field('name', state.customerOf)"),
        );
      },
    );

    test('row.watch lambdas over a bool or an enum are found', () async {
      final (found, _, _) = await _scan(
        _app(
          'row.watch<bool>((o) => o.vip, builder: (v) => Text("\$v")), '
          'row.watch<Tier>((o) => o.tier, builder: (v) => Text("\$v"))',
        ),
      );
      expect(found.map((l) => l.method), ['watch', 'watch']);
      expect(found.map((l) => l.property), ['vip', 'tier']);
      expect(found.map((l) => l.states), [2, 2]);
      expect(found.map((l) => l.problem), [null, null]);
      expect(found.first.item!.name, 'Person');
    });

    for (final (label, lambda, why) in [
      (
        'a comparison',
        'row.watch<bool>((o) => o.id > 1, builder: b)',
        'does more',
      ),
      ('a negation', 'row.watch<bool>((o) => !o.vip, builder: b)', 'does more'),
      (
        'a String',
        'row.watch<String>((o) => o.name, builder: b)',
        'not a bool',
      ),
      (
        'an int',
        'row.watch<int>((o) => o.id, builder: b, count: 3)',
        'not a bool',
      ),
      (
        'a nullable bool',
        'row.watch<bool?>((o) => o.maybe, builder: b)',
        'not a bool',
      ),
    ]) {
      test('row.watch over $label is B030', () async {
        final (found, _, _) = await _scan(
          _app(lambda).replaceFirst(
            'class RosterState',
            'Widget b(Object? v) => const Text("");\nclass RosterState',
          ),
        );
        expect(found.single.problem, contains(why), reason: label);
        expect(found.single.message, contains('THOR-B030'));
        expect(found.single.message, contains('row.watch((o) => …'));
        expect(found.single.message, contains('row.watch(state.'));
      });
    }

    test('a tear-off for attribute or field is a method of a state', () async {
      final (found, _, _) = await _scan(
        _app(
          "row.attribute('title', roster.idOf, child: const Text('x')), "
          "row.field('who', roster.idOf)",
        ),
      );
      expect(found, isEmpty);
    });

    test(
      'a tear-off, a method of a state and other calls are left alone',
      () async {
        final (found, _, _) = await _scan(
          _app('row.text(roster.idOf as dynamic), Text((\'x\').toString())'),
        );
        expect(found, isEmpty);
      },
    );

    for (final (label, lambda, why) in [
      ('a method call', 'row.text((o) => o.name.trim())', 'does more'),
      ('an interpolation', 'row.text((o) => \'\${o.name}!\')', 'does more'),
      ('two properties', 'row.text((o) => o.name + o.city)', 'does more'),
      (
        'an int property plus text',
        'row.text((o) => \'#\${o.id}\')',
        'does more',
      ),
      (
        'a nullable property as text',
        'row.text((o) => \'\${o.note}\')',
        'not a String, an int',
      ),
      (
        'a bool method on a property',
        'row.text((o) => o.id.toStringAsFixed(1))',
        'does more',
      ),
      ('a block body', 'row.text((o) { return o.name; })', 'must be'),
      ('a constant', 'row.text((o) => \'x\')', 'does more'),
      ('an index', 'row.text((o) => o.name[0])', 'does more'),
      (
        'a nested property',
        'row.text((o) => o.name.length.toString())',
        'does more',
      ),
      (
        'a property of a property',
        'row.text((o) => (o.name).length)',
        'does more',
      ),
      (
        'an int property read directly',
        'row.text((o) => o.id)',
        'not a String',
      ),
      ('a null-aware read', 'row.text((o) => o.note ?? \'\')', 'does more'),
    ]) {
      test(label, () async {
        final (found, _, _) = await _scan(_app(lambda));
        expect(found.single.problem, contains(why), reason: label);
        expect(found.single.message, contains('THOR-B030'));
        expect(found.single.message, contains('lib/s.dart:'));
        expect(found.single.message, contains('row.text(state.customerOf)'));
      });
    }

    test(
      'a getter of the class that computes a String is a property',
      () async {
        final (found, _, _) = await _scan(_app('row.text((o) => o.label)'));
        expect(found.single.property, 'label');
        expect(found.single.problem, isNull);
      },
    );

    test('a private, final or generic row class cannot have a probe', () async {
      for (final (extra, decl) in [
        ('class _Hidden { const _Hidden(); String get t => "t"; }', '_Hidden'),
        (
          'final class Sealed { const Sealed(); String get t => "t"; }',
          'Sealed',
        ),
        ('class Box<T> { const Box(); String get t => "t"; }', 'Box<int>'),
      ]) {
        final source = _app('const Text("")', extra: extra)
            .replaceFirst('const Text("")', 'row.text((o) => o.t)')
            .replaceAll('List<Person>', 'List<$decl>')
            .replaceAll('int idOf(Person p)', 'int idOf($decl p)');
        final (found, _, _) = await _scan(source);
        expect(found.single.problem, isNotNull, reason: decl);
        expect(found.single.message, contains('THOR-B030'), reason: decl);
      }
    });
  });

  group('the probe', () {
    test('a class per row type, registered, with its String getters', () async {
      final code = await resolveSources(
        {'app|lib/s.dart': _app('row.text((o) => o.name)')},
        (resolver) async {
          final lib = await resolver.libraryFor(
            AssetId.parse('app|lib/s.dart'),
          );
          final result =
              await lib.session.getResolvedLibraryByElement(lib)
                  as ResolvedLibraryResult;
          final lambdas = rowLambdasIn(result.units.first.unit, 'lib/s.dart');
          return statesLibrary(
            [
              for (final c in lib.classes)
                if (isRegisteredState(c)) (c, 'lib/s.dart'),
            ],
            warn: (_) {},
            problems: [],
            rowItems: {for (final l in lambdas) ?l.item},
          );
        },
        rootPackage: 'app',
        readAllSourcesFromFilesystem: true,
      );
      expect(code, contains('registerRowProbes({'));
      expect(code, contains('t0.Person: (log) => _RowProbe0(log)'));
      expect(code, contains('class _RowProbe0 implements t0.Person'));
      for (final p in ['name', 'city', 'label']) {
        expect(code, contains('String get $p {'), reason: p);
        expect(code, contains("log.read('$p')"), reason: p);
      }
      expect(code, contains('String? get note {'));
      // An int answers with a number the lambda can only turn into text.
      expect(code, contains("int get id => log.integer('id');"));
      expect(code, contains('noSuchMethod'));
    });

    test('a bool or enum getter answers with a choice of its values', () async {
      final code = await resolveSources(
        {
          'app|lib/s.dart': _app(
            'row.watch<bool>((o) => o.vip, builder: (v) => Text("\$v"))',
          ),
        },
        (resolver) async {
          final lib = await resolver.libraryFor(
            AssetId.parse('app|lib/s.dart'),
          );
          final result =
              await lib.session.getResolvedLibraryByElement(lib)
                  as ResolvedLibraryResult;
          final lambdas = rowLambdasIn(result.units.first.unit, 'lib/s.dart');
          return statesLibrary(
            [
              for (final c in lib.classes)
                if (isRegisteredState(c)) (c, 'lib/s.dart'),
            ],
            warn: (_) {},
            problems: [],
            rowItems: {for (final l in lambdas) ?l.item},
          );
        },
        rootPackage: 'app',
        readAllSourcesFromFilesystem: true,
      );
      expect(
        code,
        contains(
          "bool get vip => log.choose('vip', const [false, true]) as bool;",
        ),
      );
      expect(
        code,
        contains(
          "t0.Tier get tier => log.choose('tier', t0.Tier.values) as t0.Tier;",
        ),
      );
      // Nullable ones are not finite states.
      expect(code, isNot(contains('get maybe')));
    });

    test('the generated registry compiles against the app', () async {
      final source = _app('row.text((o) => o.name)');
      final code = await resolveSources(
        {'app|lib/s.dart': source},
        (resolver) async {
          final lib = await resolver.libraryFor(
            AssetId.parse('app|lib/s.dart'),
          );
          final result =
              await lib.session.getResolvedLibraryByElement(lib)
                  as ResolvedLibraryResult;
          final lambdas = rowLambdasIn(result.units.first.unit, 'lib/s.dart');
          return statesLibrary(
            [
              for (final c in lib.classes)
                if (isRegisteredState(c)) (c, 'lib/s.dart'),
            ],
            warn: (_) {},
            problems: [],
            rowItems: {for (final l in lambdas) ?l.item},
          );
        },
        rootPackage: 'app',
        readAllSourcesFromFilesystem: true,
      );
      final errors = await compileErrors({
        'app|lib/s.dart': source,
        'app|lib/states.dart': code,
      }, 'app|lib/states.dart');
      expect(errors, isEmpty);
    });

    test('an app with no row lambda registers no probes', () async {
      final code = await resolveSources(
        {'app|lib/s.dart': _app('row.text(roster.idOf as dynamic)')},
        (resolver) async {
          final lib = await resolver.libraryFor(
            AssetId.parse('app|lib/s.dart'),
          );
          return statesLibrary(
            [
              for (final c in lib.classes)
                if (isRegisteredState(c)) (c, 'lib/s.dart'),
            ],
            warn: (_) {},
            problems: [],
          );
        },
        rootPackage: 'app',
        readAllSourcesFromFilesystem: true,
      );
      expect(code, isNot(contains('registerRowProbes')));
    });
  });

  group('the lite bundle', () {
    Future<String> translate(String source) async {
      final units = await resolveSources(
        {'app|lib/s.dart': source},
        (resolver) async {
          final lib = await resolver.libraryFor(
            AssetId.parse('app|lib/s.dart'),
          );
          final result =
              await lib.session.getResolvedLibraryByElement(lib)
                  as ResolvedLibraryResult;
          return [for (final u in result.units) LiteUnit('lib/s.dart', u.unit)];
        },
        rootPackage: 'app',
        readAllSourcesFromFilesystem: true,
      );
      return translateLiteStates(units);
    }

    test('defines the reader of each property used, once', () async {
      final js = await translate(
        _app(
          'row.text((o) => o.name), row.text((o) => o.city), row.text((o) => o.name)',
        ),
      );
      expect(js, contains(r"thor.def('$Rows'"));
      expect(js, contains('name: (it) => it.name'));
      expect(js, contains('city: (it) => it.city'));
      expect(RegExp('name: \\(it\\)').allMatches(js), hasLength(1));
      expect(js, isNot(contains('label: (it)')));
    });

    test(
      'the readers of attribute and field lambdas are defined too',
      () async {
        final js = await translate(
          _app(
            "row.attribute('title', (o) => o.name, child: const Text('x')), "
            "row.field('who', (o) => o.city)",
          ),
        );
        expect(js, contains('name: (it) => it.name'));
        expect(js, contains('city: (it) => it.city'));
      },
    );

    test('the reader of a row.watch lambda is defined too', () async {
      final js = await translate(
        _app(
          'row.watch<bool>((o) => o.vip, builder: (v) => Text("\$v")), '
          'row.watch<Tier>((o) => o.tier, builder: (v) => Text("\$v"))',
        ),
      );
      expect(js, contains('vip: (it) => it.vip'));
      expect(js, contains('tier: (it) => it.tier'));
    });

    test('no row lambda, no \$Rows', () async {
      final js = await translate(_app('row.text(roster.idOf as dynamic)'));
      expect(js, isNot(contains(r'$Rows')));
    });

    test('the reader reads the item the way the state does', () async {
      final js = await translate(_app('row.text((o) => o.name)'));
      if (Process.runSync('node', ['--version']).exitCode != 0) {
        return markTestSkipped('node is not installed');
      }
      final r = Process.runSync('node', [
        '-e',
        '''
const defs = {}; globalThis.thor = { def: (n, f) => { defs[n] = f; } };
$js
const m = defs['\\\$Rows']({});
console.log(JSON.stringify([m.name({ name: 'Ana' }), Object.keys(m)]));
''',
      ]);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(jsonDecode(r.stdout as String), [
        'Ana',
        ['name', r'$s'],
      ]);
    });
  });
}
