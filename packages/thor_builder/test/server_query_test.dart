import 'package:analyzer/dart/analysis/results.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:thor_builder/src/app_entries.dart';
import 'package:thor_lints/lite.dart';

// A state with server queries whose functions use what the lite engine
// can't translate (dart:io, sync*): they must never be walked.
const _profile = r'''
import 'dart:io';

import 'package:thor_ui/thor_ui.dart';

class Profile {
  const Profile(this.name);
  factory Profile.fromJson(Map<String, Object?> json) =>
      Profile(json['name']! as String);
  final String name;
  Map<String, Object?> toJson() => {'name': name};
}

class Repo {
  const Repo();
  Future<Profile> info() async =>
      Profile(await File('/etc/hostname').readAsString());
  Iterable<int> _ids() sync* {
    yield 1;
  }
  Future<List<Profile>> page(int n) async =>
      [for (final i in _ids()) Profile('$i$n')];
  Future<int> count() async => _ids().length;
}

const repo = Repo();

class ProfileState extends ThorState {
  final info = query(repo.info);
  final people = queryWith(repo.page, arg: 0);
  final total = query(repo.count);
  final editing = state(false);

  String name() => info.data.value?.name ?? '';
  bool busy() => info.loading.value;
  void next() => people.setArg(people.arg.value + 1);
  void reload() => info.refresh();
}

final profile = ProfileState();
''';

// A query whose argument is a class that travels as JSON.
const _filtered = r'''
import 'package:thor_ui/thor_ui.dart';

class OrdersFilter {
  const OrdersFilter({this.q = '', this.page = 1, this.tags = const []});
  factory OrdersFilter.fromJson(Map<String, Object?> json) => OrdersFilter(
    q: json['q']! as String,
    page: json['page']! as int,
    tags: [for (final t in json['tags']! as List<Object?>) t! as String],
  );
  final String q;
  final int page;
  final List<String> tags;
  OrdersFilter copyWith({String? q, int? page, List<String>? tags}) =>
      OrdersFilter(q: q ?? this.q, page: page ?? this.page, tags: tags ?? this.tags);
  Map<String, Object?> toJson() => {'q': q, 'page': page, 'tags': tags};
}

Future<List<String>> list(OrdersFilter f) async => [f.q];

class OrdersState extends ThorState {
  final orders = queryWith(list, arg: const OrdersFilter());

  void search(String q) => orders.setArg(orders.arg.value.copyWith(q: q, page: 1));
  void next() => orders.setArg(
    orders.arg.value.copyWith(page: orders.arg.value.page + 1),
  );
  int page() => orders.arg.value.page;
}

final orders = OrdersState();
''';

