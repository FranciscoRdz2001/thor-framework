// `query.snapshot` (Flutter's AsyncSnapshot) in a lite state.
import 'package:analyzer/dart/analysis/results.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:thor_lints/lite.dart';

const _feed = r'''
import 'package:thor_ui/thor_ui.dart';

class Repo {
  const Repo();
  Future<List<String>> items() async => ['a'];
}

const repo = Repo();

class FeedState extends ThorState {
  final items = query(repo.items);

  bool ready() => items.snapshot.hasData;
  bool failed() => items.snapshot.hasError;
  String message() => items.snapshot.error ?? '';
  bool offline() => items.snapshot.errorKind == ServerErrorKind.network;
  bool waiting() => items.snapshot.connectionState == ConnectionState.waiting;
  int count() {
    final snap = items.snapshot;
    return snap.hasData ? snap.data!.length : 0;
  }
}

final feed = FeedState();
''';

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
  late String js;
  setUpAll(() async => js = await _lite(_feed));

  test('the snapshot is read from the query, its fields as they are', () {
    expect(js, contains('items.snapshot().hasData'));
    expect(js, contains('items.snapshot().hasError'));
    expect(js, contains(r'items.snapshot().error ?? '));
    expect(js, contains(r'$nn(snap.data).length'));
  });

  test('connectionState and errorKind are the enums of thor', () {
    expect(
      js,
      contains(
        r'items.snapshot().connectionState === $ConnectionState$values[1]',
      ),
    );
    expect(
      js,
      contains(r'items.snapshot().errorKind === $ServerErrorKind$values[0]'),
    );
    expect(js, contains(r'thor.CS = $ConnectionState$values;'));
    expect(js, contains(r'thor.K = $ServerErrorKind$values;'));
  });

  test('the page can switch on the phase and print the message', () {
    expect(js, contains(r"'items$phase': () => items.phase()"));
    expect(js, contains(r"'items$message': () => items.error.value ?? ''"));
  });

  test(
    'a state that never asks for a snapshot ships no ConnectionState',
    () async {
      final out = await _lite(
        _feed.replaceAll(RegExp(r'  bool ready.*?\n\}\n', dotAll: true), '}\n'),
      );
      expect(out, isNot(contains('ConnectionState')));
      expect(out, isNot(contains('thor.CS')));
    },
  );

  test('requireData is a hint to use `data!`', () async {
    await expectLater(
      _lite(
        _feed.replaceFirst(
          'bool ready() => items.snapshot.hasData;',
          'int ready() => items.snapshot.requireData.length;',
        ),
      ),
      throwsA(
        isA<LiteTranslationException>().having(
          (e) => e.toString(),
          'message',
          allOf(contains('requireData'), contains('data!')),
        ),
      ),
    );
  });

  test('snapshot fields the browser does not have are a lite error', () async {
    await expectLater(
      _lite(
        _feed.replaceFirst(
          'bool ready() => items.snapshot.hasData;',
          'bool ready() => items.snapshot.toString().isEmpty;',
        ),
      ),
      throwsA(isA<LiteTranslationException>()),
    );
  });
}
