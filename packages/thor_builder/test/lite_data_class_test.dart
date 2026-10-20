// The builder (the registry of JSON models) and the lite translator (how a
// `state(...)` field is read back) agree on what a data class is
// (`isJsonDataClass`), also for a class a workspace package declares.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thor_builder/src/app_steps.dart';
import 'package:thor_lints/lite.dart';

const _model = '''
class Todo {
  const Todo(this.title);
  factory Todo.fromJson(Map<String, Object?> j) => Todo(j['t']! as String);
  final String title;
  Map<String, Object?> toJson() => {'t': title};
}

class Loose {
  const Loose(this.title);
  factory Loose.fromJson(Map<String, Object?> j) => Loose(j['t']! as String);
  final String title;
  Map<String, Object?> toJson(int indent) => {'t': title};
}
''';

const _state = '''
import 'package:shared_models/model.dart';
import 'package:thor_ui/thor_ui.dart';

class TodosState extends ThorState {
  final todos = state<List<Todo>>(<Todo>[]);
  final loose = state<Loose?>(null);
  String first() => todos.value.isEmpty ? '' : todos.value.first.title;
}
''';

void main() {
  test('the translator and the builder read a data class alike', () async {
    final (list, loose) = await resolveSources(
      {
        'pkg|lib/model.dart': _model,
        'app|lib/s.dart': _state.replaceAll('shared_models', 'pkg'),
      },
      (resolver) async {
        final lib = await resolver.libraryFor(AssetId.parse('app|lib/s.dart'));
        final state = lib.classes.single;
        DartType field(String name) =>
            (state.getField(name)!.type as InterfaceType).typeArguments.single;
        return (field('todos'), field('loose'));
      },
      rootPackage: 'app',
      readAllSourcesFromFilesystem: true,
    );
    expect(jsonStateModel(list)?.element.name, 'Todo');
    expect(isJsonDataClass(jsonStateModel(list)?.element), isTrue);
    // A `toJson` that takes a parameter is not one for either.
    expect(jsonStateModel(loose), isNull);
  });

  test('a data class of another package needs its source', () async {
    Future<List<LiteUnit>> units({required bool withPackage}) => resolveSources(
      {
        'pkg|lib/model.dart': _model,
        'app|lib/s.dart': _state.replaceAll('shared_models', 'pkg'),
      },
      (resolver) async {
        Future<List<LiteUnit>> of(String id, String name) async {
          final lib = await resolver.libraryFor(AssetId.parse(id));
          final result =
              await lib.session.getResolvedLibraryByElement(lib)
                  as ResolvedLibraryResult;
          return [for (final u in result.units) LiteUnit(name, u.unit)];
        }

        return [
          ...await of('app|lib/s.dart', 'lib/s.dart'),
          if (withPackage) ...await of('pkg|lib/model.dart', 'pkg/model.dart'),
        ];
      },
      rootPackage: 'app',
      readAllSourcesFromFilesystem: true,
    );

    final js = translateLiteStates(await units(withPackage: true));
    expect(js, contains('(j) => j.map((x) => Todo.fromJson(x))'));
    expect(js, isNot(contains('Loose.fromJson')));

    try {
      translateLiteStates(await units(withPackage: false));
      fail('expected a lite error');
    } on LiteTranslationException catch (e) {
      final error = e.errors.firstWhere(
        (x) => x.message.startsWith(dataClassSourceMissing),
      );
      expect(error.message, startsWith(dataClassSourceMissing));
      expect(error.message, contains('Todo'));
      expect(error.message, contains('package:pkg/model.dart'));
    }
  });

  test(
    'writeLiteStates adds the package that declares the model',
    () async {
      final lib = await Isolate.resolvePackageUri(
        Uri.parse('package:thor_builder/src/app_steps.dart'),
      );
      final builder = p.normalize(
        p.join(p.dirname(lib!.toFilePath()), '..', '..'),
      );
      final checkout = p.dirname(p.dirname(builder));
      final tmp = Directory.systemTemp.createTempSync('thor_data_class_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final root = tmp.resolveSymbolicLinksSync();
      final app = p.join(root, 'app');
      final shared = p.join(root, 'shared_models');
      final config =
          jsonDecode(
                File(
                  p.join(checkout, '.dart_tool', 'package_config.json'),
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      final base = Uri.directory(p.join(checkout, '.dart_tool'));
      final packages = [
        for (final package
            in (config['packages']! as List).cast<Map<String, Object?>>())
          {
            ...package,
            'rootUri': '${base.resolve(package['rootUri']! as String)}',
          },
        for (final (name, dir) in [('app', app), ('shared_models', shared)])
          {
            'name': name,
            'rootUri': '${Uri.directory(dir)}',
            'packageUri': 'lib/',
            'languageVersion': '3.8',
          },
      ];
      File(p.join(app, '.dart_tool', 'package_config.json'))
        ..createSync(recursive: true)
        ..writeAsStringSync(jsonEncode({...config, 'packages': packages}));
      File(
        p.join(app, 'pubspec.yaml'),
      ).writeAsStringSync('name: app\nenvironment:\n  sdk: ^3.10.0\n');
      File(p.join(app, 'lib', 's.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync(_state);
      File(p.join(shared, 'lib', 'model.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync(_model);

      final out = StringBuffer(), err = StringBuffer();
      final outPath = p.join(app, 'build', 'state.js');
      final code = await writeLiteStates(
        app,
        outPath: outPath,
        readable: true,
        out: out,
        err: err,
      );
      expect(code, 0, reason: '$err');
      final js = File(outPath).readAsStringSync();
      expect(js, contains('(j) => j.map((x) => Todo.fromJson(x))'));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
