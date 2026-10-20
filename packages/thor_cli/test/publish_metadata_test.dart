// What pub.dev asks of a package, checked without the network: `dart pub
// publish --dry-run` itself runs in `dart tool/publish_check.dart` (it
// resolves from pub.dev).
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final root = p.normalize(p.join(Directory.current.path, '..', '..'));
  final packages = [
    for (final dir in Directory(p.join(root, 'packages')).listSync())
      // thor_engine_oracle is internal: never published.
      if (dir is Directory &&
          p.basename(dir.path) != 'thor_engine_oracle' &&
          File(p.join(dir.path, 'pubspec.yaml')).existsSync())
        dir,
  ];

  test('there are packages to check', () => expect(packages, isNotEmpty));

  for (final dir in packages) {
    final name = p.basename(dir.path);
    group(name, () {
      final pubspec =
          loadYaml(File(p.join(dir.path, 'pubspec.yaml')).readAsStringSync())
              as YamlMap;

      test('metadata', () {
        final description = pubspec['description'] as String;
        expect(description.length, inInclusiveRange(60, 180));
        expect(pubspec['repository'], contains('/packages/$name'));
        expect(pubspec['issue_tracker'], isNotNull);
        final topics = pubspec['topics'] as YamlList;
        expect(topics.length, inInclusiveRange(1, 5));
        // Not on pub.dev yet: every package keeps publish_to: none until its
        // first release.
        expect(pubspec['publish_to'], 'none');
      });

      test('LICENSE is the root one, with README and CHANGELOG', () {
        expect(
          File(p.join(dir.path, 'LICENSE')).readAsStringSync(),
          File(p.join(root, 'LICENSE')).readAsStringSync(),
        );
        expect(File(p.join(dir.path, 'README.md')).existsSync(), isTrue);
        expect(File(p.join(dir.path, 'CHANGELOG.md')).existsSync(), isTrue);
      });

      test('siblings are path dependencies of a published-to-be version', () {
        final deps = pubspec['dependencies'] as YamlMap?;
        for (final entry in (deps ?? YamlMap()).entries) {
          if (!(entry.key as String).startsWith('thor_')) continue;
          expect(
            (entry.value as YamlMap)['path'],
            '../${entry.key}',
            reason: 'tool/publish_check.dart rewrites exactly this shape',
          );
        }
      });
    });
  }
}
