// `thor: resources:` / `thor: sdk:`: what the compiled server
// reads at run time reaches build/resources.
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thor_cli/src/resources.dart';
import 'package:thor_cli/src/run.dart' show ThorException;
import 'package:thor_cli/src/workspace.dart';

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('thor_res_'));
  tearDown(() => root.deleteSync(recursive: true));

  Project app({String thor = '', String dep = ''}) {
    File(p.join(root.path, 'dev', 'pubspec.yaml'))
      ..createSync(recursive: true)
      ..writeAsStringSync('name: dev\n$dep');
    File(p.join(root.path, 'dev', 'lib', 'assets', 'bridge.js'))
      ..createSync(recursive: true)
      ..writeAsStringSync('// bridge');
    File(p.join(root.path, 'dev', 'lib', 'one.txt')).writeAsStringSync('1');
    File(p.join(root.path, 'app', 'pubspec.yaml'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        'name: app\ndependencies:\n  thor_ui: any\n  dev:\n    path: ../dev\n$thor',
      );
    File(p.join(root.path, 'app', '.dart_tool', 'package_config.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {'name': 'dev', 'rootUri': '../../dev', 'packageUri': 'lib/'},
          ],
        }),
      );
    return Project(p.join(root.path, 'app'));
  }

  test('a package lists files and folders under thor.resources', () {
    final project = app(
      dep: 'thor:\n  resources:\n    - assets\n    - one.txt\n',
    );
    final res = ServerResources(project);
    expect(res.declared(), {
      'dev': ['assets', 'one.txt'],
    });
    final out = p.join(root.path, 'out');
    final files = res.copyInto(out)..sort();
    expect(files, [
      p.join('dev', 'assets', 'bridge.js'),
      p.join('dev', 'one.txt'),
    ]);
    expect(
      File(p.join(out, 'dev', 'assets', 'bridge.js')).readAsStringSync(),
      '// bridge',
    );
    expect(res.wantsSdk, isFalse);
  });

  test('nothing declared copies nothing', () {
    final res = ServerResources(app());
    expect(res.declared(), isEmpty);
    expect(res.copyInto(p.join(root.path, 'out')), isEmpty);
  });

  test('a path outside lib/ or a missing one is an error', () {
    expect(
      () => ServerResources(
        app(dep: 'thor:\n  resources:\n    - ../x\n'),
      ).declared(),
      throwsA(isA<ThorException>()),
    );
    expect(
      () => ServerResources(
        app(dep: 'thor:\n  resources:\n    - nope\n'),
      ).copyInto(p.join(root.path, 'out')),
      throwsA(isA<ThorException>()),
    );
  });

  test('thor.sdk bundles the SDK libraries', () {
    final res = ServerResources(app(thor: 'thor:\n  sdk: true\n'));
    expect(res.wantsSdk, isTrue);
    final out = p.join(root.path, 'out');
    res.copyInto(out);
    expect(
      File(p.join(out, 'dart-sdk', 'lib', 'core', 'core.dart')).existsSync(),
      isTrue,
    );
    expect(
      Directory(p.join(out, 'dart-sdk', 'lib', '_internal')).existsSync(),
      isTrue,
    );
  });
}
