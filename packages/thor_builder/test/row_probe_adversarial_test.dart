// Adversarial: row classes a probe must survive (`implements` from another
// library): a constructor with required params, `late` and mutable fields, a
// private member, a getter that throws, a `noSuchMethod`, a setter, an
// abstract class, a mixin-composed class.
import 'package:analyzer/dart/analysis/results.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:thor_builder/src/app_entries.dart';
import 'package:thor_lints/lite.dart';

import 'support.dart';

String _app(String rowClass, String lambda) =>
    '''
import 'package:thor_ui/thor_ui.dart';

$rowClass

class RosterState extends ThorState {
  final people = state<List<Person>>(const []);
  int idOf(Person p) => 1;
}

final roster = RosterState();

Widget page() => Watch.list(
  roster.people.call,
  itemKey: roster.idOf,
  each: (row) => Row(children: [row.text($lambda)]),
);
''';

Future<(List<RowLambda>, List<String>)> _build(String source) async {
  final code = await resolveSources(
    {'app|lib/s.dart': source},
    (resolver) async {
      final lib = await resolver.libraryFor(AssetId.parse('app|lib/s.dart'));
      final result =
          await lib.session.getResolvedLibraryByElement(lib)
              as ResolvedLibraryResult;
      final lambdas = rowLambdasIn(result.units.first.unit, 'lib/s.dart');
      final states = statesLibrary(
        [
          for (final c in lib.classes)
            if (isRegisteredState(c)) (c, 'lib/s.dart'),
        ],
        warn: (_) {},
        problems: [],
        rowItems: {
          for (final l in lambdas)
            if (l.problem == null) ?l.item,
        },
      );
      return (lambdas, states);
    },
    rootPackage: 'app',
    readAllSourcesFromFilesystem: true,
  );
  final (lambdas, states) = code;
  final errors = await compileErrors({
    'app|lib/s.dart': source,
    'app|lib/states.dart': states,
  }, 'app|lib/states.dart');
  return (lambdas, errors);
}

void main() {
  for (final (label, rowClass, lambda) in [
    (
      'required constructor params and a late field',
      '''
class Person {
  Person(this.name, {required this.city});
  final String name;
  final String city;
  late String nick = name.toUpperCase();
}
''',
      '(o) => o.nick',
    ),
    (
      'a mutable field (has a setter)',
      'class Person { Person(); String name = ""; }',
      '(o) => o.name',
    ),
    (
      'a getter that throws',
      '''
class Person {
  const Person();
  String get name => throw StateError('boom');
}
''',
      '(o) => o.name',
    ),
    (
      'a private member next to the public one',
      '''
class Person {
  const Person();
  String get _secret => 's';
  String get name => _secret;
}
''',
      '(o) => o.name',
    ),
    (
      'a class with its own noSuchMethod',
      '''
class Person {
  const Person();
  String get name => 'n';
  @override
  dynamic noSuchMethod(Invocation i) => 'x';
}
''',
      '(o) => o.name',
    ),
    (
      'an abstract class',
      'abstract class Person { String get name; }',
      '(o) => o.name',
    ),
    (
      'an inherited getter through a mixin',
      '''
mixin Named { String get name => 'n'; }
class Person with Named { const Person(); }
''',
      '(o) => o.name',
    ),
    (
      'an extension type',
      'extension type const Person(String name) {}',
      '(o) => o.name',
    ),
    (
      'a record-like class with a static String',
      'class Person { const Person(); static String s = "x"; String get name => "n"; }',
      '(o) => o.name',
    ),
  ]) {
    test('the probe compiles for $label', () async {
      final (lambdas, errors) = await _build(_app(rowClass, lambda));
      expect(
        errors,
        isEmpty,
        reason: '$label\n${lambdas.map((l) => l.problem)}',
      );
    });
  }
}
