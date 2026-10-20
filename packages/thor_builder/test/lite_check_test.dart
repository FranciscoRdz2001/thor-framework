// `checkLiteSubset`: whether a package fits the lite subset without a build:
// its states and every data class, named by a state of the package or not.
@TestOn('vm')
library;

import 'package:analyzer/dart/analysis/results.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:thor_lints/lite.dart';

Future<LiteCheck> _check(Map<String, String> files) => resolveSources(
  {for (final f in files.entries) 'app|lib/${f.key}': f.value},
  (resolver) async {
    final units = <LiteUnit>[];
    for (final name in files.keys) {
      final lib = await resolver.libraryFor(AssetId.parse('app|lib/$name'));
      final result =
          await lib.session.getResolvedLibraryByElement(lib)
              as ResolvedLibraryResult;
      for (final u in result.units) {
        units.add(LiteUnit('lib/${u.path.split('/').last}', u.unit));
      }
    }
    return checkLiteSubset(units);
  },
  rootPackage: 'app',
  readAllSourcesFromFilesystem: true,
);

const _status = '''
class SessionStatus {
  const SessionStatus(this.url);
  factory SessionStatus.fromJson(Map<String, Object?> j) =>
      SessionStatus(Uri.parse(j['url']! as String));
  final Uri url;
  Map<String, Object?> toJson() => {'url': '\$url'};
}
''';

void main() {
  test(
    'a data class no state names is checked: Uri.parse is outside',
    () async {
      final check = await _check({'status.dart': _status});
      expect(check.ok, isFalse);
      expect(check.states, 0);
      expect(check.dataClasses, 1);
      expect(check.errors.map((e) => e.message).join('\n'), contains('Uri'));
      expect(check.errors.first.path, 'lib/status.dart');
    },
  );

  test('a data class inside the subset passes', () async {
    final check = await _check({
      'status.dart': '''
class SessionStatus {
  const SessionStatus(this.url);
  factory SessionStatus.fromJson(Map<String, Object?> j) =>
      SessionStatus(j['url']! as String);
  final String url;
  bool get isLocal => url.startsWith('http://localhost');
  Map<String, Object?> toJson() => {'url': url};
}
''',
    });
    expect(check.errors, isEmpty);
    expect(check.ok, isTrue);
    expect(check.dataClasses, 1);
  });

  test('a method of a data class is checked too', () async {
    final check = await _check({
      'status.dart': '''
class SessionStatus {
  const SessionStatus(this.url);
  factory SessionStatus.fromJson(Map<String, Object?> j) =>
      SessionStatus(j['url']! as String);
  final String url;
  Uri get parsed => Uri.parse(url);
  Map<String, Object?> toJson() => {'url': url};
}
''',
    });
    expect(check.ok, isFalse);
  });

  test('nothing to check: no state and no data class', () async {
    final check = await _check({'plain.dart': 'int one() => 1;\n'});
    expect(check.empty, isTrue);
    expect(check.ok, isTrue);
  });
}
