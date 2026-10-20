// A state with `onHydrated` wakes only on the pages that name it (`named`);
// `bool get global => true` makes it wake everywhere.
import 'package:analyzer/dart/analysis/results.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:thor_lints/lite.dart';

Future<String> _lite(String source) => resolveSources(
  {'app|lib/shop.dart': source},
  (resolver) async {
    final lib = await resolver.libraryFor(AssetId.parse('app|lib/shop.dart'));
    final res =
        await lib.session.getResolvedLibraryByElement(lib)
            as ResolvedLibraryResult;
    return translateLiteStates([
      for (final u in res.units) LiteUnit('lib/shop.dart', u.unit),
    ]);
  },
  rootPackage: 'app',
  readAllSourcesFromFilesystem: true,
);

void main() {
  const state = '''
import 'package:thor_engine/thor_engine.dart';

class PollState extends ThorState {
  final n = state(0);

  @override
  void onHydrated() => n.value = 1;
}

final poll = PollState();
''';

  test('onHydrated without queries is named; global removes it', () async {
    final lazy = await _lite(state);
    expect(lazy, contains('idle: true'));
    expect(lazy, contains('named: true'));
    final app = await _lite(
      state.replaceFirst(
        '  @override\n  void onHydrated',
        '  @override\n  bool get global => true;\n\n  @override\n  void onHydrated',
      ),
    );
    expect(app, contains('idle: true'));
    expect(app, isNot(contains('named: true')));
  });
}
