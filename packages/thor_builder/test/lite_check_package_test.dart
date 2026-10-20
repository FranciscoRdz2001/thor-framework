// `checkLitePackage` (`thor analyze --lite`): a package on disk, with no
// ThorState, whose data classes the build of another package would reject.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thor_builder/src/app_steps.dart';

Future<String> _package(Map<String, String> files) async {
  final lib = await Isolate.resolvePackageUri(
    Uri.parse('package:thor_builder/src/app_steps.dart'),
  );
  final builder = p.normalize(p.join(p.dirname(lib!.toFilePath()), '..', '..'));
  final checkout = p.dirname(p.dirname(builder));
  final tmp = Directory.systemTemp.createTempSync('thor_lite_check_');
  addTearDown(() => tmp.deleteSync(recursive: true));
  final app = p.join(tmp.resolveSymbolicLinksSync(), 'protocol');
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
      {...package, 'rootUri': '${base.resolve(package['rootUri']! as String)}'},
    {
      'name': 'protocol',
      'rootUri': '${Uri.directory(app)}',
      'packageUri': 'lib/',
      'languageVersion': '3.8',
    },
  ];
  File(p.join(app, '.dart_tool', 'package_config.json'))
    ..createSync(recursive: true)
    ..writeAsStringSync(jsonEncode({...config, 'packages': packages}));
  File(
    p.join(app, 'pubspec.yaml'),
  ).writeAsStringSync('name: protocol\nenvironment:\n  sdk: ^3.10.0\n');
  for (final f in files.entries) {
    File(p.join(app, 'lib', f.key))
      ..createSync(recursive: true)
      ..writeAsStringSync(f.value);
  }
  return app;
}

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
    'a protocol package with Uri.parse in a fromJson is refused',
    () async {
      final app = await _package({'status.dart': _status});
      final out = StringBuffer(), err = StringBuffer();
      final code = await checkLitePackage(app, out: out, err: err);
      expect(code, 1);
      expect('$err', contains('lib/status.dart'));
      expect('$err', contains('THOR-B012'));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'a package inside the subset passes',
    () async {
      final app = await _package({
        'status.dart': _status
            .replaceAll('Uri.parse(', '(')
            .replaceAll('final Uri url', 'final String url'),
      });
      final out = StringBuffer(), err = StringBuffer();
      final code = await checkLitePackage(app, out: out, err: err);
      expect(code, 0, reason: '$err');
      expect('$out', contains('1 data class'));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