// A query whose argument is a record of simple values.
const _recorded = r'''
import 'package:thor_ui/thor_ui.dart';

class Profile {
  const Profile(this.name);
  final String name;
}

Future<List<String>> fetch((String, {int page, double ratio}) f) async => [f.$1];

class ListState extends ThorState {
  final list = queryWith(fetch, arg: ('', page: 1, ratio: 0.5));

  void next() => list.setArg((
    list.arg.value.$1,
    page: list.arg.value.page + 1,
    ratio: list.arg.value.ratio,
  ));
}

final listState = ListState();
''';

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
    test('a query field gives its members and nothing else', () async {
      final (code, problems) = await _registry(_profile);
      expect(problems, isEmpty);
      expect(code, contains("...s.info.members('info')"));
      expect(code, contains("...s.people.members('people')"));
      expect(
        code,
        contains(
          "ThorMember.state('editing', s.editing, variants: const [false, true])",
        ),
      );
      // The repository never becomes a member: only what went through
      // query(...) is callable.
      expect(code, isNot(contains('repo')));
    });

    test('lists the endpoints thor build prints', () async {
      final ids = await _resolve(
        _profile,
        (lib) async => queryEndpoints(lib.element.classes),
      );
      expect(ids, [
        'ProfileState.info',
        'ProfileState.people',
        'ProfileState.total',
      ]);
    });

    test('a result that is not JSON is THOR-B021', () async {
      final (_, problems) = await _registry(
        _profile.replaceFirst(
          '  Map<String, Object?> toJson() => {\'name\': name};\n',
          '',
        ),
      );
      expect(problems.single.toString(), contains('THOR-B021'));
      expect(problems.single.toString(), contains('ProfileState.info'));
      expect(problems.single.toString(), contains('toJson()'));
    });

    test('an argument that is not JSON is THOR-B021', () async {
      // `Profile` has toJson/fromJson: it is fine as an argument now; a
      // class without them is not.
      final (_, problems) = await _registry(
        _profile
            .replaceFirst('page(int n)', 'page(Filter n)')
            .replaceFirst('arg: 0', 'arg: const Filter()')
            .replaceFirst(
              'void next() => people.setArg(people.arg.value + 1);',
              '',
            )
            .replaceFirst(
              'class Repo {',
              'class Filter {\n  const Filter();\n}\n\nclass Repo {',
            ),
      );
      expect(problems.single.toString(), contains('THOR-B021'));
      expect(problems.single.toString(), contains('takes an argument'));
      expect(problems.single.toString(), contains('toJson()'));
      expect(problems.single.toString(), contains('record'));
    });

    test('an argument may be a class with toJson and fromJson', () async {
      final (code, problems) = await _registry(_filtered);
      expect(problems, isEmpty);
      // The registry says how the argument becomes JSON and back.
      expect(
        code,
        contains(
          "...s.orders.members('orders', argToJson: (a) => a.toJson(), "
          'argFromJson: t',
        ),
      );
      expect(code, contains('OrdersFilter.fromJson'));
    });

    test('a query with a record argument is in the calls set', () async {
      final (code, problems) = await _registry('''
import 'package:thor_ui/thor_ui.dart';

Future<List<String>> fetchNear(({double lat, double lng}) p) async => [];
Future<void> store(String s) async {}

class MapState extends ThorState {
  final near = queryWith(fetchNear, arg: (lat: 0.0, lng: 0.0));
  final save = commandWith(store);
}
''');
      expect(problems, isEmpty);
      expect(code, contains("calls: const {'near', 'save'}"));
    });

    test('an argument may be a record of simple values', () async {
      final (code, problems) = await _registry(_recorded);
      expect(problems, isEmpty);
      expect(
        code,
        contains(
          r"argToJson: (a) => {'\$1': a.$1, 'page': a.page, 'ratio': a.ratio}",
        ),
      );
      // A double comes back from JSON as an int when it has no fraction.
      expect(
        code,
        contains(
          r"argFromJson: (j) => (j['\$1']! as String, "
          "page: j['page']! as int, "
          "ratio: (j['ratio']! as num).toDouble())",
        ),
      );
    });

    test('a record with a class inside is THOR-B021', () async {
      final (_, problems) = await _registry(
        _recorded
            .replaceFirst(
              '{int page, double ratio}) f',
              '{int page, Profile ratio}) f',
            )
            .replaceFirst('[f.\$1]', '[f.ratio.name]')
            .replaceFirst('ratio: 0.5)', "ratio: Profile('x'))")
            .replaceFirst('list.arg.value.\$1,', "'',")
            .replaceFirst(
              'ratio: list.arg.value.ratio',
              'ratio: list.arg.value.ratio',
            ),
      );
      expect(problems.single.toString(), contains('THOR-B021'));
    });
  });

  group('the lite translation', () {
    late String js;
    setUpAll(() async => js = await _lite(_profile));

    test('makes each query with the part `query`', () {
      expect(js, contains('// thor-lite parts: json query'));
      expect(
        js,
        contains(
          r"$Q($, 'ProfileState', 'info', null, (j) => Profile.fromJson(j));",
        ),
      );
      expect(
        js,
        contains(
          r"$Q($, 'ProfileState', 'people', 0, "
          r'(j) => j.map((x) => Profile.fromJson(x)), 1);',
        ),
      );
      expect(js, contains(r"'info$loading': () => info.loading.value"));
      expect(js, contains(r"'info$refresh': () => info.refresh()"));
    });

    group('ssr: false', () {
      Future<String> lite(String queries, [String extra = '']) => _lite(
        _profile
            .replaceFirst(
              '  final info = query(repo.info);\n'
              '  final people = queryWith(repo.page, arg: 0);\n',
              queries,
            )
            .replaceFirst('  final editing = state(false);\n', '$extra\n'),
      );

      test(
        'the state wakes at hydration and asks what nothing asked',
        () async {
          final out = await lite(
            '  final info = query(repo.info, ssr: false);\n'
            '  final people = queryWith(repo.page, arg: 0, ssr: false);\n',
          );
          expect(out, contains('idle: true'));
          // Only where the page names the state: another page of the app
          // makes no request.
          expect(out, contains('named: true'));
          expect(out, contains('lifecycle'));
          expect(
            out,
            contains(
              r'$l: { h: () => { if (!info.loading.peek() && info.data.peek() '
              '== null) info.refresh(); if (!people.loading.peek() && '
              'people.data.peek() == null) people.refresh(); } }',
            ),
          );
        },
      );

      test('after the state\'s own onHydrated, which may ask first', () async {
        final out = await lite(
          '  final info = query(repo.info, ssr: false);\n'
              '  final people = queryWith(repo.page, arg: 0);\n',
          '  void onHydrated() => people.setArg(2);\n',
        );
        expect(
          out,
          contains(
            r'h: () => { try { return onHydrated(); } finally { if (!info.loading.peek()',
          ),
        );
        // Only the query that opted out is started.
        expect(out, isNot(contains('people.loading.peek()')));
      });

      test('a query nothing has asked yet starts waiting, as drawn', () async {
        final out = await lite(
          '  final info = query(repo.info, ssr: false);\n'
          '  final people = queryWith(repo.page, arg: 0);\n',
        );
        expect(out, contains('info.ssrOff = 1;'));
        expect(out, isNot(contains('people.ssrOff')));
      });

      test('a query that draws on the server starts nothing', () async {
        for (final q in ['', ', ssr: true']) {
          final out = await lite(
            '  final info = query(repo.info$q);\n'
            '  final people = queryWith(repo.page, arg: 0);\n',
          );
          expect(out, isNot(contains('idle: true')));
          expect(out, isNot(contains('named: true')));
          expect(out, isNot(contains('.loading.peek()')));
        }
      });

      test('a value that is not a literal is an error', () async {
        await expectLater(
          lite(
            '  final info = query(repo.info, ssr: _later);\n'
                '  final people = queryWith(repo.page, arg: 0);\n',
            '  static const _later = false;\n',
          ),
          throwsA(predicate((e) => '$e'.contains('`ssr:` takes a literal'))),
        );
      });
    });

    test('never translates the server function', () {
      // dart:io and sync* would be lite errors if the repository were
      // walked; it is not in the output at all.
      expect(js, isNot(contains('Repo')));
      expect(js, isNot(contains('hostname')));
      expect(js, isNot(contains('_ids')));
    });

    test('state methods read and drive the query', () {
      expect(js, contains('info.data.value?.name'));
      expect(js, contains('people.setArg(people.arg.value + 1)'));
      expect(js, contains('info.refresh()'));
    });

    test('a class argument brings its toJson and fromJson', () async {
      final orders = await _lite(_filtered);
      expect(orders, contains('toJson()'));
      expect(orders, contains('fromJson('));
      expect(
        orders,
        contains(
          r"$Q($, 'OrdersState', 'orders', $c1, null, 1, null, "
          '(j) => OrdersFilter.fromJson(j), (a) => a.toJson());',
        ),
      );
      // The state's methods drive it with copyWith.
      expect(orders, contains('orders.setArg(orders.arg.value.copyWith('));
    });

    test('a record argument is read back field by field', () async {
      final list = await _lite(_recorded);
      expect(
        list,
        contains(
          r"$Q($, 'ListState', 'list', Object.freeze({ $1: '', page: 1, ratio: 0.5 }), null, 1, null, "
          r"(j) => Object.freeze({ $1: j.get('$1'), page: j.get('page'), ratio: j.get('ratio') }));",
        ),
      );
    });

    test('a class that is not an argument keeps its JSON out', () async {
      // Profile has toJson/fromJson but no query uses it as an argument or
      // a result here: nothing of it is translated.
      final orders = await _lite(_filtered);
      expect(orders, isNot(contains('Profile')));
    });
  });
}
