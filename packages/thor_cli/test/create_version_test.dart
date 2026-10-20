import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// `thor create` says which thor it takes the packages from, and warns when
/// that checkout is stale, so an old global install doesn't go unnoticed
/// (the user got deprecated API from a checkout 430 commits behind).
void main() {
  late Directory tmp;
  late String cli;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('thor_create_version');
    cli = p.join(Directory.current.path, 'bin', 'thor.dart');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  ProcessResult git(String dir, List<String> args) => Process.runSync('git', [
    '-c',
    'user.name=t',
    '-c',
    'user.email=t@t',
    '-c',
    'commit.gpgsign=false',
    ...args,
  ], workingDirectory: dir);

  /// A fake thor checkout (just the folders `ThorHome` looks for) cloned
  /// from an origin that is one commit ahead.
  String fakeCheckout() {
    final origin = p.join(tmp.path, 'origin');
    for (final d in ['thor_ui', 'thor_cli']) {
      Directory(p.join(origin, 'packages', d)).createSync(recursive: true);
      File(p.join(origin, 'packages', d, 'f')).writeAsStringSync('1');
    }
    git(origin, ['init', '-q', '-b', 'master']);
    git(origin, ['add', '.']);
    git(origin, ['commit', '-qm', 'one']);
    final clone = p.join(tmp.path, 'clone');
    git(tmp.path, ['clone', '-q', origin, clone]);
    File(p.join(origin, 'packages', 'thor_ui', 'f')).writeAsStringSync('2');
    git(origin, ['commit', '-qam', 'two']);
    git(clone, ['fetch', '-q']);
    return clone;
  }

  test('create prints the checkout and warns that it is behind', () {
    final checkout = fakeCheckout();
    final work = Directory(p.join(tmp.path, 'work'))..createSync();
    final r = Process.runSync(
      'dart',
      [cli, 'create', 'shop', '--no-pub'],
      workingDirectory: work.path,
      environment: {'THOR_HOME': checkout},
    );
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    final out = r.stdout as String;
    expect(
      out,
      matches(
        RegExp(r'thor: .*clone @ [0-9a-f]{7,} \(\d{4}-\d\d-\d\d\), master'),
      ),
    );
    expect(out, contains('1 commit behind'));
    expect(out, contains('tool/thor setup'));
    expect(Directory(p.join(work.path, 'shop')).existsSync(), isTrue);
  });

  test('create --git says the repository and the ref', () {
    final work = Directory(p.join(tmp.path, 'work'))..createSync();
    final r = Process.runSync('dart', [
      cli,
      'create',
      'shop',
      '--no-pub',
      '--git',
      'https://x/thor.git',
    ], workingDirectory: work.path);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    expect(r.stdout, contains('thor: git https://x/thor.git @ master'));
  });
}
