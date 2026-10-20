// thorResource / thorDartSdkPath: files and the Dart SDK a compiled server
// reads at run time.
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

void main() {
  test('a package: URI resolves to its file (JIT)', () async {
    final file = await thorResource('package:thor_server/thor_server.dart');
    expect(file.existsSync(), isTrue);
    expect(
      await readThorResource('package:thor_server/thor_server.dart'),
      contains('library;'),
    );
  });

  test('a missing resource says where it looked and what to declare', () {
    expect(
      thorResource('package:thor_server/nope.js'),
      throwsA(
        isA<FileSystemException>().having(
          (e) => e.message,
          'message',
          allOf(contains('thor: resources:'), contains('build')),
        ),
      ),
    );
  });

  test('not a package: URI is an argument error', () {
    expect(thorResource('file:///x'), throwsArgumentError);
  });

  test('the SDK path is one with lib/_internal', () {
    final sdk = thorDartSdkPath();
    expect(sdk, isNotNull);
    expect(Directory('$sdk/lib/_internal').existsSync(), isTrue);
  });
  group('a build (no package config for it)', () {
    late Directory dir;
    late Directory before;
    setUp(() {
      before = Directory.current;
      dir = Directory.systemTemp.createTempSync('thor_res_').absolute;
      File('${dir.path}/build/resources/far_pkg/assets/bridge.js')
        ..createSync(recursive: true)
        ..writeAsStringSync('// bridge');
      Directory(
        '${dir.path}/build/resources/dart-sdk/lib/_internal',
      ).createSync(recursive: true);
      Directory.current = dir;
    });
    tearDown(() {
      Directory.current = before;
      dir.deleteSync(recursive: true);
    });

    test('a package: URI is read from build/resources', () async {
      final file = await thorResource('package:far_pkg/assets/bridge.js');
      expect(file.isAbsolute, isTrue);
      expect(file.readAsStringSync(), '// bridge');
    });

    test('the bundled SDK comes first, as an absolute path', () {
      final sdk = thorDartSdkPath()!;
      expect(Directory(sdk).isAbsolute, isTrue);
      expect(
        Directory(sdk).resolveSymbolicLinksSync(),
        Directory(
          '${dir.path}/build/resources/dart-sdk',
        ).resolveSymbolicLinksSync(),
      );
    });
  });
}
